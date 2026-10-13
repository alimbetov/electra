import 'dart:convert';
import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

class TopologyFixture {
  final components = <String>{},
      systems = <EngineeringSystem>[],
      memberships = <ComponentSystemMembership>[];
  final ports = <EngineeringPort>[],
      profiles = <ConnectionCompatibilityProfile>[],
      connections = <EngineeringConnection>[];
  final internals = <InternalConnectivity>[],
      topologyProfiles = <TopologyProfile>[],
      groups = <TopologyGroup>[];
  final assemblyProfiles = <AssemblyProfile>[],
      assemblies = <ComponentAssembly>[];
  ProfileIdentity identity(String id) => ProfileIdentity(
      id: id,
      projectId: 'p',
      code: id,
      version: 'test-1',
      source:
          'Fictional engineering acceptance fixture; no normative thresholds');
  void system(String id, String family) {
    final f =
        bundledEngineeringSystemFamilies.firstWhere((f) => f.code == family);
    systems.add(EngineeringSystem(
        id: id,
        projectId: 'p',
        code: id,
        name: id,
        familyId: f.id,
        familyVersion: f.version));
  }

  void participate(String component, String system) {
    components.add(component);
    memberships.add(ComponentSystemMembership(
        systemId: system, componentId: component, role: 'TEST_PARTICIPANT'));
  }

  EngineeringPort port(String component, String code,
      {EngineeringPortKind kind = EngineeringPortKind.data,
      PortDirection direction = PortDirection.bidirectional,
      PortDirection? powerDirection,
      String protocol = 'TEST-ETH',
      double? voltage,
      double? acceptMax,
      int capacity = 1}) {
    final p = EngineeringPort(
        id: '$component.$code',
        componentId: component,
        code: code,
        kind: kind,
        direction: direction,
        capacity: capacity,
        connector: 'TEST-CONNECTOR',
        protocol: EngineeringProfileReference(id: protocol, version: '1'),
        powerDirection: powerDirection,
        voltage: voltage == null
            ? null
            : PortVoltageDomain(
                currentKind: PortCurrentKind.dc,
                minimumV: voltage,
                maximumV: acceptMax ?? voltage));
    ports.add(p);
    return p;
  }

  void profile(String id, String family,
      {EngineeringPortKind kind = EngineeringPortKind.data,
      ConnectionLayer layer = ConnectionLayer.data,
      CompatibilityFlow flow = CompatibilityFlow.bidirectional,
      String protocol = 'TEST-ETH'}) {
    profiles.add(ConnectionCompatibilityProfile(
        identity: identity(id),
        familyCodes: [family],
        media: [ConnectionMedium.wired],
        semanticCode: id,
        layer: layer,
        flow: flow,
        kindA: kind,
        kindB: kind,
        connectorA: 'TEST-CONNECTOR',
        connectorB: 'TEST-CONNECTOR',
        protocolA: EngineeringProfileReference(id: protocol, version: '1'),
        protocolB: EngineeringProfileReference(id: protocol, version: '1')));
  }

  void connect(String id, String system, String a, String b, String profile,
          {String? group}) =>
      connections.add(EngineeringConnection(
          id: id,
          systemId: system,
          fromPortId: a,
          toPortId: b,
          profileId: profile,
          medium: ConnectionMedium.wired,
          groupId: group));
  void internal(String id, String component, String a, String b,
          ConnectionLayer layer, {bool bidirectional = true}) =>
      internals.add(InternalConnectivity(
          id: id,
          componentId: component,
          fromPortId: a,
          toPortId: b,
          layer: layer,
          bidirectional: bidirectional,
          evidence:
              'Declared static passive mapping, not switching or conversion'));
  EngineeringTopologyGraph graph() => EngineeringTopologyGraph(
      projectId: 'p',
      componentIds: components,
      systems: systems,
      families: bundledEngineeringSystemFamilies,
      memberships: memberships,
      ports: ports,
      connectionProfiles: profiles,
      connections: connections,
      internalLinks: internals,
      topologyProfiles: topologyProfiles,
      groups: groups,
      assemblyProfiles: assemblyProfiles,
      assemblies: assemblies);
}

