import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/id_generator.dart';
import '../application/project_hierarchy_service.dart';
import '../application/project_repositories.dart';
import '../data/database/app_database.dart';
import '../data/database/drift_unit_of_work.dart';
import '../data/repositories/drift_project_hierarchy_repository.dart';
import '../domain/project_models.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final projectHierarchyRepositoryProvider =
    Provider<DriftProjectHierarchyRepository>((ref) {
      return DriftProjectHierarchyRepository(ref.watch(databaseProvider));
    });

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ref.watch(projectHierarchyRepositoryProvider);
});

final floorRepositoryProvider = Provider<FloorRepository>((ref) {
  return ref.watch(projectHierarchyRepositoryProvider);
});

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return ref.watch(projectHierarchyRepositoryProvider);
});

final unitOfWorkProvider = Provider<LocalUnitOfWork>((ref) {
  return DriftUnitOfWork(ref.watch(databaseProvider));
});

final idGeneratorProvider = Provider<IdGenerator>((ref) {
  return UuidV7IdGenerator();
});

final projectHierarchyServiceProvider = Provider<ProjectHierarchyService>((
  ref,
) {
  return ProjectHierarchyService(
    projects: ref.watch(projectRepositoryProvider),
    floors: ref.watch(floorRepositoryProvider),
    rooms: ref.watch(roomRepositoryProvider),
    unitOfWork: ref.watch(unitOfWorkProvider),
    idGenerator: ref.watch(idGeneratorProvider),
    originDeviceId: 'local-device',
  );
});

final projectsProvider = StreamProvider<List<ProjectRecord>>((ref) {
  return ref.watch(projectRepositoryProvider).watchProjects();
});

final projectProvider = StreamProvider.family<ProjectRecord?, String>((
  ref,
  projectId,
) {
  return ref.watch(projectRepositoryProvider).watchProject(projectId);
});

final floorsProvider = StreamProvider.family<List<FloorRecord>, String>((
  ref,
  projectId,
) {
  return ref.watch(floorRepositoryProvider).watchFloors(projectId);
});

final floorProvider = StreamProvider.family<FloorRecord?, String>((
  ref,
  floorId,
) {
  return ref.watch(floorRepositoryProvider).watchFloor(floorId);
});

final roomsProvider = StreamProvider.family<List<RoomRecord>, String>((
  ref,
  floorId,
) {
  return ref.watch(roomRepositoryProvider).watchRooms(floorId);
});

final roomProvider = StreamProvider.family<RoomRecord?, String>((ref, roomId) {
  return ref.watch(roomRepositoryProvider).watchRoom(roomId);
});
