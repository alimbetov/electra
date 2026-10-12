import '../domain/project_models.dart';
import 'id_generator.dart';
import 'project_repositories.dart';

final class ProjectHierarchyService {
  ProjectHierarchyService({
    required this.projects,
    required this.floors,
    required this.rooms,
    required this.unitOfWork,
    required this.idGenerator,
    required this.originDeviceId,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final ProjectRepository projects;
  final FloorRepository floors;
  final RoomRepository rooms;
  final LocalUnitOfWork unitOfWork;
  final IdGenerator idGenerator;
  final String originDeviceId;
  final DateTime Function() _clock;

  Future<ProjectRecord> createProject(ProjectFormDraft draft) {
    return unitOfWork.run(() async {
      final now = _clock();
      final project = ProjectRecord(
        id: idGenerator.next(),
        name: draft.name.trim(),
        reference: draft.reference.trim(),
        measurementSystem: draft.measurementSystem,
        defaultStructuralHeightMm: draft.defaultStructuralHeightMm,
        defaultFinishedCeilingHeightMm: draft.defaultFinishedCeilingHeightMm,
        revision: 1,
        createdAt: now,
        updatedAt: now,
        originDeviceId: originDeviceId,
      );
      await projects.saveProject(project);
      return project;
    });
  }

  Future<FloorRecord> createFloor({
    required String projectId,
    required FloorFormDraft draft,
  }) {
    return unitOfWork.run(() async {
      final project = await projects.findProject(projectId);
      if (project == null) {
        throw StateError('Project $projectId does not exist.');
      }
      final now = _clock();
      final floor = FloorRecord(
        id: idGenerator.next(),
        projectId: projectId,
        name: draft.name.trim(),
        code: draft.code.trim(),
        sortOrder: draft.sortOrder,
        defaultStructuralHeightMm: draft.defaultStructuralHeightMm,
        defaultFinishedCeilingHeightMm: draft.defaultFinishedCeilingHeightMm,
        revision: 1,
        createdAt: now,
        updatedAt: now,
        originDeviceId: originDeviceId,
      );
      await floors.saveFloor(floor);
      return floor;
    });
  }

  Future<RoomRecord> createRoom({
    required String floorId,
    required RoomFormDraft draft,
  }) {
    return unitOfWork.run(() async {
      final floor = await floors.findFloor(floorId);
      if (floor == null) {
        throw StateError('Floor $floorId does not exist.');
      }
      final now = _clock();
      final room = RoomRecord(
        id: idGenerator.next(),
        floorId: floorId,
        name: draft.name.trim(),
        type: draft.type,
        category: draft.category,
        widthMm: draft.widthMm,
        depthMm: draft.depthMm,
        structuralHeightMmOverride: draft.structuralHeightMmOverride,
        finishedCeilingHeightMmOverride: draft.finishedCeilingHeightMmOverride,
        revision: 1,
        createdAt: now,
        updatedAt: now,
        originDeviceId: originDeviceId,
      );
      await rooms.saveRoom(room);
      return room;
    });
  }
}
