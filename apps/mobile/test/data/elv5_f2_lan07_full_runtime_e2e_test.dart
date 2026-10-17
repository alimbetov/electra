import 'package:electra_mobile/application/elv5/lan/lan07_patch_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 LAN-07 production Q6/Q7/Q8 authoritative policy replacement, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.lan07,
        subjectKind: 'PATCH_PANEL',
        subjectId: 'patch-panel-1',
      );
      late Map<String, Object?> payload;
      await lifecycle.run(
        seed: (db) async {
          await seedF2LanTopology(db);
          payload = f2Lan07Payload(f2Lan07Assignments(5));
          await replaceF2LanAggregate(
            db,
            operation: 'REPLACE_PATCH_PANEL_ASSIGNMENTS',
            payload: payload,
            commandId: 'seed-source',
          );
          payload = await loadF2LanAggregate(
            db,
            'REPLACE_PATCH_PANEL_ASSIGNMENTS',
            'patch-panel-1',
          );
          await _replace(db, payload, 2, null, false);
        },
        mutate: (db) => _replace(db, payload, 3, 1, true),
        dependencyDomains: {
          'LAN_PATCH_PANEL_ASSIGNMENTS',
          'LAN07_PATCH_PANEL_CONTRACT',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(o['occupied'], 5);
          expect(o['free'], 3);
          expect(o['spareHeadroom'], 1);
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(o['occupied'], 5);
          expect(o['free'], 1);
          expect(o['spareHeadroom'], -1);
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, payload, 5, 2, false),
            throwsA(
              predicate(
                (e) => e.toString().contains('LAN07_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2LanAggregate(
              db,
              operation: 'REPLACE_PATCH_PANEL_ASSIGNMENTS',
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
).replaceLan07(
  ReplaceLan07PatchPanelContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: _contract(payload, changed: changed),
  ),
);
Lan07PatchPanelContract _contract(
  Map<String, Object?> payload, {
  Set<String>? requiredSources,
  bool changed = false,
}) => Lan07PatchPanelContract(
  panelId: 'patch-panel-1',
  expectedAggregateFingerprint: lan07AggregateFingerprint(payload),
  policyRef: Lan07PolicyRef(
    policyCode: 'PATCH_SPARE_POLICY',
    editionId: 'patch-policy-v1',
    contentHash: f2LanHash('d'),
  ),
  physicalPortIds: <String>[for (var i = 1; i <= 8; i++) 'patch-panel-1-p$i'],
  unavailablePortIds:
      changed
          ? const ['patch-panel-1-p7', 'patch-panel-1-p8']
          : const <String>[],
  requiredSourceEndpointIds:
      requiredSources ??
      const <String>{'term-1', 'term-2', 'term-3', 'term-4', 'term-5'},
  absoluteMinimumSpare: 2,
  spareRatio: Elv5Rational.zero,
  spareCombinerCode: 'MAX',
  panelEvidenceRef: 'CATALOG:panel-1',
  panelEvidenceContentHash: f2LanHash('c'),
);
