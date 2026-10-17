import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_lan_persistence.dart';
import 'lan02_port_contract.dart';

final class Lan02PersistedInputResolver
    implements Elv5ProcessInputResolver<Lan02Input> {
  Lan02PersistedInputResolver({
    required this.lanStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5LanFactStore lanStore;
  final Lan02PortContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan02;

  @override
  Future<Elv5CapturedInput<Lan02Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('LAN02_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'SWITCH') {
      throw StateError('LAN02_SUBJECT_KIND_MUST_BE_SWITCH');
    }
    final switchId = request.subject.id;
    final aggregate = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_PORT_CAPACITY_ASSIGNMENTS',
      subjectId: switchId,
    );
    final missing = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan02-missing.v1',
      'switchId': switchId,
    });
    if (aggregate == null) {
      _blocked(
        request,
        'LAN02_PORT_ASSIGNMENTS_REQUIRED',
        missing,
        missing,
        const <Elv5DependencyMarker>[],
        <String, Object?>{'switchId': switchId},
      );
    }
    final payload = aggregate.payload;
    if (_text(payload, 'switchId') != switchId) {
      throw StateError('LAN02_SWITCH_IDENTITY_MISMATCH:$switchId');
    }
    final aggregateFingerprint = _encoder.sha256(payload);
    final deps = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'LAN_PORT_CAPACITY', switchId),
    ];

    final snapshot = await contractSource.loadActiveForSwitch(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      switchId: switchId,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'LAN02_PORT_CONTRACT_REQUIRED',
        aggregateFingerprint,
        aggregateFingerprint,
        deps,
        <String, Object?>{'switchId': switchId},
      );
    }
    final contract = snapshot.contract;
    deps.add(
      _dependency(
        request,
        'POLICY',
        'LAN02_PORT_CONTRACT',
        snapshot.evidenceRef,
        memberId:
            '${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
      ),
    );
    if (contract.switchId != switchId ||
        contract.expectedAggregateFingerprint != aggregateFingerprint) {
      _blocked(
        request,
        'LAN02_SWITCH_AGGREGATE_FINGERPRINT_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        deps,
        <String, Object?>{
          'expected': contract.expectedAggregateFingerprint,
          'actual': aggregateFingerprint,
        },
      );
    }

    final spareRef = _map(payload['sparePolicyRef'], 'sparePolicyRef');
    if (_text(spareRef, 'policyCode') != contract.sparePolicy.policyCode ||
        _text(spareRef, 'editionId') != contract.sparePolicy.editionId ||
        _text(spareRef, 'contentHash').toLowerCase() !=
            contract.sparePolicy.contentHash) {
      _blocked(
        request,
        'LAN02_SPARE_POLICY_IDENTITY_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        deps,
        <String, Object?>{
          'expected': contract.sparePolicy.toCanonicalValue(),
          'actual': spareRef,
        },
      );
    }
    deps.add(
      _dependency(
        request,
        'POLICY',
        'LAN_PORT_SPARE_POLICY',
        contract.sparePolicy.editionId,
        memberId: contract.sparePolicy.contentHash,
      ),
    );

    final portById = <String, Lan02PortContractItem>{
      for (final p in contract.ports) p.portId: p,
    };
    final assignments = <Lan02PortAssignment>[];
    final rows = _objects(payload['assignments'], 'assignments');
    for (final row in rows) {
      final portId = _text(row, 'portId');
      final endpointId = _text(row, 'endpointId');
      final media = _text(row, 'media').toUpperCase();
      final speedRaw = _text(row, 'speedBps');
      final speedBps = BigInt.tryParse(speedRaw);
      if (speedBps == null || speedBps <= BigInt.zero) {
        throw FormatException('LAN02 speedBps must be positive integer text.');
      }
      final million = BigInt.from(1000000);
      if (speedBps % million != BigInt.zero) {
        _blocked(
          request,
          'LAN02_SPEED_BPS_NOT_WHOLE_MBPS',
          aggregateFingerprint,
          snapshot.contentHash,
          deps,
          <String, Object?>{'endpointId': endpointId, 'speedBps': speedRaw},
        );
      }
      final physical = portById[portId];
      if (physical != null && physical.media != media) {
        // Keep this as kernel FAIL by preserving the persisted required media.
      }
      assignments.add(
        Lan02PortAssignment(
          endpointId: endpointId,
          portId: portId,
          requiredMedia: media,
          requiredSpeedMbps: (speedBps ~/ million).toInt(),
        ),
      );
      deps.add(
        _dependency(
          request,
          'SET',
          'LAN_SWITCH_PORT',
          switchId,
          memberId: portId,
        ),
      );
    }

    final input = Lan02Input(
      switchId: switchId,
      ports: <Lan02PhysicalPort>[
        for (final p in contract.ports)
          Lan02PhysicalPort(
            portId: p.portId,
            media: p.media,
            maxSpeedMbps: p.maxSpeedMbps,
          ),
      ],
      assignments: assignments,
      unavailablePortIds: contract.unavailablePortIds,
      sparePolicy: Lan02SparePolicy(
        absoluteMinimum: contract.absoluteMinimum,
        ratio: contract.ratio,
        combiner:
            contract.combinerCode == 'MAX'
                ? Lan02SpareCombiner.max
                : Lan02SpareCombiner.sum,
      ),
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan02-captured-input.v1',
      'aggregateFingerprint': aggregateFingerprint,
      'contractEvidenceRef': snapshot.evidenceRef,
      'contractContentHash': snapshot.contentHash,
    });
    return Elv5CapturedInput<Lan02Input>(
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

Elv5PureKernelExecutor<Lan02Input, Lan02Result> buildLan02Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Lan02Input, Lan02Result>(
  processCode: Elv5ProcessCode.lan02,
  calculate: const Lan02PortCapacityKernel().evaluate,
  encodeOutput:
      (r) => <String, Object?>{
        'schema': 'electra.elv5-lan02-output.v1',
        'status': r.status.name,
        'occupied': r.occupied,
        'requiredSpare': r.requiredSpare,
        'available': r.available,
        'headroomPorts': r.headroomPorts,
        'incompatibleEndpointIds': r.incompatibleEndpointIds,
      },
  encodeEvidence:
      (c, _) => <String, Object?>{
        'schema': 'electra.elv5-lan02-evidence.v1',
        'source':
            'PERSISTED_PORT_ASSIGNMENTS_PLUS_IMMUTABLE_PORT_INVENTORY_AND_SPARE_POLICY',
        'captureRevision': c.captureRevision,
      },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (_) => Elv5Completion.complete,
  assessmentOf:
      (r) =>
          r.status == Lan02AssessmentStatus.pass
              ? Elv5Assessment.pass
              : Elv5Assessment.fail,
  nowUtc: nowUtc,
);

List<Map<String, Object?>> _objects(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be array.');
  return [for (final raw in value) _map(raw, field)];
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
