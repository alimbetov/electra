import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa01_address_capacity_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 FA-01 production Q6/Q7/Q8 contract replacement, independent SQLite race, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.fa01,
        subjectKind: 'FIRE_LOOP',
        subjectId: 'loop-1',
      );
      await lifecycle.run(
        seed: (db) async {
          await seedF2FireTopology(db);
          await replaceF2FireLoop(db);
          await _replace(db, revision: 2, bindingRevision: null, limit: 3);
        },
        mutate: (db) async {
          // The pointer fault proves contract, edition and revision all roll back
          // if invalidation cannot commit in the source replacement transaction.
          final before = await _store(db).loadActiveForLoop(
            projectId: 'p',
            designRevisionId: 'd',
            loopId: 'loop-1',
          );
          await db.customStatement(
            "CREATE TRIGGER reject_fa01_invalidation BEFORE UPDATE ON discipline_evaluation_pointers BEGIN SELECT RAISE(ABORT, 'FA01_INVALIDATION_FAULT'); END",
          );
          await expectLater(
            _replace(db, revision: 3, bindingRevision: 1, limit: 1),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA01_INVALIDATION_FAULT'),
              ),
            ),
          );
          await db.customStatement('DROP TRIGGER reject_fa01_invalidation');
          final rolledBack = await _store(db).loadActiveForLoop(
            projectId: 'p',
            designRevisionId: 'd',
            loopId: 'loop-1',
          );
          expect(rolledBack!.evidenceRef, before!.evidenceRef);
          expect(await lifecycle.revision(), 3);
          expect((await lifecycle.pointer()).read<int>('generation'), 1);
          await _replace(db, revision: 3, bindingRevision: 1, limit: 1);
        },
        dependencyDomains: {
          'FIRE_LOOP',
          'FA01_ADDRESS_CAPACITY_CONTRACT',
          'FIRE_DEVICE_PROFILE',
        },
        initialOutput: (output) {
          expect(output['deviceCount'], 2);
          expect(output['deviceHeadroom'], 1);
          expect(output['addressCount'], 2);
        },
        changedOutput: (output) {
          expect(output['deviceCount'], 2);
          expect(output['deviceHeadroom'], -1);
          expect(output['addressCount'], 2);
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, revision: 5, bindingRevision: 2, limit: 4),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA01_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2FireLoop(db, deviceCount: 3, commandId: 'frozen-loop'),
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

DriftFa01AddressCapacityContractStore _store(AppDatabase db) =>
    DriftFa01AddressCapacityContractStore(
      db,
      originDeviceId: 'f2-fire',
      nowUtc: Elv5F2ProductionLifecycle.now,
    );
Future<void> _replace(
  AppDatabase db, {
  required int revision,
  required int? bindingRevision,
  required int limit,
}) => _store(db).replace(
  ReplaceFa01AddressCapacityContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'capacity',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Fa01AddressCapacityContract(
      loopId: 'loop-1',
      deviceLimit: limit,
      addressLimit: 10,
      requiredDeviceSpare: 0,
      requiredAddressSpare: 0,
      profileAddressConsumption: const {'DETECTOR': 1},
      profileDeviceCountContribution: const {'DETECTOR': 1},
    ),
  ),
);
