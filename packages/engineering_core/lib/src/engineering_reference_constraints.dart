import 'engineering_reference_catalog.dart';
import 'engineering_topology.dart';

enum InstallationSurface { wall, ceiling, floor, rack, enclosure, pole, freeStanding }

enum MountingMethod { surface, flush, suspended, bracket, dinRail, rackUnit, insideEnclosure, poleClamp }

enum EnvironmentClass { indoor, outdoor, damp, dusty, corrosive, conditioned, unconditioned }

enum TopologyParticipation { endpoint, source, sink, branch, hub, controller, isolator, passive }

class MountingConstraintProfile {
  MountingConstraintProfile({
    required Iterable<InstallationSurface> allowedSurfaces,
    required Iterable<MountingMethod> allowedMethods,
    this.enclosureRequired = false,
    this.minimumClearanceMm,
  })  : allowedSurfaces = List.unmodifiable(allowedSurfaces),
        allowedMethods = List.unmodifiable(allowedMethods);

  final List<InstallationSurface> allowedSurfaces;
  final List<MountingMethod> allowedMethods;
  final bool enclosureRequired;
  final double? minimumClearanceMm;

  List<String> validate() => [
        if (allowedSurfaces.isEmpty) 'Declare at least one installation surface.',
        if (allowedMethods.isEmpty) 'Declare at least one mounting method.',
        if (allowedSurfaces.toSet().length != allowedSurfaces.length)
          'Installation surfaces must be unique.',
        if (allowedMethods.toSet().length != allowedMethods.length)
          'Mounting methods must be unique.',
        if (minimumClearanceMm != null &&
            (!minimumClearanceMm!.isFinite || minimumClearanceMm! < 0))
          'Minimum clearance must be finite and nonnegative.',
      ];

  Map<String, Object?> toMap() => {
        'allowedSurfaces': allowedSurfaces.map((v) => v.name).toList(),
        'allowedMethods': allowedMethods.map((v) => v.name).toList(),
        'enclosureRequired': enclosureRequired,
        'minimumClearanceMm': minimumClearanceMm,
      };

  factory MountingConstraintProfile.fromMap(Map<String, dynamic> m) =>
      MountingConstraintProfile(
        allowedSurfaces: (m['allowedSurfaces'] as List)
            .map((v) => InstallationSurface.values.byName(v as String)),
        allowedMethods: (m['allowedMethods'] as List)
            .map((v) => MountingMethod.values.byName(v as String)),
        enclosureRequired: m['enclosureRequired'] as bool? ?? false,
        minimumClearanceMm: (m['minimumClearanceMm'] as num?)?.toDouble(),
      );
}

class EnvironmentConstraintProfile {
  EnvironmentConstraintProfile({
    required Iterable<EnvironmentClass> allowedClasses,
    this.minimumIpRating,
    this.minimumTemperatureC,
    this.maximumTemperatureC,
  }) : allowedClasses = List.unmodifiable(allowedClasses);

  final List<EnvironmentClass> allowedClasses;
  final String? minimumIpRating;
  final double? minimumTemperatureC;
  final double? maximumTemperatureC;

  List<String> validate() => [
        if (allowedClasses.isEmpty) 'Declare at least one environment class.',
        if (allowedClasses.toSet().length != allowedClasses.length)
          'Environment classes must be unique.',
        if ((minimumTemperatureC == null) != (maximumTemperatureC == null))
          'Declare both minimum and maximum temperatures or neither.',
        if (minimumTemperatureC != null &&
            (!minimumTemperatureC!.isFinite ||
                !maximumTemperatureC!.isFinite ||
                maximumTemperatureC! < minimumTemperatureC!))
          'Environment temperature range is invalid.',
        if (minimumIpRating != null && minimumIpRating!.trim().isEmpty)
          'IP rating cannot be blank.',
      ];

  Map<String, Object?> toMap() => {
        'allowedClasses': allowedClasses.map((v) => v.name).toList(),
        'minimumIpRating': minimumIpRating,
        'minimumTemperatureC': minimumTemperatureC,
        'maximumTemperatureC': maximumTemperatureC,
      };

