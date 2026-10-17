import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'acs01_role_profile_contract.dart';
import 'elv5_acs_persistence.dart';

final class Acs01PersistedInputResolver
    implements Elv5ProcessInputResolver<Acs01Input> {
  Acs01PersistedInputResolver({
    required this.acsStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5AcsFactStore acsStore;
  final Acs01RoleProfileContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.acs01;

  @override
  Future<Elv5CapturedInput<Acs01Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('ACS01_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'DOOR') {
      throw StateError('ACS01_SUBJECT_KIND_MUST_BE_DOOR');
    }
    final doorId = request.subject.id;
    final aggregate = await acsStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
      subjectId: doorId,
    );
    final missing = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs01-missing.v1',
      'doorId': doorId,
    });
    if (aggregate == null) {
      _blocked(
        request,
        'ACS01_DOOR_ROLE_ASSIGNMENTS_REQUIRED',
        missing,
        missing,
        const <Elv5DependencyMarker>[],
        <String, Object?>{'doorId': doorId},
      );
    }
    final payload = aggregate!.payload;
    if (_text(payload, 'doorAssemblyId') != doorId) {
      throw StateError('ACS01_DOOR_IDENTITY_MISMATCH:$doorId');
    }
    final aggregateFingerprint = _encoder.sha256(payload);
    final deps = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'ACS_DOOR_CALCULATION', doorId),
    ];

    final snapshot = await contractSource.loadActiveForDoor(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      doorId: doorId,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'ACS01_ROLE_PROFILE_CONTRACT_REQUIRED',
        aggregateFingerprint,
        aggregateFingerprint,
        deps,
        <String, Object?>{'doorId': doorId},
      );
    }
    final contract = snapshot!.contract;
    deps.add(
      _dependency(
        request,
        'POLICY',
        'ACS01_ROLE_PROFILE_CONTRACT',
        snapshot.evidenceRef,
        memberId:
            '${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
      ),
    );
    if (contract.doorId != doorId ||
        contract.expectedDoorAggregateFingerprint != aggregateFingerprint) {
      _blocked(
        request,
        'ACS01_DOOR_AGGREGATE_FINGERPRINT_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        deps,
        <String, Object?>{
          'expected': contract.expectedDoorAggregateFingerprint,
          'actual': aggregateFingerprint,
        },
      );
    }

    final rows = _objects(payload['roleAssignments'], 'roleAssignments');
    final assignments = <Acs01RoleAssignment>[];
    final componentIds = <String>{};
    for (final row in rows) {
      final componentId = _text(row, 'componentId');
      final roleCode = _text(row, 'roleCode');
      final slot = row['slot'];
      if (slot is! int || slot < 0) {
        throw FormatException(
          'ACS01 assignment slot must be nonnegative integer.',
        );
      }
      assignments.add(
        Acs01RoleAssignment(
          assignmentId: '${roleCode.toUpperCase()}:$slot:$componentId',
          componentId: componentId,
          role: _role(roleCode),
        ),
      );
      componentIds.add(componentId);
      deps.add(
        _dependency(
          request,
          'FACT',
          'COMPONENT_REFERENCE_BINDING',
          componentId,
        ),
      );
    }

    final capabilityIds =
        contract.capabilities.map((e) => e.componentId).toSet();
    if (componentIds.length != capabilityIds.length ||
        !capabilityIds.containsAll(componentIds)) {
      _blocked(
        request,
        'ACS01_COMPONENT_CAPABILITY_CLOSURE_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        deps,
        <String, Object?>{
          'assigned': componentIds.toList()..sort(),
          'capabilities': capabilityIds.toList()..sort(),
        },
      );
    }
    final capabilities = <Acs01ComponentCapabilities>[
      for (final value in contract.capabilities)
        Acs01ComponentCapabilities(
          componentId: value.componentId,
          allowedRoles: value.allowedRoleCodes.map(_role).toSet(),
          allowRoleSharing: value.allowRoleSharing,
        ),
    ];
    for (final value in contract.capabilities) {
      deps.add(
        _dependency(
          request,
          'POLICY',
          'ACS_COMPONENT_ROLE_CAPABILITY',
          value.evidenceRef,
          memberId: value.evidenceContentHash,
        ),
      );
    }

    final input = Acs01Input(
      doorId: doorId,
      profileId: contract.profileId,
      rootRequirement: _requirement(contract.rootRequirement),
      assignments: assignments,
      capabilities: capabilities,
      assignmentClosureComplete: contract.assignmentClosureComplete,
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs01-captured-input.v1',
      'doorAggregateFingerprint': aggregateFingerprint,
      'contractEvidenceRef': snapshot.evidenceRef,
      'contractContentHash': snapshot.contentHash,
    });
    return Elv5CapturedInput<Acs01Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: snapshot.contentHash,
      dependencies: deps,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: aggregate.revision,
    );
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reason,
    String input,
    String policy,
    List<Elv5DependencyMarker> deps,
    Map<String, Object?> evidence,
  ) =>
      throw Elv5CaptureBlockedException(
        request: request,
        reasonCode: reason,
        inputFingerprint: input,
        policyFingerprint: policy,
        dependencies: deps,
        evidence: evidence,
      );

  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest request,
    String relation,
    String domain,
    String subjectId, {
    String? memberId,
  }) {
    final value = <String, Object?>{
      'schema': 'electra.elv5-dependency-key.v1',
      'relationKind': relation,
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
      relationKind: relation,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Acs01Input, Acs01Result> buildAcs01Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Acs01Input, Acs01Result>(
  processCode: Elv5ProcessCode.acs01,
  calculate: const Acs01RoleCompletenessKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-acs01-output.v1',
        'status': result.status.name,
        'governingNodeId': result.governingNodeId,
        'illegalSharingComponentIds': result.illegalSharingComponentIds,
        'requirements': <Object?>[
          for (final row in result.nodeResults)
            <String, Object?>{
              'nodeId': row.nodeId,
              'status': row.status.name,
              'margin': row.margin,
              'selectedChildNodeIds': row.selectedChildNodeIds,
            },
        ],
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-acs01-evidence.v1',
        'source': 'PERSISTED_DOOR_ROLE_ASSIGNMENTS_PLUS_IMMUTABLE_ROLE_PROFILE',
        'captureRevision': captured.captureRevision,
      },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf:
      (result) =>
          result.status == Acs01AssessmentStatus.unresolved
              ? Elv5Completion.incomplete
              : Elv5Completion.complete,
  assessmentOf:
      (result) => switch (result.status) {
        Acs01AssessmentStatus.pass => Elv5Assessment.pass,
        Acs01AssessmentStatus.fail => Elv5Assessment.fail,
        Acs01AssessmentStatus.unresolved => Elv5Assessment.unresolved,
      },
  nowUtc: nowUtc,
);

Acs01RequirementNode _requirement(Acs01RoleRequirementContract value) {
  final kind = value.kindCode;
  if (kind == 'AT_LEAST' || kind == 'EXACTLY') {
    return Acs01RequirementNode.roleCount(
      nodeId: value.nodeId,
      kind:
          kind == 'AT_LEAST'
              ? Acs01RequirementKind.atLeast
              : Acs01RequirementKind.exactly,
      role: _role(value.roleCode!),
      count: value.count,
    );
  }
  return Acs01RequirementNode.group(
    nodeId: value.nodeId,
    kind: switch (kind) {
      'ALL_OF' => Acs01RequirementKind.allOf,
      'ANY_OF' => Acs01RequirementKind.anyOf,
      'EXACTLY_ONE_OF' => Acs01RequirementKind.exactlyOneOf,
      _ => throw StateError('ACS01_UNSUPPORTED_REQUIREMENT_KIND:$kind'),
    },
    children: <Acs01RequirementNode>[
      for (final child in value.children) _requirement(child),
    ],
  );
}

Acs01RoleCode _role(String code) => switch (code.trim().toUpperCase()) {
  'READER_ENTRY' => Acs01RoleCode.entryReader,
  'READER_EXIT' => Acs01RoleCode.exitReader,
  'REQUEST_TO_EXIT' || 'EXIT_BUTTON' => Acs01RoleCode.exitButton,
  'LOCK' => Acs01RoleCode.lock,
  'DOOR_CONTACT' => Acs01RoleCode.doorContact,
  'EMERGENCY_RELEASE' => Acs01RoleCode.emergencyRelease,
  'FIRE_RELEASE_INPUT' || 'OTHER' => Acs01RoleCode.other,
  _ => throw StateError('ACS01_UNSUPPORTED_ROLE:$code'),
};

List<Map<String, Object?>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be array.');
  return <Map<String, Object?>>[for (final raw in value) _map(raw, field)];
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty)
    throw FormatException('$key must be text.');
  return value.trim();
}
