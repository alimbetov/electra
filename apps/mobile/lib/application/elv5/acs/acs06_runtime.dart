import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'acs06_topology_contract.dart';
import 'elv5_acs_persistence.dart';

final class Acs06PersistedInputResolver
    implements Elv5ProcessInputResolver<Acs06Input> {
  Acs06PersistedInputResolver({
    required this.acsStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5AcsFactStore acsStore;
  final Acs06TopologyContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.acs06;

  @override
  Future<Elv5CapturedInput<Acs06Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('ACS06_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'DOOR') {
      throw StateError('ACS06_SUBJECT_KIND_MUST_BE_DOOR');
    }
    final doorId = request.subject.id;
    final snapshot = await acsStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
      subjectId: doorId,
    );
    final missing = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs06-missing.v1',
      'doorId': doorId,
    });
    if (snapshot == null) {
      _blocked(
        request,
        'ACS06_DOOR_ROLE_ASSIGNMENTS_REQUIRED',
        missing,
        missing,
        const <Elv5DependencyMarker>[],
        <String, Object?>{'doorId': doorId},
      );
    }
    final payload = snapshot!.payload;
    final persistedDoorId = _text(payload, 'doorAssemblyId');
    if (persistedDoorId != doorId) {
      throw StateError('ACS06_DOOR_IDENTITY_MISMATCH:$persistedDoorId:$doorId');
    }
    final aggregateFingerprint = _encoder.sha256(payload);
    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'ACS_DOOR_CALCULATION', doorId),
    ];

    final contractSnapshot = await contractSource.loadActiveForDoor(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      doorId: doorId,
    );
    if (contractSnapshot == null) {
      _blocked(
        request,
        'ACS06_TOPOLOGY_CONTRACT_REQUIRED',
        aggregateFingerprint,
        aggregateFingerprint,
        dependencies,
        <String, Object?>{'doorId': doorId},
      );
    }
    final contract = contractSnapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'ACS06_TOPOLOGY_CONTRACT',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    );
    if (contract.doorId != doorId ||
        contract.expectedDoorAggregateFingerprint != aggregateFingerprint) {
      _blocked(
        request,
        'ACS06_DOOR_AGGREGATE_FINGERPRINT_MISMATCH',
        aggregateFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'doorId': doorId,
          'expected': contract.expectedDoorAggregateFingerprint,
          'actual': aggregateFingerprint,
        },
      );
    }

    final persistedProfile = _map(
      payload['topologyProfileRef'],
      'topologyProfileRef',
    );
    final actualProfile = <String, Object?>{
      'profileCode': _text(persistedProfile, 'profileCode'),
      'editionId': _text(persistedProfile, 'editionId'),
      'contentHash': _text(persistedProfile, 'contentHash'),
    };
    if (_encoder.sha256(actualProfile) !=
        _encoder.sha256(contract.topologyProfile.toCanonicalValue())) {
      _blocked(
        request,
        'ACS06_TOPOLOGY_PROFILE_IDENTITY_MISMATCH',
        aggregateFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'persisted': actualProfile,
          'contract': contract.topologyProfile.toCanonicalValue(),
        },
      );
    }

    final roleRows = _objects(payload['roleAssignments'], 'roleAssignments');
    final roleCodes = <String>{};
    final componentIds = <String>{};
    String? lockComponentId;
    for (final row in roleRows) {
      final role = _text(row, 'roleCode').toUpperCase();
      final component = _text(row, 'componentId');
      roleCodes.add(role);
      componentIds.add(component);
      if (role == 'LOCK') {
        if (lockComponentId != null) {
          _blocked(
            request,
            'ACS06_MULTIPLE_LOCK_ASSIGNMENTS',
            aggregateFingerprint,
            contractSnapshot.contentHash,
            dependencies,
            <String, Object?>{'doorId': doorId},
          );
        }
        lockComponentId = component;
      }
      dependencies.add(
        _dependency(request, 'FACT', 'COMPONENT_REFERENCE_BINDING', component),
      );
    }
    if (lockComponentId == null) {
      _blocked(
        request,
        'ACS06_LOCK_ASSIGNMENT_REQUIRED',
        aggregateFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{'doorId': doorId},
      );
    }
    final mappedComponents = contract.componentNodeIdByComponentId.keys.toSet();
    if (mappedComponents.length != componentIds.length ||
        !mappedComponents.containsAll(componentIds)) {
      _blocked(
        request,
        'ACS06_COMPONENT_NODE_MAPPING_MISMATCH',
        aggregateFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'persisted': componentIds.toList()..sort(),
          'mapped': mappedComponents.toList()..sort(),
        },
      );
    }

    final truthRows = _objects(
      payload['releaseTruthTable'],
      'releaseTruthTable',
    );
    final truthTable = <Acs06TruthRow>[];
    final seenCauses = <String>{};
    for (final row in truthRows) {
      final causeCode = _text(row, 'causeCode').toUpperCase();
      if (!seenCauses.add(causeCode)) {
        _blocked(
          request,
          'ACS06_DUPLICATE_TRUTH_CAUSE',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'causeCode': causeCode},
        );
      }
      final requiredRoles =
          _strings(
            row['requiredEvidenceRoles'],
            'requiredEvidenceRoles',
          ).map((e) => e.toUpperCase()).toSet();
      final missingRoles = requiredRoles.difference(roleCodes);
      if (missingRoles.isNotEmpty) {
        _blocked(
          request,
          'ACS06_REQUIRED_EVIDENCE_ROLE_MISSING',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'causeCode': causeCode,
            'missingRoles': missingRoles.toList()..sort(),
          },
        );
      }
      dependencies.add(
        _dependency(
          request,
          'SET',
          'ACS_RELEASE_CAUSE',
          doorId,
          memberId: causeCode,
        ),
      );
      truthTable.add(
        Acs06TruthRow(
          cause: _cause(causeCode),
          expectedOutcome: _outcome(_text(row, 'expectedOutcomeCode')),
        ),
      );
    }
    if (seenCauses.length != Acs06ReleaseCause.values.length) {
      _blocked(
        request,
        'ACS06_TRUTH_TABLE_INCOMPLETE',
        aggregateFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{'causeCount': seenCauses.length},
      );
    }

    final input = Acs06Input(
      doorId: doorId,
      lockNodeId: contract.componentNodeIdByComponentId[lockComponentId]!,
      edges: <Acs06GraphEdge>[
        for (final edge in contract.edges)
          Acs06GraphEdge(
            edgeId: edge.edgeId,
            fromNodeId: edge.fromNodeId,
            toNodeId: edge.toNodeId,
            kind: _edgeKind(edge.kindCode),
          ),
      ],
      causeProfiles: <Acs06CauseProfile>[
        for (final profile in contract.causeProfiles)
          Acs06CauseProfile(
            cause: _cause(profile.causeCode),
            requiredPaths: <Acs06PathRequirement>[
              for (final path in profile.requiredPaths)
                Acs06PathRequirement(
                  requirementId: path.requirementId,
                  fromNodeId: path.fromNodeId,
                  toNodeId: path.toNodeId,
                  allowedKinds: path.allowedKindCodes.map(_edgeKind).toSet(),
                ),
            ],
            outcomeWhenSatisfied: _outcome(profile.outcomeWhenSatisfiedCode),
            requiresConductiveFeed: profile.requiresConductiveFeed,
            requiresSupervision: profile.requiresSupervision,
          ),
      ],
      truthTable: truthTable,
      safetyMode: _safetyMode(_text(payload, 'safetyMode')),
      projectDefinedPowerFailureOutcome:
          contract.projectDefinedPowerFailureOutcomeCode == null
              ? null
              : _outcome(contract.projectDefinedPowerFailureOutcomeCode!),
    );

    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs06-captured-input.v1',
      'doorAggregateFingerprint': aggregateFingerprint,
      'contractEvidenceRef': contractSnapshot.evidenceRef,
      'contractContentHash': contractSnapshot.contentHash,
    });
    return Elv5CapturedInput<Acs06Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: contractSnapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: snapshot.revision,
    );
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reasonCode,
    String inputFingerprint,
    String policyFingerprint,
    List<Elv5DependencyMarker> dependencies,
    Map<String, Object?> evidence,
  ) =>
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: reasonCode,
        inputFingerprint: inputFingerprint,
        policyFingerprint: policyFingerprint,
        dependencies: dependencies,
        evidence: evidence,
      );

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

