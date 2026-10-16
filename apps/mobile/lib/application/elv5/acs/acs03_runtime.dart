import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_acs_persistence.dart';

/// ACS-03 persisted-fact boundary.
///
/// The current schema proves the door/role aggregate, but does not yet persist
/// the exact lock state/event profile plus distinct conductive-feed/control-path
/// identities required by the authoritative ACS-03 dossier. Legacy catalog
/// `operatingCurrentA` is binary floating point and is intentionally not
/// promoted into an exact ELV5 engineering fact.
///
/// Until that exact contract is persisted, ACS-03 remains addressable and
/// produces durable BLOCKED evidence rather than `PROCESS_RUNTIME_NOT_IMPLEMENTED`
/// or a nominal calculation with invented state semantics.
final class Acs03PersistedInputResolver
    implements Elv5ProcessInputResolver<Acs03Input> {
  Acs03PersistedInputResolver({
    required this.acsStore,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5AcsMutationStore acsStore;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.acs03;

  @override
  Future<Elv5CapturedInput<Acs03Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('ACS03_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'DOOR') {
      throw StateError('ACS03_SUBJECT_KIND_MUST_BE_DOOR');
    }

    final door = await acsStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
      subjectId: request.subject.id,
    );
    if (door == null) {
      throw StateError('ACS03_DOOR_FACTS_MISSING:${request.subject.id}');
    }
    final doorId = _text(door.payload, 'doorAssemblyId');
    if (doorId != request.subject.id) {
      throw StateError('ACS03_DOOR_ID_MISMATCH:$doorId:${request.subject.id}');
    }

    final assignments = _objects(
      door.payload['roleAssignments'],
      'roleAssignments',
    );
    final lockAssignments = assignments
        .where((row) => _text(row, 'roleCode').toUpperCase() == 'LOCK')
        .toList();
    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'ACS_DOOR_CALCULATION', doorId),
    ];
    final policyFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs03-policy-basis.v1',
      'topologyProfileRef': door.payload['topologyProfileRef'],
      'safetyMode': door.payload['safetyMode'],
      'resolvedElectricalPolicy': null,
    });
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs03-captured-door-basis.v1',
      'aggregateId': door.aggregateId,
      'aggregateRevision': door.revision,
      'payload': door.payload,
    });

    if (lockAssignments.isEmpty) {
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: 'ACS03_LOCK_ROLE_ASSIGNMENT_MISSING',
        inputFingerprint: inputFingerprint,
        policyFingerprint: policyFingerprint,
        dependencies: dependencies,
        evidence: <String, Object?>{
          'doorId': doorId,
          'doorAggregateId': door.aggregateId,
          'doorAggregateRevision': door.revision,
          'requiredRoleCode': 'LOCK',
        },
      );
    }
    if (lockAssignments.length != 1) {
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: 'ACS03_LOCK_ROLE_ASSIGNMENT_AMBIGUOUS',
        inputFingerprint: inputFingerprint,
        policyFingerprint: policyFingerprint,
        dependencies: dependencies,
        evidence: <String, Object?>{
          'doorId': doorId,
          'lockAssignmentCount': lockAssignments.length,
          'requiredMultiplicity': 1,
        },
      );
    }

    final lockId = _text(lockAssignments.single, 'componentId');
    dependencies.add(
      _dependency(request, 'FACT', 'ACS_LOCK_COMPONENT', lockId),
    );
    throw Elv5CaptureBlockedException(
      request: request,
      reasonCode: 'ACS03_EXACT_ELECTRICAL_EVENT_CONTRACT_REQUIRED',
      inputFingerprint: inputFingerprint,
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      evidence: <String, Object?>{
        'doorId': doorId,
        'lockId': lockId,
        'doorAggregateId': door.aggregateId,
        'doorAggregateRevision': door.revision,
        'topologyProfileRef': door.payload['topologyProfileRef'],
        'missingMandatoryFacts': <String>[
          'EXACT_LOCK_STATE_PROFILE',
          'EVENT_DURATION_AND_SIMULTANEITY_POLICY',
          'CONDUCTIVE_FEED_PATH',
          'CONTROL_PATH',
          'PWR03_EVENT_MAPPING',
        ],
        'rejectedFallback': 'LEGACY_DOUBLE_OPERATING_CURRENT',
      },
    );
  }

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relationKind,
    String domain,
    String subjectId,
  ) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relationKind,
      'domain': domain,
      'subjectId': subjectId,
    };
    return Elv5DependencyMarker(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      dependencyKey: utf8.decode(_encoder.encode(value)),
      dependencyKeySha256: _encoder.sha256(value),
      logicalNodeKeySha256: _encoder.sha256(request.nodeKey.toCanonicalValue()),
      relationKind: relationKind,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Acs03Input, Acs03Result> buildAcs03Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Acs03Input, Acs03Result>(
  processCode: Elv5ProcessCode.acs03,
  calculate: const Acs03ElectricalKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-acs03-output.v1',
    'status': result.status.name,
    'governingCaseId': result.governingCaseId,
    'limitingReason': result.limitingReason,
    'cases': [
      for (final item in result.cases)
        <String, Object?>{
          'eventId': item.eventId,
          'state': item.state.name,
          'durationMicroseconds': item.durationMicroseconds.toString(),
          'status': item.status.name,
          'terminalVoltageLowerV': item.terminalVoltage?.lower.value.toMap(),
          'terminalVoltageUpperV': item.terminalVoltage?.upper.value.toMap(),
          'sharedTrunkCurrentLowerA':
              item.sharedTrunkCurrent?.lower.value.toMap(),
          'sharedTrunkCurrentUpperA':
              item.sharedTrunkCurrent?.upper.value.toMap(),
          'minimumVoltageMarginV': item.minimumVoltageMargin?.value.toMap(),
          'maximumVoltageMarginV': item.maximumVoltageMargin?.value.toMap(),
          'reason': item.reason,
        },
    ],
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-acs03-evidence.v1',
    'source': 'ELV5_ACS_DOOR_PLUS_VERIFIED_ELV4_PWR_EVIDENCE',
    'captureRevision': captured.captureRevision,
  },
  executionOf: (result) => result.status == Acs03AssessmentStatus.blocked
      ? Elv5Execution.blocked
      : Elv5Execution.succeeded,
  completionOf: (result) =>
      result.status == Acs03AssessmentStatus.unresolved ||
              result.status == Acs03AssessmentStatus.blocked
          ? Elv5Completion.incomplete
          : Elv5Completion.complete,
  assessmentOf: (result) => switch (result.status) {
    Acs03AssessmentStatus.pass => Elv5Assessment.pass,
    Acs03AssessmentStatus.fail => Elv5Assessment.fail,
    Acs03AssessmentStatus.unresolved => Elv5Assessment.unresolved,
    Acs03AssessmentStatus.blocked => Elv5Assessment.unresolved,
  },
  nowUtc: nowUtc,
);

List<Map<String, Object?>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be list.');
  return [
    for (final item in value)
      if (item is Map)
        Map<String, Object?>.from(item)
      else
        throw FormatException('$field contains non-object entry.'),
  ];
}

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return raw.trim();
}
