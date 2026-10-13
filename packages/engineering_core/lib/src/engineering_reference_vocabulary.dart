import 'engineering_system.dart';
import 'engineering_topology.dart';

enum ConnectorClass {
  rj45,
  lc,
  sc,
  bnc,
  screwTerminal,
  pluggableTerminal,
  custom
}

enum SignalMediaKind {
  balancedCopper,
  opticalFiber,
  coax,
  dcPower,
  multicoreControl,
  wireless,
  logical
}

class ReferenceEntry {
  const ReferenceEntry(
      {required this.code, required this.label, this.deprecated = false});
  final String code, label;
  final bool deprecated;
  List<String> validate() => [
        if (!RegExp(r'^[A-Z][A-Z0-9_.-]*$').hasMatch(code) ||
            label.trim().isEmpty)
          'Reference codes must be canonical uppercase codes with a display label.'
      ];
  Map<String, Object?> toMap() =>
      {'code': code, 'label': label, 'deprecated': deprecated};
  factory ReferenceEntry.fromMap(Map<String, dynamic> m) => ReferenceEntry(
      code: m['code'] as String,
      label: m['label'] as String,
      deprecated: m['deprecated'] as bool? ?? false);
}

class ConnectorDefinition {
  ConnectorDefinition(
      {required this.identity,
      required this.connectorClass,
      required Iterable<String> mediaCodes,
      this.contactCount})
      : mediaCodes = List.unmodifiable(mediaCodes);
  final ReferenceEntry identity;
  final ConnectorClass connectorClass;
  final List<String> mediaCodes;
  final int? contactCount;
  String get code => identity.code;
  List<String> validate() => [
        ...identity.validate(),
        if (contactCount != null && contactCount! <= 0)
          'Contact count must be positive.',
        if (mediaCodes.isEmpty ||
            mediaCodes.toSet().length != mediaCodes.length)
          'Declare distinct supported media codes.',
      ];
  Map<String, Object?> toMap() => {
        'identity': identity.toMap(),
        'connectorClass': connectorClass.name,
        'mediaCodes': mediaCodes,
        'contactCount': contactCount
      };
  factory ConnectorDefinition.fromMap(Map<String, dynamic> m) =>
      ConnectorDefinition(
          identity:
              ReferenceEntry.fromMap(m['identity'] as Map<String, dynamic>),
          connectorClass:
              ConnectorClass.values.byName(m['connectorClass'] as String),
          mediaCodes: (m['mediaCodes'] as List).cast<String>(),
          contactCount: m['contactCount'] as int?);
}

class ProtocolDefinition {
  ProtocolDefinition(
      {required this.identity,
      required Iterable<EngineeringPortKind> portKinds,
      this.dataRateMbps})
      : portKinds = List.unmodifiable(portKinds);
  final ReferenceEntry identity;
  final List<EngineeringPortKind> portKinds;
  final double? dataRateMbps;
  String get code => identity.code;
  List<String> validate() => [
        ...identity.validate(),
        if (portKinds.isEmpty || portKinds.toSet().length != portKinds.length)
          'Declare distinct protocol port kinds.',
        if (dataRateMbps != null &&
            (!dataRateMbps!.isFinite || dataRateMbps! <= 0))
          'Data rate must be positive and finite.',
      ];
  Map<String, Object?> toMap() => {
        'identity': identity.toMap(),
        'portKinds': portKinds.map((v) => v.name).toList(),
        'dataRateMbps': dataRateMbps
      };
  factory ProtocolDefinition.fromMap(Map<String, dynamic> m) =>
      ProtocolDefinition(
          identity:
              ReferenceEntry.fromMap(m['identity'] as Map<String, dynamic>),
          portKinds: (m['portKinds'] as List)
              .map((v) => EngineeringPortKind.values.byName(v as String)),
          dataRateMbps: (m['dataRateMbps'] as num?)?.toDouble());
}

class VoltageDefinition {
  VoltageDefinition({required this.identity, required this.domain});
  final ReferenceEntry identity;
  final PortVoltageDomain domain;
  String get code => identity.code;
  List<String> validate() => [
        ...identity.validate(),
        if (!domain.valid) 'Voltage domain is invalid.',
      ];
  Map<String, Object?> toMap() =>
      {'identity': identity.toMap(), 'domain': domain.toMap()};
  factory VoltageDefinition.fromMap(Map<String, dynamic> m) =>
      VoltageDefinition(
          identity:
              ReferenceEntry.fromMap(m['identity'] as Map<String, dynamic>),
          domain:
              PortVoltageDomain.fromMap(m['domain'] as Map<String, dynamic>));
}