TopologyFixture lanFixture() {
  final f = TopologyFixture()..system('lan', 'LAN');
  for (final id in ['outlet', 'patch', 'switch']) {
    f.participate(id, 'lan');
  }
  f.port('outlet', 'ETH');
  f.port('patch', 'REAR');
  f.port('patch', 'FRONT');
  f.port('patch', 'UNUSED-A');
  f.port('patch', 'UNUSED-B');
  f.port('switch', 'P1');
  f.profile('ethernet', 'LAN');
  f.topologyProfiles.add(TopologyProfile(
      identity: f.identity('link-path'),
      shape: TopologyShape.path,
      layer: TraceLayer.data));
  f.groups.add(const TopologyGroup(
      id: 'link',
      systemId: 'lan',
      code: 'LINK-01',
      profileId: 'link-path',
      startPortId: 'outlet.ETH',
      endPortId: 'switch.P1'));
  f.connect('horizontal', 'lan', 'outlet.ETH', 'patch.REAR', 'ethernet',
      group: 'link');
  f.connect('patch-cord', 'lan', 'patch.FRONT', 'switch.P1', 'ethernet',
      group: 'link');
  f.internal('patch-mapping', 'patch', 'patch.REAR', 'patch.FRONT',
      ConnectionLayer.data);
  f.internal('unused-mapping', 'patch', 'patch.UNUSED-A', 'patch.UNUSED-B',
      ConnectionLayer.data);
  return f;
}

TopologyFixture fireFixture() {
  final f = TopologyFixture()..system('fire', 'FIRE');
  for (final id in ['facp', 'detector', 'callpoint']) {
    f.participate(id, 'fire');
  }
  f.port('facp', 'OUT',
      kind: EngineeringPortKind.bus,
      direction: PortDirection.output,
      protocol: 'TEST-LOOP');
  f.port('facp', 'RETURN',
      kind: EngineeringPortKind.bus,
      direction: PortDirection.input,
      protocol: 'TEST-LOOP');
  for (final id in ['detector', 'callpoint']) {
    f.port(id, 'IN',
        kind: EngineeringPortKind.bus,
        direction: PortDirection.input,
        protocol: 'TEST-LOOP');
    f.port(id, 'OUT',
        kind: EngineeringPortKind.bus,
        direction: PortDirection.output,
        protocol: 'TEST-LOOP',
        capacity: id == 'detector' ? 2 : 1);
    f.internal('$id-mapping', id, '$id.IN', '$id.OUT', ConnectionLayer.signal,
        bidirectional: false);
  }
  f.profile('loop-segment', 'FIRE',
      kind: EngineeringPortKind.bus,
      flow: CompatibilityFlow.directed,
      layer: ConnectionLayer.signal,
      protocol: 'TEST-LOOP');
  f.topologyProfiles.add(TopologyProfile(
      identity: f.identity('loop-profile'),
      shape: TopologyShape.loop,
      layer: TraceLayer.signal));
  f.groups.add(const TopologyGroup(
      id: 'loop',
      systemId: 'fire',
      code: 'L1',
      profileId: 'loop-profile',
      startPortId: 'facp.OUT',
      endPortId: 'facp.RETURN'));
  f.connect('first', 'fire', 'facp.OUT', 'detector.IN', 'loop-segment',
      group: 'loop');
  f.connect('second', 'fire', 'detector.OUT', 'callpoint.IN', 'loop-segment',
      group: 'loop');
  f.connect('return', 'fire', 'callpoint.OUT', 'facp.RETURN', 'loop-segment',
      group: 'loop');
  return f;
}

