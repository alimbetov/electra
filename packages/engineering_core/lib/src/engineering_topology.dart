import 'engineering_system.dart';

enum EngineeringPortKind {
  power,
  data,
  signal,
  bus,
  dataPower,
  audio,
  video,
  fiber,
  rf,
  contact
}

enum PortDirection { input, output, bidirectional }

enum PortCurrentKind { ac, dc }

enum ConnectionLayer { power, data, signal, dataPower, signalPower }

enum TraceLayer { all, power, data, signal }

enum ConnectionMedium { wired, wireless, logical }

enum CompatibilityFlow { directed, bidirectional }

enum TopologyShape { path, loop, tree, star }

enum TopologyTraceDirection { both, upstream, downstream }

bool layerServes(ConnectionLayer layer, TraceLayer trace) =>
    trace == TraceLayer.all ||
    switch (trace) {
      TraceLayer.power => [
          ConnectionLayer.power,
          ConnectionLayer.dataPower,
          ConnectionLayer.signalPower
        ].contains(layer),
      TraceLayer.data =>
        [ConnectionLayer.data, ConnectionLayer.dataPower].contains(layer),
      TraceLayer.signal =>
        [ConnectionLayer.signal, ConnectionLayer.signalPower].contains(layer),
      TraceLayer.all => true,
    };
bool carriesPower(ConnectionLayer layer) =>
    layerServes(layer, TraceLayer.power);

class ProfileIdentity {
  const ProfileIdentity(
      {required this.id,
      required this.projectId,
      required this.code,
      required this.version,
      required this.source});
  final String id, projectId, code, version, source;
  List<String> validate() => [
        if ([id, projectId, code, version, source].any((s) => s.trim().isEmpty))
          'Profile identity, project, code, version and source are required.'
      ];
  Map<String, Object?> toMap() => {
        'id': id,
        'projectId': projectId,
        'code': code,
        'version': version,
        'source': source
      };
  factory ProfileIdentity.fromMap(Map<String, dynamic> m) => ProfileIdentity(
      id: m['id'] as String,
      projectId: m['projectId'] as String,
      code: m['code'] as String,
      version: m['version'] as String,
      source: m['source'] as String);
}

class PortVoltageDomain {
  const PortVoltageDomain(
      {required this.currentKind,
      required this.minimumV,
      required this.maximumV});
  final PortCurrentKind currentKind;
  final double minimumV, maximumV;
  bool get valid =>
      minimumV.isFinite &&
      maximumV.isFinite &&
      minimumV > 0 &&
      maximumV >= minimumV;
  Map<String, Object?> toMap() => {
        'currentKind': currentKind.name,
        'minimumV': minimumV,
        'maximumV': maximumV
      };
  factory PortVoltageDomain.fromMap(
          Map<String, dynamic> m) =>
      PortVoltageDomain(
          currentKind:
              PortCurrentKind.values.byName(m['currentKind'] as String),
          minimumV: (m['minimumV'] as num).toDouble(),
          maximumV: (m['maximumV'] as num).toDouble());
}

