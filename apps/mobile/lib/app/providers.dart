import '../application/engineering_system_repository.dart';
import '../data/repositories/drift_engineering_system_repository.dart';
import '../application/panel_generation_repository.dart';
import '../data/repositories/drift_panel_generation_repository.dart';
import '../application/manufacturer_repository.dart';
import '../data/repositories/drift_manufacturer_repository.dart';
import '../application/protection_repository.dart';
import '../data/repositories/drift_protection_repository.dart';
import '../application/dependency_recalculation_repository.dart';
import '../data/repositories/drift_dependency_recalculation_repository.dart';
import '../application/floor_routing_repository.dart';
import '../data/repositories/drift_floor_routing_repository.dart';
import '../application/cable_routing_repository.dart';
import '../data/repositories/drift_cable_routing_repository.dart';
import '../application/electrical_circuit_repository.dart';
import '../data/repositories/drift_electrical_circuit_repository.dart';
import '../application/electrical_load_repository.dart';
import '../data/repositories/drift_electrical_load_repository.dart';
import '../application/catalog_preferences_repository.dart';
import '../data/repositories/drift_catalog_preferences_repository.dart';

import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/component_instance_repository.dart';
import '../application/component_placement_service.dart';
import '../application/geometry_repository.dart';
import '../application/id_generator.dart';
import '../application/project_hierarchy_service.dart';
import '../application/project_repositories.dart';
import '../data/database/app_database.dart';
import '../data/database/drift_unit_of_work.dart';
import '../data/repositories/drift_component_instance_repository.dart';
import '../data/repositories/drift_geometry_repository.dart';
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

final geometryRepositoryProvider = Provider<GeometryRepository>((ref) {
  return DriftGeometryRepository(
    ref.watch(databaseProvider),
    originDeviceId: 'local-device',
  );
});

final componentInstanceRepositoryProvider =
    Provider<ComponentInstanceRepository>((ref) {
      return DriftComponentInstanceRepository(
        ref.watch(databaseProvider),
        originDeviceId: 'local-device',
      );
    });

final catalogPreferencesRepositoryProvider =
    Provider<CatalogPreferencesRepository>((ref) {
      return DriftCatalogPreferencesRepository(ref.watch(databaseProvider));
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

final componentPlacementServiceProvider = Provider<ComponentPlacementService>((
  ref,
) {
  return ComponentPlacementService(
    components: ref.watch(componentInstanceRepositoryProvider),
    geometry: ref.watch(geometryRepositoryProvider),
    idGenerator: ref.watch(idGeneratorProvider),
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

final roomGeometryProvider =
    StreamProvider.family<RoomGeometrySnapshot, String>((ref, roomId) {
      return ref.watch(geometryRepositoryProvider).watchRoomGeometry(roomId);
    });

final roomComponentsProvider =
    StreamProvider.family<List<ComponentInstance>, String>((ref, roomId) {
      return ref
          .watch(componentInstanceRepositoryProvider)
          .watchRoomComponents(roomId);
    });

final electricalLoadRepositoryProvider = Provider<ElectricalLoadRepository>((
  ref,
) {
  return DriftElectricalLoadRepository(
    ref.watch(databaseProvider),
    originDeviceId: 'local-device',
  );
});
final roomElectricalLoadsProvider =
    StreamProvider.family<List<EquipmentElectricalLoad>, String>(
      (ref, roomId) =>
          ref.watch(electricalLoadRepositoryProvider).watchRoomLoads(roomId),
    );
final roomConsumptionGroupsProvider =
    StreamProvider.family<List<RoomConsumptionGroup>, String>(
      (ref, roomId) =>
          ref.watch(electricalLoadRepositoryProvider).watchRoomGroups(roomId),
    );

final electricalCircuitRepositoryProvider =
    Provider<ElectricalCircuitRepository>(
      (ref) => DriftElectricalCircuitRepository(
        ref.watch(databaseProvider),
        originDeviceId: 'local-device',
      ),
    );
final roomElectricalCircuitsProvider =
    StreamProvider.family<List<CircuitSnapshot>, String>(
      (ref, roomId) => ref
          .watch(electricalCircuitRepositoryProvider)
          .watchRoomCircuits(roomId),
    );

final cableRoutingRepositoryProvider = Provider<CableRoutingRepository>(
  (ref) => DriftCableRoutingRepository(
    ref.watch(databaseProvider),
    originDeviceId: 'local-device',
  ),
);
final roomRoutingProvider = StreamProvider.family<RoomRoutingSnapshot, String>(
  (ref, roomId) =>
      ref.watch(cableRoutingRepositoryProvider).watchRoomRouting(roomId),
);

final floorRoutingRepositoryProvider = Provider<FloorRoutingRepository>(
  (ref) => DriftFloorRoutingRepository(
    ref.watch(databaseProvider),
    originDeviceId: 'local-device',
  ),
);
final floorRoutingProvider = StreamProvider.family<
  FloorRoutingSnapshot,
  String
>((ref, floorId) => ref.watch(floorRoutingRepositoryProvider).watch(floorId));

final dependencyRecalculationRepositoryProvider =
    Provider<DependencyRecalculationRepository>(
      (ref) => DriftDependencyRecalculationRepository(
        ref.watch(databaseProvider),
        originDeviceId: 'local-device',
      ),
    );
final projectRecalculationProvider =
    StreamProvider.family<ProjectRecalculationSnapshot, String>(
      (ref, projectId) =>
          ref.watch(dependencyRecalculationRepositoryProvider).watch(projectId),
    );

final protectionRepositoryProvider = Provider<ProtectionRepository>(
  (ref) => DriftProtectionRepository(
    ref.watch(databaseProvider),
    originDeviceId: 'local-device',
  ),
);
final projectProtectionProvider = StreamProvider.family<
  ProjectProtectionSnapshot,
  String
>((ref, projectId) => ref.watch(protectionRepositoryProvider).watch(projectId));

final manufacturerRepositoryProvider = Provider<ManufacturerRepository>(
  (ref) => DriftManufacturerRepository(
    ref.watch(databaseProvider),
    originDeviceId: 'local-device',
  ),
);
final projectManufacturerProvider =
    StreamProvider.family<ProjectManufacturerSnapshot, String>(
      (ref, id) => ref.watch(manufacturerRepositoryProvider).watch(id),
    );

final panelGenerationRepositoryProvider = Provider<PanelGenerationRepository>(
  (ref) => DriftPanelGenerationRepository(
    ref.watch(databaseProvider),
    originDeviceId: 'local-device',
  ),
);
final projectPanelGenerationProvider =
    StreamProvider.family<ProjectPanelGenerationSnapshot, String>(
      (ref, id) => ref.watch(panelGenerationRepositoryProvider).watch(id),
    );

final engineeringSystemRepositoryProvider =
    Provider<EngineeringSystemRepository>(
      (ref) => DriftEngineeringSystemRepository(
        ref.watch(databaseProvider),
        originDeviceId: 'local-device',
      ),
    );
final projectEngineeringSystemsProvider =
    StreamProvider.family<ProjectEngineeringSystemsSnapshot, String>(
      (ref, id) => ref.watch(engineeringSystemRepositoryProvider).watch(id),
    );
