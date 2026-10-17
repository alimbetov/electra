import 'dart:convert';

import 'package:engineering_core/engineering_core.dart'
    show
        PowerDependencyKey,
        PowerEvaluationScopeKind,
        PowerProcessCode,
        PowerRational;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import '../power/elv4_current_evidence_source.dart';
import 'acs03_electrical_contract.dart';
import 'elv5_acs_persistence.dart';

final class Acs03PersistedInputResolver
    implements Elv5ProcessInputResolver<Acs03Input> {
  Acs03PersistedInputResolver({
    required this.acsStore,
    required this.contractSource,
    required this.powerEvidence,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5AcsMutationStore acsStore;
  final Acs03ElectricalContractSource contractSource;
  final Elv4CurrentEvidenceSource powerEvidence;
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
    final doorFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs03-door-basis.v2',
      'aggregateId': door.aggregateId,
      'aggregateRevision': door.revision,
      'payload': door.payload,
    });

    if (lockAssignments.length != 1) {
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: lockAssignments.isEmpty
            ? 'ACS03_LOCK_ROLE_ASSIGNMENT_MISSING'
            : 'ACS03_LOCK_ROLE_ASSIGNMENT_AMBIGUOUS',
        inputFingerprint: doorFingerprint,
        policyFingerprint: _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-acs03-policy-basis.v2',
          'topologyProfileRef': door.payload['topologyProfileRef'],
        }),
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
    final contractSnapshot = await contractSource.loadActiveForDoor(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      doorId: doorId,
    );
    if (contractSnapshot == null) {
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: 'ACS03_EXACT_ELECTRICAL_EVENT_CONTRACT_REQUIRED',
        inputFingerprint: doorFingerprint,
        policyFingerprint: _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-acs03-policy-basis.v2',
          'topologyProfileRef': door.payload['topologyProfileRef'],
          'electricalContract': null,
        }),
        dependencies: dependencies,
        evidence: <String, Object?>{
          'doorId': doorId,
          'lockId': lockId,
          'missingMandatoryFacts': <String>[
            'EXACT_LOCK_STATE_PROFILE',
            'EVENT_DURATION_AND_SIMULTANEITY_POLICY',
            'CONDUCTIVE_FEED_PATH',
            'CONTROL_PATH',
            'PWR01_PWR03_EVENT_MAPPING',
          ],
          'rejectedFallback': 'LEGACY_DOUBLE_OPERATING_CURRENT',
        },
      );
    }
    final contract = contractSnapshot.contract;
    if (contract.doorId != doorId || contract.lockId != lockId) {
      throw StateError('ACS03_CONTRACT_IDENTITY_MISMATCH:$doorId:$lockId');
    }
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'ACS03_ELECTRICAL_CONTRACT',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    );

    final events = <Acs03OperatingEvent>[];
    final evidence = <Acs03PwrEvidence>[];
    final upstreamGenerations = <String, int>{};
    final upstreamBasis = <Map<String, Object?>>[];
    String? requiredMembershipFingerprint;

    for (final event in contract.events) {
      final pwr03 = await _requireSingleCurrent(
        request: request,
        processCode: PowerProcessCode.pwr03,
        scenarioId: event.scenarioId,
        segmentId: event.segmentId,
        subjectId: event.domainId,
        reasonCode: 'ACS03_PWR03_EVENT_EVIDENCE_MISSING',
        dependencies: dependencies,
        inputFingerprint: doorFingerprint,
        policyFingerprint: contractSnapshot.contentHash,
      );
      final pwr01 = await _requireSingleCurrent(
        request: request,
        processCode: PowerProcessCode.pwr01,
        scenarioId: event.scenarioId,
        segmentId: event.segmentId,
        subjectId: event.lockLoadOriginId,
        reasonCode: 'ACS03_PWR01_LOCK_LOAD_EVIDENCE_MISSING',
        dependencies: dependencies,
        inputFingerprint: doorFingerprint,
        policyFingerprint: contractSnapshot.contentHash,
      );

      final pwr01Output = pwr01.output;
      if (pwr01Output['completeA'] != true) {
        _blocked(
          request,
          'ACS03_PWR01_LOCK_CURRENT_INCOMPLETE',
          doorFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'eventId': event.eventId,
            'evaluationId': pwr01.evaluationId,
          },
        );
      }
      final knownA = _powerRational(pwr01Output['knownA'], 'knownA');
      final expectedA = event.lockCurrent.value;
      if (_elv5(knownA) != expectedA) {
        _blocked(
          request,
          'ACS03_LOCK_CURRENT_EVIDENCE_MISMATCH',
          doorFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'eventId': event.eventId,
            'expectedA': expectedA.toMap(),
            'pwr01A': knownA.toMap(),
            'evaluationId': pwr01.evaluationId,
          },
        );
      }

      final pwr03Output = pwr03.output;
      if (pwr03Output['physicalComplete'] != true) {
        _blocked(
          request,
          'ACS03_PWR03_PHYSICAL_CLOSURE_INCOMPLETE',
          doorFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'eventId': event.eventId,
            'evaluationId': pwr03.evaluationId,
          },
        );
      }
      final terminal = _singleById(
        pwr03Output['terminals'],
        'loadId',
        event.lockLoadOriginId,
        'ACS03_PWR03_LOCK_TERMINAL_MISSING',
      );
      final section = _singleById(
        pwr03Output['sections'],
        'sectionId',
        event.sharedTrunkSectionId,
        'ACS03_PWR03_SHARED_TRUNK_SECTION_MISSING',
      );
      final membershipFingerprint = _membershipFingerprint(pwr03);
      requiredMembershipFingerprint ??= membershipFingerprint;

      final terminalMinimum = Voltage(
        _elv5(_powerRational(terminal['minimumV'], 'minimumV')),
      );
      final terminalMaximum = Voltage(
        _elv5(_powerRational(terminal['maximumV'], 'maximumV')),
      );
      final trunkCurrent = Current(
        _elv5(_powerRational(section['currentA'], 'currentA')),
      );
      final currentMargin = Current(
        _elv5(_powerRational(section['currentMarginA'], 'currentMarginA')),
      );

      events.add(
        Acs03OperatingEvent(
          eventId: event.eventId,
          state: event.state,
          durationMicroseconds: event.durationMicroseconds,
          lockCurrent: event.lockCurrent,
        ),
      );
      evidence.add(
        Acs03PwrEvidence(
          eventId: event.eventId,
          membershipFingerprint: membershipFingerprint,
          terminalVoltage: Elv5Interval<VoltageDim>(
            terminalMinimum,
            terminalMaximum,
          ),
          sharedTrunkCurrent: Elv5Interval<CurrentDim>(
            trunkCurrent,
            trunkCurrent,
          ),
          sourceCurrentMargin: Elv5Interval<CurrentDim>(
            currentMargin,
            currentMargin,
          ),
        ),
      );

      for (final snapshot in <Elv4CurrentEvaluationSnapshot>[pwr01, pwr03]) {
        upstreamGenerations[snapshot.nodeKey.sha256] =
            snapshot.pointerGeneration;
        dependencies.add(
          _dependency(
            request,
            'UPSTREAM_EVALUATION',
            snapshot.nodeKey.processCode == PowerProcessCode.pwr01
                ? 'ELV4_PWR01_CURRENT'
                : 'ELV4_PWR03_CURRENT',
            snapshot.evaluationId,
            memberId:
                '${snapshot.nodeKey.sha256}:${snapshot.pointerGeneration}:${snapshot.evidenceSha256}',
          ),
        );
        upstreamBasis.add(<String, Object?>{
          'evaluationId': snapshot.evaluationId,
          'nodeKeySha256': snapshot.nodeKey.sha256,
          'generation': snapshot.pointerGeneration,
          'evidenceSha256': snapshot.evidenceSha256,
        });
      }
    }

    final input = Acs03Input(
      doorId: doorId,
      lockId: lockId,
      conductiveFeedPathId: contract.conductiveFeedPathId,
      controlPathId: contract.controlPathId,
      requiredMembershipFingerprint: requiredMembershipFingerprint!,
      events: events,
      evidence: evidence,
      minimumTerminalVoltage: contract.minimumTerminalVoltage,
      maximumTerminalVoltage: contract.maximumTerminalVoltage,
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs03-captured-input.v2',
      'doorFingerprint': doorFingerprint,
      'contractEvidenceRef': contractSnapshot.evidenceRef,
      'contractContentHash': contractSnapshot.contentHash,
      'upstream': upstreamBasis
        ..sort(
          (a, b) => (a['evaluationId']! as String).compareTo(
            b['evaluationId']! as String,
          ),
        ),
    });

    return Elv5CapturedInput<Acs03Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: upstreamGenerations,
      captureRevision: door.revision,
    );
  }

  Future<Elv4CurrentEvaluationSnapshot> _requireSingleCurrent({
    required Elv5CalculationRequest request,
    required PowerProcessCode processCode,
    required String scenarioId,
    required String segmentId,
    required String subjectId,
    required String reasonCode,
    required List<Elv5DependencyMarker> dependencies,
    required String inputFingerprint,
    required String policyFingerprint,
  }) async {
    final values = await powerEvidence.loadCurrent(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      processCode: processCode,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
      subjectId: subjectId,
    );
    if (values.length != 1) {
      _blocked(
        request,
        values.isEmpty ? reasonCode : '${reasonCode}_AMBIGUOUS',
        inputFingerprint,
        policyFingerprint,
        dependencies,
        <String, Object?>{
          'processCode': processCode.name,
          'scenarioId': scenarioId,
          'segmentId': segmentId,
          'subjectId': subjectId,
          'matchCount': values.length,
        },
      );
    }
    return values.single;
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reasonCode,
    String inputFingerprint,
    String policyFingerprint,
    List<Elv5DependencyMarker> dependencies,
    Map<String, Object?> evidence,
  ) {
    throw Elv5CaptureBlockedException(
      request: request,
      reasonCode: reasonCode,
      inputFingerprint: inputFingerprint,
      policyFingerprint: policyFingerprint,
      dependencies: dependencies,
      evidence: evidence,
    );
  }

  String _membershipFingerprint(Elv4CurrentEvaluationSnapshot snapshot) {
    final inputs = _map(snapshot.evidence['inputs'], 'inputs');
    final rawKeys = inputs['dependencyKeys'];
    if (rawKeys is! List || rawKeys.any((value) => value is! String)) {
      throw StateError(
        'ACS03_PWR03_DEPENDENCY_KEYS_INVALID:${snapshot.evaluationId}',
      );
    }
    final closure = <String>[
      for (final raw in rawKeys.cast<String>())
        if (PowerDependencyKey.decode(raw).scenarioId == null) raw,
    ]..sort();
    if (closure.isEmpty) {
      throw StateError(
        'ACS03_PWR03_MEMBERSHIP_CLOSURE_EMPTY:${snapshot.evaluationId}',
      );
    }
    return _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs03-pwr03-membership-closure.v1',
      'dependencyKeys': closure,
    });
  }

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relationKind,
    String domain,
    String subjectId, {
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relationKind,
      'domain': domain,
      'subjectId': subjectId,
      if (memberId != null) 'memberId': memberId,
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
          'sharedTrunkCurrentLowerA': item.sharedTrunkCurrent?.lower.value
              .toMap(),
          'sharedTrunkCurrentUpperA': item.sharedTrunkCurrent?.upper.value
              .toMap(),
          'minimumVoltageMarginV': item.minimumVoltageMargin?.value.toMap(),
          'maximumVoltageMarginV': item.maximumVoltageMargin?.value.toMap(),
          'sourceCurrentMarginLowerA': item.sourceCurrentMargin?.lower.value
              .toMap(),
          'sourceCurrentMarginUpperA': item.sourceCurrentMargin?.upper.value
              .toMap(),
          'reason': item.reason,
        },
    ],
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-acs03-evidence.v2',
    'source': 'ELV5_EXACT_ACS03_CONTRACT_PLUS_VERIFIED_CURRENT_PWR01_PWR03',
    'captureRevision': captured.captureRevision,
    'upstreamPointerGenerations': captured.upstreamPointerGenerations,
    'membershipFingerprint': captured.value.requiredMembershipFingerprint,
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

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

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

Map<String, Object?> _singleById(
  Object? raw,
  String idField,
  String expectedId,
  String errorCode,
) {
  final rows = _objects(raw, idField);
  final matching = rows.where((row) => row[idField] == expectedId).toList();
  if (matching.length != 1) {
    throw StateError('$errorCode:$expectedId:${matching.length}');
  }
  return matching.single;
}

PowerRational _powerRational(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be a rational map.');
  return PowerRational.fromMap(Map<String, Object?>.from(raw));
}

Elv5Rational _elv5(PowerRational value) =>
    Elv5Rational(value.numerator, value.denominator);

String _text(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String || raw.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return raw.trim();
}