void main() {
  test(
      'CCTV: combined PoE connection and independent switch power graph share one component identity',
      () {
    final f = TopologyFixture()
      ..system('cctv', 'CCTV')
      ..system('power', 'POWER');
    f.participate('camera', 'cctv');
    f.participate('switch', 'cctv');
    f.participate('switch', 'power');
    f.participate('ups', 'power');
    f.port('switch', 'POE',
        kind: EngineeringPortKind.dataPower,
        powerDirection: PortDirection.output,
        voltage: 48);
    f.port('camera', 'ETH',
        kind: EngineeringPortKind.dataPower,
        powerDirection: PortDirection.input,
        voltage: 44,
        acceptMax: 57);
    f.port('ups', 'OUT',
        kind: EngineeringPortKind.power,
        direction: PortDirection.output,
        powerDirection: PortDirection.output,
        voltage: 24,
        protocol: 'TEST-DC');
    f.port('switch', 'PWR',
        kind: EngineeringPortKind.power,
        direction: PortDirection.input,
        powerDirection: PortDirection.input,
        voltage: 24,
        protocol: 'TEST-DC');
    f.profile('poe', 'CCTV',
        kind: EngineeringPortKind.dataPower, layer: ConnectionLayer.dataPower);
    f.profile('dc', 'POWER',
        kind: EngineeringPortKind.power,
        layer: ConnectionLayer.power,
        flow: CompatibilityFlow.directed,
        protocol: 'TEST-DC');
    f.connect('camera-link', 'cctv', 'switch.POE', 'camera.ETH', 'poe');
    f.connect('switch-feed', 'power', 'ups.OUT', 'switch.PWR', 'dc');
    final g = f.graph();
    expect(g.findings(), isEmpty);
    expect(g.componentIds.length, 3);
    expect(
        g
            .trace('camera.ETH',
                layer: TraceLayer.power,
                direction: TopologyTraceDirection.upstream)
            .connectionIds,
        ['camera-link']);
    expect(
        g
            .trace('camera.ETH',
                layer: TraceLayer.power,
                direction: TopologyTraceDirection.downstream)
            .connectionIds,
        isEmpty);
    expect(
        g
            .trace('camera.ETH',
                layer: TraceLayer.data,
                direction: TopologyTraceDirection.downstream)
            .connectionIds,
        ['camera-link']);
    expect(
        g
            .trace('switch.PWR',
                layer: TraceLayer.power,
                direction: TopologyTraceDirection.upstream)
            .connectionIds,
        ['switch-feed']);
    // No fictitious passive conversion joins the switch input to its PoE source.
    f.internal('fake-conversion', 'switch', 'switch.PWR', 'switch.POE',
        ConnectionLayer.power);
    expect(f.graph().internalFindings(f.internals.last).map((i) => i.code),
        contains('PASSIVE_POWER'));
  });
  test(
      'LAN: permanent path traverses passive rear/front mapping without phantom external cable',
      () {
    final f = lanFixture(), g = f.graph();
    expect(g.findings(), isEmpty);
    final trace = g.trace('outlet.ETH',
        layer: TraceLayer.data,
        direction: TopologyTraceDirection.downstream,
        systemId: 'lan');
    expect(trace.portIds,
        ['outlet.ETH', 'patch.FRONT', 'patch.REAR', 'switch.P1']);
    expect(trace.connectionIds, ['horizontal', 'patch-cord']);
    expect(trace.internalLinkIds, ['patch-mapping']);
    expect(f.internals.first.toMap().keys, isNot(contains('medium')));
    f.internals.removeAt(0);
    expect(f.graph().groupFindings(f.groups.single).map((i) => i.code),
        contains('GROUP_INCOMPLETE'));
  });
  test(
      'ACS: non-owning door roles, reader protocol, channel occupancy and incompatible lock voltage',
      () {
    final f = TopologyFixture()..system('acs', 'ACS');
    for (final id in ['reader', 'controller', 'lock', 'psu']) {
      f.participate(id, 'acs');
    }
    f.port('reader', 'BUS',
        kind: EngineeringPortKind.bus, protocol: 'TEST-OSDP');
    f.port('controller', 'READER',
        kind: EngineeringPortKind.bus, protocol: 'TEST-OSDP');
    f.profile('reader-bus', 'ACS',
        kind: EngineeringPortKind.bus,
        layer: ConnectionLayer.signal,
        protocol: 'TEST-OSDP');
    f.connect('reader', 'acs', 'controller.READER', 'reader.BUS', 'reader-bus');
    f.assemblyProfiles.add(AssemblyProfile(
        identity: f.identity('door-profile'),
        roles: const [
          AssemblyRoleRule(code: 'READER', minimum: 1, maximum: 1),
          AssemblyRoleRule(code: 'LOCK', minimum: 1, maximum: 1),
          AssemblyRoleRule(code: 'CONTROLLER', minimum: 1, maximum: 1)
        ],
        allowSharedComponents: false));
    f.assemblies.add(ComponentAssembly(
        id: 'door',
        code: 'D101',
        profileId: 'door-profile',
        members: const [
          AssemblyMember(componentId: 'reader', role: 'READER'),
          AssemblyMember(componentId: 'lock', role: 'LOCK'),
          AssemblyMember(componentId: 'controller', role: 'CONTROLLER')
        ]));
    expect(f.graph().findings(), isEmpty);
    f.port('psu', 'OUT',
        kind: EngineeringPortKind.power,
        direction: PortDirection.output,
        powerDirection: PortDirection.output,
        voltage: 24,
        protocol: 'TEST-DC');
    f.port('lock', 'IN',
        kind: EngineeringPortKind.power,
        direction: PortDirection.input,
        powerDirection: PortDirection.input,
        voltage: 12,
        protocol: 'TEST-DC');
    f.profile('lock-feed', 'ACS',
        kind: EngineeringPortKind.power,
        layer: ConnectionLayer.power,
        flow: CompatibilityFlow.directed,
        protocol: 'TEST-DC');
    f.connect('bad-lock', 'acs', 'psu.OUT', 'lock.IN', 'lock-feed');
    expect(f.graph().connectionFindings(f.connections.last).map((i) => i.code),
        contains('VOLTAGE_DOMAIN'));
    f.participate('reader2', 'acs');
    f.port('reader2', 'BUS',
        kind: EngineeringPortKind.bus, protocol: 'TEST-OSDP');
    f.connect(
        'reader2', 'acs', 'controller.READER', 'reader2.BUS', 'reader-bus');
    expect(f.graph().connectionFindings(f.connections.last).map((i) => i.code),
        contains('PORT_CAPACITY'));
  });
  test(
      'fire: binary loop segments close through declared device internals and explicit controller return',
      () {
    final f = fireFixture();
    expect(f.graph().findings(), isEmpty);
    expect(
        f
            .graph()
            .trace('facp.OUT',
                layer: TraceLayer.signal,
                direction: TopologyTraceDirection.downstream)
            .portIds,
        contains('facp.RETURN'));
    f.connections.removeLast();
    final findings = f.graph().groupFindings(f.groups.single);
    expect(findings.map((i) => i.code), contains('GROUP_INCOMPLETE'));
    expect(findings.any((i) => i.code == 'GROUP_CYCLE'), isFalse);
    expect(findings.first.profile!.version, 'test-1');
  });
  test(
      'fire loop rejects branch even when port declared capacity permits the extra channel',
      () {
    final f = fireFixture()..participate('branch', 'fire');
    f.port('branch', 'IN',
        kind: EngineeringPortKind.bus,
        direction: PortDirection.input,
        protocol: 'TEST-LOOP');
    f.connect('branch', 'fire', 'detector.OUT', 'branch.IN', 'loop-segment',
        group: 'loop');
    expect(f.graph().connectionFindings(f.connections.last), isEmpty);
    expect(f.graph().groupFindings(f.groups.single).map((i) => i.code),
        contains('GROUP_BRANCH'));
  });
  test(
      'unknown compatibility, wrong protocol edition and duplicate pair are never silently accepted',
      () {
    final f = lanFixture();
    final original = f.ports.first;
    f.ports[0] =
        EngineeringPort.fromMap({...original.toMap(), 'connector': null});
    expect(f.graph().connectionFindings(f.connections.first).map((i) => i.code),
        contains('COMPATIBILITY_UNRESOLVED'));
    f.ports[0] = EngineeringPort.fromMap({
      ...original.toMap(),
      'protocol': {'id': 'TEST-ETH', 'version': '2'}
    });
    expect(f.graph().connectionFindings(f.connections.first).map((i) => i.code),
        contains('INTERFACE_PROTOCOL'));
    f.ports[0] = original;
    f.connect('duplicate', 'lan', 'patch.REAR', 'outlet.ETH', 'ethernet');
    expect(f.graph().connectionFindings(f.connections.last).map((i) => i.code),
        contains('DUPLICATE_CONNECTION'));
  });
  test(
      'snapshot codecs preserve pinned compatibility, protocol, mapping and non-owning assembly contracts',
      () {
    final f = lanFixture();
    Map<String, dynamic> json(Map<String, Object?> m) =>
        jsonDecode(jsonEncode(m)) as Map<String, dynamic>;
    expect(EngineeringPort.fromMap(json(f.ports.first.toMap())).toMap(),
        f.ports.first.toMap());
    expect(
        ConnectionCompatibilityProfile.fromMap(json(f.profiles.first.toMap()))
            .toMap(),
        f.profiles.first.toMap());
    expect(
        EngineeringConnection.fromMap(json(f.connections.first.toMap()))
            .toMap(),
        f.connections.first.toMap());
    expect(
        InternalConnectivity.fromMap(json(f.internals.first.toMap())).toMap(),
        f.internals.first.toMap());
    expect(TopologyGroup.fromMap(json(f.groups.first.toMap())).toMap(),
        f.groups.first.toMap());
    expect(
        TopologyProfile.fromMap(json(f.topologyProfiles.first.toMap())).toMap(),
        f.topologyProfiles.first.toMap());
  });
}