class MediaDefinition {
  MediaDefinition(
      {required this.identity,
      required this.kind,
      required this.connectionMedium});
  final ReferenceEntry identity;
  final SignalMediaKind kind;
  final ConnectionMedium connectionMedium;
  String get code => identity.code;
  List<String> validate() => [
        ...identity.validate(),
        if ((kind == SignalMediaKind.wireless &&
                connectionMedium != ConnectionMedium.wireless) ||
            (kind == SignalMediaKind.logical &&
                connectionMedium != ConnectionMedium.logical) ||
            (![SignalMediaKind.wireless, SignalMediaKind.logical]
                    .contains(kind) &&
                connectionMedium != ConnectionMedium.wired))
          'Signal medium and connection medium disagree.',
      ];
  Map<String, Object?> toMap() => {
        'identity': identity.toMap(),
        'kind': kind.name,
        'connectionMedium': connectionMedium.name
      };
  factory MediaDefinition.fromMap(Map<String, dynamic> m) => MediaDefinition(
      identity: ReferenceEntry.fromMap(m['identity'] as Map<String, dynamic>),
      kind: SignalMediaKind.values.byName(m['kind'] as String),
      connectionMedium:
          ConnectionMedium.values.byName(m['connectionMedium'] as String));
}

class InterfaceDefinition {
  InterfaceDefinition(
      {required this.identity,
      required this.kind,
      required this.direction,
      required this.capacity,
      required this.connectorCode,
      required this.protocolCode,
      required this.mediaCode,
      this.voltageCode,
      this.powerDirection,
      this.powerLimitW,
      this.powerDemandW});
  final ReferenceEntry identity;
  final EngineeringPortKind kind;
  final PortDirection direction;
  final int capacity;
  final String connectorCode;
  final String protocolCode;
  final String mediaCode;
  final String? voltageCode;
  final PortDirection? powerDirection;
  final double? powerLimitW;
  final double? powerDemandW;
  String get code => identity.code;
  List<String> validate() => [
        ...identity.validate(),
        if (capacity <= 0) 'Interface capacity must be positive.',
        if ([connectorCode, protocolCode, mediaCode].any((c) => c.isEmpty))
          'Resolve connector, protocol and medium.',
        for (final v in [powerLimitW, powerDemandW])
          if (v != null && (!v.isFinite || v <= 0))
            'Power quantities must be positive and finite.',
      ];
  Map<String, Object?> toMap() => {
        'identity': identity.toMap(),
        'kind': kind.name,
        'direction': direction.name,
        'capacity': capacity,
        'connectorCode': connectorCode,
        'protocolCode': protocolCode,
        'mediaCode': mediaCode,
        'voltageCode': voltageCode,
        'powerDirection': powerDirection?.name,
        'powerLimitW': powerLimitW,
        'powerDemandW': powerDemandW
      };
  factory InterfaceDefinition.fromMap(Map<String, dynamic> m) =>
      InterfaceDefinition(
          identity:
              ReferenceEntry.fromMap(m['identity'] as Map<String, dynamic>),
          kind: EngineeringPortKind.values.byName(m['kind'] as String),
          direction: PortDirection.values.byName(m['direction'] as String),
          capacity: m['capacity'] as int,
          connectorCode: m['connectorCode'] as String,
          protocolCode: m['protocolCode'] as String,
          mediaCode: m['mediaCode'] as String,
          voltageCode: m['voltageCode'] as String?,
          powerDirection: m['powerDirection'] == null
              ? null
              : PortDirection.values.byName(m['powerDirection'] as String),
          powerLimitW: (m['powerLimitW'] as num?)?.toDouble(),
          powerDemandW: (m['powerDemandW'] as num?)?.toDouble());
}

