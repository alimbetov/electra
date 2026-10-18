import 'package:electra_mobile/application/elv5/acs/acs01_role_profile_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs01_role_profile_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_acs_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_acs_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 ACS-01 production Q6/Q7/Q8 immutable role requirements, rollback, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.acs01,
        subjectKind: 'DOOR',
        subjectId: 'door-1',
      );
      late String fingerprint;
      await lifecycle.run(
        seed: (db) async {
          await seedF2AcsTopology(db);
          await replaceF2AcsAggregate(
            db,
            operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
            payload: f2AcsDoorPayload(),
            commandId: 'seed-door',
          );
          fingerprint = const Elv5CanonicalJsonV1().sha256(
            await loadF2AcsAggregate(
              db,
              operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
              subjectId: 'door-1',
            ),
          );
          await _replace(db, fingerprint, 2, null, 1);
        },
        mutate: (db) async {
          await db.customStatement(
            "CREATE TRIGGER reject_acs01_invalidation BEFORE UPDATE ON discipline_evaluation_pointers BEGIN SELECT RAISE(ABORT, 'ACS01_INVALIDATION_FAULT'); END",
          );
          await expectLater(
            _replace(db, fingerprint, 3, 1, 2),
            throwsA(
              predicate(
                (e) => e.toString().contains('ACS01_INVALIDATION_FAULT'),
              ),
            ),
          );
          await db.customStatement('DROP TRIGGER reject_acs01_invalidation');
          expect(await lifecycle.revision(), 3);
          expect((await lifecycle.pointer()).read<int>('generation'), 1);
          await _replace(db, fingerprint, 3, 1, 2);
        },
        dependencyDomains: {
          'ACS_DOOR_CALCULATION',
          'ACS01_ROLE_PROFILE_CONTRACT',
          'ACS_COMPONENT_ROLE_CAPABILITY',
          'COMPONENT_REFERENCE_BINDING',
        },
        initialOutput: (o) => _check(o, 'pass', 0),
        changedOutput: (o) => _check(o, 'fail', -1),
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, fingerprint, 5, 2, 1),
            throwsA(
              predicate(
                (e) => e.toString().contains('ACS01_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2AcsAggregate(
              db,
              operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
              payload: f2AcsDoorPayload(),
              commandId: 'frozen-door',
            ),
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

void _check(Map<String, dynamic> o, String status, int margin) {
  expect(o['status'], status);
  expect(o['illegalSharingComponentIds'], isEmpty);
  final requirements = o['requirements'] as List;
  expect(requirements, hasLength(7));
  expect(
    requirements.singleWhere((v) => v['nodeId'] == 'LOCK')['margin'],
    margin,
  );
}

Future<void> _replace(
  AppDatabase db,
  String fingerprint,
  int revision,
  int? bindingRevision,
  int locks,
) => DriftElv5AcsContractMutationCoordinator(
  db,
  originDeviceId: 'f2-acs',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceAcs01(
  ReplaceAcs01RoleProfileContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'role-profile',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Acs01RoleProfileContract(
      doorId: 'door-1',
      profileId: 'ACS-DOOR-SINGLE',
      expectedDoorAggregateFingerprint: fingerprint,
      assignmentClosureComplete: true,
      rootRequirement: Acs01RoleRequirementContract.group(
        nodeId: 'all-roles',
        kindCode: 'ALL_OF',
        children: [
          for (final role in f2AcsRoleByComponent.values)
            Acs01RoleRequirementContract.roleCount(
              nodeId: role,
              kindCode: 'AT_LEAST',
              roleCode: role,
              count: role == 'LOCK' ? locks : 1,
            ),
        ],
      ),
      capabilities: [
        for (final e in f2AcsRoleByComponent.entries)
          Acs01ComponentCapabilityContract(
            componentId: e.key,
            allowedRoleCodes: [e.value],
            allowRoleSharing: false,
            evidenceRef: 'fixture-role-${e.key}',
            evidenceContentHash: const Elv5CanonicalJsonV1().sha256({
              'component': e.key,
              'role': e.value,
            }),
          ),
      ],
    ),
  ),
);
