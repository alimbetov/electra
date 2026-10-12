import 'core_enums.dart';

enum ComponentDefinitionSource { system, user, project, imported }

class ComponentPortDefinition {
  const ComponentPortDefinition({
    required this.code,
    required this.type,
    required this.discipline,
    this.required = false,
  });

  final String code;
  final String type;
  final Discipline discipline;
  final bool required;
}

class ElectricalLoadProfile {
  const ElectricalLoadProfile({
    required this.nominalVoltageV,
    required this.phases,
    this.ratedPowerW,
    this.ratedCurrentA,
    this.powerFactor,
    this.efficiency,
    this.startingCurrentFactor,
    this.loadType,
    this.dedicatedCircuitRecommended = false,
  });

  final double? ratedPowerW;
  final double? ratedCurrentA;
  final double nominalVoltageV;
  final int phases;
  final double? powerFactor;
  final double? efficiency;
  final double? startingCurrentFactor;
  final String? loadType;
  final bool dedicatedCircuitRecommended;
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
