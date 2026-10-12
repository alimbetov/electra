import '../domain/project_models.dart';

abstract interface class ProjectRepository {
  Stream<List<ProjectRecord>> watchProjects();
  Stream<ProjectRecord?> watchProject(String projectId);
  Future<ProjectRecord?> findProject(String projectId);
  Future<void> saveProject(ProjectRecord project);
  Future<void> deleteProject(String projectId);
}

abstract interface class FloorRepository {
  Stream<List<FloorRecord>> watchFloors(String projectId);
  Stream<FloorRecord?> watchFloor(String floorId);
  Future<FloorRecord?> findFloor(String floorId);
  Future<void> saveFloor(FloorRecord floor);
  Future<void> deleteFloor(String floorId);
}

abstract interface class RoomRepository {
  Stream<List<RoomRecord>> watchRooms(String floorId);
  Stream<RoomRecord?> watchRoom(String roomId);
  Future<RoomRecord?> findRoom(String roomId);
  Future<void> saveRoom(RoomRecord room);
  Future<void> deleteRoom(String roomId);
}

abstract interface class LocalUnitOfWork {
  Future<T> run<T>(Future<T> Function() action);
}
