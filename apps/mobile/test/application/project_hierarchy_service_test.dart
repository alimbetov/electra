import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/application/project_repositories.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'application service creates canonical Project Floor Room hierarchy',
    () async {
      final repository = _FakeHierarchyRepository();
      final service = ProjectHierarchyService(
        projects: repository,
        floors: repository,
        rooms: repository,
        unitOfWork: repository,
        idGenerator: FixedSequenceIdGenerator([
          'project-1',
          'floor-1',
          'room-1',
        ]),
        originDeviceId: 'device-test',
        clock: () => DateTime.utc(2026, 10, 12),
      );

      final project = await service.createProject(
        const ProjectFormDraft(
          name: '  Plant A  ',
          reference: '  PA-01 ',
          measurementSystem: MeasurementSystem.metric,
          defaultStructuralHeightMm: 4000,
          defaultFinishedCeilingHeightMm: 3800,
        ),
      );
      final floor = await service.createFloor(
        projectId: project.id,
        draft: const FloorFormDraft(
          name: ' Floor 1 ',
          code: ' F01 ',
          sortOrder: 1,
        ),
      );
      final room = await service.createRoom(
        floorId: floor.id,
        draft: const RoomFormDraft(
          name: ' Workshop ',
          type: RoomType.workshop,
          category: RoomCategory.technical,
          widthMm: 8000,
          depthMm: 6000,
        ),
      );

      expect(project.name, 'Plant A');
      expect(project.reference, 'PA-01');
      expect(floor.projectId, project.id);
      expect(floor.name, 'Floor 1');
      expect(room.floorId, floor.id);
      expect(room.name, 'Workshop');
      expect(room.originDeviceId, 'device-test');
      expect(repository.transactionCount, 3);
    },
  );
}

final class _FakeHierarchyRepository
    implements
        ProjectRepository,
        FloorRepository,
        RoomRepository,
        LocalUnitOfWork {
  final projects = <String, ProjectRecord>{};
  final floors = <String, FloorRecord>{};
  final rooms = <String, RoomRecord>{};
  var transactionCount = 0;

  @override
  Future<T> run<T>(Future<T> Function() action) async {
    transactionCount++;
    return action();
  }

  @override
  Future<void> saveProject(ProjectRecord project) async {
    projects[project.id] = project;
  }

  @override
  Future<void> saveFloor(FloorRecord floor) async {
    floors[floor.id] = floor;
  }

  @override
  Future<void> saveRoom(RoomRecord room) async {
    rooms[room.id] = room;
  }

  @override
  Future<ProjectRecord?> findProject(String projectId) async =>
      projects[projectId];

  @override
  Future<FloorRecord?> findFloor(String floorId) async => floors[floorId];

  @override
  Future<RoomRecord?> findRoom(String roomId) async => rooms[roomId];

  @override
  Stream<List<ProjectRecord>> watchProjects() =>
      Stream.value(projects.values.toList());

  @override
  Stream<ProjectRecord?> watchProject(String projectId) =>
      Stream.value(projects[projectId]);

  @override
  Stream<List<FloorRecord>> watchFloors(String projectId) => Stream.value(
    floors.values.where((floor) => floor.projectId == projectId).toList(),
  );

  @override
  Stream<FloorRecord?> watchFloor(String floorId) =>
      Stream.value(floors[floorId]);

  @override
  Stream<List<RoomRecord>> watchRooms(String floorId) => Stream.value(
    rooms.values.where((room) => room.floorId == floorId).toList(),
  );

  @override
  Stream<RoomRecord?> watchRoom(String roomId) => Stream.value(rooms[roomId]);

  @override
  Future<void> deleteProject(String projectId) async {
    projects.remove(projectId);
  }

  @override
  Future<void> deleteFloor(String floorId) async {
    floors.remove(floorId);
  }

  @override
  Future<void> deleteRoom(String roomId) async {
    rooms.remove(roomId);
  }
}
