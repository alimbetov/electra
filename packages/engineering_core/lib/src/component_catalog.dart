import 'core_enums.dart';

enum ComponentDefinitionSource { system, user, project, imported }

enum SupplySystem {
  singlePhaseAc,
  threePhaseAc,
  directCurrent,
  controlVoltage,
  custom,
}

enum StartingMethod {
  none,
  directOnLine,
  starDelta,
  softStarter,
  vfd,
  custom,
}

enum PhaseConfiguration {
  l1N,
  l2N,
  l3N,
  l1L2,
  l2L3,
  l3L1,
  l1L2L3,
  l1L2L3N,
  dcPosNeg,
  custom,
}

enum RouteSeparationClass {
  general,
  power,
  highPower,
  control,
  data,
  instrumentation,
  safety,
  emcSensitive,
}

class RoutingProfile {
  const RoutingProfile({
    this.allowedMethods = const [],
    this.preferredMethods = const [],
    this.forbiddenMethods = const [],
    this.separationClass = RouteSeparationClass.general,
    this.minimumBendRadiusMm,
    this.maximumRunLengthMm,
    this.requiresDedicatedConduit = false,
    this.requiresShielding = false,
    this.requiresMechanicalProtection = false,
  });

  final List<String> allowedMethods;
  final List<String> preferredMethods;
  final List<String> forbiddenMethods;
  final RouteSeparationClass separationClass;
  final double? minimumBendRadiusMm;
  final double? maximumRunLengthMm;
  final bool requiresDedicatedConduit;
  final bool requiresShielding;
  final bool requiresMechanicalProtection;
}

class ComponentPortDefinition {
  const ComponentPortDefinition({
    required this.code,
    required this.type,
    required this.discipline,
    this.required = false,
    this.routingProfile,
  });

  final String code;
  final String type;
  final Discipline discipline;
  final bool required;
  final RoutingProfile? routingProfile;
}

class ElectricalLoadProfile {
  const ElectricalLoadProfile({
    required this.nominalVoltageV,
    required this.phases,
    this.supplySystem = SupplySystem.singlePhaseAc,
    this.phaseConfiguration,
    this.frequencyHz,
    this.ratedPowerW,
    this.ratedCurrentA,
    this.powerFactor,
    this.efficiency,
    this.startingMethod = StartingMethod.none,
    this.startingCurrentFactor,
    this.loadType,
    this.dedicatedCircuitRecommended = false,
    this.requiresNeutral = false,
    this.requiresProtectiveEarth = true,
  });

  final double? ratedPowerW;
  final double? ratedCurrentA;
  final double nominalVoltageV;
  final int phases;
  final SupplySystem supplySystem;
  final PhaseConfiguration? phaseConfiguration;
  final double? frequencyHz;
  final double? powerFactor;
  final double? efficiency;
  final StartingMethod startingMethod;
  final double? startingCurrentFactor;
  final String? loadType;
  final bool dedicatedCircuitRecommended;
  final bool requiresNeutral;
  final bool requiresProtectiveEarth;
}

class ComponentDefinition {
  const ComponentDefinition({
    required this.id,
    required this.code,
    required this.displayName,
    required this.category,
    required this.primaryDiscipline,
    required this.source,
    required this.version,
    this.compatibleDisciplines = const [],
    this.ports = const [],
    this.electricalLoadProfile,
    this.routingProfile,
    this.metadata = const {},
  });

  final String id;
  final String code;
  final String displayName;
  final String category;
  final Discipline primaryDiscipline;
  final List<Discipline> compatibleDisciplines;
  final ComponentDefinitionSource source;
  final int version;
  final List<ComponentPortDefinition> ports;
  final ElectricalLoadProfile? electricalLoadProfile;
  final RoutingProfile? routingProfile;
  final Map<String, Object?> metadata;
}

class LayerComponentLibrary {
  const LayerComponentLibrary({
    required this.discipline,
    required this.definitions,
  });

  final Discipline discipline;
  final List<ComponentDefinition> definitions;

  Iterable<ComponentDefinition> get systemDefinitions =>
      definitions.where((item) => item.source == ComponentDefinitionSource.system);

  Iterable<ComponentDefinition> get customDefinitions => definitions.where(
        (item) => item.source == ComponentDefinitionSource.user ||
            item.source == ComponentDefinitionSource.project,
      );
}
