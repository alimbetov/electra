import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_fire_persistence.dart';
import 'fa01_address_capacity_contract.dart';

final class Fa01PersistedInputResolver
    implements Elv5ProcessInputResolver<Fa01Input> {
  Fa01PersistedInputResolver({
    required this.fireStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5FireFactStore fireStore;
  final Fa01AddressCapacityContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa01;

  @override
  Future<Elv5CapturedInput<Fa01Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('FA01_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'FIRE_LOOP') {
      throw StateError('FA01_SUBJECT_KIND_MUST_BE_FIRE_LOOP');
    }

    final snapshot = await fireStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_FIRE_LOOP_ASSIGNMENTS',
      subjectId: request.subject.id,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'FA01_FIRE_LOOP_ASSIGNMENTS_MISSING',
        _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-fa01-missing-loop.v1',
          'loopId': request.subject.id,
        }),
        _encoder.sha256(<String, Object?>{
          'schema': 'electra.elv5-fa01-missing-policy.v1',
          'loopId': request.subject.id,
        }),
        const <Elv5DependencyMarker>[],
        <String, Object?>{'loopId': request.subject.id},
      );
    }
    final loopId = _text(snapshot.payload, 'loopId');
    if (loopId != request.subject.id) {
      throw StateError('FA01_LOOP_ID_MISMATCH:$loopId:${request.subject.id}');
    }
    final aggregateFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa01-loop-basis.v1',
      'aggregateId': snapshot.aggregateId,
      'aggregateRevision': snapshot.revision,
      'payload': snapshot.payload,
    });
    final dependencies = <Elv5DependencyMarker>[
      _dependency(request, 'SET', 'FIRE_LOOP', loopId),
    ];

    final contractSnapshot = await contractSource.loadActiveForLoop(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      loopId: loopId,
    );
    if (contractSnapshot == null) {
      _blocked(
        request,
        'FA01_ADDRESS_CAPACITY_CONTRACT_REQUIRED',
        aggregateFingerprint,
        aggregateFingerprint,
        dependencies,
        <String, Object?>{'loopId': loopId},
      );
    }
    final contract = contractSnapshot.contract;
    if (contract.loopId != loopId) {
      throw StateError('FA01_CONTRACT_LOOP_IDENTITY_MISMATCH:$loopId');
    }
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'FA01_ADDRESS_CAPACITY_CONTRACT',
        contractSnapshot.evidenceRef,
        memberId:
            '${contractSnapshot.bindingId}:${contractSnapshot.bindingRevision}:${contractSnapshot.contentHash}',
      ),
    );

    final domain = _map(snapshot.payload['addressDomain'], 'addressDomain');
    final panelId = _text(domain, 'panelId');
    final domainLoopId = _text(domain, 'loopId');
    if (domainLoopId != loopId) {
      throw StateError(
        'FA01_ADDRESS_DOMAIN_LOOP_MISMATCH:$domainLoopId:$loopId',
      );
    }
    final minAddress = _int(domain, 'minAddress');
    final maxAddress = _int(domain, 'maxAddress');
    if (minAddress < 0 || maxAddress < minAddress) {
      throw StateError('FA01_ADDRESS_DOMAIN_INVALID:$minAddress:$maxAddress');
    }
    final domainCapacity = maxAddress - minAddress + 1;
    if (contract.addressLimit > domainCapacity) {
      _blocked(
        request,
        'FA01_ADDRESS_LIMIT_EXCEEDS_DOMAIN',
        aggregateFingerprint,
        contractSnapshot.contentHash,
        dependencies,
        <String, Object?>{
          'addressLimit': contract.addressLimit,
          'domainCapacity': domainCapacity,
          'minAddress': minAddress,
          'maxAddress': maxAddress,
        },
      );
    }
    final domainId = '$panelId|$loopId';

    final reservedValues = _ints(
      domain['reservedAddresses'],
      'reservedAddresses',
    );
    final reserved = <Fa01AddressKey>{};
    for (final address in reservedValues) {
      if (address < minAddress || address > maxAddress) {
        throw StateError('FA01_RESERVED_ADDRESS_OUTSIDE_DOMAIN:$address');
      }
      reserved.add(Fa01AddressKey(domainId: domainId, address: address));
    }

    final devices = <Fa01DeviceAssignment>[];
    final seenDevices = <String>{};
    for (final row in _objects(
      snapshot.payload['deviceAssignments'],
      'deviceAssignments',
    )) {
      final deviceId = _text(row, 'deviceId');
      if (!seenDevices.add(deviceId)) {
        throw StateError('FA01_DUPLICATE_DEVICE_ID:$deviceId');
      }
      final profileRef = _text(row, 'profileRef');
      final expectedAddresses = contract.profileAddressConsumption[profileRef];
      final deviceContribution =
          contract.profileDeviceCountContribution[profileRef];
      if (expectedAddresses == null || deviceContribution == null) {
        _blocked(
          request,
          'FA01_PROFILE_RESOURCE_EVIDENCE_MISSING',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{'deviceId': deviceId, 'profileRef': profileRef},
        );
      }
      final expanded = _ints(row['expandedAddresses'], 'expandedAddresses');
      if (expanded.isEmpty || expanded.toSet().length != expanded.length) {
        throw StateError('FA01_EXPANDED_ADDRESS_SET_INVALID:$deviceId');
      }
      if (expanded.length != expectedAddresses) {
        _blocked(
          request,
          'FA01_PROFILE_CONSUMPTION_CARDINALITY_MISMATCH',
          aggregateFingerprint,
          contractSnapshot.contentHash,
          dependencies,
          <String, Object?>{
            'deviceId': deviceId,
            'profileRef': profileRef,
            'expectedConsumption': expectedAddresses,
            'expandedCount': expanded.length,
          },
        );
      }
      final keys = <Fa01AddressKey>{};
      for (final address in expanded) {
        if (address < minAddress || address > maxAddress) {
          _blocked(
            request,
            'FA01_EXPANDED_ADDRESS_OUTSIDE_DOMAIN',
            aggregateFingerprint,
            contractSnapshot.contentHash,
            dependencies,
            <String, Object?>{
              'deviceId': deviceId,
              'address': address,
              'minAddress': minAddress,
              'maxAddress': maxAddress,
            },
          );
        }
        keys.add(Fa01AddressKey(domainId: domainId, address: address));
      }
      devices.add(
        Fa01DeviceAssignment(
          deviceId: deviceId,
          addresses: keys,
          expectedConsumption: expectedAddresses,
          physicalDeviceCountContribution: deviceContribution,
        ),
      );
      dependencies.add(
        _dependency(
          request,
          'FACT',
          'FIRE_DEVICE_PROFILE',
          profileRef,
          memberId: '$deviceId:$expectedAddresses:$deviceContribution',
        ),
      );
    }

    final input = Fa01Input(
      loopId: loopId,
      devices: devices,
      reserved: reserved,
      policy: Fa01CapacityPolicy(
        deviceLimit: contract.deviceLimit,
        addressLimit: contract.addressLimit,
        requiredDeviceSpare: contract.requiredDeviceSpare,
        requiredAddressSpare: contract.requiredAddressSpare,
      ),
    );
    final inputFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-fa01-captured-input.v1',
      'aggregateFingerprint': aggregateFingerprint,
      'contractEvidenceRef': contractSnapshot.evidenceRef,
      'contractContentHash': contractSnapshot.contentHash,
      'domainId': domainId,
    });
    return Elv5CapturedInput<Fa01Input>(
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
    String reason,
    String inputFp,
    String policyFp,
    List<Elv5DependencyMarker> deps,
    Map<String, Object?> evidence,
  ) {
    throw Elv5CaptureBlockedException(
      request: request,
      reasonCode: reason,
      inputFingerprint: inputFp,
      policyFingerprint: policyFp,
      dependencies: deps,
      evidence: evidence,
    );
  }

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