  factory EnvironmentConstraintProfile.fromMap(Map<String, dynamic> m) =>
      EnvironmentConstraintProfile(
        allowedClasses: (m['allowedClasses'] as List)
            .map((v) => EnvironmentClass.values.byName(v as String)),
        minimumIpRating: m['minimumIpRating'] as String?,
        minimumTemperatureC: (m['minimumTemperatureC'] as num?)?.toDouble(),
        maximumTemperatureC: (m['maximumTemperatureC'] as num?)?.toDouble(),
      );
}

class TopologyConstraintProfile {
  TopologyConstraintProfile({
    required Iterable<TopologyShape> allowedShapes,
    required Iterable<TopologyParticipation> allowedRoles,
    this.branchingAllowed = true,
    this.closedLoopRequired = false,
    this.nodeOrderMatters = false,
    this.maximumDegree,
  })  : allowedShapes = List.unmodifiable(allowedShapes),
        allowedRoles = List.unmodifiable(allowedRoles);

  final List<TopologyShape> allowedShapes;
  final List<TopologyParticipation> allowedRoles;
  final bool branchingAllowed;
  final bool closedLoopRequired;
  final bool nodeOrderMatters;
  final int? maximumDegree;

  List<String> validate() => [
        if (allowedShapes.isEmpty) 'Declare at least one topology shape.',
        if (allowedRoles.isEmpty) 'Declare at least one topology role.',
        if (allowedShapes.toSet().length != allowedShapes.length)
          'Topology shapes must be unique.',
        if (allowedRoles.toSet().length != allowedRoles.length)
          'Topology roles must be unique.',
        if (closedLoopRequired && !allowedShapes.contains(TopologyShape.loop))
          'A closed-loop constraint requires loop topology support.',
        if (maximumDegree != null && maximumDegree! <= 0)
          'Maximum topology degree must be positive.',
      ];

  Map<String, Object?> toMap() => {
        'allowedShapes': allowedShapes.map((v) => v.name).toList(),
        'allowedRoles': allowedRoles.map((v) => v.name).toList(),
        'branchingAllowed': branchingAllowed,
        'closedLoopRequired': closedLoopRequired,
        'nodeOrderMatters': nodeOrderMatters,
        'maximumDegree': maximumDegree,
      };

  factory TopologyConstraintProfile.fromMap(Map<String, dynamic> m) =>
      TopologyConstraintProfile(
        allowedShapes: (m['allowedShapes'] as List)
            .map((v) => TopologyShape.values.byName(v as String)),
        allowedRoles: (m['allowedRoles'] as List)
            .map((v) => TopologyParticipation.values.byName(v as String)),
        branchingAllowed: m['branchingAllowed'] as bool? ?? true,
        closedLoopRequired: m['closedLoopRequired'] as bool? ?? false,
        nodeOrderMatters: m['nodeOrderMatters'] as bool? ?? false,
        maximumDegree: m['maximumDegree'] as int?,
      );
}

class EngineeringProfileConstraints {
  const EngineeringProfileConstraints({
    required this.discipline,
    required this.mounting,
    required this.environment,
    required this.topology,
  });

  final ReferenceDiscipline discipline;
  final MountingConstraintProfile mounting;
  final EnvironmentConstraintProfile environment;
  final TopologyConstraintProfile topology;

  List<String> validate() => [
        ...mounting.validate(),
        ...environment.validate(),
        ...topology.validate(),
      ];

  Map<String, Object?> toMap() => {
        'discipline': discipline.name,
        'mounting': mounting.toMap(),
        'environment': environment.toMap(),
        'topology': topology.toMap(),
      };

  factory EngineeringProfileConstraints.fromMap(Map<String, dynamic> m) =>
      EngineeringProfileConstraints(
        discipline: ReferenceDiscipline.values.byName(m['discipline'] as String),
        mounting: MountingConstraintProfile.fromMap(
          m['mounting'] as Map<String, dynamic>,
        ),
        environment: EnvironmentConstraintProfile.fromMap(
          m['environment'] as Map<String, dynamic>,
        ),
        topology: TopologyConstraintProfile.fromMap(
          m['topology'] as Map<String, dynamic>,
        ),
      );
}

enum ProfileRevisionChangeKind {
  discipline,
  engineeringClass,
  capabilities,
  ports,
  interfaces,
  characteristics,
  mounting,
  environment,
  topology,
  lifecycle,
}

