import 'package:electra_mobile/application/component_placement_history.dart';

import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_component_instance_repository.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('component instance survives SQLite close and reopen exactly', () async {
    final directory = await Directory.systemTemp.createTemp('electra-fl6-');
    final file = File('${directory.path}/electra.sqlite');
    AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

    var database = openDatabase();
    final hierarchy = DriftProjectHierarchyRepository(database);
    final hierarchyService = ProjectHierarchyService(
      projects: hierarchy,
      floors: hierarchy,
      rooms: hierarchy,
      unitOfWork: DriftUnitOfWork(database),
      idGenerator: FixedSequenceIdGenerator(const [
        'project-components',
        'floor-components',
        'room-components',
      ]),
      originDeviceId: 'component-test-device',
      clock: () => DateTime.utc(2026, 10, 12, 15),
    );

    final project = await hierarchyService.createProject(
      const ProjectFormDraft(
        name: 'Components Project',
        reference: 'C-01',
        measurementSystem: MeasurementSystem.metric,
        defaultStructuralHeightMm: 3200,
        defaultFinishedCeilingHeightMm: 3000,
      ),
    );
    final floor = await hierarchyService.createFloor(
      projectId: project.id,
      draft: const FloorFormDraft(name: 'Floor 01', code: 'F01', sortOrder: 1),
    );
    final room = await hierarchyService.createRoom(
      floorId: floor.id,
      draft: const RoomFormDraft(
        name: 'Workshop',
        type: RoomType.workshop,
        category: RoomCategory.technical,
        widthMm: 6000,
        depthMm: 5000,
      ),
    );

    final patch = SurfacePatch(
      id: 'wall-components',
      roomId: room.id,
      surfaceId: 'Wall A',
      frame: LocalCoordinateFrame(
        origin: const Point3Mm(0, 0, 0),
        uAxis: const Vector3D(1, 0, 0),
        vAxis: const Vector3D(0, 0, 1),
      ),
      boundary: Polygon2Mm(const [
        Point2Mm(0, 0),
        Point2Mm(6000, 0),
        Point2Mm(6000, 3200),
        Point2Mm(0, 3200),
      ]),
      orientation: SurfaceOrientation.vertical,
    );
    final geometry = DriftGeometryRepository(
      database,
      originDeviceId: 'component-test-device',
      clock: () => DateTime.utc(2026, 10, 12, 16),
    );
    await geometry.replaceRoomGeometry(
      RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
    );

    var components = DriftComponentInstanceRepository(
      database,
      originDeviceId: 'component-test-device',
      clock: () => DateTime.utc(2026, 10, 12, 17),
    );
    const instance = ComponentInstance(
      id: 'socket-001',
      definitionId: 'system-socket-230v',
      definitionVersion: 4,
      roomId: 'room-components',
      hostSurfacePatchId: 'wall-components',
      localPosition: Point2Mm(1250, 300),
      rotationRadians: 0.25,
      displayNameOverride: 'Bench socket',
      metadataOverrides: {'circuitHint': 'C-12'},
    );

    await components.replaceRoomComponents(
      roomId: room.id,
      instances: const [instance],
    );
    await database.close();

    database = openDatabase();
    components = DriftComponentInstanceRepository(
      database,
      originDeviceId: 'component-test-device',
    );
    final restored = await components.loadRoomComponents(room.id);

    expect(restored, hasLength(1));
    final restoredInstance = restored.single;
    expect(restoredInstance.id, instance.id);
    expect(restoredInstance.definitionId, instance.definitionId);
    expect(restoredInstance.definitionVersion, instance.definitionVersion);
    expect(restoredInstance.roomId, room.id);
    expect(restoredInstance.hostSurfacePatchId, patch.id);
    expect(restoredInstance.localPosition, const Point2Mm(1250, 300));
    expect(restoredInstance.rotationRadians, 0.25);
    expect(restoredInstance.displayNameOverride, 'Bench socket');
    expect(restoredInstance.metadataOverrides['circuitHint'], 'C-12');

    final history = ComponentPlacementHistory(components);
    history.record(restoredInstance);
    await history.undo();
    expect(await components.loadRoomComponents(room.id), isEmpty);
    var row = await database.select(database.componentInstances).getSingle();
    expect(row.deletedAt, isNotNull);
    expect(row.revision, 2);
    final createdAt = row.createdAt;
    await history.redo();
    row = await database.select(database.componentInstances).getSingle();
    expect(row.deletedAt, isNull);
    expect(row.revision, 3);
    expect(row.createdAt, createdAt);
    expect(
      (await components.loadRoomComponents(room.id)).single.id,
      instance.id,
    );
    expect(
      (await components.loadRoomComponents(room.id)).single.localPosition,
      instance.localPosition,
    );

    // A new placement invalidates redo, without replacing another component.
    await history.undo();
    const second = ComponentInstance(
      id: 'socket-002',
      definitionId: 'system-socket-230v',
      definitionVersion: 4,
      roomId: 'room-components',
      hostSurfacePatchId: 'wall-components',
      localPosition: Point2Mm(2000, 500),
    );
    await components.saveComponent(second);
    history.record(second);
    expect(history.canRedo, isFalse);
    await history.undo();
    await history.redo();
    expect((await components.loadRoomComponents(room.id)).single.id, second.id);
    await database.close();
    database = openDatabase();
    components = DriftComponentInstanceRepository(
      database,
      originDeviceId: 'component-test-device',
    );
    expect((await components.loadRoomComponents(room.id)).single.id, second.id);

    await database.close();
    await directory.delete(recursive: true);
  });

  test('schema v2 upgrades to v3 without losing persisted geometry', () async {
    final directory = await Directory.systemTemp.createTemp('electra-v2-v3-');
    final file = File('${directory.path}/electra.sqlite');
    AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

    var database = openDatabase();
    final hierarchy = DriftProjectHierarchyRepository(database);
    final hierarchyService = ProjectHierarchyService(
      projects: hierarchy,
      floors: hierarchy,
      rooms: hierarchy,
      unitOfWork: DriftUnitOfWork(database),
      idGenerator: FixedSequenceIdGenerator(const [
        'project-v2-v3',
        'floor-v2-v3',
        'room-v2-v3',
      ]),
      originDeviceId: 'migration-test-device',
      clock: () => DateTime.utc(2026, 10, 12, 18),
    );

    final project = await hierarchyService.createProject(
      const ProjectFormDraft(
        name: 'Migration Project',
        reference: 'M-23',
        measurementSystem: MeasurementSystem.metric,
        defaultStructuralHeightMm: 3200,
        defaultFinishedCeilingHeightMm: 3000,
      ),
    );
    final floor = await hierarchyService.createFloor(
      projectId: project.id,
      draft: const FloorFormDraft(name: 'Floor 02', code: 'F02', sortOrder: 2),
    );
    final room = await hierarchyService.createRoom(
      floorId: floor.id,
      draft: const RoomFormDraft(
        name: 'Migration Workshop',
        type: RoomType.workshop,
        category: RoomCategory.technical,
        widthMm: 5000,
        depthMm: 4000,
      ),
    );

    final patch = SurfacePatch(
      id: 'migration-wall',
      roomId: room.id,
      surfaceId: 'Migration Wall',
      frame: LocalCoordinateFrame(
        origin: const Point3Mm(0, 0, 0),
        uAxis: const Vector3D(1, 0, 0),
        vAxis: const Vector3D(0, 0, 1),
      ),
      boundary: Polygon2Mm(const [
        Point2Mm(0, 0),
        Point2Mm(5000, 0),
        Point2Mm(5000, 3000),
        Point2Mm(0, 3000),
      ]),
      orientation: SurfaceOrientation.vertical,
    );
    final geometry = DriftGeometryRepository(
      database,
      originDeviceId: 'migration-test-device',
    );
    await geometry.replaceRoomGeometry(
      RoomGeometrySnapshot(roomId: room.id, patches: [patch]),
    );

    await database.customStatement('DROP TABLE engineering_port_connections');
    await database.customStatement('DROP TABLE engineering_internal_mappings');
    await database.customStatement(
      'DROP TABLE engineering_component_assemblies',
    );
    await database.customStatement('DROP TABLE engineering_topology_groups');
    await database.customStatement(
      'DROP TABLE engineering_compatibility_profiles',
    );
    await database.customStatement('DROP TABLE engineering_topology_profiles');
    await database.customStatement('DROP TABLE engineering_assembly_profiles');
    await database.customStatement('DROP TABLE engineering_port_instances');
    await database.customStatement(
      'DROP TABLE component_engineering_memberships',
    );
    await database.customStatement('DROP TABLE project_engineering_systems');
    await database.customStatement('DROP TABLE engineering_family_definitions');
    await database.customStatement('DROP TABLE panel_generation_configs');
    await database.customStatement('DROP TABLE circuit_product_selections');
    await database.customStatement('DROP TABLE manufacturer_policies');
    await database.customStatement('DROP TABLE manufacturer_products');
    await database.customStatement('DROP TABLE manufacturer_catalogs');
    await database.customStatement('DROP TABLE circuit_protection_settings');
    await database.customStatement('DROP TABLE protection_rulesets');
    await database.customStatement('DROP TABLE normative_documents');
    await database.customStatement('DROP TABLE project_derived_results');
    await database.customStatement('DROP TABLE floor_panel_feeds');
    await database.customStatement('DROP TABLE floor_routing_handoffs');
    await database.customStatement('DROP TABLE floor_routing_panels');
    await database.customStatement('DROP TABLE junction_connections');
    await database.customStatement('DROP TABLE routing_junctions');
    await database.customStatement('DROP TABLE cable_runs');
    await database.customStatement('DROP TABLE cable_route_segments');
    await database.customStatement('DROP TABLE cable_route_nodes');
    await database.customStatement('DROP TABLE cable_routes');
    await database.customStatement('DROP TABLE physical_channels');
    await database.customStatement('DROP TABLE circuit_load_assignments');
    await database.customStatement('DROP TABLE electrical_circuits');
    await database.customStatement('DROP TABLE equipment_electrical_loads');
    await database.customStatement('DROP TABLE consumption_groups');
    await database.customStatement('DROP TABLE component_instances');
    await database.customStatement('DROP TABLE component_catalog_preferences');
    await database.customStatement('DROP TABLE component_reference_bindings');
    await database.customStatement('DROP TABLE engineering_reference_catalogs');
    await database.customStatement('PRAGMA user_version = 2');
    await database.close();

    database = openDatabase();
    final restoredGeometry = await DriftGeometryRepository(
      database,
      originDeviceId: 'migration-test-device',
    ).loadRoomGeometry(room.id);
    final tables =
        await database
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
    final names = tables.map((row) => row.read<String>('name')).toSet();

    expect(database.schemaVersion, 16);
    expect(names, contains('component_instances'));
    expect(restoredGeometry.patches, hasLength(1));
    expect(restoredGeometry.patches.single.id, patch.id);
    expect(restoredGeometry.validate(), isEmpty);

    await database.close();
    await directory.delete(recursive: true);
  });
}
