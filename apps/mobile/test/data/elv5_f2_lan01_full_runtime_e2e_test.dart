import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 LAN-01 production Q6/Q7/Q8 exact ELV3 geometry and authoritative composition preserve unassessed policy',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.lan01,
        subjectKind: 'LINK',
        subjectId: 'length-link-1',
      );
      await lifecycle.run(
        seed: (db) async {
          await seedF2LanTopology(db);
          await seedF2LanRoute(db);
          await replaceF2LanAggregate(
            db,
            operation: 'REPLACE_LINK_COMPOSITION',
            payload: _composition('PERMANENT'),
            commandId: 'seed-composition',
          );
        },
        mutate:
            (db) => replaceF2LanAggregate(
              db,
              operation: 'REPLACE_LINK_COMPOSITION',
              payload: _composition('PATCH'),
              commandId: 'reclassify-section',
            ),
        dependencyDomains: {
          'LAN_LINK_COMPOSITION',
          'DISCIPLINE_POLICY',
          'ELV3_REALIZED_LINK_SECTION',
        },
        initialAssessment: 'NOTASSESSED',
        changedAssessment: 'NOTASSESSED',
        initialOutput: (o) => _check(o, 1),
        changedOutput: (o) => _check(o, 0),
        mutationAfterFreeze: (db) async {
          await expectLater(
            replaceF2LanAggregate(
              db,
              operation: 'REPLACE_LINK_COMPOSITION',
              payload: _composition('PERMANENT'),
              commandId: 'frozen-composition',
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

Map<String, Object?> _composition(String classification) => {
  'linkId': 'length-link-1',
  'orderedSections': [
    {
      'ordinal': 0,
      'realizedSectionId': 'traversal-1',
      'classification': classification,
    },
  ],
  'policyBindingId': 'explicit-length-policy-unresolved',
};
void _check(Map<String, dynamic> o, int permanent) {
  expect(o['linkId'], 'length-link-1');
  final p = o['permanent'] as Map;
  final c = o['channel'] as Map;
  expect(p['lengthLowerM'], Elv5Rational.integer(permanent).toMap());
  expect(p['lengthUpperM'], Elv5Rational.integer(permanent).toMap());
  expect(c['lengthLowerM'], Elv5Rational.one.toMap());
  expect(c['lengthUpperM'], Elv5Rational.one.toMap());
  expect(p['passes'], isNull);
  expect(c['passes'], isNull);
  expect(p['marginM'], isNull);
  expect(c['marginM'], isNull);
}
