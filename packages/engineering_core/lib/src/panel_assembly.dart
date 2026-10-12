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

enum PanelZoneType {
  mainIncoming,
  busBar,
  peNBar,
  terminals,
  plcIo,
  controlPower,
  cableDuct,
  spare,
  noMount,
  custom,
}

enum PanelDuctOrientation { horizontal, vertical }

class PanelEnclosureGeometry {
  const PanelEnclosureGeometry({
    required this.widthMm,
    required this.heightMm,
    required this.depthMm,
    this.usableWidthMm,
    this.usableHeightMm,
  });

  final double widthMm;
  final double heightMm;
  final double depthMm;
  final double? usableWidthMm;
  final double? usableHeightMm;
}

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
    this.enclosureGeometry,
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
  final PanelEnclosureGeometry? enclosureGeometry;
  final int revision;
  final List<PanelMountingSection> sections;

  int get totalDinRailRows =>
      sections.fold(0, (sum, section) => sum + section.rails.length);
}

class PanelMountingSection {
  const PanelMountingSection({
    required this.id,
    required this.name,
    this.rails = const [],
    this.terminalRails = const [],
    this.cableDucts = const [],
    this.reservedZones = const [],
  });

  final String id;
  final String name;
  final List<DinRail> rails;
  final List<PanelTerminalRail> terminalRails;
  final List<PanelCableDuct> cableDucts;
  final List<PanelReservedZone> reservedZones;
}

class DinRail {
  const DinRail({
    required this.id,
    required this.capacityModules,
    this.rowIndex = 0,
    this.railLengthMm,
    this.modulePitchMm,
    this.placements = const [],
  });

  final String id;
  final int rowIndex;
  final int capacityModules;
  final double? railLengthMm;
  final double? modulePitchMm;
  final List<PanelModulePlacement> placements;

  int get occupiedModules => placements.fold(
        0,
        (sum, placement) => sum + placement.moduleWidthUnits,
      );

  int get remainingModules => capacityModules - occupiedModules;

  double? get occupiedPhysicalWidthMm {
    if (placements.isEmpty) return 0;
    final widths = placements.map((placement) {
      if (placement.physicalWidthMm != null) {
        return placement.physicalWidthMm!;
      }
      if (modulePitchMm != null) {
        return placement.moduleWidthUnits * modulePitchMm!;
      }
      return null;
    }).toList();

    if (widths.any((width) => width == null)) return null;
    return widths.fold<double>(0, (sum, width) => sum + width!);
  }

  bool get exceedsModuleCapacity => occupiedModules > capacityModules;

  bool get exceedsPhysicalLength {
    final occupied = occupiedPhysicalWidthMm;
    return railLengthMm != null && occupied != null && occupied > railLengthMm!;
  }
}

class PanelModulePlacement {
  const PanelModulePlacement({
    required this.componentDefinitionId,
    required this.position,
    required this.moduleWidthUnits,
    this.physicalWidthMm,
  });

  final String componentDefinitionId;
  final int position;
  final int moduleWidthUnits;
  final double? physicalWidthMm;
}

class PanelTerminalRail {
  const PanelTerminalRail({
    required this.id,
    required this.terminalCapacity,
    this.lengthMm,
  });

  final String id;
  final int terminalCapacity;
  final double? lengthMm;
}

class PanelCableDuct {
  const PanelCableDuct({
    required this.id,
    required this.orientation,
    required this.widthMm,
    required this.lengthMm,
  });

  final String id;
  final PanelDuctOrientation orientation;
  final double widthMm;
  final double lengthMm;
}

class PanelReservedZone {
  const PanelReservedZone({
    required this.id,
    required this.type,
    required this.widthMm,
    required this.heightMm,
    this.label,
  });

  final String id;
  final PanelZoneType type;
  final double widthMm;
  final double heightMm;
  final String? label;
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
