import 'engineering_decision.dart';
import 'manufacturer_catalog.dart';

enum ConsumptionLoadType {
  lighting,
  generalSocket,
  dedicatedAppliance,
  heating,
  hvac,
  motor,
  pump,
  evCharger,
  server,
  industrialMachine,
  automation,
  custom,
}

enum PanelProposalStatus {
  proposed,
  userConfirmed,
  manuallyModified,
  validated,
}

class ConsumptionGroup {
  const ConsumptionGroup({
    required this.id,
    required this.name,
    required this.loadType,
    required this.loadIds,
    required this.connectedPowerW,
    required this.voltageV,
    required this.phases,
    this.calculatedDemandPowerW,
    this.requiresDedicatedCircuit = false,
    this.roomIds = const [],
    this.zoneId,
  });

  final String id;
  final String name;
  final ConsumptionLoadType loadType;
  final List<String> loadIds;
  final double connectedPowerW;
  final double? calculatedDemandPowerW;
  final double voltageV;
  final int phases;
  final bool requiresDedicatedCircuit;
  final List<String> roomIds;
  final String? zoneId;
}

class GeneratedCircuitProposal {
  const GeneratedCircuitProposal({
    required this.id,
    required this.name,
    required this.sourceConsumptionGroupIds,
    required this.protectionRequirement,
    this.phase,
    this.cableDefinitionId,
    this.ratedCurrentA,
    this.designCurrentA,
    this.dedicated = false,
    this.selectedManufacturerProductId,
  });

  final String id;
  final String name;
  final List<String> sourceConsumptionGroupIds;
  final FunctionalDeviceRequirement protectionRequirement;
  final String? phase;
  final String? cableDefinitionId;
  final double? ratedCurrentA;
  final double? designCurrentA;
  final bool dedicated;
  final String? selectedManufacturerProductId;
}

class ResidualProtectionGroupProposal {
  const ResidualProtectionGroupProposal({
    required this.id,
    required this.circuitIds,
    required this.protectionRequirement,
    this.selectedManufacturerProductId,
  });

  final String id;
  final List<String> circuitIds;
  final FunctionalDeviceRequirement protectionRequirement;
  final String? selectedManufacturerProductId;
}

class PanelGenerationProposal {
  const PanelGenerationProposal({
    required this.id,
    required this.panelId,
    required this.ruleset,
    this.status = PanelProposalStatus.proposed,
    this.incomingRequirement,
    this.circuits = const [],
    this.residualProtectionGroups = const [],
    this.decisions = const [],
    this.warnings = const [],
    this.estimatedModuleCount,
    this.recommendedSpareModules,
  });

  final String id;
  final String panelId;
  final ElectricalRulesetRef ruleset;
  final PanelProposalStatus status;
  final FunctionalDeviceRequirement? incomingRequirement;
  final List<GeneratedCircuitProposal> circuits;
  final List<ResidualProtectionGroupProposal> residualProtectionGroups;
  final List<EngineeringDecision> decisions;
  final List<String> warnings;
  final int? estimatedModuleCount;
  final int? recommendedSpareModules;
}