class CompatibilityDefinition {
  CompatibilityDefinition(
      {required this.identity,
      required Iterable<String> familyCodes,
      required this.fromInterfaceCode,
      required this.toInterfaceCode,
      required this.medium,
      required this.layer,
      required this.flow})
      : familyCodes = List.unmodifiable(familyCodes);
  final ReferenceEntry identity;
  final List<String> familyCodes;
  final String fromInterfaceCode;
  final String toInterfaceCode;
  final ConnectionMedium medium;
  final ConnectionLayer layer;
  final CompatibilityFlow flow;
  String get code => identity.code;
  List<String> validate() => [
        ...identity.validate(),
        if (familyCodes.isEmpty ||
            familyCodes
                .any((c) => c.trim().isEmpty || c != c.trim().toUpperCase()) ||
            familyCodes.toSet().length != familyCodes.length)
          'Declare distinct canonical family codes.',
        if (fromInterfaceCode.isEmpty || toInterfaceCode.isEmpty)
          'Declare two ordered interface codes.',
      ];
  Map<String, Object?> toMap() => {
        'identity': identity.toMap(),
        'familyCodes': familyCodes,
        'fromInterfaceCode': fromInterfaceCode,
        'toInterfaceCode': toInterfaceCode,
        'medium': medium.name,
        'layer': layer.name,
        'flow': flow.name
      };
  factory CompatibilityDefinition.fromMap(Map<String, dynamic> m) =>
      CompatibilityDefinition(
          identity:
              ReferenceEntry.fromMap(m['identity'] as Map<String, dynamic>),
          familyCodes: (m['familyCodes'] as List).cast<String>(),
          fromInterfaceCode: m['fromInterfaceCode'] as String,
          toInterfaceCode: m['toInterfaceCode'] as String,
          medium: ConnectionMedium.values.byName(m['medium'] as String),
          layer: ConnectionLayer.values.byName(m['layer'] as String),
          flow: CompatibilityFlow.values.byName(m['flow'] as String));
}

