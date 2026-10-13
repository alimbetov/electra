import 'dart:convert';
import 'dart:io';
import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

EngineeringReferenceCatalog fixture() => EngineeringReferenceCatalog.fromMap(
    jsonDecode(File('../../docs/examples/elv2-reference-catalog.json')
        .readAsStringSync()) as Map<String, dynamic>);
void main() {
  test(
      'four disciplines roundtrip typed characteristics and instantiate exact provenance',
      () {
    final c = fixture();
    expect(c.validate(), isEmpty);
    expect(c.profiles.map((p) => p.discipline).toSet(),
        ReferenceDiscipline.values.toSet());
    final restored = EngineeringReferenceCatalog.fromMap(
        jsonDecode(jsonEncode(c.toMap())) as Map<String, dynamic>);
    expect(restored.profile('LOCK').characteristics, isA<AcsCharacteristics>());
    expect(
        (restored.profile('OUTLET').characteristics as LanCharacteristics)
            .category,
        CopperCategory.cat6);
    var id = 0;
    final ports = c.profile('DETECTOR').instantiate(
        componentId: 'placed-detector',
        catalogId: c.id,
        version: c.version,
        nextId: () => 'port-${id++}');
    expect(ports.map((p) => p.componentId), everyElement('placed-detector'));
    expect(ports.first.templateProvenance!.id, '${c.id}/DETECTOR/IN');
    expect(ports.first.templateProvenance!.version, '1');
    expect(ports.first.voltage, isNull);
    expect(() => c.profiles.clear(), throwsUnsupportedError);
    expect(() => c.profile('CAMERA').portTemplates.clear(),
        throwsUnsupportedError);
  });
  test(
      'invalid discipline and quantities are rejected without label-dependent calculations',
      () {
    final p = fixture().profile('CAMERA');
    final wrong = ComponentEngineeringProfile.fromMap(
        {...p.toMap(), 'engineeringClass': 'detector'});
    expect(wrong.validate(), isNotEmpty);
    expect(const FireCharacteristics(alarmCurrentA: double.nan).validate(),
        isNotEmpty);
    final renamed = ComponentEngineeringProfile.fromMap(
        {...p.toMap(), 'label': 'Another manufacturer marketing label'});
    expect(renamed.characteristics.toMap(), p.characteristics.toMap());
    expect(renamed.portTemplates.map((p) => p.toMap()),
        p.portTemplates.map((p) => p.toMap()));
  });
  test(
      'deprecated editions remain readable but cannot instantiate and duplicate ids cannot publish',
      () {
    final c = fixture(), p = fixture().profile('CAMERA');
    final deprecated =
        ComponentEngineeringProfile.fromMap({...p.toMap(), 'deprecated': true});
    expect(deprecated.validate(), isEmpty);
    expect(
        () => deprecated.instantiate(
            componentId: 'camera',
            catalogId: c.id,
            version: c.version,
            nextId: () => 'id'),
        throwsStateError);
    expect(
        () => c.profile('DETECTOR').instantiate(
            componentId: 'detector',
            catalogId: c.id,
            version: c.version,
            nextId: () => 'duplicate'),
        throwsStateError);
  });
}