Elv5PureKernelExecutor<Acs06Input, Acs06Result> buildAcs06Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Acs06Input, Acs06Result>(
  processCode: Elv5ProcessCode.acs06,
  calculate: const Acs06DoorTopologyKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-acs06-output.v1',
        'status': result.status.name,
        'governingCause': result.governingCause?.name,
        'causes': <String, Object?>{
          for (final entry in result.causes.entries)
            entry.key.name: <String, Object?>{
              'status': entry.value.status.name,
              'expectedOutcome': entry.value.expectedOutcome.name,
              'modeledOutcome': entry.value.modeledOutcome?.name,
              'failedRequirementId': entry.value.failedRequirementId,
              'reason': entry.value.reason,
            },
        },
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-acs06-evidence.v1',
        'source': 'PERSISTED_DOOR_ROLES_TRUTH_PLUS_IMMUTABLE_TOPOLOGY_CONTRACT',
        'captureRevision': captured.captureRevision,
      },
  executionOf:
      (result) =>
          result.status == Acs06AssessmentStatus.blocked
              ? Elv5Execution.blocked
              : Elv5Execution.succeeded,
  completionOf:
      (result) =>
          result.status == Acs06AssessmentStatus.blocked
              ? Elv5Completion.incomplete
              : Elv5Completion.complete,
  assessmentOf:
      (result) => switch (result.status) {
        Acs06AssessmentStatus.pass => Elv5Assessment.pass,
        Acs06AssessmentStatus.fail => Elv5Assessment.fail,
        Acs06AssessmentStatus.blocked => Elv5Assessment.unresolved,
      },
  nowUtc: nowUtc,
);