class EngineeringReferenceVocabulary {
  EngineeringReferenceVocabulary(
      {Iterable<ConnectorDefinition> connectors = const [],
      Iterable<ProtocolDefinition> protocols = const [],
      Iterable<VoltageDefinition> voltages = const [],
      Iterable<MediaDefinition> media = const [],
      Iterable<InterfaceDefinition> interfaces = const [],
      Iterable<CompatibilityDefinition> compatibility = const []})
      : connectors = List.unmodifiable(connectors),
        protocols = List.unmodifiable(protocols),
        voltages = List.unmodifiable(voltages),
        media = List.unmodifiable(media),
        interfaces = List.unmodifiable(interfaces),
        compatibility = List.unmodifiable(compatibility);
  final List<ConnectorDefinition> connectors;
  final List<ProtocolDefinition> protocols;
  final List<VoltageDefinition> voltages;
  final List<MediaDefinition> media;
  final List<InterfaceDefinition> interfaces;
  final List<CompatibilityDefinition> compatibility;
  List<ReferenceEntry> get entries => [
        ...connectors.map((v) => v.identity),
        ...protocols.map((v) => v.identity),
        ...voltages.map((v) => v.identity),
        ...media.map((v) => v.identity),
        ...interfaces.map((v) => v.identity),
        ...compatibility.map((v) => v.identity)
      ];
  bool get isEmpty => entries.isEmpty;
  InterfaceDefinition interface(String code) =>
      interfaces.singleWhere((v) => v.code == code);
  List<String> validate() {
    final errors = <String>[];
    final ci = {for (final v in connectors) v.code: v},
        pi = {for (final v in protocols) v.code: v},
        vi = {for (final v in voltages) v.code: v},
        mi = {for (final v in media) v.code: v},
        ii = {for (final v in interfaces) v.code: v};
    for (final codes in [
      connectors.map((v) => v.code),
      protocols.map((v) => v.code),
      voltages.map((v) => v.code),
      media.map((v) => v.code),
      interfaces.map((v) => v.code),
      compatibility.map((v) => v.code)
    ]) {
      if (codes.toSet().length != codes.length)
        errors.add('Duplicate reference definition code.');
    }
    for (final v in connectors) {
      errors.addAll(v.validate());
      if (v.mediaCodes.any((c) => !mi.containsKey(c)))
        errors.add('Connector ${v.code} references an unknown medium.');
    }
    for (final v in protocols) {
      errors.addAll(v.validate());
    }
    for (final v in voltages) {
      errors.addAll(v.validate());
    }
    for (final v in media) {
      errors.addAll(v.validate());
    }
    for (final v in interfaces) {
      errors.addAll(v.validate());
      final c = ci[v.connectorCode],
          p = pi[v.protocolCode],
          m = mi[v.mediaCode];
      if (c == null ||
          p == null ||
          m == null ||
          (v.voltageCode != null && !vi.containsKey(v.voltageCode)))
        errors.add('Interface ${v.code} has unresolved reference codes.');
      if (c != null && !c.mediaCodes.contains(v.mediaCode))
        errors.add('Connector does not support interface medium ${v.code}.');
      if (p != null && !p.portKinds.contains(v.kind))
        errors.add('Protocol does not support interface kind ${v.code}.');
      if (v.kind == EngineeringPortKind.power &&
          v.powerDirection != v.direction)
        errors
            .add('Power-only interface direction must match power direction.');
      if ([EngineeringPortKind.power, EngineeringPortKind.dataPower]
              .contains(v.kind) &&
          v.powerDirection == null)
        errors.add(
            'Power-capable interface ${v.code} needs explicit power direction.');
    }
    for (final rule in compatibility) {
      errors.addAll(rule.validate());
      final a = ii[rule.fromInterfaceCode], b = ii[rule.toInterfaceCode];
      if (a == null || b == null) {
        errors
            .add('Compatibility ${rule.code} references an unknown interface.');
        continue;
      }
      if (mi[a.mediaCode]?.connectionMedium != rule.medium ||
          mi[b.mediaCode]?.connectionMedium != rule.medium ||
          a.mediaCode != b.mediaCode)
        errors.add(
            'Compatibility ${rule.code} requires a common declared medium.');
      if (a.protocolCode != b.protocolCode)
        errors.add(
            'Compatibility ${rule.code} cannot translate protocols; model an explicit converter.');
      if (rule.flow == CompatibilityFlow.directed
          ? a.direction == PortDirection.input ||
              b.direction == PortDirection.output
          : a.direction != PortDirection.bidirectional ||
              b.direction != PortDirection.bidirectional)
        errors.add(
            'Compatibility ${rule.code} disagrees with interface directions.');
      if (carriesPower(rule.layer) &&
          (a.powerDirection == null ||
              b.powerDirection == null ||
              a.powerDirection == PortDirection.input ||
              b.powerDirection == PortDirection.output))
        errors.add('Compatibility ${rule.code} disagrees with power flow.');
      final requiredKinds = switch (rule.layer) {
        ConnectionLayer.power => [EngineeringPortKind.power],
        ConnectionLayer.data => [
            EngineeringPortKind.data,
            EngineeringPortKind.dataPower,
            EngineeringPortKind.fiber
          ],
        ConnectionLayer.signal => [
            EngineeringPortKind.signal,
            EngineeringPortKind.bus,
            EngineeringPortKind.contact,
            EngineeringPortKind.audio,
            EngineeringPortKind.video,
            EngineeringPortKind.rf
          ],
        ConnectionLayer.dataPower => [EngineeringPortKind.dataPower],
        ConnectionLayer.signalPower => [
            EngineeringPortKind.bus,
            EngineeringPortKind.signal
          ]
      };
      if (!requiredKinds.contains(a.kind) || !requiredKinds.contains(b.kind))
        errors.add('Compatibility ${rule.code} disagrees with semantic layer.');
    }
    return errors;
  }

  List<ReferenceEntry> interfaceEntries(String code) {
    final i = interface(code);
    return [
      i.identity,
      connectors.singleWhere((v) => v.code == i.connectorCode).identity,
      protocols.singleWhere((v) => v.code == i.protocolCode).identity,
      media.singleWhere((v) => v.code == i.mediaCode).identity,
      if (i.voltageCode != null)
        voltages.singleWhere((v) => v.code == i.voltageCode).identity
    ];
  }

