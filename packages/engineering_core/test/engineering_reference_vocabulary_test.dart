import 'dart:convert';
import 'dart:io';
import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';
import 'engineering_topology_test.dart' show TopologyFixture;

Map<String, dynamic> catalogMap() =>
    jsonDecode(File('../../docs/examples/elv2-interface-catalog.json')
        .readAsStringSync()) as Map<String, dynamic>;
EngineeringReferenceCatalog catalog() =>
    EngineeringReferenceCatalog.fromMap(catalogMap());

TopologyFixture scenario([EngineeringReferenceCatalog? edition]) {
  final c = edition ?? catalog();
  final f = TopologyFixture();
  for (final discipline in ReferenceDiscipline.values) {
    f.system(discipline.name, discipline.name.toUpperCase());
  }
  for (final profile in c.profiles) {
    f.participate(profile.code, profile.discipline.name);
    var index = 0;
    f.ports.addAll(profile.instantiate(
        componentId: profile.code,
        catalogId: c.id,
        version: c.version,
        vocabulary: c.vocabulary,
        nextId: () =>
            '${profile.code}.${profile.portTemplates[index++].code}'));
  }
  f.profiles.addAll(c.connectionProfiles('p'));
  void connect(String code, String system, String a, String b, String rule) =>
      f.connect(code, system, a, b, '${c.id}/compatibility/$rule');
  connect('camera', 'cctv', 'POE_SWITCH.ETH', 'CAMERA.ETH', 'CCTV-POE');
  connect('horizontal', 'lan', 'OUTLET.ETH', 'PATCH.REAR', 'LAN-LINK');
  connect('patch-cord', 'lan', 'PATCH.FRONT', 'LAN_SWITCH.ETH', 'LAN-LINK');
  f.internal(
      'patch', 'PATCH', 'PATCH.REAR', 'PATCH.FRONT', ConnectionLayer.data);
  connect('reader', 'acs', 'CONTROLLER.BUS', 'READER.BUS', 'ACS-BUS');
  connect('lock', 'acs', 'CONTROLLER.PWR', 'LOCK.PWR', 'ACS-POWER');
  connect('loop-out', 'fire', 'FACP.OUT', 'DETECTOR.IN', 'FIRE-LOOP');
  connect('loop-return', 'fire', 'DETECTOR.OUT', 'FACP.RETURN', 'FIRE-LOOP');
  f.internal('detector', 'DETECTOR', 'DETECTOR.IN', 'DETECTOR.OUT',
      ConnectionLayer.signal,
      bidirectional: false);
  return f;
}

