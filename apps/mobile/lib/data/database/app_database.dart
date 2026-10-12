import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

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
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'electra'));

  @override
  int get schemaVersion => 9;

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
        if (from < 3) {
          await migrator.createTable(componentInstances);
        }
        if (from < 4) {
          await migrator.createTable(componentCatalogPreferences);
        }
        if (from < 5) {
          await migrator.createTable(consumptionGroups);
          await migrator.createTable(equipmentElectricalLoads);
        }
        if (from < 6) {
          // Earlier upgrades create the current load table including this column.
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
      }
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
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
      'CREATE INDEX IF NOT EXISTS idx_floor_project_order '
      'ON floors(project_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_room_floor_name '
      'ON rooms(floor_id, name)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_project_updated '
      'ON projects(updated_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_surface_patch_room '
      'ON surface_patches(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_surface_edge_patch '
      'ON surface_edges(patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_opening_patch '
      'ON openings(host_surface_patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_spatial_feature_patch '
      'ON spatial_features(host_surface_patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_component_instance_room '
      'ON component_instances(room_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_component_instance_patch '
      'ON component_instances(host_surface_patch_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_component_instance_definition '
      'ON component_instances(definition_id, definition_version)',
    );
  }
}