  EngineeringPort resolve(EngineeringPort template, String interfaceCode,
      {required String catalogId,
      required String version,
      bool newInstantiation = true}) {
    final i = interface(interfaceCode);
    if (newInstantiation &&
        interfaceEntries(interfaceCode).any((v) => v.deprecated))
      throw StateError(
          'Deprecated interface references cannot create new ports.');
    if (template.kind != i.kind)
      throw StateError('Template kind differs from referenced interface.');
    return EngineeringPort.fromMap({
      ...template.toMap(),
      'interfaceProvenance': EngineeringProfileReference(
              id: '$catalogId/interface/$interfaceCode', version: version)
          .toMap(),
      'direction': i.direction.name,
      'capacity': i.capacity,
      'connector': '$catalogId/connector/${i.connectorCode}',
      'protocol': EngineeringProfileReference(
              id: '$catalogId/protocol/${i.protocolCode}', version: version)
          .toMap(),
      'voltage': i.voltageCode == null
          ? null
          : voltages.singleWhere((v) => v.code == i.voltageCode).domain.toMap(),
      'powerDirection': i.powerDirection?.name,
      'powerLimitW': i.powerLimitW,
      'powerDemandW': i.powerDemandW
    });
  }

  List<ConnectionCompatibilityProfile> connectionProfiles(
          {required String projectId,
          required String catalogId,
          required String catalogCode,
          required String version,
          required String source}) =>
      [
        for (final r in compatibility)
          if (!r.identity.deprecated &&
              ![
                ...interfaceEntries(r.fromInterfaceCode),
                ...interfaceEntries(r.toInterfaceCode)
              ].any((v) => v.deprecated))
            ConnectionCompatibilityProfile(
                identity: ProfileIdentity(
                    id: '$catalogId/compatibility/${r.code}',
                    projectId: projectId,
                    code: '$catalogCode.${r.code}',
                    version: version,
                    source:
                        '$source; reference catalog $catalogId edition $version'),
                familyCodes: r.familyCodes,
                media: [r.medium],
                semanticCode: r.code,
                layer: r.layer,
                flow: r.flow,
                kindA: interface(r.fromInterfaceCode).kind,
                kindB: interface(r.toInterfaceCode).kind,
                connectorA:
                    '$catalogId/connector/${interface(r.fromInterfaceCode).connectorCode}',
                connectorB:
                    '$catalogId/connector/${interface(r.toInterfaceCode).connectorCode}',
                interfaceA: EngineeringProfileReference(
                    id: '$catalogId/interface/${r.fromInterfaceCode}',
                    version: version),
                interfaceB: EngineeringProfileReference(
                    id: '$catalogId/interface/${r.toInterfaceCode}',
                    version: version),
                protocolA: EngineeringProfileReference(
                    id:
                        '$catalogId/protocol/${interface(r.fromInterfaceCode).protocolCode}',
                    version: version),
                protocolB: EngineeringProfileReference(
                    id: '$catalogId/protocol/${interface(r.toInterfaceCode).protocolCode}',
                    version: version))
      ];
  Map<String, Object?> toMap() => {
        'connectors': connectors.map((v) => v.toMap()).toList(),
        'protocols': protocols.map((v) => v.toMap()).toList(),
        'voltages': voltages.map((v) => v.toMap()).toList(),
        'media': media.map((v) => v.toMap()).toList(),
        'interfaces': interfaces.map((v) => v.toMap()).toList(),
        'compatibility': compatibility.map((v) => v.toMap()).toList()
      };
  factory EngineeringReferenceVocabulary.fromMap(Map<String, dynamic> m) =>
      EngineeringReferenceVocabulary(
        connectors: ((m['connectors'] as List?) ?? [])
            .map((v) => ConnectorDefinition.fromMap(v as Map<String, dynamic>)),
        protocols: ((m['protocols'] as List?) ?? [])
            .map((v) => ProtocolDefinition.fromMap(v as Map<String, dynamic>)),
        voltages: ((m['voltages'] as List?) ?? [])
            .map((v) => VoltageDefinition.fromMap(v as Map<String, dynamic>)),
        media: ((m['media'] as List?) ?? [])
            .map((v) => MediaDefinition.fromMap(v as Map<String, dynamic>)),
        interfaces: ((m['interfaces'] as List?) ?? [])
            .map((v) => InterfaceDefinition.fromMap(v as Map<String, dynamic>)),
        compatibility: ((m['compatibility'] as List?) ?? []).map(
            (v) => CompatibilityDefinition.fromMap(v as Map<String, dynamic>)),
      );
}