void main() {
  test('typed references roundtrip immutably and resolve technical properties',
      () {
    final c = catalog();
    expect(c.validate(), isEmpty);
    final restored = EngineeringReferenceCatalog.fromMap(
        jsonDecode(jsonEncode(c.toMap())) as Map<String, dynamic>);
    expect(restored.toMap(), c.toMap());
    final v = restored.vocabulary;
    expect(() => v.connectors.clear(), throwsUnsupportedError);
    expect(() => v.connectors.first.mediaCodes.clear(), throwsUnsupportedError);
    expect(() => v.protocols.first.portKinds.clear(), throwsUnsupportedError);
    expect(() => v.interfaces.clear(), throwsUnsupportedError);
    expect(() => v.compatibility.first.familyCodes.clear(),
        throwsUnsupportedError);
    expect(() => c.profile('CAMERA').portInterfaceCodes.clear(),
        throwsUnsupportedError);
    final p = scenario(restored).ports.singleWhere((p) => p.id == 'CAMERA.ETH');
    expect(p.voltage!.minimumV, 44);
    expect(p.voltage!.maximumV, 52);
    expect(p.powerDirection, PortDirection.input);
    expect(p.powerDemandW, 8);
    expect(p.interfaceProvenance!.toMap(),
        {'id': '${c.id}/interface/POE-IN', 'version': '1'});
    expect(p.protocol!.toMap(), {'id': '${c.id}/protocol/ETH', 'version': '1'});
    expect(p.templateProvenance!.id, '${c.id}/CAMERA/ETH');
    expect(p.connector, '${c.id}/connector/RJ45');
    final template = EngineeringPort.fromMap({
      ...p.toMap(),
      'capacity': 99,
      'powerDemandW': 999,
      'connector': 'marketing label'
    });
    final resolved =
        v.resolve(template, 'POE-IN', catalogId: c.id, version: c.version);
    expect(resolved.capacity, 1);
    expect(resolved.powerDemandW, 8);
    expect(resolved.connector, p.connector);
  });
  test(
      'four disciplines retain distinct signal, data and directed power traces',
      () {
    final f = scenario(), g = f.graph();
    expect(g.findings(), isEmpty);
    expect(g.trace('OUTLET.ETH', layer: TraceLayer.data).portIds,
        ['LAN_SWITCH.ETH', 'OUTLET.ETH', 'PATCH.FRONT', 'PATCH.REAR']);
    expect(
        g
            .trace('CAMERA.ETH',
                layer: TraceLayer.data,
                direction: TopologyTraceDirection.downstream)
            .portIds,
        ['CAMERA.ETH', 'POE_SWITCH.ETH']);
    expect(
        g
            .trace('CAMERA.ETH',
                layer: TraceLayer.power,
                direction: TopologyTraceDirection.downstream)
            .portIds,
        ['CAMERA.ETH']);
    expect(g.trace('CONTROLLER.BUS', layer: TraceLayer.signal).portIds,
        ['CONTROLLER.BUS', 'READER.BUS']);
    expect(g.trace('CONTROLLER.PWR', layer: TraceLayer.power).portIds,
        ['CONTROLLER.PWR', 'LOCK.PWR']);
    expect(
        g
            .trace('FACP.OUT',
                layer: TraceLayer.signal,
                direction: TopologyTraceDirection.downstream)
            .portIds,
        ['DETECTOR.IN', 'DETECTOR.OUT', 'FACP.OUT', 'FACP.RETURN']);
    final profile = f.profiles.first;
    expect(ConnectionCompatibilityProfile.fromMap(profile.toMap()).toMap(),
        profile.toMap());
    expect(profile.interfaceA!.version, '1');
  });
  test('same connector and protocol cannot bypass ordered interface provenance',
      () {
    final f = scenario();
    final index = f.ports.indexWhere((p) => p.id == 'CAMERA.ETH');
    f.ports[index] = EngineeringPort.fromMap({
      ...f.ports[index].toMap(),
      'interfaceProvenance': {
        'id': '${catalog().id}/interface/POE-OUT',
        'version': '1'
      }
    });
    expect(f.graph().connectionFindings(f.connections.first).map((v) => v.code),
        contains('INTERFACE_EDITION'));
  });
  test(
      'later interface and protocol editions do not satisfy pinned compatibility',
      () {
    final f = scenario();
    final index = f.ports.indexWhere((p) => p.id == 'CAMERA.ETH');
    final p = f.ports[index];
    f.ports[index] = EngineeringPort.fromMap({
      ...p.toMap(),
      'interfaceProvenance': {'id': p.interfaceProvenance!.id, 'version': '2'},
      'protocol': {'id': p.protocol!.id, 'version': '2'}
    });
    expect(f.graph().connectionFindings(f.connections.first).map((v) => v.code),
        containsAll(['INTERFACE_EDITION', 'INTERFACE_PROTOCOL']));
  });
  test(
      'missing voltage stays unresolved instead of inventing an electrical default',
      () {
    final m = catalogMap();
    ((m['vocabulary']['interfaces'] as List).first as Map)
        .remove('voltageCode');
    final c = EngineeringReferenceCatalog.fromMap(m);
    expect(c.validate(), isEmpty);
    expect(scenario(c).graph().findings().map((v) => v.code),
        contains('POWER_UNRESOLVED'));
  });
  test(
      'source range and declared power still constrain a catalog-compatible pair',
      () {
    for (final change in [
      {
        'voltage': {'currentKind': 'dc', 'minimumV': 40, 'maximumV': 60}
      },
      {'powerLimitW': 1}
    ]) {
      final f = scenario();
      final i = f.ports.indexWhere((p) => p.id == 'POE_SWITCH.ETH');
      f.ports[i] = EngineeringPort.fromMap({...f.ports[i].toMap(), ...change});
      expect(
          f.graph().findings().map((v) => v.code),
          contains(change.containsKey('voltage')
              ? 'VOLTAGE_DOMAIN'
              : 'DECLARED_POWER_LIMIT'));
    }
  });
  test(
      'invalid references, duplicate codes and inconsistent kinds cannot import',
      () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (m) => m['vocabulary']['interfaces'][0]['protocolCode'] = 'UNKNOWN',
      (m) => m['vocabulary']['interfaces'][0]['connectorCode'] = 'UNKNOWN',
      (m) => m['vocabulary']['interfaces'][0]['voltageCode'] = 'UNKNOWN',
      (m) => m['vocabulary']['interfaces'][0]['mediaCode'] = 'DC',
      (m) => m['vocabulary']['interfaces'][0]['kind'] = 'rf',
      (m) => m['vocabulary']['interfaces'][0]['powerDirection'] = null,
      (m) => m['vocabulary']['media'][0]['connectionMedium'] = 'wireless',
      (m) => m['vocabulary']['protocols'][0]['identity']['code'] = 'lowercase',
      (m) => (m['vocabulary']['protocols'] as List)
          .add(m['vocabulary']['protocols'][0]),
      (m) => m['vocabulary']['compatibility'][0]['toInterfaceCode'] = 'UNKNOWN',
      (m) => m['vocabulary']['compatibility'][0]['layer'] = 'power',
      (m) => m['vocabulary']['compatibility'][3]['fromInterfaceCode'] = 'DC-IN',
      (m) => m['profiles'][0]['portInterfaceCodes']['ETH'] = 'LAN',
      (m) => m['profiles'][0]['portInterfaceCodes']['ABSENT'] = 'LAN',
    ]) {
      final m = catalogMap();
      mutate(m);
      expect(EngineeringReferenceCatalog.fromMap(m).validate(), isNotEmpty);
    }
  });
  test(
      'a declared compatible connector pair cannot silently translate protocols',
      () {
    final m = catalogMap();
    (m['vocabulary']['protocols'] as List).add({
      'identity': {'code': 'OTHER', 'label': 'Other protocol'},
      'portKinds': ['dataPower']
    });
    m['vocabulary']['interfaces'][1]['protocolCode'] = 'OTHER';
    expect(EngineeringReferenceCatalog.fromMap(m).validate().join(' '),
        contains('cannot translate protocols'));
  });
  test(
      'deprecated references remain readable but block new ports and compatibility',
      () {
    for (final section in [
      'connectors',
      'protocols',
      'voltages',
      'media',
      'interfaces',
      'compatibility'
    ]) {
      final m = catalogMap();
      m['vocabulary'][section][0]['identity']['deprecated'] = true;
      final c = EngineeringReferenceCatalog.fromMap(m);
      expect(c.validate(), isEmpty);
      expect(c.connectionProfiles('p').any((p) => p.semanticCode == 'CCTV-POE'),
          isFalse);
      if (section != 'compatibility') {
        expect(
            () => c.profile('POE_SWITCH').instantiate(
                componentId: 's',
                catalogId: c.id,
                version: c.version,
                vocabulary: c.vocabulary,
                nextId: () => 's.ETH'),
            throwsStateError);
      }
    }
  });
  test(
      'legacy catalog and topology maps omit absent vocabulary identity fields',
      () {
    final c = EngineeringReferenceCatalog.fromMap(jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json')
            .readAsStringSync()) as Map<String, dynamic>);
    expect(c.validate(), isEmpty);
    expect(c.toMap().containsKey('vocabulary'), isFalse);
    for (final p in c.profiles) {
      expect(p.toMap().containsKey('portInterfaceCodes'), isFalse);
      expect(p.portTemplates.first.toMap().containsKey('interfaceProvenance'),
          isFalse);
    }
    final f = TopologyFixture()..profile('legacy', 'LAN');
    expect(f.profiles.first.toMap().containsKey('interfaceA'), isFalse);
    expect(
        ConnectionCompatibilityProfile.fromMap(f.profiles.first.toMap())
            .toMap(),
        f.profiles.first.toMap());
  });
}