Elv5PureKernelExecutor<Fa01Input, Fa01Result> buildFa01Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Fa01Input, Fa01Result>(
  processCode: Elv5ProcessCode.fa01,
  calculate: const Fa01AddressCapacityKernel().evaluate,
  encodeOutput:
      (result) => <String, Object?>{
        'schema': 'electra.elv5-fa01-output.v1',
        'status': result.status.name,
        'deviceCount': result.deviceCount,
        'addressCount': result.addressCount,
        'deviceHeadroom': result.deviceHeadroom,
        'addressHeadroom': result.addressHeadroom,
        'collisions': [
          for (final c in result.collisions)
            <String, Object?>{
              'domainId': c.key.domainId,
              'address': c.key.address,
              'claimants': c.claimants,
            },
        ],
      },
  encodeEvidence:
      (captured, _) => <String, Object?>{
        'schema': 'electra.elv5-fa01-evidence.v1',
        'source':
            'PERSISTED_FIRE_LOOP_ASSIGNMENTS_PLUS_IMMUTABLE_PROFILE_CAPACITY_CONTRACT',
        'captureRevision': captured.captureRevision,
      },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (_) => Elv5Completion.complete,
  assessmentOf:
      (result) =>
          result.status == Fa01AssessmentStatus.pass
              ? Elv5Assessment.pass
              : Elv5Assessment.fail,
  nowUtc: nowUtc,
);

List<Map<String, Object?>> _objects(Object? raw, String field) {
  if (raw is! List) throw FormatException('$field must be array.');
  return [for (final v in raw) _map(v, field)];
}

Map<String, Object?> _map(Object? raw, String field) {
  if (raw is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(raw);
}

String _text(Map<String, Object?> map, String key) {
  final v = map[key];
  if (v is! String || v.trim().isEmpty)
    throw FormatException('$key must be text.');
  return v.trim();
}

int _int(Map<String, Object?> map, String key) {
  final v = map[key];
  if (v is! int) throw FormatException('$key must be int.');
  return v;
}

List<int> _ints(Object? raw, String field) {
  if (raw is! List || raw.any((v) => v is! int))
    throw FormatException('$field must be integer array.');
  return raw.cast<int>();
}