class EngineeringPort {
  const EngineeringPort(
      {required this.id,
      required this.componentId,
      required this.code,
      required this.kind,
      required this.direction,
      required this.capacity,
      this.connector,
      this.protocol,
      this.voltage,
      this.powerDirection,
      this.powerLimitW,
      this.powerDemandW,
      this.templateProvenance,
      this.interfaceProvenance});
  final String id, componentId, code;
  final EngineeringPortKind kind;
  final PortDirection direction;
  final int capacity;
  final String? connector;
  final EngineeringProfileReference? protocol, templateProvenance;
  final EngineeringProfileReference? interfaceProvenance;
  final PortVoltageDomain? voltage;
  final PortDirection? powerDirection;
  final double? powerLimitW, powerDemandW;
  List<String> validate() => [
        if ([id, componentId, code].any((s) => s.trim().isEmpty))
          'Port identity, owner and code are required.',
        if (capacity <= 0) 'Port capacity must be positive.',
        if (voltage != null && !voltage!.valid) 'Invalid voltage domain.',
        if (interfaceProvenance != null && !interfaceProvenance!.valid)
          'Interface provenance needs an identity and edition.',
        if (protocol != null && !protocol!.valid ||
            templateProvenance != null && !templateProvenance!.valid)
          'Profile provenance needs an identity and edition.',
        for (final v in [powerLimitW, powerDemandW])
          if (v != null && (!v.isFinite || v <= 0))
            'Power quantities must be positive and finite.',
      ];
  Map<String, Object?> toMap() => {
        'id': id,
        'componentId': componentId,
        'code': code,
        'kind': kind.name,
        'direction': direction.name,
        'capacity': capacity,
        'connector': connector,
        'protocol': protocol?.toMap(),
        'voltage': voltage?.toMap(),
        'powerDirection': powerDirection?.name,
        'powerLimitW': powerLimitW,
        'powerDemandW': powerDemandW,
        if (interfaceProvenance != null)
          'interfaceProvenance': interfaceProvenance!.toMap(),
        'templateProvenance': templateProvenance?.toMap()
      };
  factory EngineeringPort.fromMap(Map<String, dynamic> m) => EngineeringPort(
      id: m['id'] as String,
      componentId: m['componentId'] as String,
      code: m['code'] as String,
      kind: EngineeringPortKind.values.byName(m['kind'] as String),
      direction: PortDirection.values.byName(m['direction'] as String),
      capacity: m['capacity'] as int,
      connector: m['connector'] as String?,
      protocol: m['protocol'] == null
          ? null
          : EngineeringProfileReference.fromMap(
              m['protocol'] as Map<String, dynamic>),
      voltage: m['voltage'] == null
          ? null
          : PortVoltageDomain.fromMap(m['voltage'] as Map<String, dynamic>),
      powerDirection: m['powerDirection'] == null
          ? null
          : PortDirection.values.byName(m['powerDirection'] as String),
      powerLimitW: (m['powerLimitW'] as num?)?.toDouble(),
      powerDemandW: (m['powerDemandW'] as num?)?.toDouble(),
      interfaceProvenance: m['interfaceProvenance'] == null
          ? null
          : EngineeringProfileReference.fromMap(
              m['interfaceProvenance'] as Map<String, dynamic>),
      templateProvenance: m['templateProvenance'] == null
          ? null
          : EngineeringProfileReference.fromMap(
              m['templateProvenance'] as Map<String, dynamic>));
}

/// Exact project-authored compatibility edition; no implicit national thresholds.
class ConnectionCompatibilityProfile {
  ConnectionCompatibilityProfile(
      {required this.identity,
      required Iterable<String> familyCodes,
      required Iterable<ConnectionMedium> media,
      required this.semanticCode,
      required this.layer,
      required this.flow,
      required this.kindA,
      required this.kindB,
      required this.connectorA,
      required this.connectorB,
      required this.protocolA,
      required this.protocolB,
      this.interfaceA,
      this.interfaceB})
      : familyCodes = List.unmodifiable(familyCodes.toList()..sort()),
        media = List.unmodifiable(media);
  final ProfileIdentity identity;
  String get id => identity.id;
  final List<String> familyCodes;
  final List<ConnectionMedium> media;
  final String semanticCode, connectorA, connectorB;
  final ConnectionLayer layer;
  final CompatibilityFlow flow;
  final EngineeringPortKind kindA, kindB;
  final EngineeringProfileReference protocolA, protocolB;
  final EngineeringProfileReference? interfaceA, interfaceB;
  List<String> validate() => [
        ...identity.validate(),
        if ((interfaceA == null) != (interfaceB == null) ||
            interfaceA?.valid == false ||
            interfaceB?.valid == false)
          "Declare both exact interface editions or neither.",
        if (media.isEmpty || media.toSet().length != media.length)
          'Declare allowed connection media.',
        if (familyCodes.isEmpty ||
            familyCodes.any((s) => s.trim().isEmpty) ||
            familyCodes.toSet().length != familyCodes.length)
          'Specify unique allowed family codes.',
        if ([semanticCode, connectorA, connectorB]
                .any((s) => s.trim().isEmpty) ||
            !protocolA.valid ||
            !protocolB.valid)
          'Semantic, connector and exact protocol profiles are required.'
      ];
  Map<String, Object?> toMap() => {
        'identity': identity.toMap(),
        'familyCodes': familyCodes,
        'media': media.map((m) => m.name).toList(),
        'semanticCode': semanticCode,
        'layer': layer.name,
        'flow': flow.name,
        'kindA': kindA.name,
        'kindB': kindB.name,
        'connectorA': connectorA,
        'connectorB': connectorB,
        'protocolA': protocolA.toMap(),
        if (interfaceA != null) 'interfaceA': interfaceA!.toMap(),
        if (interfaceB != null) 'interfaceB': interfaceB!.toMap(),
        'protocolB': protocolB.toMap()
      };
  factory ConnectionCompatibilityProfile.fromMap(Map<String, dynamic> m) =>
      ConnectionCompatibilityProfile(
          identity:
              ProfileIdentity.fromMap(m['identity'] as Map<String, dynamic>),
          familyCodes: (m['familyCodes'] as List).cast<String>(),
          media: (m['media'] as List)
              .map((s) => ConnectionMedium.values.byName(s as String)),
          semanticCode: m['semanticCode'] as String,
          layer: ConnectionLayer.values.byName(m['layer'] as String),
          flow: CompatibilityFlow.values.byName(m['flow'] as String),
          kindA: EngineeringPortKind.values.byName(m['kindA'] as String),
          kindB: EngineeringPortKind.values.byName(m['kindB'] as String),
          connectorA: m['connectorA'] as String,
          connectorB: m['connectorB'] as String,
          protocolA: EngineeringProfileReference.fromMap(
              m['protocolA'] as Map<String, dynamic>),
          interfaceA: m['interfaceA'] == null
              ? null
              : EngineeringProfileReference.fromMap(
                  m['interfaceA'] as Map<String, dynamic>),
          interfaceB: m['interfaceB'] == null
              ? null
              : EngineeringProfileReference.fromMap(
                  m['interfaceB'] as Map<String, dynamic>),
          protocolB: EngineeringProfileReference.fromMap(
              m['protocolB'] as Map<String, dynamic>));
}

