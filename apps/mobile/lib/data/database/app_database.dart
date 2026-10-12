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
  ],
)
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'electra'));

  @override
  int get schemaVersion => 4;

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
      }
      await _createIndexes();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
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
