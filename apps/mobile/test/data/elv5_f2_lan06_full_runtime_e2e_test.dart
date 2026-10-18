import 'package:electra_mobile/application/elv5/lan/lan06_rack_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 LAN-06 production Q6/Q7/Q8 authoritative policy replacement, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.lan06,
        subjectKind: 'RACK',
        subjectId: 'rack-1',
      );
      late Map<String, Object?> payload;
      await lifecycle.run(
        seed: (db) async {
          await seedF2LanTopology(db);
          payload = f2Lan06Payload(capacityBasis: 'GROSS_WITH_EXCLUSIONS');
          await replaceF2LanRack(db, payload, 'seed-source');
          payload = await loadF2LanAggregate(
            db,
            'REPLACE_RACK_CAPACITY_BASIS',
            'rack-1',
          );
          await _replace(db, payload, 2, null, false);
        },
        mutate: (db) => _replace(db, payload, 3, 1, true),
        dependencyDomains: {
          'LAN_RACK_CAPACITY_BASIS',
          'LAN06_RACK_BASIS_CONTRACT',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(o['requiredRu'], 4);
          expect(o['ruMargin'], 2);
          expect(o['layoutStatus'], 'notAssessed');
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(o['requiredRu'], 4);
          expect(o['ruMargin'], -1);
          expect(o['layoutStatus'], 'notAssessed');
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, payload, 5, 2, false),
            throwsA(
              predicate(
                (e) => e.toString().contains('LAN06_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2LanRack(db, payload, 'frozen-source'),
            throwsA(
              predicate(
                (e) => e.toString().contains('ELV5_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _replace(
  AppDatabase db,
  Map<String, Object?> payload,
  int revision,
  int? bindingRevision,
  bool changed,
) => DriftElv5LanContractMutationCoordinator(
  db,
  originDeviceId: 'f2-lan',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceLan06(
  ReplaceLan06RackBasisContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: _contract(
      payload,
      ruCapacity: changed ? 3 : 6,
      weightCapacityKg: '100',
    ),
  ),
);
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
      contentHash: f2LanHash('d'),
    ),
    ruCapacity: ruCapacity,
    weightCapacityKg:
        weightCapacityKg == null
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
        evidenceContentHash: f2LanHash('a'),
      ),
      Lan06EquipmentBasisContract(
        equipmentId: 'eq-2',
        ru: 1,
        weightKg: Elv5Rational.parseDecimal(weights[1]),
        depthM: Elv5Rational.parseDecimal('0.8'),
        evidenceRef: 'CATALOG:eq-2',
        evidenceContentHash: f2LanHash('b'),
      ),
    ],
    rackEvidenceRef: 'CATALOG:rack-1',
    rackEvidenceContentHash: f2LanHash('c'),
  );
}
