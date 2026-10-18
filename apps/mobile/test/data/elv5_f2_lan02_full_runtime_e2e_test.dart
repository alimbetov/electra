import 'package:electra_mobile/application/elv5/lan/lan02_port_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 LAN-02 production Q6/Q7/Q8 authoritative policy replacement, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.lan02,
        subjectKind: 'SWITCH',
        subjectId: 'switch-1',
      );
      late Map<String, Object?> payload;
      await lifecycle.run(
        seed: (db) async {
          await seedF2LanTopology(db);
          payload = f2Lan02Payload();
          await replaceF2LanAggregate(
            db,
            operation: 'REPLACE_PORT_CAPACITY_ASSIGNMENTS',
            payload: payload,
            commandId: 'seed-source',
          );
          payload = await loadF2LanAggregate(
            db,
            'REPLACE_PORT_CAPACITY_ASSIGNMENTS',
            'switch-1',
          );
          await _replace(db, payload, 2, null, false);
        },
        mutate: (db) => _replace(db, payload, 3, 1, true),
        dependencyDomains: {'LAN_PORT_CAPACITY', 'LAN02_PORT_CONTRACT'},
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(o['occupied'], 2);
          expect(o['headroomPorts'], 0);
          expect(o['incompatibleEndpointIds'], isEmpty);
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(o['available'], 3);
          expect(o['incompatibleEndpointIds'], contains('endpoint-2'));
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, payload, 5, 2, false),
            throwsA(
              predicate(
                (e) => e.toString().contains('LAN02_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2LanAggregate(
              db,
              operation: 'REPLACE_PORT_CAPACITY_ASSIGNMENTS',
              payload: payload,
              commandId: 'frozen-source',
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
).replaceLan02(
  ReplaceLan02PortContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: _contract(payload, changed: changed),
  ),
);
Lan02PortContract _contract(
  Map<String, Object?> payload, {
  bool changed = false,
}) => Lan02PortContract(
  switchId: 'switch-1',
  expectedAggregateFingerprint: const Elv5CanonicalJsonV1().sha256(payload),
  sparePolicy: Lan02PolicyIdentity(
    policyCode: 'LAN-PORT-SPARE',
    editionId: 'spare-v1',
    contentHash: f2LanHash('b'),
  ),
  ports: <Lan02PortContractItem>[
    Lan02PortContractItem(
      portId: 'switch-1-p1',
      media: 'COPPER',
      maxSpeedMbps: 1000,
    ),
    Lan02PortContractItem(
      portId: 'switch-1-p2',
      media: 'COPPER',
      maxSpeedMbps: changed ? 100 : 1000,
    ),
    Lan02PortContractItem(
      portId: 'switch-1-p3',
      media: 'COPPER',
      maxSpeedMbps: 1000,
    ),
  ],
  absoluteMinimum: 1,
  ratio: Elv5Rational.zero,
  combinerCode: 'MAX',
);
