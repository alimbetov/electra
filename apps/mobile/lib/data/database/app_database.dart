import 'dart:convert';
import 'package:engineering_core/engineering_core.dart'
    show bundledNormativeDocuments, bundledEngineeringSystemFamilies;
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';
part 'power_database_tables.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get reference => text().withDefault(const Constant(''))();
  TextColumn get measurementSystem => text()();
  IntColumn get defaultStructuralHeightMm => integer()();
  IntColumn get defaultFinishedCeilingHeightMm => integer()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Floors extends Table {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get name => text()();
  TextColumn get code => text().withDefault(const Constant(''))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get defaultStructuralHeightMm => integer().nullable()();
  IntColumn get defaultFinishedCeilingHeightMm => integer().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get floorId => text().references(Floors, #id)();
  TextColumn get name => text()();
  TextColumn get roomType => text()();
  TextColumn get roomCategory => text()();
  IntColumn get widthMm => integer()();
  IntColumn get depthMm => integer()();
  IntColumn get structuralHeightMmOverride => integer().nullable()();
  IntColumn get finishedCeilingHeightMmOverride => integer().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

mixin GeometryAuditColumns on Table {
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get originDeviceId => text()();
}

@DataClassName('SurfacePatchRow')
class SurfacePatches extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get surfaceId => text()();
  IntColumn get originXmm => integer()();
  IntColumn get originYmm => integer()();
  IntColumn get originZmm => integer()();
  RealColumn get uAxisX => real()();
  RealColumn get uAxisY => real()();
  RealColumn get uAxisZ => real()();
  RealColumn get vAxisX => real()();
  RealColumn get vAxisY => real()();
  RealColumn get vAxisZ => real()();
  TextColumn get orientation => text()();
  TextColumn get boundaryJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SurfaceEdgeRow')
class SurfaceEdges extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get patchId => text().references(SurfacePatches, #id)();
  IntColumn get startXmm => integer()();
  IntColumn get startYmm => integer()();
  IntColumn get endXmm => integer()();
  IntColumn get endYmm => integer()();
  TextColumn get kind => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SurfaceAdjacencyRow')
class SurfaceAdjacencies extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  @ReferenceName('outgoingSurfaceAdjacencies')
  TextColumn get fromPatchId => text().references(SurfacePatches, #id)();
  @ReferenceName('outgoingEdgeAdjacencies')
  TextColumn get fromEdgeId => text().references(SurfaceEdges, #id)();
  @ReferenceName('incomingSurfaceAdjacencies')
  TextColumn get toPatchId => text().references(SurfacePatches, #id)();
  @ReferenceName('incomingEdgeAdjacencies')
  TextColumn get toEdgeId => text().references(SurfaceEdges, #id)();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('OpeningRow')
class Openings extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get hostSurfacePatchId => text().references(SurfacePatches, #id)();
  TextColumn get boundaryJson => text()();
  TextColumn get openingType => text()();
  IntColumn get depthMm => integer().nullable()();
  IntColumn get sillHeightMm => integer().nullable()();
  IntColumn get headHeightMm => integer().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SpatialFeatureRow')
class SpatialFeatures extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get hostSurfacePatchId => text().references(SurfacePatches, #id)();
  TextColumn get featureType => text()();
  TextColumn get footprintJson => text()();
  IntColumn get depthMm => integer()();
  IntColumn get elevationMm => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ComponentInstanceRow')
class ComponentInstances extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get definitionId => text()();
  IntColumn get definitionVersion => integer()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get hostSurfacePatchId => text().references(SurfacePatches, #id)();
  IntColumn get localXmm => integer()();
  IntColumn get localYmm => integer()();
  RealColumn get rotationRadians => real().withDefault(const Constant(0))();
  TextColumn get displayNameOverride => text().nullable()();
  TextColumn get metadataOverridesJson =>
      text().withDefault(const Constant('{}'))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ComponentCatalogPreferences extends Table {
  TextColumn get definitionId => text()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  IntColumn get useOrder => integer().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {definitionId};
}

@DataClassName('ConsumptionGroupRow')
class ConsumptionGroups extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get name => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EquipmentElectricalLoadRow')
class EquipmentElectricalLoads extends Table with GeometryAuditColumns {
  TextColumn get componentInstanceId =>
      text().references(ComponentInstances, #id)();
  TextColumn get consumptionGroupId =>
      text().nullable().references(ConsumptionGroups, #id)();
  RealColumn get nominalVoltageV => real()();
  IntColumn get phases => integer()();
  TextColumn get supplySystem => text()();
  TextColumn get phaseConfiguration => text().nullable()();
  RealColumn get frequencyHz => real().nullable()();
  RealColumn get ratedPowerW => real().nullable()();
  RealColumn get ratedCurrentA => real().nullable()();
  RealColumn get powerFactor => real().nullable()();
  RealColumn get efficiency => real().nullable()();
  TextColumn get startingMethod => text()();
  RealColumn get startingCurrentFactor => real().nullable()();
  TextColumn get loadType => text().nullable()();
  BoolColumn get dedicatedCircuitRecommended =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresNeutral =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get requiresProtectiveEarth =>
      boolean().withDefault(const Constant(true))();
  TextColumn get powerBasis => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {componentInstanceId};
}

@DataClassName('ElectricalCircuitRow')
class ElectricalCircuits extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get name => text()();
  RealColumn get nominalVoltageV => real()();
  IntColumn get phases => integer()();
  TextColumn get supplySystem => text()();
  RealColumn get demandFactor => real().withDefault(const Constant(1))();
  TextColumn get sourceGroupId =>
      text().nullable().references(ConsumptionGroups, #id)();
  TextColumn get reviewedInputSignature => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CircuitLoadAssignmentRow')
class CircuitLoadAssignments extends Table {
  TextColumn get componentInstanceId =>
      text().references(EquipmentElectricalLoads, #componentInstanceId)();
  TextColumn get circuitId => text().references(ElectricalCircuits, #id)();
  @override
  Set<Column<Object>> get primaryKey => {componentInstanceId};
}

@DataClassName('PhysicalChannelRow')
class PhysicalChannels extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableRouteRow')
class CableRoutes extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get name => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableRouteNodeRow')
class CableRouteNodes extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get routeId => text().references(CableRoutes, #id)();
  IntColumn get sequence => integer()();
  TextColumn get kind => text()();
  @ReferenceName('primaryRouteNodes')
  TextColumn get patchId => text().references(SurfacePatches, #id)();
  IntColumn get localXmm => integer()();
  IntColumn get localYmm => integer()();
  IntColumn get worldXmm => integer()();
  IntColumn get worldYmm => integer()();
  IntColumn get worldZmm => integer()();
  @ReferenceName('secondaryRouteNodes')
  TextColumn get otherPatchId =>
      text().nullable().references(SurfacePatches, #id)();
  IntColumn get otherLocalXmm => integer().nullable()();
  IntColumn get otherLocalYmm => integer().nullable()();
  TextColumn get adjacencyId =>
      text().nullable().references(SurfaceAdjacencies, #id)();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableRouteSegmentRow')
class CableRouteSegments extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get routeId => text().references(CableRoutes, #id)();
  IntColumn get sequence => integer()();
  @ReferenceName('outgoingRouteSegments')
  TextColumn get fromNodeId => text().references(CableRouteNodes, #id)();
  @ReferenceName('incomingRouteSegments')
  TextColumn get toNodeId => text().references(CableRouteNodes, #id)();
  TextColumn get surfacePatchId => text().references(SurfacePatches, #id)();
  TextColumn get layingMethod => text()();
  TextColumn get physicalChannelId =>
      text().nullable().references(PhysicalChannels, #id)();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableRunRow')
class CableRuns extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get name => text()();
  TextColumn get circuitId => text().references(ElectricalCircuits, #id)();
  TextColumn get routeId => text().references(CableRoutes, #id)();
  RealColumn get reservePercent => real().withDefault(const Constant(0))();
  IntColumn get terminationAllowanceMm =>
      integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RoutingJunctionRow')
class RoutingJunctions extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get patchId => text().references(SurfacePatches, #id)();
  TextColumn get code => text()();
  TextColumn get kind => text()();
  IntColumn get localXmm => integer()();
  IntColumn get localYmm => integer()();
  IntColumn get worldXmm => integer()();
  IntColumn get worldYmm => integer()();
  IntColumn get worldZmm => integer()();
  TextColumn get notes => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('JunctionConnectionRow')
class JunctionConnections extends Table {
  TextColumn get junctionId => text().references(RoutingJunctions, #id)();
  TextColumn get runId => text().references(CableRuns, #id)();
  TextColumn get nodeId => text().references(CableRouteNodes, #id)();
  TextColumn get direction => text()();
  TextColumn get circuitId => text().references(ElectricalCircuits, #id)();
  TextColumn get channelId =>
      text().nullable().references(PhysicalChannels, #id)();
  @override
  Set<Column<Object>> get primaryKey => {junctionId, runId};
}

@DataClassName('FloorRoutingPanelRow')
class FloorRoutingPanels extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get floorId => text().references(Floors, #id)();
  TextColumn get code => text()();
  TextColumn get name => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FloorPanelFeedRow')
class FloorPanelFeeds extends Table {
  TextColumn get panelId => text().references(FloorRoutingPanels, #id)();
  TextColumn get runId => text().references(CableRuns, #id)();
  TextColumn get endpointSignature => text()();
  @override
  Set<Column<Object>> get primaryKey => {panelId, runId};
}

@DataClassName('FloorRoutingHandoffRow')
class FloorRoutingHandoffs extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get floorId => text().references(Floors, #id)();
  TextColumn get name => text()();
  @ReferenceName('outgoingFloorHandoffs')
  TextColumn get fromRunId => text().references(CableRuns, #id)();
  @ReferenceName('incomingFloorHandoffs')
  TextColumn get toRunId => text().references(CableRuns, #id)();
  TextColumn get fromSignature => text()();
  TextColumn get toSignature => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ProjectDerivedResultRow')
class ProjectDerivedResults extends Table with GeometryAuditColumns {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get nodeKey => text()();
  TextColumn get fingerprint => text()();
  TextColumn get inputsJson => text()();
  TextColumn get dependenciesJson => text()();
  TextColumn get resultJson => text()();
  TextColumn get state => text()();
  TextColumn get previousResultJson => text().nullable()();
  TextColumn get changesJson => text().withDefault(const Constant('[]'))();
  TextColumn get manualValue => text().nullable()();
  TextColumn get manualReason => text().nullable()();
  TextColumn get manualReviewedFingerprint => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {projectId, nodeKey};
}

@DataClassName('NormativeDocumentRow')
class NormativeDocuments extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get standardCode => text()();
  TextColumn get version => text()();
  TextColumn get jurisdiction => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {standardCode, version, jurisdiction},
  ];
}

@DataClassName('ProtectionRulesetRow')
class ProtectionRulesets extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get normativeDocumentId =>
      text().references(NormativeDocuments, #id)();
  TextColumn get ruleId => text()();
  TextColumn get version => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, ruleId, version},
  ];
}

@DataClassName('CircuitProtectionSettingRow')
class CircuitProtectionSettings extends Table with GeometryAuditColumns {
  TextColumn get circuitId => text().references(ElectricalCircuits, #id)();
  TextColumn get rulesetId =>
      text().nullable().references(ProtectionRulesets, #id)();
  TextColumn get inputsJson => text()();
  TextColumn get reviewedFingerprint => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {circuitId};
}

@DataClassName('ManufacturerCatalogRow')
class ManufacturerCatalogs extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get manufacturer => text()();
  TextColumn get catalogVersion => text()();
  TextColumn get region => text().nullable()();
  TextColumn get sourceReference => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ManufacturerProductRow')
class ManufacturerProducts extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get catalogId => text().references(ManufacturerCatalogs, #id)();
  TextColumn get sku => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {catalogId, sku},
  ];
}

@DataClassName('ManufacturerPolicyRow')
class ManufacturerPolicies extends Table with GeometryAuditColumns {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {projectId};
}

@DataClassName('CircuitProductSelectionRow')
class CircuitProductSelections extends Table with GeometryAuditColumns {
  TextColumn get circuitId => text().references(ElectricalCircuits, #id)();
  TextColumn get productId => text().references(ManufacturerProducts, #id)();
  TextColumn get requirementFingerprint => text()();
  TextColumn get policyJson => text()();
  TextColumn get snapshotJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {circuitId};
}

@DataClassName('PanelGenerationConfigRow')
class PanelGenerationConfigs extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get floorId => text().references(Floors, #id)();
  TextColumn get payloadJson => text()();
  TextColumn get reviewedFingerprint => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {floorId},
  ];
}

@DataClassName('EngineeringFamilyDefinitionRow')
class EngineeringFamilyDefinitions extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get code => text()();
  TextColumn get familyVersion => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {code, familyVersion},
  ];
}

@DataClassName('ProjectEngineeringSystemRow')
class ProjectEngineeringSystems extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  TextColumn get familyId =>
      text().references(EngineeringFamilyDefinitions, #id)();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, code},
  ];
}

@DataClassName('ComponentEngineeringMembershipRow')
class ComponentEngineeringMemberships extends Table with GeometryAuditColumns {
  TextColumn get systemId =>
      text().references(ProjectEngineeringSystems, #id)();
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get role => text()();
  @override
  Set<Column<Object>> get primaryKey => {systemId, componentId};
}

@DataClassName('EngineeringReferenceCatalogRow')
class EngineeringReferenceCatalogs extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  TextColumn get catalogVersion => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, code, catalogVersion},
  ];
}

@DataClassName('ComponentReferenceBindingRow')
class ComponentReferenceBindings extends Table with GeometryAuditColumns {
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get catalogId =>
      text().references(EngineeringReferenceCatalogs, #id)();
  TextColumn get profileCode => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {componentId};
}

@DataClassName('EngineeringPortInstanceRow')
class EngineeringPortInstances extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get code => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {componentId, code},
  ];
}

@DataClassName('EngineeringCompatibilityProfileRow')
class EngineeringCompatibilityProfiles extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  TextColumn get profileVersion => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, code, profileVersion},
  ];
}

@DataClassName('EngineeringTopologyProfileRow')
class EngineeringTopologyProfiles extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  TextColumn get profileVersion => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, code, profileVersion},
  ];
}

@DataClassName('EngineeringAssemblyProfileRow')
class EngineeringAssemblyProfiles extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  TextColumn get profileVersion => text()();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, code, profileVersion},
  ];
}

@DataClassName('EngineeringTopologyGroupRow')
class EngineeringTopologyGroups extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get systemId =>
      text().references(ProjectEngineeringSystems, #id)();
  TextColumn get code => text()();
  TextColumn get profileId =>
      text().references(EngineeringTopologyProfiles, #id)();
  @ReferenceName('topologyGroupsStartingAtPort')
  TextColumn get startPortId =>
      text().references(EngineeringPortInstances, #id)();
  @ReferenceName('topologyGroupsEndingAtPort')
  TextColumn get endPortId =>
      text().nullable().references(EngineeringPortInstances, #id)();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {systemId, code},
  ];
}

@DataClassName('EngineeringPortConnectionRow')
class EngineeringPortConnections extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get systemId =>
      text().references(ProjectEngineeringSystems, #id)();
  @ReferenceName('outgoingEngineeringPortConnections')
  TextColumn get fromPortId =>
      text().references(EngineeringPortInstances, #id)();
  @ReferenceName('incomingEngineeringPortConnections')
  TextColumn get toPortId => text().references(EngineeringPortInstances, #id)();
  TextColumn get profileId =>
      text().references(EngineeringCompatibilityProfiles, #id)();
  TextColumn get groupId =>
      text().nullable().references(EngineeringTopologyGroups, #id)();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EngineeringInternalMappingRow')
class EngineeringInternalMappings extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  @ReferenceName('outgoingEngineeringInternalMappings')
  TextColumn get fromPortId =>
      text().references(EngineeringPortInstances, #id)();
  @ReferenceName('incomingEngineeringInternalMappings')
  TextColumn get toPortId => text().references(EngineeringPortInstances, #id)();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EngineeringComponentAssemblyRow')
class EngineeringComponentAssemblies extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  TextColumn get profileId =>
      text().references(EngineeringAssemblyProfiles, #id)();
  TextColumn get payloadJson => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, code},
  ];
}

@DataClassName('EngineeringPlacementOperationRow')
class EngineeringPlacementOperations extends Table {
  TextColumn get operationId => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  IntColumn get fingerprintVersion => integer()();
  TextColumn get commandFingerprint => text()();
  TextColumn get status => text()();
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get resultJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originDeviceId => text()();
  @override
  Set<Column<Object>> get primaryKey => {operationId};
}

@DataClassName('ElvCableRow')
class ElvCables extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get label => text()();
  TextColumn get normalizedLabel => text()();
  TextColumn get name => text()();
  TextColumn get definitionCatalogId =>
      text().references(EngineeringReferenceCatalogs, #id)();
  TextColumn get definitionCatalogVersion => text()();
  TextColumn get definitionCode => text()();
  TextColumn get definitionContentHash => text()();
  TextColumn get lifecycleState => text()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableAllocationRow')
class CableAllocations extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get engineeringConnectionId =>
      text().references(EngineeringPortConnections, #id)();
  TextColumn get cableId => text().references(ElvCables, #id)();
  TextColumn get lifecycleState => text()();
  TextColumn get transitionRef => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableAllocationResourceSelectionRow')
class CableAllocationResourceSelections extends Table {
  TextColumn get allocationId => text().references(CableAllocations, #id)();
  TextColumn get cableDefinitionRefJson => text()();
  TextColumn get selectionJson => text()();
  TextColumn get resolvedAtomsJson => text()();
  TextColumn get selectionSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();
  @override
  Set<Column<Object>> get primaryKey => {allocationId};
}

@DataClassName('CableResourceClaimRow')
class CableResourceClaims extends Table {
  TextColumn get allocationId => text().references(CableAllocations, #id)();
  TextColumn get cableId => text().references(ElvCables, #id)();
  TextColumn get resourceAtom => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();
  @override
  Set<Column<Object>> get primaryKey => {allocationId, resourceAtom};
}

@DataClassName('CableTerminationMappingRow')
class CableTerminationMappings extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get allocationId => text().references(CableAllocations, #id)();
  TextColumn get resourceIdentity => text()();
  TextColumn get endRole => text()();
  TextColumn get endpointPortId =>
      text().references(EngineeringPortInstances, #id)();
  TextColumn get endpointTerminalRef => text().nullable()();
  TextColumn get terminationRole => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {allocationId, resourceIdentity, endRole},
  ];
}

@DataClassName('CommandExecutionRecordRow')
class CommandExecutionRecords extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get commandId => text()();
  TextColumn get commandType => text()();
  IntColumn get payloadSchemaVersion => integer()();
  TextColumn get normalizedPayloadSha256 => text()();
  TextColumn get outcomeKind => text()();
  TextColumn get logicalResultJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get committedAt => dateTime()();
  TextColumn get originDeviceId => text()();
  @override
  Set<Column<Object>> get primaryKey => {projectId, commandId};
}

@DataClassName('ProjectDesignRevisionRow')
class ProjectDesignRevisions extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  IntColumn get sequence => integer()();
  TextColumn get state => text()();
  @ReferenceName('basedOnProjectDesignRevision')
  TextColumn get basedOnRevisionId =>
      text().nullable().references(ProjectDesignRevisions, #id)();
  IntColumn get snapshotSchemaVersion => integer().nullable()();
  TextColumn get snapshotHash => text().nullable()();
  DateTimeColumn get frozenAt => dateTime().nullable()();
  DateTimeColumn get supersededAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {projectId, code},
    {projectId, sequence},
  ];
}

@DataClassName('DesignRevisionPhysicalSnapshotRow')
class DesignRevisionPhysicalSnapshots extends Table {
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  IntColumn get schemaVersion => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get payloadSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId};
}

@DataClassName('CanonicalCableRunRow')
class CanonicalCableRuns extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get cableId => text().references(ElvCables, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  @ReferenceName('basedOnCanonicalCableRun')
  TextColumn get basedOnCableRunId =>
      text().nullable().references(CanonicalCableRuns, #id)();
  TextColumn get lifecycleState => text()();
  RealColumn get reservePercent => real().withDefault(const Constant(0))();
  IntColumn get terminationAllowanceMm =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableRunTraversalRow')
class CableRunTraversals extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get cableRunId => text().references(CanonicalCableRuns, #id)();
  IntColumn get sequence => integer()();
  TextColumn get routeSegmentId => text().references(CableRouteSegments, #id)();
  TextColumn get direction => text()();
  TextColumn get physicalCarrierId => text().nullable()();
  TextColumn get carrierCompartmentId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {cableRunId, sequence},
  ];
}

@DataClassName('RouteHandoffRow')
class RouteHandoffs extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  @ReferenceName('handoffFromRouteNode')
  TextColumn get fromRouteNodeId => text().references(CableRouteNodes, #id)();
  @ReferenceName('handoffToRouteNode')
  TextColumn get toRouteNodeId => text().references(CableRouteNodes, #id)();
  TextColumn get kind => text()();
  BoolColumn get bidirectional => boolean().withDefault(const Constant(true))();
  TextColumn get adjacencyRef => text().nullable()();
  TextColumn get evidenceJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RouteBendEvidenceRow')
class RouteBendEvidence extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get routeNodeId => text().references(CableRouteNodes, #id)();
  RealColumn get radiusMm => real()();
  TextColumn get evidenceKind => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get provenance => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LegacyRouteAdoptionRow')
class LegacyRouteAdoptions extends Table {
  TextColumn get legacySourceIdentity => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get cableId => text().references(ElvCables, #id)();
  TextColumn get canonicalCableRunId =>
      text().references(CanonicalCableRuns, #id)();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {legacySourceIdentity};
}

@DataClassName('PathwayContextRow')
class PathwayContexts extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get kind => text()();
  TextColumn get hostType => text()();
  TextColumn get hostJson => text()();
  @ReferenceName('parentPathwayContext')
  TextColumn get parentContextId =>
      text().nullable().references(PathwayContexts, #id)();
  TextColumn get provenance => text().nullable()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PhysicalCarrierRow')
class PhysicalCarriers extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get pathwayContextId => text().references(PathwayContexts, #id)();
  TextColumn get code => text()();
  TextColumn get normalizedCode => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PhysicalCarrierCompartmentRow')
class PhysicalCarrierCompartments extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get carrierId => text().references(PhysicalCarriers, #id)();
  TextColumn get code => text()();
  TextColumn get normalizedCode => text()();
  IntColumn get sequence => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TraversalCarrierAssignmentRow')
class TraversalCarrierAssignments extends Table with GeometryAuditColumns {
  TextColumn get traversalId => text().references(CableRunTraversals, #id)();
  TextColumn get cableRunId => text().references(CanonicalCableRuns, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get carrierId => text().references(PhysicalCarriers, #id)();
  TextColumn get compartmentId =>
      text().nullable().references(PhysicalCarrierCompartments, #id)();

  @override
  Set<Column<Object>> get primaryKey => {traversalId};
}

@DriftDatabase(
  tables: [
    Projects,
    Floors,
    Rooms,
    SurfacePatches,
    SurfaceEdges,
    SurfaceAdjacencies,
    Openings,
    SpatialFeatures,
    ComponentInstances,
    ComponentCatalogPreferences,
    ConsumptionGroups,
    EquipmentElectricalLoads,
    ElectricalCircuits,
    CircuitLoadAssignments,
    PhysicalChannels,
    CableRoutes,
    CableRouteNodes,
    CableRouteSegments,
    CableRuns,
    RoutingJunctions,
    JunctionConnections,
    FloorRoutingPanels,
    FloorPanelFeeds,
    FloorRoutingHandoffs,
    ProjectDerivedResults,
    NormativeDocuments,
    ProtectionRulesets,
    CircuitProtectionSettings,
    ManufacturerCatalogs,
    ManufacturerProducts,
    ManufacturerPolicies,
    CircuitProductSelections,
    PanelGenerationConfigs,
    EngineeringFamilyDefinitions,
    ProjectEngineeringSystems,
    ComponentEngineeringMemberships,
    EngineeringReferenceCatalogs,
    ComponentReferenceBindings,
    EngineeringPortInstances,
    EngineeringCompatibilityProfiles,
    EngineeringTopologyProfiles,
    EngineeringAssemblyProfiles,
    EngineeringTopologyGroups,
    EngineeringPortConnections,
    EngineeringInternalMappings,
    EngineeringComponentAssemblies,
    EngineeringPlacementOperations,
    ElvCables,
    CableAllocations,
    CableAllocationResourceSelections,
    CableResourceClaims,
    CableTerminationMappings,
    CommandExecutionRecords,
    ProjectDesignRevisions,
    DesignRevisionPhysicalSnapshots,
    CanonicalCableRuns,
    CableRunTraversals,
    RouteHandoffs,
    RouteBendEvidence,
    LegacyRouteAdoptions,
    PathwayContexts,
    PhysicalCarriers,
    PhysicalCarrierCompartments,
    TraversalCarrierAssignments,
    PowerPortBindings,
    PowerComponentBindings,
    PowerTransferBindings,
    PowerTransferOutputs,
    PowerLoadBindings,
    PowerCapacityGroups,
    PowerCapacityGroupMembers,
    PowerSupplyRequirements,
    PowerSupplyRequirementInputs,
    PowerOperatingScenarios,
    PowerScenarioSegments,
    PowerScenarioStates,
    PowerScenarioSourceSelections,
    PowerScenarioUnavailableSources,
    PoeDeliveryBindings,
    PoeDeliveryPathMembers,
    BackupAssemblies,
    BackupProtectedOutputs,
    BatteryBankBindings,
    DesignRevisionPowerSnapshots,
    DesignRevisionSnapshotManifests,
    PowerEvaluationRecords,
    PowerEvaluationPointers,
    PowerOperationRecords,
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'electra'));

  @override
  int get schemaVersion => 22;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 1) {
        await migrator.createAll();
      } else {
        if (from < 2) {
          await migrator.createTable(surfacePatches);
          await migrator.createTable(surfaceEdges);
          await migrator.createTable(surfaceAdjacencies);
          await migrator.createTable(openings);
          await migrator.createTable(spatialFeatures);
        }
        if (from < 3) await migrator.createTable(componentInstances);
        if (from < 4) await migrator.createTable(componentCatalogPreferences);
        if (from < 5) {
          await migrator.createTable(consumptionGroups);
          await migrator.createTable(equipmentElectricalLoads);
        }
        if (from < 6) {
          if (from >= 5)
            await migrator.addColumn(
              equipmentElectricalLoads,
              equipmentElectricalLoads.powerBasis,
            );
          await migrator.createTable(electricalCircuits);
          await migrator.createTable(circuitLoadAssignments);
        }
        if (from < 7) {
          await migrator.createTable(physicalChannels);
          await migrator.createTable(cableRoutes);
          await migrator.createTable(cableRouteNodes);
          await migrator.createTable(cableRouteSegments);
          await migrator.createTable(cableRuns);
        }
        if (from < 8) {
          await migrator.createTable(routingJunctions);
          await migrator.createTable(junctionConnections);
        }
        if (from < 9) {
          await migrator.createTable(floorRoutingPanels);
          await migrator.createTable(floorPanelFeeds);
          await migrator.createTable(floorRoutingHandoffs);
        }
        if (from < 10) await migrator.createTable(projectDerivedResults);
        if (from < 11) {
          await migrator.createTable(normativeDocuments);
          await migrator.createTable(protectionRulesets);
          await migrator.createTable(circuitProtectionSettings);
        }
        if (from < 14) {
          await migrator.createTable(engineeringFamilyDefinitions);
          await migrator.createTable(projectEngineeringSystems);
          await migrator.createTable(componentEngineeringMemberships);
        }
        if (from < 13) await migrator.createTable(panelGenerationConfigs);
        if (from < 12) {
          await migrator.createTable(manufacturerCatalogs);
          await migrator.createTable(manufacturerProducts);
          await migrator.createTable(manufacturerPolicies);
          await migrator.createTable(circuitProductSelections);
        }
        if (from < 16) {
          await migrator.createTable(engineeringReferenceCatalogs);
          await migrator.createTable(componentReferenceBindings);
        }
        if (from < 15) {
          await migrator.createTable(engineeringPortInstances);
          await migrator.createTable(engineeringCompatibilityProfiles);
          await migrator.createTable(engineeringTopologyProfiles);
          await migrator.createTable(engineeringAssemblyProfiles);
          await migrator.createTable(engineeringTopologyGroups);
          await migrator.createTable(engineeringPortConnections);
          await migrator.createTable(engineeringInternalMappings);
          await migrator.createTable(engineeringComponentAssemblies);
        }
        if (from < 17)
          await migrator.createTable(engineeringPlacementOperations);
        if (from < 18) {
          await migrator.createTable(elvCables);
          await migrator.createTable(commandExecutionRecords);
        }
        if (from < 19) {
          await migrator.createTable(cableAllocations);
          await migrator.createTable(cableAllocationResourceSelections);
          await migrator.createTable(cableResourceClaims);
          await migrator.createTable(cableTerminationMappings);
        }
        if (from < 20) {
          await migrator.createTable(projectDesignRevisions);
          await migrator.createTable(designRevisionPhysicalSnapshots);
          await migrator.createTable(canonicalCableRuns);
          await migrator.createTable(cableRunTraversals);
          await migrator.createTable(routeHandoffs);
          await migrator.createTable(routeBendEvidence);
          await migrator.createTable(legacyRouteAdoptions);
        }
        if (from < 21) {
          await migrator.createTable(pathwayContexts);
          await migrator.createTable(physicalCarriers);
          await migrator.createTable(physicalCarrierCompartments);
          await migrator.createTable(traversalCarrierAssignments);
        }
        if (from < 22) {
          await migrator.createTable(powerPortBindings);
          await migrator.createTable(powerComponentBindings);
          await migrator.createTable(powerTransferBindings);
          await migrator.createTable(powerTransferOutputs);
          await migrator.createTable(powerLoadBindings);
          await migrator.createTable(powerCapacityGroups);
          await migrator.createTable(powerCapacityGroupMembers);
          await migrator.createTable(powerSupplyRequirements);
          await migrator.createTable(powerSupplyRequirementInputs);
          await migrator.createTable(powerOperatingScenarios);
          await migrator.createTable(powerScenarioSegments);
          await migrator.createTable(powerScenarioStates);
          await migrator.createTable(powerScenarioSourceSelections);
          await migrator.createTable(powerScenarioUnavailableSources);
          await migrator.createTable(poeDeliveryBindings);
          await migrator.createTable(poeDeliveryPathMembers);
          await migrator.createTable(backupAssemblies);
          await migrator.createTable(backupProtectedOutputs);
          await migrator.createTable(batteryBankBindings);
          await migrator.createTable(designRevisionPowerSnapshots);
          await migrator.createTable(designRevisionSnapshotManifests);
          await migrator.createTable(powerEvaluationRecords);
          await migrator.createTable(powerEvaluationPointers);
          await migrator.createTable(powerOperationRecords);
        }
      }
      await _createIndexes();
      await _createPowerIntegrityGuards();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await _createPowerIntegrityGuards();
      final now = DateTime.now().toUtc();
      for (final family in bundledEngineeringSystemFamilies) {
        await into(engineeringFamilyDefinitions).insert(
          EngineeringFamilyDefinitionsCompanion.insert(
            id: family.id,
            code: family.code,
            familyVersion: family.version,
            payloadJson: jsonEncode(family.toMap()),
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'bundled-elv0-catalog',
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
      for (final doc in bundledNormativeDocuments) {
        await into(normativeDocuments).insert(
          NormativeDocumentsCompanion.insert(
            id: doc.id,
            standardCode: doc.standardCode,
            version: doc.version,
            jurisdiction: doc.jurisdiction,
            payloadJson: jsonEncode(doc.toMap()),
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'bundled-fl13-catalog',
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_floor_routing_panel ON floor_routing_panels(floor_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_floor_routing_handoff ON floor_routing_handoffs(floor_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cable_route_room ON cable_routes(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_route_node_order ON cable_route_nodes(route_id, sequence)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_route_segment_order ON cable_route_segments(route_id, sequence)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_cable_run_circuit ON cable_runs(circuit_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_channel_room ON physical_channels(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_electrical_circuit_room ON electrical_circuits(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_circuit_load_assignment_circuit ON circuit_load_assignments(circuit_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_consumption_group_room ON consumption_groups(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_equipment_load_group ON equipment_electrical_loads(consumption_group_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_floor_project_order ON floors(project_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_room_floor_name ON rooms(floor_id, name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_updated ON projects(updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_surface_patch_room ON surface_patches(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_surface_edge_patch ON surface_edges(patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_opening_patch ON openings(host_surface_patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_spatial_feature_patch ON spatial_features(host_surface_patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_component_instance_room ON component_instances(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_component_instance_patch ON component_instances(host_surface_patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_component_instance_definition ON component_instances(definition_id, definition_version)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_engineering_placement_operation_project ON engineering_placement_operations(project_id, status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_cable_project ON elv_cables(project_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_cable_definition_catalog ON elv_cables(definition_catalog_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_cable_active_label ON elv_cables(project_id, normalized_label) WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_allocation_project ON cable_allocations(project_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_allocation_cable ON cable_allocations(cable_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_allocation_connection ON cable_allocations(engineering_connection_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_connection_consuming_allocation ON cable_allocations(project_id, engineering_connection_id) WHERE lifecycle_state IN ('RESERVED','ACTIVE') AND deleted_at IS NULL",
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_resource_claim ON cable_resource_claims(cable_id, resource_atom)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_termination_allocation ON cable_termination_mappings(allocation_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_design_revision_working ON project_design_revisions(project_id) WHERE state = 'WORKING' AND deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_design_revision_project ON project_design_revisions(project_id, sequence)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_active_run_per_cable_revision ON canonical_cable_runs(cable_id, design_revision_id) WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_run_revision ON canonical_cable_runs(project_id, design_revision_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_traversal_run_order ON cable_run_traversals(cable_run_id, sequence)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_traversal_segment ON cable_run_traversals(route_segment_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_handoff_project ON route_handoffs(project_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_bend_project ON route_bend_evidence(project_id, route_node_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_pathway_project ON pathway_contexts(project_id, lifecycle_state)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_pathway_active_identity ON pathway_contexts(project_id, id) WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_carrier_project ON physical_carriers(project_id, pathway_context_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_carrier_active_code ON physical_carriers(project_id, normalized_code) WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_compartment_carrier ON physical_carrier_compartments(carrier_id, sequence)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_elv_traversal_carrier_assignment_run ON traversal_carrier_assignments(cable_run_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_port_binding_scope ON power_port_bindings(project_id, design_revision_id, port_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_power_port_binding_active ON power_port_bindings(design_revision_id, port_id) WHERE deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_component_binding_scope ON power_component_bindings(project_id, design_revision_id, component_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_power_component_binding_active ON power_component_bindings(design_revision_id, component_id) WHERE deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_transfer_input ON power_transfer_bindings(design_revision_id, input_port_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_transfer_output ON power_transfer_outputs(design_revision_id, output_port_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_load_input ON power_load_bindings(design_revision_id, input_port_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_capacity_owner ON power_capacity_groups(design_revision_id, owner_component_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_capacity_member ON power_capacity_group_members(design_revision_id, output_port_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_requirement_consumer ON power_supply_requirements(design_revision_id, consumer_component_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_requirement_input ON power_supply_requirement_inputs(design_revision_id, input_port_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_scenario_segment ON power_scenario_segments(design_revision_id, scenario_id, ordinal)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_scenario_state ON power_scenario_states(design_revision_id, scenario_id, segment_id, component_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_poe_connection ON poe_delivery_path_members(design_revision_id, connection_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_poe_allocation ON poe_delivery_path_members(design_revision_id, allocation_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_backup_output ON backup_protected_outputs(design_revision_id, output_port_id)',
    );
    await customStatement(
      "CREATE UNIQUE INDEX IF NOT EXISTS ux_power_battery_bank_active ON battery_bank_bindings(design_revision_id, bank_component_id) WHERE deleted_at IS NULL",
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_evaluation_scope ON power_evaluation_records(project_id, design_revision_id, logical_node_key_sha256)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_power_pointer_scope ON power_evaluation_pointers(project_id, design_revision_id, logical_node_key_sha256)',
    );
  }

  Future<void> _createPowerIntegrityGuards() async {
    const scopedTables = <String>[
      'power_port_bindings',
      'power_component_bindings',
      'power_transfer_bindings',
      'power_transfer_outputs',
      'power_load_bindings',
      'power_capacity_groups',
      'power_capacity_group_members',
      'power_supply_requirements',
      'power_supply_requirement_inputs',
      'power_operating_scenarios',
      'power_scenario_segments',
      'power_scenario_states',
      'power_scenario_source_selections',
      'power_scenario_unavailable_sources',
      'poe_delivery_bindings',
      'poe_delivery_path_members',
      'backup_assemblies',
      'backup_protected_outputs',
      'battery_bank_bindings',
      'design_revision_power_snapshots',
      'design_revision_snapshot_manifests',
      'power_evaluation_records',
      'power_evaluation_pointers',
      'power_operation_records',
    ];
    for (final table in scopedTables) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_${table}_scope_insert '
        'BEFORE INSERT ON $table FOR EACH ROW '
        'WHEN NOT EXISTS ('
        'SELECT 1 FROM project_design_revisions r '
        'WHERE r.id = NEW.design_revision_id '
        'AND r.project_id = NEW.project_id '
        'AND r.deleted_at IS NULL) '
        "BEGIN SELECT RAISE(ABORT, 'ELV4_SCOPE_REVISION_PROJECT_MISMATCH'); END",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_${table}_scope_update '
        'BEFORE UPDATE ON $table FOR EACH ROW '
        'WHEN NOT EXISTS ('
        'SELECT 1 FROM project_design_revisions r '
        'WHERE r.id = NEW.design_revision_id '
        'AND r.project_id = NEW.project_id '
        'AND r.deleted_at IS NULL) '
        "BEGIN SELECT RAISE(ABORT, 'ELV4_SCOPE_REVISION_PROJECT_MISMATCH'); END",
      );
    }

    const immutableTables = <String>[
      'design_revision_power_snapshots',
      'design_revision_snapshot_manifests',
      'power_evaluation_records',
    ];
    for (final table in immutableTables) {
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_${table}_immutable_update '
        'BEFORE UPDATE ON $table '
        "BEGIN SELECT RAISE(ABORT, 'ELV4_IMMUTABLE_EVIDENCE'); END",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS trg_${table}_immutable_delete '
        'BEFORE DELETE ON $table '
        "BEGIN SELECT RAISE(ABORT, 'ELV4_IMMUTABLE_EVIDENCE'); END",
      );
    }
  }
}
