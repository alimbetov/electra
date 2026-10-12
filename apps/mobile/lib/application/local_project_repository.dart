import '../domain/models.dart';

/// Application-facing persistence contract for the local project hierarchy.
///
/// The first implementation is expected to use Drift/SQLite. Cloud DTOs and
/// authentication concepts must not leak through this interface.
abstract interface class LocalProjectRepository {
  Stream<List<ProjectDraft>> watchProjects();

  Future<ProjectDraft?> findProject(String projectId);

  Future<void> createProject(ProjectDraft project);

  Future<void> updateProject(ProjectDraft project);

  Future<void> deleteProject(String projectId);

  Stream<List<RoomDraft>> watchRooms(String projectId);

  Future<void> createRoom({
    required String projectId,
    required RoomDraft room,
  });

  Future<void> updateRoom({
    required String projectId,
    required RoomDraft room,
  });

  Future<void> deleteRoom({
    required String projectId,
    required String roomId,
  });
}