class EngineeringConnection {
  const EngineeringConnection(
      {required this.id,
      required this.systemId,
      required this.fromPortId,
      required this.toPortId,
      required this.profileId,
      required this.medium,
      this.groupId});
  final String id, systemId, fromPortId, toPortId, profileId;
  final ConnectionMedium medium;
  final String? groupId;
  Map<String, Object?> toMap() => {
        'id': id,
        'systemId': systemId,
        'fromPortId': fromPortId,
        'toPortId': toPortId,
        'profileId': profileId,
        'medium': medium.name,
        'groupId': groupId
      };
  factory EngineeringConnection.fromMap(Map<String, dynamic> m) =>
      EngineeringConnection(
          id: m['id'] as String,
          systemId: m['systemId'] as String,
          fromPortId: m['fromPortId'] as String,
          toPortId: m['toPortId'] as String,
          profileId: m['profileId'] as String,
          medium: ConnectionMedium.values.byName(m['medium'] as String),
          groupId: m['groupId'] as String?);
}

class InternalConnectivity {
  const InternalConnectivity(
      {required this.id,
      required this.componentId,
      required this.fromPortId,
      required this.toPortId,
      required this.layer,
      required this.bidirectional,
      required this.evidence});
  final String id, componentId, fromPortId, toPortId, evidence;
  final ConnectionLayer layer;
  final bool bidirectional;
  Map<String, Object?> toMap() => {
        'id': id,
        'componentId': componentId,
        'fromPortId': fromPortId,
        'toPortId': toPortId,
        'layer': layer.name,
        'bidirectional': bidirectional,
        'evidence': evidence
      };
  factory InternalConnectivity.fromMap(Map<String, dynamic> m) =>
      InternalConnectivity(
          id: m['id'] as String,
          componentId: m['componentId'] as String,
          fromPortId: m['fromPortId'] as String,
          toPortId: m['toPortId'] as String,
          layer: ConnectionLayer.values.byName(m['layer'] as String),
          bidirectional: m['bidirectional'] as bool,
          evidence: m['evidence'] as String);
}