Acs06ReleaseCause _cause(String code) => switch (code.trim().toUpperCase()) {
  'NORMAL_ACCESS' => Acs06ReleaseCause.normalAccess,
  'REQUEST_TO_EXIT' => Acs06ReleaseCause.requestToExit,
  'FIRE_RELEASE' => Acs06ReleaseCause.fireRelease,
  'EMERGENCY_BREAK_GLASS' => Acs06ReleaseCause.emergencyBreakGlass,
  'POWER_FAILURE' => Acs06ReleaseCause.powerFailure,
  _ => throw StateError('ACS06_UNSUPPORTED_RELEASE_CAUSE:$code'),
};

Acs06LockOutcome _outcome(String code) => switch (code.trim().toUpperCase()) {
  'LOCKED' || 'SECURED' => Acs06LockOutcome.secured,
  'UNLOCKED' || 'RELEASED' => Acs06LockOutcome.released,
  _ => throw StateError('ACS06_UNSUPPORTED_LOCK_OUTCOME:$code'),
};

Acs06LockSafetyMode _safetyMode(String code) => switch (code
    .trim()
    .toUpperCase()) {
  'FAIL_SAFE' => Acs06LockSafetyMode.failSafe,
  'FAIL_SECURE' => Acs06LockSafetyMode.failSecure,
  'PROJECT_DEFINED' => Acs06LockSafetyMode.projectDefined,
  _ => throw StateError('ACS06_UNSUPPORTED_SAFETY_MODE:$code'),
};

Acs06EdgeKind _edgeKind(String code) => switch (code.trim().toUpperCase()) {
  'DATA' => Acs06EdgeKind.data,
  'CONTROL' => Acs06EdgeKind.control,
  'POWER_FEED' => Acs06EdgeKind.powerFeed,
  'MONITOR' => Acs06EdgeKind.monitor,
  'RELEASE' => Acs06EdgeKind.release,
  _ => throw StateError('ACS06_UNSUPPORTED_EDGE_KIND:$code'),
};

List<Map<String, Object?>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be array.');
  return <Map<String, Object?>>[for (final raw in value) _map(raw, field)];
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((e) => e is! String)) {
    throw FormatException('$field must be string array.');
  }
  return value.cast<String>();
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return value.trim();
}
