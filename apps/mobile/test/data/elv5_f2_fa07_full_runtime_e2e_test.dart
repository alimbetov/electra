import 'package:electra_mobile/application/elv5/fire/fa01_membership_fingerprint.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_fire_write_unit_of_work.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract_write.dart';
import 'package:electra_mobile/application/elv5/fire/fa07_topology_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa07_topology_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa01_address_capacity_contract_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa07_topology_contract_store.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 FA-07 production Q6/Q7/Q8 real membership, return loss, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.fa07,
        subjectKind: 'FIRE_LOOP',
        subjectId: 'loop-1',
      );
      late String membership;
      await lifecycle.run(
        seed: (db) async {
          await seedF2FireTopology(db);
          await replaceF2FireLoop(db);
          await DriftFa01AddressCapacityContractStore(
            db,
            originDeviceId: 'f2-fire',
          ).replace(
            ReplaceFa01AddressCapacityContractCommand(
              projectId: 'p',
              designRevisionId: 'd',
              bindingId: 'capacity',
              expectedBindingRevision: null,
              expectedDesignRevision: 2,
              contract: Fa01AddressCapacityContract(
                loopId: 'loop-1',
                deviceLimit: 3,
                addressLimit: 10,
                requiredDeviceSpare: 0,
                requiredAddressSpare: 0,
                profileAddressConsumption: const {'DETECTOR': 1},
                profileDeviceCountContribution: const {'DETECTOR': 1},
              ),
            ),
          );
          final fa01 = Elv5F2ProductionLifecycle(
            process: Elv5ProcessCode.fa01,
            subjectKind: 'FIRE_LOOP',
            subjectId: 'loop-1',
          )..db = db;
          await fa01
              .runtime(db)
              .service
              .execute(fa01.command('membership-source', 3, 0));
          final evaluation = await fa01.evaluation();
          expect(evaluation.read<String>('execution'), 'SUCCEEDED');
          expect(evaluation.read<String>('completion'), 'COMPLETE');
          expect(evaluation.read<String>('assessment'), 'PASS');
          final loop = await DriftElv5FireWriteUnitOfWork(
            db,
            originDeviceId: 'f2-fire',
          ).run(
            (session) => session.fire.load(
              projectId: 'p',
              designRevisionId: 'd',
              operation: 'REPLACE_FIRE_LOOP_ASSIGNMENTS',
              subjectId: 'loop-1',
            ),
          );
          membership = fa01MembershipFingerprint(
            loopId: 'loop-1',
            addressDomain: Map<String, Object?>.from(
              loop!.payload['addressDomain'] as Map,
            ),
            deviceAssignments:
                (loop.payload['deviceAssignments'] as List)
                    .map((v) => Map<String, Object?>.from(v as Map))
                    .toList(),
          );
          await _replace(
            db,
            revision: 3,
            bindingRevision: null,
            membership: membership,
            closed: true,
          );
        },
        mutate:
            (db) => _replace(
              db,
              revision: 4,
              bindingRevision: 1,
              membership: membership,
              closed: false,
            ),
        dependencyDomains: {'FIRE_LOOP', 'FA07_TOPOLOGY_CONTRACT'},
        initialOutput: (output) {
          expect(output['status'], 'pass');
          expect((output['cases'] as Map)['normal']['reachableDeviceIds'], [
            'n1',
            'n2',
          ]);
        },
        changedOutput: (output) {
          expect(output['status'], 'fail');
          expect(output['reason'], 'FA07_RETURN_CLOSURE_INCOMPLETE');
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(
              db,
              revision: 6,
              bindingRevision: 2,
              membership: membership,
              closed: true,
            ),
            throwsA(
              predicate(
                (e) => e.toString().contains('FA07_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _replace(
  AppDatabase db, {
  required int revision,
  required int? bindingRevision,
  required String membership,
  required bool closed,
}) => DriftFa07TopologyContractStore(
  db,
  originDeviceId: 'f2-fire',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replace(
  ReplaceFa07TopologyContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'topology',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Fa07TopologyContract(
      loopId: 'loop-1',
      topologyProfile: Fa07TopologyProfileIdentity(
        profileCode: 'CLASS-A',
        editionId: 'v1',
        contentHash: List.filled(64, 'a').join(),
      ),
      expectedFa01MembershipFingerprint: membership,
      sourceNodeId: 'source',
      returnNodeId: 'return',
      deviceNodeIdByDeviceId: const {'d1': 'n1', 'd2': 'n2'},
      edges: [
        Fa07EdgeContract(edgeId: 'e1', fromNodeId: 'source', toNodeId: 'n1'),
        Fa07EdgeContract(edgeId: 'e2', fromNodeId: 'n1', toNodeId: 'n2'),
        if (closed)
          Fa07EdgeContract(edgeId: 'e3', fromNodeId: 'n2', toNodeId: 'return')
        else
          // Keep the contract graph structurally complete while deliberately
          // removing the forward return closure: return participates in the
          // graph but cannot be reached from source through the device chain.
          Fa07EdgeContract(
            edgeId: 'e3',
            fromNodeId: 'return',
            toNodeId: 'source',
          ),
      ],
      permittedBranchNodeIds: const [],
      maxBranchNodes: 0,
      requiredFaultCases: const [],
      faultScenarios: const [],
    ),
  ),
);
