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

@DriftDatabase(tables: [Projects, Floors, Rooms])
final class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'electra'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 1) {
        await migrator.createAll();
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
  }
}
