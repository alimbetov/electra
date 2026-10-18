import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  group('ELV5 P0 runtime-entry contract', () {
    test('pins accepted schema transition and closed inventories', () {
      expect(Elv5RuntimeContract.inheritedDatabaseSchema, 23);
      expect(Elv5RuntimeContract.databaseSchema, 24);
      expect(Elv5RuntimeContract.processCount, 27);
      expect(Elv5RuntimeContract.commandCount, 16);
      expect(
        () => Elv5RuntimeContract.validateDatabaseEntry(
          inheritedSchema: 23,
          targetSchema: 24,
        ),
        returnsNormally,
      );
      expect(
        () => Elv5RuntimeContract.validateDatabaseEntry(
          inheritedSchema: 23,
          targetSchema: 25,
        ),
        throwsStateError,
      );
    });
  });

  group('ELV5 exact numeric primitives', () {
    test('normalizes rationals and enforces reserve >= 1', () {
      expect(
        Elv5Rational(BigInt.from(2), BigInt.from(4)),
        Elv5Rational(BigInt.one, BigInt.from(2)),
      );
      expect(
        Elv5RuntimeContract.validateReserveMultiplier(
          Elv5Rational.parseDecimal('1.10'),
        ),
        Elv5Rational(BigInt.from(11), BigInt.from(10)),
      );
      expect(
        () => Elv5RuntimeContract.validateReserveMultiplier(
          Elv5Rational.parseDecimal('0.99'),
        ),
        throwsArgumentError,
      );
    });

    test('mass is dimension-safe quantity and intervals are conservative', () {
      final oneKg = Mass(Elv5Rational.one);
      final twoKg = Mass(Elv5Rational.integer(2));
      final range = Elv5Interval<MassDim>(oneKg, twoKg);
      expect(range.lower.value, Elv5Rational.one);
      expect(range.upper.value, Elv5Rational.integer(2));
    });
  });

  group('ELV5 canonical JSON', () {
    const encoder = Elv5CanonicalJsonV1();

    test('map and set order are invariant while list order is significant', () {
      final a = <String, Object?>{
        'set': <String>{'b', 'a'},
        'map': <String, Object?>{'y': 2, 'x': 1},
      };
      final b = <String, Object?>{
        'map': <String, Object?>{'x': 1, 'y': 2},
        'set': <String>{'a', 'b'},
      };
      expect(encoder.sha256(a), encoder.sha256(b));
      expect(encoder.sha256(<int>[1, 2]), isNot(encoder.sha256(<int>[2, 1])));
      expect(jsonDecode(utf8.decode(encoder.encode(a))), isA<Map>());
    });
  });

  group('ELV5 P1 process inventory', () {
    test('contains exactly 27 stable unique codes with v1 versions', () {
      expect(Elv5ProcessCode.values, hasLength(27));
      expect(Elv5ProcessCatalog.all, hasLength(27));
      expect(Elv5ProcessCatalog.byCode, hasLength(27));
      final wireCodes =
          Elv5ProcessCode.values.map((code) => code.wireCode).toSet();
      expect(wireCodes, hasLength(27));
      expect(
        wireCodes,
        containsAll(<String>['CCTV-01', 'LAN-07', 'ACS-06', 'FA-08']),
      );
      for (final descriptor in Elv5ProcessCatalog.all) {
        expect(descriptor.versions.inputSchemaVersion, '1');
        expect(descriptor.versions.outputSchemaVersion, '1');
        expect(
          descriptor.versions.algorithmVersion,
          'electra.elv5.${descriptor.code.wireCode.toLowerCase()}.algorithm.v1',
        );
      }
    });

    test('engineering node v3 keeps DESIGN scenario fixed at NONE', () {
      final node = Elv5EngineeringNodeKeyV3(
        designRevisionId: 'revision-r1',
        scope: Elv5ScopeRef(
          kind: Elv5ScopeKind.design,
          scopeId: 'design-root',
          scenarioKey: 'NONE',
        ),
        processCode: Elv5ProcessCode.cctv02,
        subject: Elv5SubjectRef(kind: 'CAMERA', id: 'camera-01'),
      );
      expect(node.toCanonicalValue(), <Object?>[
        'engineering-node-v3',
        'ELV5',
        'revision-r1',
        'NONE',
        'DESIGN',
        'design-root',
        'CCTV-02',
        'CAMERA',
        'camera-01',
      ]);
      expect(
        () => Elv5ScopeRef(
          kind: Elv5ScopeKind.design,
          scopeId: 'design-root',
          scenarioKey: 'scenario-a',
        ),
        throwsArgumentError,
      );
    });
  });
}
