import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../calculation/elv5_blocked_capture.dart';
import '../calculation/elv5_calculation_runtime.dart';
import '../calculation/elv5_kernel_executor.dart';
import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_lan_persistence.dart';
import 'lan06_rack_contract.dart';

final class Lan06PersistedInputResolver
    implements Elv5ProcessInputResolver<Lan06Input> {
  Lan06PersistedInputResolver({
    required this.lanStore,
    required this.contractSource,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final Elv5LanFactStore lanStore;
  final Lan06RackBasisContractSource contractSource;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan06;

  @override
  Future<Elv5CapturedInput<Lan06Input>> capture(
    Elv5CalculationRequest request,
  ) async {
    if (request.processCode != processCode) {
      throw StateError('LAN06_RESOLVER_PROCESS_CODE_MISMATCH');
    }
    if (request.subject.kind != 'RACK') {
      throw StateError('LAN06_SUBJECT_KIND_MUST_BE_RACK');
    }

    final rackId = request.subject.id;
    final aggregate = await lanStore.load(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      operation: 'REPLACE_RACK_CAPACITY_BASIS',
      subjectId: rackId,
    );
    final basisFingerprint = _encoder.sha256(<String, Object?>{
      'schema': 'electra.elv5-lan06-capture-basis.v1',
      'rackId': rackId,
    });
    if (aggregate == null) {
      _blocked(
        request,
        'LAN06_RACK_CAPACITY_BASIS_REQUIRED',
        basisFingerprint,
        basisFingerprint,
        const <Elv5DependencyMarker>[],
        <String, Object?>{'rackId': rackId},
      );
    }
    if (_text(aggregate!.payload, 'rackId') != rackId) {
      throw StateError('LAN06_RACK_ID_MISMATCH:$rackId');
    }

    final dependencies = <Elv5DependencyMarker>[
      _dependency(
        request,
        'SET',
        'LAN_RACK_CAPACITY_BASIS',
        rackId,
        memberId: '${aggregate.aggregateId}:${aggregate.revision}',
      ),
    ];
    final aggregateFingerprint = lan06AggregateFingerprint(aggregate.payload);
    final snapshot = await contractSource.loadActiveForRack(
      projectId: request.projectId,
      designRevisionId: request.designRevisionId,
      rackId: rackId,
    );
    if (snapshot == null) {
      _blocked(
        request,
        'LAN06_RACK_BASIS_CONTRACT_REQUIRED',
        aggregateFingerprint,
        basisFingerprint,
        dependencies,
        <String, Object?>{'rackId': rackId},
      );
    }
    final contract = snapshot!.contract;
    dependencies.add(
      _dependency(
        request,
        'POLICY',
        'LAN06_RACK_BASIS_CONTRACT',
        snapshot.evidenceRef,
        memberId:
            '${snapshot.bindingId}:${snapshot.bindingRevision}:${snapshot.contentHash}',
      ),
    );

    if (contract.expectedAggregateFingerprint != aggregateFingerprint) {
      _blocked(
        request,
        'LAN06_AGGREGATE_FINGERPRINT_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'expected': contract.expectedAggregateFingerprint,
          'actual': aggregateFingerprint,
        },
      );
    }

    final policyRef = _map(aggregate.payload['policyRef'], 'policyRef');
    if (_text(policyRef, 'policyCode') != contract.policyRef.policyCode ||
        _text(policyRef, 'editionId') != contract.policyRef.editionId ||
        _text(policyRef, 'contentHash').toLowerCase() !=
            contract.policyRef.contentHash) {
      _blocked(
        request,
        'LAN06_POLICY_IDENTITY_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'actualPolicyRef': policyRef,
          'expectedPolicyRef': contract.policyRef.toCanonicalValue(),
        },
      );
    }

    final equipmentIds = _stringList(aggregate.payload['equipmentIds'], 'equipmentIds');
    final actualSet = equipmentIds.toSet();
    if (actualSet.length != equipmentIds.length) {
      _blocked(
        request,
        'LAN06_DUPLICATE_EQUIPMENT_MEMBERSHIP',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{'equipmentIds': equipmentIds},
      );
    }
    final expectedSet = contract.equipment.map((e) => e.equipmentId).toSet();
    if (!_setEquals(actualSet, expectedSet)) {
      _blocked(
        request,
        'LAN06_EQUIPMENT_MEMBERSHIP_MISMATCH',
        aggregateFingerprint,
        snapshot.contentHash,
        dependencies,
        <String, Object?>{
          'aggregateEquipmentIds': actualSet.toList()..sort(),
          'contractEquipmentIds': expectedSet.toList()..sort(),
        },
      );
    }

    final capacityBasisWire = _text(aggregate.payload, 'capacityBasis');
    final capacityBasis = switch (capacityBasisWire) {
      'GROSS_WITH_EXCLUSIONS' => Lan06CapacityBasis.grossWithExclusions,
      'NET_USABLE' => Lan06CapacityBasis.netUsable,
      _ => throw StateError('LAN06_CAPACITY_BASIS_UNSUPPORTED:$capacityBasisWire'),
    };

    final excludedCapacity =
        _map(aggregate.payload['excludedCapacity'], 'excludedCapacity');
    final reservedRu = _wholeNonnegativeRu(
      _text(excludedCapacity, 'reservedRu'),
      'reservedRu',
      request,
      aggregateFingerprint,
      snapshot.contentHash,
      dependencies,
    );
    final unavailableRu = _wholeNonnegativeRu(
      _text(excludedCapacity, 'unavailableRu'),
      'unavailableRu',
      request,
      aggregateFingerprint,
      snapshot.contentHash,
      dependencies,
    );
    final provenance = _text(excludedCapacity, 'provenance');
    final includedInNet = capacityBasis == Lan06CapacityBasis.netUsable;

    final equipment = <Lan06EquipmentDemand>[
      for (final item in contract.equipment)
        Lan06EquipmentDemand(
          equipmentId: item.equipmentId,
          ru: item.ru,
          weight: item.weightKg == null ? null : Mass(item.weightKg!),
          depth: item.depthM == null ? null : Length(item.depthM!),
        ),
    ];
    final exclusions = <Lan06Exclusion>[
      if (reservedRu > 0)
        Lan06Exclusion(
          exclusionId: 'RESERVED:$provenance',
          ru: reservedRu,
          alreadyIncludedInNetCapacity: includedInNet,
        ),
      if (unavailableRu > 0)
        Lan06Exclusion(
          exclusionId: 'UNAVAILABLE:$provenance',
          ru: unavailableRu,
          alreadyIncludedInNetCapacity: includedInNet,
        ),
    ];

    for (final item in contract.equipment) {
      dependencies.add(
        _dependency(
          request,
          'FACT',
          'LAN06_EQUIPMENT_DEFINITION',
          item.evidenceRef,
          memberId: '${item.equipmentId}:${item.evidenceContentHash}',
        ),
      );
    }
    dependencies.add(
      _dependency(
        request,
        'FACT',
        'LAN06_RACK_DEFINITION',
        contract.rackEvidenceRef,
        memberId: contract.rackEvidenceContentHash,
      ),
    );

    final input = Lan06Input(
      rackId: rackId,
      equipment: List.unmodifiable(equipment),
      capacityBasis: capacityBasis,
      capacity: Lan06CapacityFacts(
        ruCapacity: contract.ruCapacity,
        weightCapacity: contract.weightCapacityKg == null
            ? null
            : Mass(contract.weightCapacityKg!),
        depthCapacity: contract.depthCapacityM == null
            ? null
            : Length(contract.depthCapacityM!),
      ),
      exclusions: List.unmodifiable(exclusions),
      explicitSpareRu: contract.explicitSpareRu,
    );

    return Elv5CapturedInput<Lan06Input>(
      request: request,
      value: input,
      inputFingerprint: _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-lan06-captured-input.v1',
        'aggregateFingerprint': aggregateFingerprint,
        'contractContentHash': snapshot.contentHash,
        'capacityBasis': capacityBasisWire,
      }),
      policyFingerprint: snapshot.contentHash,
      dependencies: dependencies,
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: aggregate.revision,
    );
  }

  int _wholeNonnegativeRu(
    String raw,
    String field,
    Elv5CalculationRequest request,
    String inputFingerprint,
    String policyFingerprint,
    List<Elv5DependencyMarker> dependencies,
  ) {
    Elv5Rational value;
    try {
      value = Elv5Rational.parseDecimal(raw);
    } on FormatException {
      _blocked(
        request,
        'LAN06_EXCLUSION_RU_INVALID',
        inputFingerprint,
        policyFingerprint,
        dependencies,
        <String, Object?>{'field': field, 'value': raw},
      );
    }
    if (value < Elv5Rational.zero || !value.isInteger) {
      _blocked(
        request,
        'LAN06_NON_INTEGER_RU_UNSUPPORTED',
        inputFingerprint,
        policyFingerprint,
        dependencies,
        <String, Object?>{'field': field, 'value': raw},
      );
    }
    return (value.numerator ~/ value.denominator).toInt();
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

Elv5PureKernelExecutor<Lan06Input, Lan06Result> buildLan06Executor({
  DateTime Function()? nowUtc,
}) => Elv5PureKernelExecutor<Lan06Input, Lan06Result>(
  processCode: Elv5ProcessCode.lan06,
  calculate: const Lan06RackCapacityKernel().evaluate,
  encodeOutput: (result) => <String, Object?>{
    'schema': 'electra.elv5-lan06-output.v1',
    'status': result.status.name,
    'requiredRu': result.requiredRu,
    'availableRu': result.availableRu,
    'ruMargin': result.ruMargin,
    'requiredWeightKg': result.requiredWeight?.value.toMap(),
    'weightMarginKg': result.weightMargin?.value.toMap(),
    'weightStatus': result.weightStatus.name,
    'requiredDepthM': result.requiredDepth?.value.toMap(),
    'depthMarginM': result.depthMargin?.value.toMap(),
    'depthStatus': result.depthStatus.name,
    'layoutStatus': result.layoutStatus.name,
  },
  encodeEvidence: (captured, _) => <String, Object?>{
    'schema': 'electra.elv5-lan06-evidence.v1',
    'source': 'PERSISTED_RACK_MEMBERSHIP_PLUS_IMMUTABLE_DIMENSION_EVIDENCE',
    'captureRevision': captured.captureRevision,
    'layoutOwnership': 'ELV6_NOT_ASSESSED',
  },
  executionOf: (_) => Elv5Execution.succeeded,
  completionOf: (result) => result.status == Lan06AssessmentStatus.unresolved
      ? Elv5Completion.partial
      : Elv5Completion.complete,
  assessmentOf: (result) => switch (result.status) {
    Lan06AssessmentStatus.pass => Elv5Assessment.pass,
    Lan06AssessmentStatus.fail => Elv5Assessment.fail,
    Lan06AssessmentStatus.unresolved => Elv5Assessment.unresolved,
    Lan06AssessmentStatus.notAssessed => Elv5Assessment.notAssessed,
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

List<String> _stringList(Object? value, String field) {
  if (value is! List || value.any((e) => e is! String)) {
    throw FormatException('$field must be string array.');
  }
  return [for (final item in value) (item as String).trim()];
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
