import 'dart:convert';
import 'dart:io';

import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

EngineeringReferenceCatalog fixture() => EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );

void main() {
  test('template-code identity mapping survives port template reorder', () {
    final catalog = fixture();
    final original = catalog.profile('DETECTOR');
    final reordered = ComponentEngineeringProfile.fromMap({
      ...original.toMap(),
      'portTemplates':
          original.portTemplates.reversed.map((p) => p.toMap()).toList()
    });
    List<EngineeringPort> instantiate(ComponentEngineeringProfile profile) =>
        profile.instantiate(
          componentId: 'detector',
          catalogId: catalog.id,
          version: catalog.version,
          nextId: () =>
              throw StateError('Index-based ID allocation must not run'),
          idForTemplate: (code) => 'stable-$code',
        );
    final before = {
      for (final port in instantiate(original)) port.code: port.toMap()
    };
    final after = {
      for (final port in instantiate(reordered)) port.code: port.toMap()
    };
    expect(after, before);
  });

  test(
    'four disciplines roundtrip typed profiles constraints and exact provenance',
    () {
      final catalog = fixture();
      expect(catalog.validate(), isEmpty);
      expect(catalog.validateForPublication(), isEmpty);
      expect(
        catalog.profiles.map((profile) => profile.discipline).toSet(),
        ReferenceDiscipline.values.toSet(),
      );
      expect(
        catalog.profiles.every((profile) => profile.hasDefinedConstraints),
        isTrue,
      );

      final restored = EngineeringReferenceCatalog.fromMap(
        jsonDecode(jsonEncode(catalog.toMap())) as Map<String, dynamic>,
      );
      expect(
          restored.profile('LOCK').characteristics, isA<AcsCharacteristics>());
      expect(
        (restored.profile('OUTLET').characteristics as LanCharacteristics)
            .category,
        CopperCategory.cat6,
      );
      expect(
        restored.profile('CAMERA').constraints!.mounting.allows(
              InstallationSurface.wall,
              MountingMethod.bracket,
            ),
        isTrue,
      );

      var id = 0;
      final ports = catalog.profile('DETECTOR').instantiate(
            componentId: 'placed-detector',
            catalogId: catalog.id,
            version: catalog.version,
            nextId: () => 'port-${id++}',
          );
      expect(ports.map((port) => port.componentId),
          everyElement('placed-detector'));
      expect(
        ports.first.templateProvenance!.id,
        '${catalog.id}/DETECTOR/IN',
      );
      expect(ports.first.templateProvenance!.version, '1');
      expect(ports.first.voltage, isNull);
      expect(() => catalog.profiles.clear(), throwsUnsupportedError);
      expect(
        () => catalog.profile('CAMERA').portTemplates.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'invalid discipline and quantities are rejected without label dependent rules',
    () {
      final profile = fixture().profile('CAMERA');
      final wrong = ComponentEngineeringProfile.fromMap({
        ...profile.toMap(),
        'engineeringClass': 'detector',
      });
      expect(wrong.validate(), isNotEmpty);
      expect(
        const FireCharacteristics(alarmCurrentA: double.nan).validate(),
        isNotEmpty,
      );
      final renamed = ComponentEngineeringProfile.fromMap({
        ...profile.toMap(),
        'label': 'Another manufacturer marketing label',
      });
      expect(renamed.characteristics.toMap(), profile.characteristics.toMap());
      expect(
        renamed.portTemplates.map((port) => port.toMap()),
        profile.portTemplates.map((port) => port.toMap()),
      );
    },
  );

  test(
    'deprecated profiles remain readable but cannot instantiate duplicate ports',
    () {
      final catalog = fixture();
      final profile = catalog.profile('CAMERA');
      final deprecated = ComponentEngineeringProfile.fromMap({
        ...profile.toMap(),
        'deprecated': true,
      });
      expect(deprecated.validate(), isEmpty);
      expect(
        () => deprecated.instantiate(
          componentId: 'camera',
          catalogId: catalog.id,
          version: catalog.version,
          nextId: () => 'id',
        ),
        throwsStateError,
      );
      expect(
        () => catalog.profile('DETECTOR').instantiate(
              componentId: 'detector',
              catalogId: catalog.id,
              version: catalog.version,
              nextId: () => 'duplicate',
            ),
        throwsStateError,
      );
    },
  );

  test('historical catalog remains readable but cannot be newly published', () {
    final map = fixture().toMap();
    final profiles =
        (map['profiles'] as List).cast<Map<String, dynamic>>().map((profile) {
      final copy = Map<String, dynamic>.from(profile)
        ..remove('constraints')
        ..remove('constraintsState');
      return copy;
    }).toList();
    final legacy = EngineeringReferenceCatalog.fromMap({
      ...map,
      'id': 'legacy-v0',
      'version': '0',
      'profiles': profiles,
    });

    expect(legacy.validate(), isEmpty);
    expect(legacy.validateForPublication(), isNotEmpty);
    expect(
      legacy.profiles.every(
        (profile) =>
            profile.constraintsState ==
            ProfileConstraintsState.legacyUnspecified,
      ),
      isTrue,
    );
  });
}