class TopologyProfile {
  const TopologyProfile(
      {required this.identity, required this.shape, required this.layer});
  final ProfileIdentity identity;
  String get id => identity.id;
  final TopologyShape shape;
  final TraceLayer layer;
  List<String> validate() => [
        ...identity.validate(),
        if (layer == TraceLayer.all) 'Select a concrete topology layer.'
      ];
  Map<String, Object?> toMap() =>
      {'identity': identity.toMap(), 'shape': shape.name, 'layer': layer.name};
  factory TopologyProfile.fromMap(Map<String, dynamic> m) => TopologyProfile(
      identity: ProfileIdentity.fromMap(m['identity'] as Map<String, dynamic>),
      shape: TopologyShape.values.byName(m['shape'] as String),
      layer: TraceLayer.values.byName(m['layer'] as String));
}

class TopologyGroup {
  const TopologyGroup(
      {required this.id,
      required this.systemId,
      required this.code,
      required this.profileId,
      required this.startPortId,
      this.endPortId});
  final String id, systemId, code, profileId, startPortId;
  final String? endPortId;
  Map<String, Object?> toMap() => {
        'id': id,
        'systemId': systemId,
        'code': code,
        'profileId': profileId,
        'startPortId': startPortId,
        'endPortId': endPortId
      };
  factory TopologyGroup.fromMap(Map<String, dynamic> m) => TopologyGroup(
      id: m['id'] as String,
      systemId: m['systemId'] as String,
      code: m['code'] as String,
      profileId: m['profileId'] as String,
      startPortId: m['startPortId'] as String,
      endPortId: m['endPortId'] as String?);
}

class AssemblyRoleRule {
  const AssemblyRoleRule(
      {required this.code, required this.minimum, required this.maximum});
  final String code;
  final int minimum, maximum;
  Map<String, Object?> toMap() =>
      {'code': code, 'minimum': minimum, 'maximum': maximum};
  factory AssemblyRoleRule.fromMap(Map<String, dynamic> m) => AssemblyRoleRule(
      code: m['code'] as String,
      minimum: m['minimum'] as int,
      maximum: m['maximum'] as int);
}

class AssemblyProfile {
  AssemblyProfile(
      {required this.identity,
      required Iterable<AssemblyRoleRule> roles,
      required this.allowSharedComponents})
      : roles = List.unmodifiable(roles);
  final ProfileIdentity identity;
  String get id => identity.id;
  final List<AssemblyRoleRule> roles;
  final bool allowSharedComponents;
  List<String> validate() => [
        ...identity.validate(),
        if (roles.isEmpty ||
            roles.map((r) => r.code).toSet().length != roles.length ||
            roles.any((r) =>
                r.code.trim().isEmpty ||
                r.minimum < 0 ||
                r.maximum < r.minimum ||
                r.maximum <= 0))
          'Specify unique roles and valid cardinalities.'
      ];
  Map<String, Object?> toMap() => {
        'identity': identity.toMap(),
        'roles': roles.map((r) => r.toMap()).toList(),
        'allowSharedComponents': allowSharedComponents
      };
  factory AssemblyProfile.fromMap(Map<String, dynamic> m) => AssemblyProfile(
      identity: ProfileIdentity.fromMap(m['identity'] as Map<String, dynamic>),
      roles: (m['roles'] as List)
          .map((r) => AssemblyRoleRule.fromMap(r as Map<String, dynamic>)),
      allowSharedComponents: m['allowSharedComponents'] as bool);
}

class AssemblyMember {
  const AssemblyMember({required this.componentId, required this.role});
  final String componentId, role;
  Map<String, Object?> toMap() => {'componentId': componentId, 'role': role};
  factory AssemblyMember.fromMap(Map<String, dynamic> m) => AssemblyMember(
      componentId: m['componentId'] as String, role: m['role'] as String);
}

class ComponentAssembly {
  ComponentAssembly(
      {required this.id,
      required this.code,
      required this.profileId,
      required Iterable<AssemblyMember> members})
      : members = List.unmodifiable(members);
  final String id, code, profileId;
  final List<AssemblyMember> members;
  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'profileId': profileId,
        'members': members.map((m) => m.toMap()).toList()
      };
  factory ComponentAssembly.fromMap(Map<String, dynamic> m) =>
      ComponentAssembly(
          id: m['id'] as String,
          code: m['code'] as String,
          profileId: m['profileId'] as String,
          members: (m['members'] as List)
              .map((r) => AssemblyMember.fromMap(r as Map<String, dynamic>)));
}
