import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_fire_persistence.dart';
import 'fa01_membership_fingerprint.dart';
import 'fa07_topology_contract.dart';

final class Fa07PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa07Input> {
  Fa07PersistedInputResolver({
    required this.fireStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());
  final Elv5FireFactStore fireStore;
  final Fa07TopologyContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();
  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa07;

  @override
  Future<Elv5CapturedInput<Fa07Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode)
      throw StateError('FA07_RESOLVER_PROCESS_CODE_MISMATCH');
    if (request.subject.kind != 'FIRE_LOOP')
      throw StateError('FA07_SUBJECT_KIND_MUST_BE_FIRE_LOOP');
    final loop = await fireStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_FIRE_LOOP_ASSIGNMENTS',
      subjectId: request.subject.id,
    );
    if (loop == null)
      _blocked(
        request,
        'FA07_FIRE_LOOP_ASSIGNMENTS_MISSING',
        _hashMissing(request.subject.id),
        _hashMissing(request.subject.id),
        const <Elv5DependencyMarker>[],
        <String, Object?>{'loopId': request.subject.id},
      );
    final loopId = _text(loop.payload, 'loopId');
    if (loopId != request.subject.id)
      throw StateError('FA07_LOOP_ID_MISMATCH:$loopId:${request.subject.id}');
    final assignments = _objects(
      loop.payload['deviceAssignments'],
      'deviceAssignments',
    );
    final persistedDeviceIds = <String>[
      for (final row in assignments) _text(row, 'deviceId'),
    ];
    if (persistedDeviceIds.toSet().length != persistedDeviceIds.length)
      throw StateError('FA07_DUPLICATE_PERSISTED_DEVICE_ID:$loopId');
    final addressDomain = _map(loop.payload['addressDomain'], 'addressDomain');
    final membership = fa01MembershipFingerprint(
      loopId: loopId,
      addressDomain: addressDomain,
      deviceAssignments: assignments,
    );
    final deps = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'FIRE_LOOP', loopId, memberId: membership),
    ];
    final aggregateFp = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa07-loop-basis.v1',
      'aggregateId': loop.aggregateId,
      'aggregateRevision': loop.revision,
      'payload': loop.payload,
    });

    final snap = await contractSource.loadActiveForLoop(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      loopId: loopId,
    );
    if (snap == null)
      _blocked(
        request,
        'FA07_TOPOLOGY_CONTRACT_REQUIRED',
        aggregateFp,
        aggregateFp,
        deps,
        <String, Object?>{
          'loopId': loopId,
          'fa01MembershipFingerprint': membership,
        },
      );
    final contract = snap.contract;
    if (contract.loopId != loopId)
      throw StateError('FA07_CONTRACT_LOOP_IDENTITY_MISMATCH:$loopId');
    deps.add(
      _dependency(
        request,
        'POLICY',
        'FA07_TOPOLOGY_CONTRACT',
        snap.evidenceRef,
        memberId:
            '${snap.bindingId}:${snap.bindingRevision}:${snap.contentHash}',
      ),
    );
    if (contract.expectedFa01MembershipFingerprint != membership) {
      _blocked(
        request,
        'FA07_FA01_MEMBERSHIP_FINGERPRINT_MISMATCH',
        aggregateFp,
        snap.contentHash,
        deps,
        <String, Object?>{
          'expected': contract.expectedFa01MembershipFingerprint,
          'actual': membership,
        },
      );
    }

    final persistedProfile = _map(
      loop.payload['topologyProfileRef'],
      'topologyProfileRef',
    );
    final actualProfile = <String, Object?>{
      'profileCode': _text(persistedProfile, 'profileCode'),
      'editionId': _text(persistedProfile, 'editionId'),
      'contentHash': _text(persistedProfile, 'contentHash'),
    };
    final expectedProfile = contract.topologyProfile.toCanonicalValue();
    if (_encoder.sha256(actualProfile) != _encoder.sha256(expectedProfile)) {
      _blocked(
        request,
        'FA07_TOPOLOGY_PROFILE_IDENTITY_MISMATCH',
        aggregateFp,
        snap.contentHash,
        deps,
        <String, Object?>{
          'persisted': actualProfile,
          'contract': expectedProfile,
        },
      );
    }

    final deviceIds = persistedDeviceIds.toSet();
    final mappedIds = contract.deviceNodeIdByDeviceId.keys.toSet();
    if (deviceIds.length != mappedIds.length ||
        !deviceIds.containsAll(mappedIds)) {
      _blocked(
        request,
        'FA07_DEVICE_NODE_MAPPING_MISMATCH',
        aggregateFp,
        snap.contentHash,
        deps,
        <String, Object?>{
          'persistedDeviceIds': deviceIds.toList()..sort(),
          'mappedDeviceIds': mappedIds.toList()..sort(),
        },
      );
    }
    final deviceNodes = <String>{
      for (final id in deviceIds) contract.deviceNodeIdByDeviceId[id]!,
    };

    final faultScenarios = <Fa07FaultScenario>[];
    for (final fault in contract.faultScenarios) {
      final expectedNodes = <String>{};
      for (final deviceId in fault.expectedReachableDeviceIds) {
        final node = contract.deviceNodeIdByDeviceId[deviceId];
        if (node == null)
          _blocked(
            request,
            'FA07_FAULT_EXPECTED_DEVICE_UNKNOWN',
            aggregateFp,
            snap.contentHash,
            deps,
            <String, Object?>{'caseCode': fault.caseCode, 'deviceId': deviceId},
          );
        expectedNodes.add(node);
      }
      faultScenarios.add(
        Fa07FaultScenario(
          caseType: _case(fault.caseCode),
          removedEdgeIds: fault.removedEdgeIds,
          expectedReachableDeviceIds: expectedNodes,
        ),
      );
    }
    final input = Fa07Input(
      loopId: loopId,
      sourceNodeId: contract.sourceNodeId,
      returnNodeId: contract.returnNodeId,
      deviceNodeIds: deviceNodes,
      addressMemberIds: deviceNodes,
      edges: [
        for (final edge in contract.edges)
          Fa07SignalEdge(
            edgeId: edge.edgeId,
            fromNodeId: edge.fromNodeId,
            toNodeId: edge.toNodeId,
          ),
      ],
      permittedBranchNodeIds: contract.permittedBranchNodeIds,
      maxBranchNodes: contract.maxBranchNodes,
      requiredFaultCases: <Fa07TopologyCase>{
        for (final code in contract.requiredFaultCases) _case(code),
      },
      faultScenarios: faultScenarios,
    );
    final fp = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa07-captured-input.v1',
      'aggregateFingerprint': aggregateFp,
      'fa01MembershipFingerprint': membership,
      'contractEvidenceRef': snap.evidenceRef,
      'contractContentHash': snap.contentHash,
    });
    return Elv5CapturedInput<Fa07Input>(
      request: request,
      value: input,
      inputFingerprint: fp,
      policyFingerprint: snap.contentHash,
      dependencies: deps,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: loop.revision,
    );
  }

  Fa07TopologyCase _case(String code) => switch (code) {
    'OPEN_FAULT' => Fa07TopologyCase.openFault,
    'SHORT_FAULT' => Fa07TopologyCase.shortFault,
    'RETURN_LOSS' => Fa07TopologyCase.returnLoss,
    _ => throw StateError('FA07_UNSUPPORTED_FAULT_CASE:$code'),
  };
  String _hashMissing(String loopId) => _encoder.sha256(<String, Object?>{
    'schema': 'electra.elv5-fa07-missing.v1',
    'loopId': loopId,
  });
  Never _blocked(
    Elv5CalculationRequest r,
    String reason,
    String input,
    String policy,
    List<Elv5DependencyMarker> deps,
    Map<String, Object?> evidence,
  ) =>
      throw Elv5CaptureBlockedException(
        request: r,
        reasonCode: reason,
        inputFingerprint: input,
        policyFingerprint: policy,
        dependencies: deps,
        evidence: evidence,
      );
  Elv5DependencyMarker _dependency(
    Elv5CalculationRequest r,
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
      projectId: r.projectId,
      designRevisionId: r.designRevisionId,
      dependencyKey: utf8.decode(_encoder.encode(value)),
      dependencyKeySha256: _encoder.sha256(value),
      logicalNodeKeySha256: _encoder.sha256(r.nodeKey.toCanonicalValue()),
      relationKind: relation,
      updatedAtUtc: _nowUtc().toUtc(),
    );
  }
}

