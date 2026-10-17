import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_persistence.dart';
import 'package:electra_mobile/application/elv5/lan/lan06_rack_contract.dart';
import 'package:electra_mobile/application/elv5/lan/lan06_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN06 reference vector reports +2 RU and leaves layout not assessed', () async {
    final payload = _payload(capacityBasis: 'GROSS_WITH_EXCLUSIONS');
    final resolver = Lan06PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload, ruCapacity: 6)),
    );

    final result = await buildLan06Executor().execute(
      await resolver.capture(_request()),
    );

    expect(result.assessment, Elv5Assessment.pass);
    expect(result.output['requiredRu'], 4);
    expect(result.output['availableRu'], 6);
    expect(result.output['ruMargin'], 2);
    expect(result.output['layoutStatus'], 'notAssessed');
  });

  test('LAN06 fails weight basis independently of passing RU basis', () async {
    final payload = _payload(capacityBasis: 'GROSS_WITH_EXCLUSIONS');
    final resolver = Lan06PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(
        _contract(
          payload,
          ruCapacity: 6,
          equipmentWeightsKg: const ['60', '50'],
          weightCapacityKg: '100',
        ),
      ),
    );

    final result = await buildLan06Executor().execute(
      await resolver.capture(_request()),
    );

    expect(result.assessment, Elv5Assessment.fail);
    expect(result.output['ruMargin'], 2);
    expect(result.output['weightStatus'], 'fail');
    expect(
      result.output['weightMarginKg'],
      <String, Object?>{'numerator': '-10', 'denominator': '1'},
    );
    expect(result.output['layoutStatus'], 'notAssessed');
  });

  test('LAN06 net usable basis does not subtract included exclusions twice', () async {
    final payload = _payload(
      capacityBasis: 'NET_USABLE',
      reservedRu: '2',
      unavailableRu: '1',
    );
    final resolver = Lan06PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload, ruCapacity: 6)),
    );

    final result = await buildLan06Executor().execute(
      await resolver.capture(_request()),
    );

    expect(result.output['availableRu'], 6);
    expect(result.output['requiredRu'], 4);
    expect(result.output['ruMargin'], 2);
    expect(result.assessment, Elv5Assessment.pass);
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
      projectId: 'project',
      designRevisionId: 'revision',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'revision',
        scenarioKey: 'NONE',
      ),
      processCode: Elv5ProcessCode.lan06,
      subject: Elv5SubjectRef(kind: 'RACK', id: 'rack-1'),
      expectedPointerGeneration: 0,
    );

Map<String, Object?> _payload({
  required String capacityBasis,
  String reservedRu = '0',
  String unavailableRu = '0',
}) =>
    <String, Object?>{
      'rackId': 'rack-1',
      'capacityBasis': capacityBasis,
      'equipmentIds': <String>['eq-1', 'eq-2'],
      'excludedCapacity': <String, Object?>{
        'reservedRu': reservedRu,
        'unavailableRu': unavailableRu,
        'provenance': 'rack-definition-v1',
      },
      'policyRef': <String, Object?>{
        'policyCode': 'RACK_CAPACITY_POLICY',
        'editionId': 'rack-policy-v1',
        'contentHash': _hash('d'),
      },
    };

Lan06RackBasisContract _contract(
  Map<String, Object?> payload, {
  required int ruCapacity,
  List<String>? equipmentWeightsKg,
  String? weightCapacityKg,
}) {
  final weights = equipmentWeightsKg ?? const <String>['20', '10'];
  return Lan06RackBasisContract(
    rackId: 'rack-1',
    expectedAggregateFingerprint: lan06AggregateFingerprint(payload),
    policyRef: Lan06PolicyRef(
      policyCode: 'RACK_CAPACITY_POLICY',
      editionId: 'rack-policy-v1',
      contentHash: _hash('d'),
    ),
    ruCapacity: ruCapacity,
    weightCapacityKg: weightCapacityKg == null
        ? null
        : Elv5Rational.parseDecimal(weightCapacityKg),
    depthCapacityM: Elv5Rational.parseDecimal('1'),
    explicitSpareRu: 1,
    equipment: <Lan06EquipmentBasisContract>[
      Lan06EquipmentBasisContract(
        equipmentId: 'eq-1',
        ru: 2,
        weightKg: Elv5Rational.parseDecimal(weights[0]),
        depthM: Elv5Rational.parseDecimal('0.6'),
        evidenceRef: 'CATALOG:eq-1',
        evidenceContentHash: _hash('a'),
      ),
      Lan06EquipmentBasisContract(
        equipmentId: 'eq-2',
        ru: 1,
        weightKg: Elv5Rational.parseDecimal(weights[1]),
        depthM: Elv5Rational.parseDecimal('0.8'),
        evidenceRef: 'CATALOG:eq-2',
        evidenceContentHash: _hash('b'),
      ),
    ],
    rackEvidenceRef: 'CATALOG:rack-1',
    rackEvidenceContentHash: _hash('c'),
  );
}

final class _Store implements Elv5LanFactStore {
  const _Store(this.payload);
  final Map<String, Object?> payload;

  @override
  Future<Elv5LanAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async =>
      Elv5LanAggregateSnapshot(
        aggregateKind: 'LAN_RACK_CAPACITY_BASIS',
        aggregateId: 'ELV5:LAN_RACK_CAPACITY_BASIS:rack-1',
        subjectId: 'rack-1',
        revision: 3,
        payload: payload,
      );
}

final class _Contracts implements Lan06RackBasisContractSource {
  const _Contracts(this.contract);
  final Lan06RackBasisContract contract;

  @override
  Future<Lan06RackBasisContractSnapshot?> loadActiveForRack({
    required String projectId,
    required String designRevisionId,
    required String rackId,
  }) async =>
      Lan06RackBasisContractSnapshot(
        bindingId: 'lan06-binding',
        bindingRevision: 1,
        evidenceRef: 'LAN06:rack-1:${_hash('e')}',
        contentHash: _hash('e'),
        contract: contract,
      );
}

String _hash(String char) => List<String>.filled(64, char).join();
