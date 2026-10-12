enum PanelType {
  distributionBoard,
  floorDistributionBoard,
  automationPanel,
  motorControlPanel,
  plcPanel,
  mixedControlPowerPanel,
  custom,
}

enum PanelMountingType { dinRail, backplate, busbar, terminalRail, custom }

class PanelAssembly {
  const PanelAssembly({
    required this.id,
    required this.code,
    required this.displayName,
    required this.panelType,
    required this.projectId,
    this.floorId,
    this.roomId,
    this.systemVoltageV,
    this.ratedCurrentA,
    this.revision = 1,
    this.sections = const [],
  });

  final String id;
  final String code;
  final String displayName;
  final PanelType panelType;
  final String projectId;
  final String? floorId;
  final String? roomId;
  final double? systemVoltageV;
  final double? ratedCurrentA;
  final int revision;
  final List<PanelMountingSection> sections;
}

class PanelMountingSection {
  const PanelMountingSection({
    required this.id,
    required this.name,
    this.rails = const [],
  });

  final String id;
  final String name;
  final List<DinRail> rails;
}

class DinRail {
  const DinRail({
    required this.id,
    required this.capacityModules,
    this.placements = const [],
  });

  final String id;
  final int capacityModules;
  final List<PanelModulePlacement> placements;

  int get occupiedModules => placements.fold(
        0,
        (sum, placement) => sum + placement.moduleWidthUnits,
      );

  int get remainingModules => capacityModules - occupiedModules;
}

class PanelModulePlacement {
  const PanelModulePlacement({
    required this.componentDefinitionId,
    required this.position,
    required this.moduleWidthUnits,
  });

  final String componentDefinitionId;
  final int position;
  final int moduleWidthUnits;
}

class PanelCircuitAssignment {
  const PanelCircuitAssignment({
    required this.circuitId,
    required this.panelId,
    this.phase,
    this.protectionComponentDefinitionId,
    this.terminalBlockId,
  });

  final String circuitId;
  final String panelId;
  final String? phase;
  final String? protectionComponentDefinitionId;
  final String? terminalBlockId;
}

class TerminalBlockDefinition {
  const TerminalBlockDefinition({
    required this.id,
    required this.code,
    required this.terminalCount,
  });

  final String id;
  final String code;
  final int terminalCount;
}

class AutomationIoAssignment {
  const AutomationIoAssignment({
    required this.moduleComponentId,
    required this.channelCode,
    required this.fieldObjectId,
    required this.signalType,
  });

  final String moduleComponentId;
  final String channelCode;
  final String fieldObjectId;
  final String signalType;
}
