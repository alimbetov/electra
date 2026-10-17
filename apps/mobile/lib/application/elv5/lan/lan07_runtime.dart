import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_lan_persistence.dart';
import 'lan07_patch_contract.dart';

final class Lan07PersistedInputResolver
    implements Elv5ProcessInputResolver<Lan07Input> {
  Lan07PersistedInputResolver({
    required this.lanStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5LanFactStore lanStore;
  final Lan07PatchPanelContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan07;

  @override
  Future<Elv5CapturedInput<Lan07Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('LAN07_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'PATCH_PANEL') {
      throw StateError('LAN07_SUBJECT_KIND_MUST_BE_PATCH_PANEL');
    }

    final panelId = request.subject.id;
    final aggregate = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_PATCH_PANEL_ASSIGNMENTS',
      subjectId: panelId,
    );
    final baseFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan07-capture-basis.v1',
      'panelId': panelId,
    });
    if (aggregate == null) {
      _blocked(
        request,
        'LAN07_PATCH_PANEL_ASSIGNMENTS_REQUIRED',
        baseFingerprint,
        baseFingerprint,
        const <Elv5DependencyMarker>[],
        <String, Object?>{'panelId': panelId},
      );
    }
    if (_text(aggregate!.payload, 'panelId') != panelId) {
      throw StateError('LAN07_PANEL_ID_MISMATCH:$panelId');
    }

    final dependencies = <Elv5DependencyMarker>[
      _dependency(
        request,
        'SET',
        'LAN_PATCH_PANEL_ASSIGNMENTS',
        panelId,
        memberId: '${aggregate.aggregateId}:${aggregate.revision}',
      ),
    ];
    final aggregateFingerprint = lan07AggregateFingerprint(aggregate.payload);
    final snapshot = await contractSource.loadActiveForPanel(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      panelId: panelId,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'LAN07_PATCH_PANEL_CONTRACT_REQUIRED',
        aggregateFingerprint,
        baseFingerprint,
        dependencies,
        <String, Object?>{'panelId': panelId},
      );
    }
    final contract = snapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'LAN07_PATCH_PANEL_CONTRACT',
        snapshot.evidenceRef,
        memberId:
            '${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
      ),
    );

    if (contract.expectedAggregateFingerprint != aggregateFingerprint) {
      _blocked(
        request,
        'LAN07_AGGREGATE_FINGERPRINT_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expected': contract.expectedAggregateFingerprint,
          'actual': aggregateFingerprint,
        },
      );
    }

    final policyRef = _map(
      aggregate.payload['sparePolicyRef'],
      'sparePolicyRef',
    );
    if (_text(policyRef, 'policyCode') != contract.policyRef.policyCode ||
        _text(policyRef, 'editionId') != contract.policyRef.editionId ||
        _text(policyRef, 'contentHash').toLowerCase() !=
            contract.policyRef.contentHash) {
      _blocked(
        request,
        'LAN07_SPARE_POLICY_IDENTITY_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'actualPolicyRef': policyRef,
          'expectedPolicyRef': contract.policyRef.toCanonicalValue(),
        },
      );
    }

    final assignments = <Lan07PatchAssignment>[];
    for (final raw in _objectList(aggregate.payload['assignments'])) {
      final portId = _text(raw, 'panelPortId');
      final sourceEndpointId = _text(raw, 'terminationId');
      final destinationEndpointId = _text(raw, 'linkId');
      assignments.add(
        Lan07PatchAssignment(
          assignmentId: _encoder.sha256(<String, Object?>{
            'schema': 'electra.elv5-lan07-assignment-id.v1',
            'panelId': panelId,
            'portId': portId,
            'sourceEndpointId': sourceEndpointId,
            'destinationEndpointId': destinationEndpointId,
          }),
          portId: portId,
          sourceEndpointId: sourceEndpointId,
          destinationEndpointId: destinationEndpointId,
        ),
      );
    }

    dependencies.add(
      _dependency(
        request,
        'FACT',
        'LAN07_PATCH_PANEL_DEFINITION',
        contract.panelEvidenceRef,
        memberId: contract.panelEvidenceContentHash,
      ),
    );

    final input = Lan07Input(
      panelId: panelId,
      ports: <Lan07PhysicalPort>[
        for (final portId in contract.physicalPortIds.toList()..sort())
          Lan07PhysicalPort(portId: portId),
      ],
      assignments: List.unmodifiable(assignments),
      unavailablePortIds: contract.unavailablePortIds,
      requiredSourceEndpointIds: contract.requiredSourceEndpointIds,
      sparePolicy: Lan07SparePolicy(
        absoluteMinimum: contract.absoluteMinimumSpare,
        ratio: contract.spareRatio,
        combiner:
            contract.spareCombinerCode == 'MAX'
                ? Lan07SpareCombiner.max
                : Lan07SpareCombiner.sum,
      ),
    );

    return Elv5CapturedInput<Lan07Input>(
      request: request,
      value: input,
      inputFingerprint: _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-lan07-captured-input.v1',
        'aggregateFingerprint': aggregateFingerprint,
        'contractContentHash': snapshot.contentHash,
      }),
      policyFingerprint: snapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: aggregate.revision,
    );
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

Elv5PureKernelExecutor<Lan07Input, Lan07Result> buildLan07Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Lan07Input, Lan07Result>(
  processCode: Elv5ProcessCode.lan07,
  calculate: const Lan07PatchPanelKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-lan07-output.v1',
        'status': result.status.name,
        'occupied': result.occupied,
        'free': result.free,
        'requiredSpare': result.requiredSpare,
        'spareHeadroom': result.spareHeadroom,
        'mappings': <Object?>[
          for (final mapping in result.mappings)
            <String, Object?>{
              'sourceEndpointId': mapping.sourceEndpointId,
              'status': mapping.status.name,
              'destinationEndpointIds': mapping.destinationEndpointIds,
            },
        ],
        'conflictingAssignmentIds': result.conflictingAssignmentIds,
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-lan07-evidence.v1',
        'source': 'PERSISTED_PATCH_ASSIGNMENTS_PLUS_IMMUTABLE_PANEL_INVENTORY',
        'captureRevision': captured.captureRevision,
      },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf:
      (result) =>
          result.status == Lan07AssessmentStatus.unresolved
              ? Elv5Completion.partial
              : Elv5Completion.complete,
  assessmentOf:
      (result) => switch (result.status) {
        Lan07AssessmentStatus.pass => Elv5Assessment.pass,
        Lan07AssessmentStatus.fail => Elv5Assessment.fail,
        Lan07AssessmentStatus.unresolved => Elv5Assessment.unresolved,
      },
  nowUtc: nowUtc,
);

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return value.trim();
}

List<Map<String, Object?>> _objectList(Object? value) {
  if (value is! List) throw const FormatException('Expected object list.');
  return <Map<String, Object?>>[
    for (final item in value)
      if (item is Map)
        Map<String, Object?>.from(item)
      else
        throw const FormatException('Expected object list entry.'),
  ];
}
