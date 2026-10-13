/// Extensible reference identity; families are catalog data rather than an enum.
class EngineeringSystemFamily {
  const EngineeringSystemFamily(
      {required this.id,
      required this.code,
      required this.name,
      required this.version,
      required this.source,
      required this.routingClass});
  final String id, code, name, version, source, routingClass;
  List<String> validate() => [
        if ([id, code, name, version, source, routingClass]
            .any((s) => s.trim().isEmpty))
          'Family identity, version, source and routing class are required.'
      ];
  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'version': version,
        'source': source,
        'routingClass': routingClass
      };
  factory EngineeringSystemFamily.fromMap(Map<String, dynamic> m) =>
      EngineeringSystemFamily(
          id: m['id'] as String,
          code: m['code'] as String,
          name: m['name'] as String,
          version: m['version'] as String,
          source: m['source'] as String,
          routingClass: m['routingClass'] as String);
}

class EngineeringProfileReference {
  const EngineeringProfileReference({required this.id, required this.version});
  final String id, version;
  bool get valid => id.trim().isNotEmpty && version.trim().isNotEmpty;
  Map<String, Object?> toMap() => {'id': id, 'version': version};
  factory EngineeringProfileReference.fromMap(Map<String, dynamic> m) =>
      EngineeringProfileReference(
          id: m['id'] as String, version: m['version'] as String);
}

/// A project network instance. Profile references do not imply executable rules.
class EngineeringSystem {
  const EngineeringSystem(
      {required this.id,
      required this.projectId,
      required this.code,
      required this.name,
      required this.familyId,
      required this.familyVersion,
      this.normativeProfile,
      this.topologyProfile});
  final String id, projectId, code, name, familyId, familyVersion;
  final EngineeringProfileReference? normativeProfile, topologyProfile;
  List<String> validate() => [
        if ([id, projectId, code, name, familyId, familyVersion]
            .any((s) => s.trim().isEmpty))
          'System identity, project, code, name and pinned family edition are required.',
        if (normativeProfile != null && !normativeProfile!.valid)
          'Normative profile needs identity and version.',
        if (topologyProfile != null && !topologyProfile!.valid)
          'Topology profile needs identity and version.',
      ];
  Map<String, Object?> toMap() => {
        'id': id,
        'projectId': projectId,
        'code': code,
        'name': name,
        'familyId': familyId,
        'familyVersion': familyVersion,
        'normativeProfile': normativeProfile?.toMap(),
        'topologyProfile': topologyProfile?.toMap()
      };
  factory EngineeringSystem.fromMap(Map<String, dynamic> m) =>
      EngineeringSystem(
          id: m['id'] as String,
          projectId: m['projectId'] as String,
          code: m['code'] as String,
          name: m['name'] as String,
          familyId: m['familyId'] as String,
          familyVersion: m['familyVersion'] as String,
          normativeProfile: m['normativeProfile'] == null
              ? null
              : EngineeringProfileReference.fromMap(
                  m['normativeProfile'] as Map<String, dynamic>),
          topologyProfile: m['topologyProfile'] == null
              ? null
              : EngineeringProfileReference.fromMap(
                  m['topologyProfile'] as Map<String, dynamic>));
}

/// Non-owning participation; component IDs remain the existing placement IDs.
class ComponentSystemMembership {
  const ComponentSystemMembership(
      {required this.systemId, required this.componentId, required this.role});
  final String systemId, componentId, role;
  List<String> validate() => [
        if ([systemId, componentId, role].any((s) => s.trim().isEmpty))
          'System, component and participation role are required.'
      ];
}

final bundledEngineeringSystemFamilies =
    List<EngineeringSystemFamily>.unmodifiable([
  for (final entry in const {
    'POWER': 'Electrical power',
    'CCTV': 'CCTV',
    'LAN': 'LAN / structured cabling',
    'WIFI': 'Wi-Fi infrastructure',
    'ACS': 'Access control',
    'FIRE': 'Fire alarm',
    'INTRUSION': 'Intrusion / security alarm',
    'INTERCOM': 'Intercom',
    'VOICE': 'Public address / voice alarm',
    'TELEPHONY': 'Telephony',
    'RF': 'TV / RF',
    'BMS': 'Building automation',
    'BUILDING_AUTOMATION': 'Building automation / control',
    'INDUSTRIAL_AUTOMATION': 'Industrial automation',
    'IOT': 'IoT / sensor networks',
    'CUSTOM': 'Custom engineering system'
  }.entries)
    EngineeringSystemFamily(
        id: 'electra-family-${entry.key.toLowerCase()}-v1',
        code: entry.key,
        name: entry.value,
        version: '1',
        source:
            'Electra ELV specification: engineering-system classification, not a normative rule pack',
        routingClass: entry.key),
]);
