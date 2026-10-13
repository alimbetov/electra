import 'engineering_topology.dart';

enum InstallationSurface {
  wall,
  ceiling,
  floor,
  rack,
  enclosure,
  pole,
  freeStanding,
}

enum MountingMethod {
  surface,
  flush,
  suspended,
  bracket,
  dinRail,
  rackUnit,
  insideEnclosure,
  poleClamp,
}

enum EnvironmentExposure { indoor, protectedOutdoor, exposedOutdoor }

enum EnvironmentMoisture { dry, damp, wet }

enum EnvironmentContamination { normal, dusty, corrosive }

enum EnvironmentClimate { conditioned, unconditioned }

enum TopologyParticipation {
  endpoint,
  source,
  sink,
  branch,
  hub,
  controller,
  isolator,
  passive,
}

class IpProtectionClass {
  const IpProtectionClass._(this.value);

  final String value;

  static final RegExp _pattern = RegExp(r'^IP[0-6X][0-9X](?:[A-Z])?$');

  factory IpProtectionClass.parse(String raw) {
    final value = raw.trim().toUpperCase();
    if (!_pattern.hasMatch(value)) {
      throw FormatException('Invalid IP protection class: $raw');
    }
    return IpProtectionClass._(value);
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      other is IpProtectionClass && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class MountingOption {
  const MountingOption({required this.surface, required this.method});

  final InstallationSurface surface;
  final MountingMethod method;

  String get identity => '${surface.name}:${method.name}';

  Map<String, Object?> toMap() => {
        'surface': surface.name,
        'method': method.name,
      };

  factory MountingOption.fromMap(Map<String, dynamic> map) => MountingOption(
        surface: InstallationSurface.values.byName(map['surface'] as String),
        method: MountingMethod.values.byName(map['method'] as String),
      );
}

class MountingConstraintProfile {
  MountingConstraintProfile({
    required Iterable<MountingOption> options,
    this.enclosureRequired = false,
    this.minimumClearanceMm,
  }) : options = List.unmodifiable(options);

  final List<MountingOption> options;
  final bool enclosureRequired;
  final double? minimumClearanceMm;

  Set<InstallationSurface> get allowedSurfaces =>
      options.map((option) => option.surface).toSet();

  Set<MountingMethod> get allowedMethods =>
      options.map((option) => option.method).toSet();

  bool allows(InstallationSurface surface, MountingMethod method) =>
      options.any(
        (option) => option.surface == surface && option.method == method,
      );

  List<String> validate() => [
        if (options.isEmpty) 'Declare at least one mounting option.',
        if (options.map((option) => option.identity).toSet().length !=
            options.length)
          'Mounting options must be unique.',
        if (minimumClearanceMm != null &&
            (!minimumClearanceMm!.isFinite || minimumClearanceMm! < 0))
          'Minimum clearance must be finite and nonnegative.',
      ];

  Map<String, Object?> toMap() => {
        'options': options.map((option) => option.toMap()).toList(),
        'enclosureRequired': enclosureRequired,
        'minimumClearanceMm': minimumClearanceMm,
      };

  factory MountingConstraintProfile.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'] as List?;
    if (rawOptions != null) {
      return MountingConstraintProfile(
        options: rawOptions.map(
          (value) => MountingOption.fromMap(value as Map<String, dynamic>),
        ),
        enclosureRequired: map['enclosureRequired'] as bool? ?? false,
        minimumClearanceMm: (map['minimumClearanceMm'] as num?)?.toDouble(),
      );
    }

    // Transitional reader for the pre-P1 branch contract. It is intentionally
    // never emitted again because independent lists lose pair compatibility.
    final surfaces = (map['allowedSurfaces'] as List? ?? const [])
        .map((value) => InstallationSurface.values.byName(value as String));
    final methods = (map['allowedMethods'] as List? ?? const [])
        .map((value) => MountingMethod.values.byName(value as String));
    return MountingConstraintProfile(
      options: [
        for (final surface in surfaces)
          for (final method in methods)
            MountingOption(surface: surface, method: method),
      ],
      enclosureRequired: map['enclosureRequired'] as bool? ?? false,
      minimumClearanceMm: (map['minimumClearanceMm'] as num?)?.toDouble(),
    );
  }
}

class EnvironmentConstraintProfile {
  EnvironmentConstraintProfile({
    required Iterable<EnvironmentExposure> allowedExposure,
    Iterable<EnvironmentMoisture> allowedMoisture = const [],
    Iterable<EnvironmentContamination> allowedContamination = const [],
    Iterable<EnvironmentClimate> allowedClimate = const [],
    this.minimumIpRating,
    this.minimumTemperatureC,
    this.maximumTemperatureC,
  })  : allowedExposure = List.unmodifiable(allowedExposure),
        allowedMoisture = List.unmodifiable(allowedMoisture),
        allowedContamination = List.unmodifiable(allowedContamination),
        allowedClimate = List.unmodifiable(allowedClimate);

  final List<EnvironmentExposure> allowedExposure;
  final List<EnvironmentMoisture> allowedMoisture;
  final List<EnvironmentContamination> allowedContamination;
  final List<EnvironmentClimate> allowedClimate;
  final IpProtectionClass? minimumIpRating;
  final double? minimumTemperatureC;
  final double? maximumTemperatureC;

