import 'package:electra_mobile/application/elv5/lan/lan04_compatibility_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_lan_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 LAN-04 production Q6/Q7/Q8 authoritative policy replacement, restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.lan04,
        subjectKind: 'LINK',
        subjectId: 'link-1',
      );
      late Map<String, Object?> payload;
      await lifecycle.run(
        seed: (db) async {
          await seedF2LanTopology(db);
          payload = f2Lan04Payload();
          await replaceF2LanAggregate(
            db,
            operation: 'REPLACE_LINK_COMPOSITION',
            payload: payload,
            commandId: 'seed-source',
          );
          payload = await loadF2LanAggregate(
            db,
            'REPLACE_LINK_COMPOSITION',
            'link-1',
          );
          await _replace(db, payload, 2, null, false);
        },
        mutate: (db) => _replace(db, payload, 3, 1, true),
        dependencyDomains: {
          'LAN_LINK_COMPOSITION',
          'LAN04_COMPATIBILITY_CONTRACT',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(o['limitingSectionId'], isNull);
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(o['limitingSectionId'], 'section-2');
          expect(o['limitingProperty'], 'speedMode');
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, payload, 5, 2, false),
            throwsA(
              predicate(
                (e) => e.toString().contains('LAN04_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
          await expectLater(
            replaceF2LanAggregate(
              db,
              operation: 'REPLACE_LINK_COMPOSITION',
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
).replaceLan04(
  ReplaceLan04CompatibilityContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: _contract(
      payload,
      section2Speeds: changed ? const ['100BASE-TX'] : const ['1000BASE-T'],
    ),
  ),
);
Lan04CompatibilityContract _contract(
  Map<String, Object?> payload, {
  List<String> section2Speeds = const ['1000BASE-T'],
  bool section1ShieldKnown = true,
}) => Lan04CompatibilityContract(
  linkId: 'link-1',
  expectedCompositionFingerprint: const Elv5CanonicalJsonV1().sha256(payload),
  requiredMediumCode: 'COPPER',
  requiredInterfaceKind: 'ETHERNET',
  requiredSpeedMode: '1000BASE-T',
  requiredConnectorKind: 'RJ45',
  shieldingRequired: true,
  sections: <Lan04SectionCapabilityContract>[
    _section(
      'section-1',
      speeds: const ['1000BASE-T'],
      shieldKnown: section1ShieldKnown,
    ),
    _section('section-2', speeds: section2Speeds),
  ],
);

Lan04SectionCapabilityContract _section(
  String id, {
  required List<String> speeds,
  bool shieldKnown = true,
}) => Lan04SectionCapabilityContract(
  sectionId: id,
  mediumCode: 'COPPER',
  supportedInterfaceKinds: const ['ETHERNET'],
  supportedSpeedModes: speeds,
  supportedConnectorKinds: const ['RJ45'],
  shieldContinuityKnown: shieldKnown,
  shieldContinuity: shieldKnown,
  evidenceRef: 'CATALOG:$id',
  evidenceContentHash: f2LanHash(id == 'section-1' ? 'a' : 'b'),
);
