import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectSameInstant(DateTime actual, DateTime expected) {
    expect(actual.millisecondsSinceEpoch, expected.millisecondsSinceEpoch);
  }

  test(
    'geometry updates preserve creation time and advance revision',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final hierarchy = DriftProjectHierarchyRepository(database);
      final hierarchyService = ProjectHierarchyService(
        projects: hierarchy,
        floors: hierarchy,
        rooms: hierarchy,
        unitOfWork: DriftUnitOfWork(database),
        idGenerator: FixedSequenceIdGenerator(const [
          'project-revision',
          'floor-revision',
          'room-revision',
        ]),
        originDeviceId: 'revision-device',
        clock: () => DateTime.utc(2026, 10, 12, 10),
      );

      final project = await hierarchyService.createProject(
        const ProjectFormDraft(
          name: 'Revision Project',
          reference: 'REV-01',
          measurementSystem: MeasurementSystem.metric,
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2900,
        ),
      );
      final floor = await hierarchyService.createFloor(
        projectId: project.id,
        draft: const FloorFormDraft(
          name: 'Floor 01',
          code: 'F01',
          sortOrder: 1,
        ),
      );
      final room = await hierarchyService.createRoom(
        floorId: floor.id,
        draft: const RoomFormDraft(
          name: 'Room 01',
          type: RoomType.office,
          category: RoomCategory.commercial,
          widthMm: 4000,
          depthMm: 3000,
        ),
      );

      var now = DateTime.utc(2026, 10, 12, 11);
      final repository = DriftGeometryRepository(
        database,
        originDeviceId: 'revision-device',
        clock: () => now,
      );
      final patch = SurfacePatch(
        id: 'patch-revision',
        roomId: room.id,
        surfaceId: 'wall-a',
        frame: LocalCoordinateFrame(
          origin: const Point3Mm(0, 0, 0),
          uAxis: const Vector3D(1, 0, 0),
          vAxis: const Vector3D(0, 0, 1),
        ),
        boundary: Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(4000, 0),
          Point2Mm(4000, 3000),
          Point2Mm(0, 3000),
        ]),
        orientation: SurfaceOrientation.vertical,
      );

      await repository.replaceRoomGeometry(
        RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
      );
      final first =
          await (database.select(database.surfacePatches)
            ..where((row) => row.id.equals(patch.id))).getSingle();

      expect(first.revision, 1);
      expectSameInstant(first.createdAt, now);
      expectSameInstant(first.updatedAt, now);
      expect(first.deletedAt, isNull);

      final createdAt = first.createdAt;
      now = DateTime.utc(2026, 10, 12, 12);
      await repository.replaceRoomGeometry(
        RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
      );
      final second =
          await (database.select(database.surfacePatches)
            ..where((row) => row.id.equals(patch.id))).getSingle();

      expect(second.revision, 2);
      expectSameInstant(second.createdAt, createdAt);
      expectSameInstant(second.updatedAt, now);
      expect(second.deletedAt, isNull);

      now = DateTime.utc(2026, 10, 12, 13);
      await repository.replaceRoomGeometry(
        RoomGeometrySnapshot(roomId: room.id),
      );
      final deleted =
          await (database.select(database.surfacePatches)
            ..where((row) => row.id.equals(patch.id))).getSingle();

      expect(deleted.revision, 3);
      expectSameInstant(deleted.createdAt, createdAt);
      expectSameInstant(deleted.updatedAt, now);
      expect(deleted.deletedAt, isNotNull);
      expectSameInstant(deleted.deletedAt!, now);

      now = DateTime.utc(2026, 10, 12, 14);
      await repository.replaceRoomGeometry(
        RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
      );
      final restored =
          await (database.select(database.surfacePatches)
            ..where((row) => row.id.equals(patch.id))).getSingle();

      expect(restored.revision, 4);
      expectSameInstant(restored.createdAt, createdAt);
      expectSameInstant(restored.updatedAt, now);
      expect(restored.deletedAt, isNull);

      await database.close();
    },
  );
}
