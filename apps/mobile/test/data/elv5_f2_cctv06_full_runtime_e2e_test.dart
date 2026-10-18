import 'package:electra_mobile/application/elv5/cctv/cctv06_link_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 CCTV-06 production Q6/Q7/Q8 exact ELV3 link and policy replacement survive restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv06,
        subjectKind: 'LINK',
        subjectId: 'length-link-1',
      );
      late Map<String, Object?> payload;
      await lifecycle.run(
        seed: (db) async {
          await seedF2LanTopology(db);
          await seedF2LanRoute(db);
          await replaceF2LanAggregate(
            db,
            operation: 'REPLACE_LINK_COMPOSITION',
            commandId: 'seed-link',
            payload: {
              'linkId': 'length-link-1',
              'orderedSections': [
                {
                  'ordinal': 0,
                  'realizedSectionId': 'traversal-1',
                  'classification': 'PERMANENT',
                },
              ],
              'policyBindingId': 'link-policy',
            },
          );
          payload = await loadF2LanAggregate(
            db,
            'REPLACE_LINK_COMPOSITION',
            'length-link-1',
          );
          await _replace(db, payload, 2, null, false);
        },
        mutate: (db) => _replace(db, payload, 3, 1, true),
        dependencyDomains: {
          'LAN_LINK_COMPOSITION',
          'CCTV06_LINK_CONTRACT',
          'ELV3_REALIZED_SECTION_LENGTH',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(o['realizedLengthM'], {
            'lower': Elv5Rational.one.toMap(),
            'upper': Elv5Rational.one.toMap(),
          });
          expect(o['lengthMarginM'], Elv5Rational.zero.toMap());
          expect(o['powerStatus'], 'notApplicable');
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(
            o['lengthMarginM'],
            Elv5Rational(BigInt.from(-1), BigInt.from(2)).toMap(),
          );
          expect(o['powerStatus'], 'notApplicable');
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, payload, 5, 2, false),
            throwsA(
              predicate(
                (e) =>
                    e.toString().contains('CCTV06_DESIGN_REVISION_READ_ONLY'),
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
) => DriftElv5CctvContractMutationCoordinator(
  db,
  originDeviceId: 'f2-cctv',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceCctv06(
  ReplaceCctv06LinkContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'link-policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Cctv06LinkContract(
      linkId: 'length-link-1',
      expectedCompositionFingerprint: const Elv5CanonicalJsonV1().sha256(
        payload,
      ),
      allowedMediaCodes: const ['COPPER'],
      allowedInterfaceKinds: const ['ETHERNET'],
      allowedCategoryTokens: const ['CAT6'],
      shieldingRequired: true,
      maximumLengthM:
          changed ? Elv5Rational(BigInt.one, BigInt.from(2)) : Elv5Rational.one,
      sections: [
        Cctv06SectionEvidenceContract(
          sectionId: 'traversal-1',
          mediumCode: 'COPPER',
          interfaceKind: 'ETHERNET',
          categoryToken: 'CAT6',
          shieldContinuityKnown: true,
          shieldContinuity: true,
          evidenceRef: 'def:section',
          evidenceContentHash: f2LanHash('a'),
        ),
      ],
      powered: false,
    ),
  ),
);
