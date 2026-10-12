import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/project_repositories.dart';
import '../../domain/project_models.dart';
import '../database/app_database.dart';

final class DriftProjectHierarchyRepository
    implements ProjectRepository, FloorRepository, RoomRepository {
  DriftProjectHierarchyRepository(this.database);

  final AppDatabase database;

  @override
  Stream<List<ProjectRecord>> watchProjects() {
    final query =
        database.select(database.projects)
          ..where((row) => row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map(_projectFromRow).toList(growable: false),
    );
  }

  @override
  Stream<ProjectRecord?> watchProject(String projectId) {
    final query = database.select(database.projects)
      ..where((row) => row.id.equals(projectId) & row.deletedAt.isNull());
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _projectFromRow(row),
    );
  }

  @override
  Future<ProjectRecord?> findProject(String projectId) async {
    final query = database.select(database.projects)
      ..where((row) => row.id.equals(projectId) & row.deletedAt.isNull());
    final row = await query.getSingleOrNull();
    return row == null ? null : _projectFromRow(row);
  }

  @override
  Future<void> saveProject(ProjectRecord project) async {
    await database
        .into(database.projects)
        .insertOnConflictUpdate(
          ProjectsCompanion(
            id: Value(project.id),
            name: Value(project.name),
            reference: Value(project.reference),
            measurementSystem: Value(project.measurementSystem.name),
            defaultStructuralHeightMm: Value(project.defaultStructuralHeightMm),
            defaultFinishedCeilingHeightMm: Value(
              project.defaultFinishedCeilingHeightMm,
            ),
            revision: Value(project.revision),
            createdAt: Value(project.createdAt),
            updatedAt: Value(project.updatedAt),
            deletedAt: Value(project.deletedAt),
            originDeviceId: Value(project.originDeviceId),
          ),
        );
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final row =
        await (database.select(database.projects)
          ..where((item) => item.id.equals(projectId))).getSingleOrNull();
    if (row == null) return;
    final now = DateTime.now().toUtc();
    await (database.update(database.projects)
      ..where((item) => item.id.equals(projectId))).write(
      ProjectsCompanion(
        revision: Value(row.revision + 1),
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  @override
  Stream<List<FloorRecord>> watchFloors(String projectId) {
    final query =
        database.select(database.floors)
          ..where(
            (row) => row.projectId.equals(projectId) & row.deletedAt.isNull(),
          )
          ..orderBy([
            (row) => OrderingTerm.asc(row.sortOrder),
            (row) => OrderingTerm.asc(row.name),
          ]);
    return query.watch().map(
      (rows) => rows.map(_floorFromRow).toList(growable: false),
    );
  }

  @override
  Stream<FloorRecord?> watchFloor(String floorId) {
    final query = database.select(database.floors)
      ..where((row) => row.id.equals(floorId) & row.deletedAt.isNull());
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _floorFromRow(row),
    );
  }

  @override
  Future<FloorRecord?> findFloor(String floorId) async {
    final query = database.select(database.floors)
      ..where((row) => row.id.equals(floorId) & row.deletedAt.isNull());
    final row = await query.getSingleOrNull();
    return row == null ? null : _floorFromRow(row);
  }

  @override
  Future<void> saveFloor(FloorRecord floor) async {
    await database
        .into(database.floors)
        .insertOnConflictUpdate(
          FloorsCompanion(
            id: Value(floor.id),
            projectId: Value(floor.projectId),
            name: Value(floor.name),
            code: Value(floor.code),
            sortOrder: Value(floor.sortOrder),
            defaultStructuralHeightMm: Value(floor.defaultStructuralHeightMm),
            defaultFinishedCeilingHeightMm: Value(
              floor.defaultFinishedCeilingHeightMm,
            ),
            revision: Value(floor.revision),
            createdAt: Value(floor.createdAt),
            updatedAt: Value(floor.updatedAt),
            deletedAt: Value(floor.deletedAt),
            originDeviceId: Value(floor.originDeviceId),
          ),
        );
  }

  @override
  Future<void> deleteFloor(String floorId) async {
    final row =
        await (database.select(database.floors)
          ..where((item) => item.id.equals(floorId))).getSingleOrNull();
    if (row == null) return;
    final now = DateTime.now().toUtc();
    await (database.update(database.floors)
      ..where((item) => item.id.equals(floorId))).write(
      FloorsCompanion(
        revision: Value(row.revision + 1),
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  @override
  Stream<List<RoomRecord>> watchRooms(String floorId) {
    final query =
        database.select(database.rooms)
          ..where((row) => row.floorId.equals(floorId) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.name)]);
    return query.watch().map(
      (rows) => rows.map(_roomFromRow).toList(growable: false),
    );
  }

  @override
  Stream<RoomRecord?> watchRoom(String roomId) {
    final query = database.select(database.rooms)
      ..where((row) => row.id.equals(roomId) & row.deletedAt.isNull());
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _roomFromRow(row),
    );
  }

  @override
  Future<RoomRecord?> findRoom(String roomId) async {
    final query = database.select(database.rooms)
      ..where((row) => row.id.equals(roomId) & row.deletedAt.isNull());
    final row = await query.getSingleOrNull();
    return row == null ? null : _roomFromRow(row);
  }

  @override
  Future<void> saveRoom(RoomRecord room) async {
    await database
        .into(database.rooms)
        .insertOnConflictUpdate(
          RoomsCompanion(
            id: Value(room.id),
            floorId: Value(room.floorId),
            name: Value(room.name),
            roomType: Value(room.type.name),
            roomCategory: Value(room.category.name),
            widthMm: Value(room.widthMm),
            depthMm: Value(room.depthMm),
            structuralHeightMmOverride: Value(room.structuralHeightMmOverride),
            finishedCeilingHeightMmOverride: Value(
              room.finishedCeilingHeightMmOverride,
            ),
            revision: Value(room.revision),
            createdAt: Value(room.createdAt),
            updatedAt: Value(room.updatedAt),
            deletedAt: Value(room.deletedAt),
            originDeviceId: Value(room.originDeviceId),
          ),
        );
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    final row =
        await (database.select(database.rooms)
          ..where((item) => item.id.equals(roomId))).getSingleOrNull();
    if (row == null) return;
    final now = DateTime.now().toUtc();
    await (database.update(database.rooms)
      ..where((item) => item.id.equals(roomId))).write(
      RoomsCompanion(
        revision: Value(row.revision + 1),
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
  }

  ProjectRecord _projectFromRow(Project row) => ProjectRecord(
    id: row.id,
    name: row.name,
    reference: row.reference,
    measurementSystem: MeasurementSystem.values.byName(row.measurementSystem),
    defaultStructuralHeightMm: row.defaultStructuralHeightMm,
    defaultFinishedCeilingHeightMm: row.defaultFinishedCeilingHeightMm,
    revision: row.revision,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    originDeviceId: row.originDeviceId,
  );

  FloorRecord _floorFromRow(Floor row) => FloorRecord(
    id: row.id,
    projectId: row.projectId,
    name: row.name,
    code: row.code,
    sortOrder: row.sortOrder,
    defaultStructuralHeightMm: row.defaultStructuralHeightMm,
    defaultFinishedCeilingHeightMm: row.defaultFinishedCeilingHeightMm,
    revision: row.revision,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    originDeviceId: row.originDeviceId,
  );

  RoomRecord _roomFromRow(Room row) => RoomRecord(
    id: row.id,
    floorId: row.floorId,
    name: row.name,
    type: RoomType.values.byName(row.roomType),
    category: RoomCategory.values.byName(row.roomCategory),
    widthMm: row.widthMm,
    depthMm: row.depthMm,
    structuralHeightMmOverride: row.structuralHeightMmOverride,
    finishedCeilingHeightMmOverride: row.finishedCeilingHeightMmOverride,
    revision: row.revision,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    originDeviceId: row.originDeviceId,
  );
}