Elv5PureKernelExecutor<Fa07Input, Fa07Result> buildFa07Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa07Input, Fa07Result>(
  processCode: Elv5ProcessCode.fa07,
  calculate: const Fa07SignalTopologyKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-fa07-output.v1',
        'status': result.status.name,
        'governingCase': result.governingCase?.name,
        'reason': result.reason,
        'cases': <String, Object?>{
          for (final e in result.cases.entries)
            e.key.name: <String, Object?>{
              'status': e.value.status.name,
              'reachableDeviceIds': e.value.reachableDeviceIds.toList()..sort(),
              'reason': e.value.reason,
            },
        },
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-fa07-evidence.v1',
        'source':
            'PERSISTED_FA01_MEMBERSHIP_PLUS_IMMUTABLE_SIGNAL_TOPOLOGY_CONTRACT',
        'captureRevision': captured.captureRevision,
      },
  executionOf:
      (result) =>
          result.status == Fa07AssessmentStatus.blocked
              ? Elv5Execution.blocked
              : Elv5Execution.succeeded,
  completionOf:
      (result) =>
          result.status == Fa07AssessmentStatus.blocked
              ? Elv5Completion.incomplete
              : Elv5Completion.complete,
  assessmentOf:
      (result) => switch (result.status) {
        Fa07AssessmentStatus.pass => Elv5Assessment.pass,
        Fa07AssessmentStatus.fail => Elv5Assessment.fail,
        Fa07AssessmentStatus.blocked => Elv5Assessment.unresolved,
      },
  nowUtc: nowUtc,
);

List<Map<String, Object?>> _objects(Object? v, String f) {
  if (v is! List) throw FormatException('$f must be array.');
  return [for (final x in v) _map(x, f)];
}

Map<String, Object?> _map(Object? v, String f) {
  if (v is! Map) throw FormatException('$f must be object.');
  return Map<String, Object?>.from(v);
}

String _text(Map<String, Object?> m, String k) {
  final v = m[k];
  if (v is! String || v.trim().isEmpty)
    throw FormatException('$k must be text.');
  return v.trim();
}