class ProfileRevisionChange {
  const ProfileRevisionChange({
    required this.kind,
    required this.summary,
    required this.connectionRelevant,
    required this.placementRelevant,
  });

  final ProfileRevisionChangeKind kind;
  final String summary;
  final bool connectionRelevant;
  final bool placementRelevant;
}

class ProfileRevisionImpact {
  ProfileRevisionImpact({
    required Iterable<ProfileRevisionChange> changes,
  }) : changes = List.unmodifiable(changes);

  final List<ProfileRevisionChange> changes;
  bool get changed => changes.isNotEmpty;
  bool get affectsConnections => changes.any((c) => c.connectionRelevant);
  bool get affectsPlacement => changes.any((c) => c.placementRelevant);
}

ProfileRevisionImpact compareEngineeringProfileRevisions({
  required ComponentEngineeringProfile previous,
  required ComponentEngineeringProfile candidate,
  EngineeringProfileConstraints? previousConstraints,
  EngineeringProfileConstraints? candidateConstraints,
}) {
  final changes = <ProfileRevisionChange>[];
  void add(
    ProfileRevisionChangeKind kind,
    String summary, {
    bool connection = false,
    bool placement = false,
  }) =>
      changes.add(
        ProfileRevisionChange(
          kind: kind,
          summary: summary,
          connectionRelevant: connection,
          placementRelevant: placement,
        ),
      );

  if (previous.discipline != candidate.discipline) {
    add(ProfileRevisionChangeKind.discipline, 'Discipline changed.',
        connection: true, placement: true);
  }
  if (previous.engineeringClass != candidate.engineeringClass) {
    add(ProfileRevisionChangeKind.engineeringClass, 'Engineering class changed.',
        connection: true, placement: true);
  }
  if (!_sameNames(previous.capabilities, candidate.capabilities)) {
    add(ProfileRevisionChangeKind.capabilities, 'Capability set changed.',
        connection: true);
  }
  if (!_sameMaps(
      previous.portTemplates.map((p) => p.toMap()),
      candidate.portTemplates.map((p) => p.toMap()))) {
    add(ProfileRevisionChangeKind.ports, 'Port templates changed.',
        connection: true);
  }
  if (!_sameStringMap(previous.portInterfaceCodes, candidate.portInterfaceCodes)) {
    add(ProfileRevisionChangeKind.interfaces, 'Port interface bindings changed.',
        connection: true);
  }
  if (!_mapEquals(previous.characteristics.toMap(), candidate.characteristics.toMap())) {
    add(ProfileRevisionChangeKind.characteristics,
        'Discipline engineering characteristics changed.');
  }
  if (previous.deprecated != candidate.deprecated) {
    add(ProfileRevisionChangeKind.lifecycle, 'Profile lifecycle state changed.',
        placement: true);
  }
  if (previousConstraints != null || candidateConstraints != null) {
    if (!_mapEquals(previousConstraints?.mounting.toMap(),
        candidateConstraints?.mounting.toMap())) {
      add(ProfileRevisionChangeKind.mounting, 'Mounting constraints changed.',
          placement: true);
    }
    if (!_mapEquals(previousConstraints?.environment.toMap(),
        candidateConstraints?.environment.toMap())) {
      add(ProfileRevisionChangeKind.environment,
          'Environment constraints changed.', placement: true);
    }
    if (!_mapEquals(previousConstraints?.topology.toMap(),
        candidateConstraints?.topology.toMap())) {
      add(ProfileRevisionChangeKind.topology, 'Topology constraints changed.',
          connection: true);
    }
  }
  return ProfileRevisionImpact(changes: changes);
}

bool _sameNames(Iterable<Enum> a, Iterable<Enum> b) =>
    _sameStrings(a.map((v) => v.name), b.map((v) => v.name));

bool _sameStrings(Iterable<String> a, Iterable<String> b) {
  final left = a.toList()..sort();
  final right = b.toList()..sort();
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _sameMaps(Iterable<Map<String, Object?>> a, Iterable<Map<String, Object?>> b) {
  final left = a.toList();
  final right = b.toList();
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (!_mapEquals(left[i], right[i])) return false;
  }
  return true;
}

bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || !_valueEquals(a[key], b[key])) return false;
  }
  return true;
}

bool _valueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return _mapEquals(a.cast<String, Object?>(), b.cast<String, Object?>());
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_valueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}
