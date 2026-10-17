import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'acs02_resource_contract.dart';
import 'elv5_acs_persistence.dart';

final class Acs02PersistedInputResolver
    implements Elv5ProcessInputResolver<Acs02Input> {
  Acs02PersistedInputResolver({
    required this.acsStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5AcsFactStore acsStore;
  final Acs02ResourceContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.acs02;

  @override
  Future<Elv5CapturedInput<Acs02Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('ACS02_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'CONTROLLER') {
      throw StateError('ACS02_SUBJECT_KIND_MUST_BE_CONTROLLER');
    }
    final controllerId = request.subject.id;
    final aggregate = await acsStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS',
      subjectId: controllerId,
    );
    final missing = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs02-missing.v1',
      'controllerId': controllerId,
    });
    if (aggregate == null) {
      _blocked(
        request,
        'ACS02_CONTROLLER_RESOURCE_ASSIGNMENTS_REQUIRED',
        missing,
        missing,
        const <Elv5DependencyMarker>[],
        <String, Object?>{'controllerId': controllerId},
      );
    }
    final payload = aggregate!.payload;
    if (_text(payload, 'controllerId') != controllerId) {
      throw StateError('ACS02_CONTROLLER_IDENTITY_MISMATCH:$controllerId');
    }
    final aggregateFingerprint = _encoder.sha256(payload);
    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'ACS_CONTROLLER_RESOURCES', controllerId),
    ];

    final snapshot = await contractSource.loadActiveForController(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      controllerId: controllerId,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'ACS02_RESOURCE_CONTRACT_REQUIRED',
        aggregateFingerprint,
        aggregateFingerprint,
        dependencies,
        <String, Object?>{'controllerId': controllerId},
      );
    }
    final contract = snapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'ACS02_RESOURCE_CONTRACT',
        snapshot.evidenceRef,
        memberId:
            '${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
      ),
    );
    if (contract.controllerId != controllerId ||
        contract.expectedControllerAggregateFingerprint !=
            aggregateFingerprint) {
      _blocked(
        request,
        'ACS02_CONTROLLER_AGGREGATE_FINGERPRINT_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expected': contract.expectedControllerAggregateFingerprint,
          'actual': aggregateFingerprint,
        },
      );
    }

    final reserveRef = _map(payload['reservePolicyRef'], 'reservePolicyRef');
    if (_text(reserveRef, 'policyCode') != contract.reservePolicy.policyCode ||
        _text(reserveRef, 'editionId') != contract.reservePolicy.editionId ||
        _text(reserveRef, 'contentHash').toLowerCase() !=
            contract.reservePolicy.contentHash) {
      _blocked(
        request,
        'ACS02_RESERVE_POLICY_IDENTITY_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expected': contract.reservePolicy.toCanonicalValue(),
          'actual': reserveRef,
        },
      );
    }
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'ACS_CONTROLLER_RESERVE_POLICY',
        contract.reservePolicy.editionId,
        memberId: contract.reservePolicy.contentHash,
      ),
    );

    final resourcesById = <String, Acs02ResourceContractItem>{
      for (final value in contract.resources) value.resourceId: value,
    };
    final assignmentRows =
        _objects(payload['resourceAssignments'], 'resourceAssignments')..sort((
          a,
          b,
        ) {
          final left =
              '${_text(a, 'resourceId')}:${_text(a, 'assignmentRole')}:${_text(a, 'subjectId')}';
          final right =
              '${_text(b, 'resourceId')}:${_text(b, 'assignmentRole')}:${_text(b, 'subjectId')}';
          return left.compareTo(right);
        });
    final assignments = <Acs02Assignment>[];
    for (var i = 0; i < assignmentRows.length; i++) {
      final row = assignmentRows[i];
      final resourceId = _text(row, 'resourceId');
      final persistedKind = _text(row, 'resourceKind').toUpperCase();
      final inventory = resourcesById[resourceId];
      if (inventory != null && inventory.resourceKindCode != persistedKind) {
        _blocked(
          request,
          'ACS02_RESOURCE_KIND_IDENTITY_MISMATCH',
          aggregateFingerprint,
          snapshot.contentHash,
          dependencies,
          <String, Object?>{
            'resourceId': resourceId,
            'persistedKind': persistedKind,
            'inventoryKind': inventory.resourceKindCode,
          },
        );
      }
      assignments.add(
        Acs02Assignment(
          assignmentId:
              '${i.toString().padLeft(6, '0')}:$resourceId:${_text(row, 'assignmentRole')}:${_text(row, 'subjectId')}',
          resourceId: resourceId,
        ),
      );
      dependencies.add(
        _dependency(
          request,
          'SET',
          'ACS_CONTROLLER_RESOURCE',
          controllerId,
          memberId: resourceId,
        ),
      );
    }

    final resources = <Acs02Resource>[
      for (final value in contract.resources)
        Acs02Resource(
          resourceId: value.resourceId,
          kind: _kind(value.resourceKindCode),
        ),
    ];
    final spareRules = <Acs02ResourceKind, Acs02SpareRule>{
      for (final value in contract.spareRules)
        _kind(value.resourceKindCode): Acs02SpareRule(
          absoluteMinimum: value.absoluteMinimum,
          ratio: value.ratio,
        ),
    };
    final input = Acs02Input(
      controllerId: controllerId,
      resources: resources,
      assignments: assignments,
      unavailableResourceIds: contract.unavailableResourceIds,
      spareRules: spareRules,
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-acs02-captured-input.v1',
      'controllerAggregateFingerprint': aggregateFingerprint,
      'contractEvidenceRef': snapshot.evidenceRef,
      'contractContentHash': snapshot.contentHash,
    });
    return Elv5CapturedInput<Acs02Input>(
      request: request,
      value: input,
      inputFingerprint: inputFingerprint,
      policyFingerprint: snapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: aggregate.revision,
    );
  }

  Never _blocked(
    Elv5CalculationRequest request,
    String reason,
    String input,
    String policy,
    List<Elv5DependencyMarker> dependencies,
    Map<String, Object?> evidence,
  ) => throw Elv5CaptureBlockedException(
    request: request,
    reasonCode: reason,
    inputFingerprint: input,
    policyFingerprint: policy,
    dependencies: dependencies,
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

Elv5PureKernelExecutor<Acs02Input, Acs02Result> buildAcs02Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Acs02Input, Acs02Result>(
  processCode: Elv5ProcessCode.acs02,
  calculate: const Acs02ResourceCapacityKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-acs02-output.v1',
    'status': result.status.name,
    'conflictingAssignmentIds': result.conflictingAssignmentIds,
    'pools': <Object?>[
      for (final entry
          in result.pools.entries.toList()
            ..sort((a, b) => a.key.name.compareTo(b.key.name)))
        <String, Object?>{
          'resourceKind': entry.key.name,
          'available': entry.value.available,
          'occupied': entry.value.occupied,
          'requiredSpare': entry.value.requiredSpare,
          'headroom': entry.value.headroom,
          'status': entry.value.status.name,
        },
    ],
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-acs02-evidence.v1',
    'source': 'PERSISTED_CONTROLLER_ASSIGNMENTS_PLUS_IMMUTABLE_RESOURCE_INVENTORY_AND_SPARE_POLICY',
    'captureRevision': captured.captureRevision,
  },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (_) => Elv5Completion.complete,
  assessmentOf: (result) => result.status == Acs02AssessmentStatus.pass
      ? Elv5Assessment.pass
      : Elv5Assessment.fail,
  nowUtc: nowUtc,
);

Acs02ResourceKind _kind(String code) => switch (code.trim().toUpperCase()) {
  'READER_CHANNEL' => Acs02ResourceKind.reader,
  'RELAY_OUTPUT' => Acs02ResourceKind.relay,
  'SUPERVISED_INPUT' => Acs02ResourceKind.supervisedInput,
  'OTHER' => Acs02ResourceKind.other,
  _ => throw StateError('ACS02_UNSUPPORTED_RESOURCE_KIND:$code'),
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
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be text.');
  }
  return value.trim();
}
