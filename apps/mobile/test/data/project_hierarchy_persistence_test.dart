import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Project Floor Room survive closing and reopening SQLite database',
    () async {
      final directory = await Directory.systemTemp.createTemp('electra-fl1-');
      final file = File('${directory.path}/electra.sqlite');
      const ids = ['project-1', 'floor-1', 'room-1'];
      final clockValue = DateTime.utc(2026, 10, 12, 12);

      AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

      var database = openDatabase();
      var repository = DriftProjectHierarchyRepository(database);
      var service = ProjectHierarchyService(
        projects: repository,
        floors: repository,
        rooms: repository,
        unitOfWork: DriftUnitOfWork(database),
        idGenerator: FixedSequenceIdGenerator([...ids]),
        originDeviceId: 'test-device',
        clock: () => clockValue,
      );

      final project = await service.createProject(
        const ProjectFormDraft(
          name: 'Workshop 01',
          reference: 'WS-01',
          measurementSystem: MeasurementSystem.metric,
          defaultStructuralHeightMm: 3500,
          defaultFinishedCeilingHeightMm: 3400,
        ),
      );
      final floor = await service.createFloor(
        projectId: project.id,
        draft: const FloorFormDraft(
          name: 'Floor 02',
          code: 'F02',
          sortOrder: 2,
        ),
      );
      final room = await service.createRoom(
        floorId: floor.id,
        draft: const RoomFormDraft(
          name: 'Workshop',
          type: RoomType.workshop,
          category: RoomCategory.technical,
          widthMm: 8000,
          depthMm: 6000,
        ),
      );

      await database.close();

      database = openDatabase();
      repository = DriftProjectHierarchyRepository(database);

      final restoredProject = await repository.findProject(project.id);
      final restoredFloor = await repository.findFloor(floor.id);
      final restoredRoom = await repository.findRoom(room.id);

      expect(restoredProject?.name, 'Workshop 01');
      expect(restoredProject?.reference, 'WS-01');
      expect(restoredProject?.defaultStructuralHeightMm, 3500);
      expect(restoredProject?.originDeviceId, 'test-device');

      expect(restoredFloor?.projectId, project.id);
      expect(restoredFloor?.name, 'Floor 02');
      expect(restoredFloor?.sortOrder, 2);

      expect(restoredRoom?.floorId, floor.id);
      expect(restoredRoom?.type, RoomType.workshop);
      expect(restoredRoom?.category, RoomCategory.technical);
      expect(restoredRoom?.widthMm, 8000);
      expect(restoredRoom?.depthMm, 6000);

      await database.close();
      await directory.delete(recursive: true);
    },
  );

  test('current schema keeps hierarchy tables and indexes', () async {
    final database = AppDatabase(NativeDatabase.memory());

    final tables =
        await database
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
    final tableNames = tables.map((row) => row.read<String>('name')).toSet();

    expect(tableNames, containsAll(['projects', 'floors', 'rooms']));

    final indexes =
        await database
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
            .get();
    final indexNames = indexes.map((row) => row.read<String>('name')).toSet();

    expect(
      indexNames,
      containsAll([
        'idx_floor_project_order',
        'idx_room_floor_name',
        'idx_project_updated',
      ]),
    );
    expect(database.schemaVersion, 4);

    await database.close();
  });
}