  List<String> validate() => [
        if (allowedExposure.isEmpty)
          'Declare at least one environment exposure class.',
        if (allowedExposure.toSet().length != allowedExposure.length)
          'Environment exposure classes must be unique.',
        if (allowedMoisture.toSet().length != allowedMoisture.length)
          'Environment moisture classes must be unique.',
        if (allowedContamination.toSet().length != allowedContamination.length)
          'Environment contamination classes must be unique.',
        if (allowedClimate.toSet().length != allowedClimate.length)
          'Environment climate classes must be unique.',
        if ((minimumTemperatureC == null) != (maximumTemperatureC == null))
          'Declare both minimum and maximum temperatures or neither.',
        if (minimumTemperatureC != null &&
            (!minimumTemperatureC!.isFinite ||
                !maximumTemperatureC!.isFinite ||
                maximumTemperatureC! < minimumTemperatureC!))
          'Environment temperature range is invalid.',
      ];

  Map<String, Object?> toMap() => {
        'allowedExposure': allowedExposure.map((value) => value.name).toList(),
        if (allowedMoisture.isNotEmpty)
          'allowedMoisture':
              allowedMoisture.map((value) => value.name).toList(),
        if (allowedContamination.isNotEmpty)
          'allowedContamination':
              allowedContamination.map((value) => value.name).toList(),
        if (allowedClimate.isNotEmpty)
          'allowedClimate': allowedClimate.map((value) => value.name).toList(),
        'minimumIpRating': minimumIpRating?.value,
        'minimumTemperatureC': minimumTemperatureC,
        'maximumTemperatureC': maximumTemperatureC,
      };

  factory EnvironmentConstraintProfile.fromMap(Map<String, dynamic> map) {
    List<T> values<T extends Enum>(
      String key,
      List<T> all,
    ) =>
        (map[key] as List? ?? const [])
            .map((value) => all.byName(value as String))
            .toList();

    if (map.containsKey('allowedExposure')) {
      return EnvironmentConstraintProfile(
        allowedExposure: values('allowedExposure', EnvironmentExposure.values),
        allowedMoisture: values('allowedMoisture', EnvironmentMoisture.values),
        allowedContamination:
            values('allowedContamination', EnvironmentContamination.values),
        allowedClimate: values('allowedClimate', EnvironmentClimate.values),
        minimumIpRating: map['minimumIpRating'] == null
            ? null
            : IpProtectionClass.parse(map['minimumIpRating'] as String),
        minimumTemperatureC: (map['minimumTemperatureC'] as num?)?.toDouble(),
        maximumTemperatureC: (map['maximumTemperatureC'] as num?)?.toDouble(),
      );
    }

    // Transitional reader for the pre-P1 flat EnvironmentClass representation.
    final legacy = (map['allowedClasses'] as List? ?? const [])
        .map((value) => value as String)
        .toSet();
    return EnvironmentConstraintProfile(
      allowedExposure: [
        if (legacy.contains('indoor')) EnvironmentExposure.indoor,
        if (legacy.contains('outdoor')) EnvironmentExposure.exposedOutdoor,
      ],
      allowedMoisture: [
        if (legacy.contains('damp')) EnvironmentMoisture.damp,
      ],
      allowedContamination: [
        if (legacy.contains('dusty')) EnvironmentContamination.dusty,
        if (legacy.contains('corrosive')) EnvironmentContamination.corrosive,
      ],
      allowedClimate: [
        if (legacy.contains('conditioned')) EnvironmentClimate.conditioned,
        if (legacy.contains('unconditioned')) EnvironmentClimate.unconditioned,
      ],
      minimumIpRating: map['minimumIpRating'] == null
          ? null
          : IpProtectionClass.parse(map['minimumIpRating'] as String),
      minimumTemperatureC: (map['minimumTemperatureC'] as num?)?.toDouble(),
      maximumTemperatureC: (map['maximumTemperatureC'] as num?)?.toDouble(),
    );
  }
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
        'allowedShapes': allowedShapes.map((value) => value.name).toList(),
        'allowedRoles': allowedRoles.map((value) => value.name).toList(),
        'branchingAllowed': branchingAllowed,
        'closedLoopRequired': closedLoopRequired,
        'nodeOrderMatters': nodeOrderMatters,
        'maximumDegree': maximumDegree,
      };

  factory TopologyConstraintProfile.fromMap(Map<String, dynamic> map) =>
      TopologyConstraintProfile(
        allowedShapes: (map['allowedShapes'] as List)
            .map((value) => TopologyShape.values.byName(value as String)),
        allowedRoles: (map['allowedRoles'] as List).map(
          (value) => TopologyParticipation.values.byName(value as String),
        ),
        branchingAllowed: map['branchingAllowed'] as bool? ?? true,
        closedLoopRequired: map['closedLoopRequired'] as bool? ?? false,
        nodeOrderMatters: map['nodeOrderMatters'] as bool? ?? false,
        maximumDegree: map['maximumDegree'] as int?,
      );
}

class EngineeringProfileConstraints {
  const EngineeringProfileConstraints({
    required this.mounting,
    required this.environment,
    required this.topology,
  });

  final MountingConstraintProfile mounting;
  final EnvironmentConstraintProfile environment;
  final TopologyConstraintProfile topology;

  List<String> validate() => [
        ...mounting.validate(),
        ...environment.validate(),
        ...topology.validate(),
      ];

  Map<String, Object?> toMap() => {
        'mounting': mounting.toMap(),
        'environment': environment.toMap(),
        'topology': topology.toMap(),
      };

  factory EngineeringProfileConstraints.fromMap(Map<String, dynamic> map) =>
      EngineeringProfileConstraints(
        mounting: MountingConstraintProfile.fromMap(
          map['mounting'] as Map<String, dynamic>,
        ),
        environment: EnvironmentConstraintProfile.fromMap(
          map['environment'] as Map<String, dynamic>,
        ),
        topology: TopologyConstraintProfile.fromMap(
          map['topology'] as Map<String, dynamic>,
        ),
      );
}
