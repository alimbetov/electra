import 'package:electra_mobile/data/repositories/drift_dependency_recalculation_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_system_repository.dart';

import 'dart:async';

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
  test('engineering systems pin families and share physical devices with project and deletion invariants', () async {
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
        'room-other',
        'other-project',
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

    final components = DriftComponentInstanceRepository(
      database,
      originDeviceId: 'load-test',
    );
    const instance = ComponentInstance(
      id: 'motor-001',
      definitionId: 'motor',
      definitionVersion: 1,
      roomId: 'room-components',
      hostSurfacePatchId: 'wall-components',
      localPosition: Point2Mm(1250, 300),
    );
    await components.saveComponent(instance);
    var systems = DriftEngineeringSystemRepository(
      database,
      originDeviceId: 'elv-test',
    );
    var data = await systems.load(project.id);
    expect(data.families.length, 16);
    expect(data.components.single.id, instance.id);
    EngineeringSystem network(String id, String code, String familyCode) {
      final family = data.families.firstWhere((f) => f.code == familyCode);
      return EngineeringSystem(
        id: id,
        projectId: project.id,
        code: code,
        name: code,
        familyId: family.id,
        familyVersion: family.version,
      );
    }

    final cctv = network('cctv', 'CCTV-01', 'CCTV'),
        lan = network('lan', 'LAN-01', 'LAN');
    await systems.saveSystem(cctv);
    await systems.saveSystem(lan);
    await systems.saveSystem(network('cctv2', 'CCTV-02', 'CCTV'));
    await expectLater(
      systems.saveSystem(network('duplicate', 'cctv-01', 'CCTV')),
      throwsStateError,
    );
    const video = ComponentSystemMembership(
      systemId: 'cctv',
      componentId: 'motor-001',
      role: 'VIDEO_SOURCE',
    );
    const transport = ComponentSystemMembership(
      systemId: 'lan',
      componentId: 'motor-001',
      role: 'NETWORK_ENDPOINT',
    );
    final events = StreamIterator(systems.watch(project.id));
    expect(await events.moveNext(), isTrue);
    final participation = () async {
      while (await events.moveNext()) {
        if (events.current.memberships.length == 1) return;
      }
      throw StateError('No membership event');
    }();
    await systems.assign(project.id, video);
    await participation.timeout(const Duration(seconds: 10));
    await events.cancel();
    await systems.assign(project.id, transport);
    await systems.assign(project.id, transport);
    data = await systems.load(project.id);
    expect(data.memberships.length, 2);
    expect(data.components.length, 1);
    expect(
      (await database.select(database.componentInstances).get()).single.id,
      instance.id,
    );
    await expectLater(
      systems.archiveSystem(project.id, cctv.id),
      throwsStateError,
    );
    await expectLater(
      systems.saveSystem(
        EngineeringSystem(
          id: cctv.id,
          projectId: project.id,
          code: cctv.code,
          name: 'Renamed',
          familyId: lan.familyId,
          familyVersion: lan.familyVersion,
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      systems.assign(
        project.id,
        const ComponentSystemMembership(
          systemId: 'cctv',
          componentId: 'missing',
          role: 'SOURCE',
        ),
      ),
      throwsStateError,
    );
    const custom = EngineeringSystemFamily(
      id: 'custom-v1',
      code: 'custom-bus',
      name: 'Custom bus',
      version: '1',
      source: 'Fictional custom reference',
      routingClass: 'SIGNAL',
    );
    await systems.saveFamily(custom);
    await systems.saveFamily(custom);
    await expectLater(
      systems.saveFamily(
        const EngineeringSystemFamily(
          id: 'custom-v1',
          code: 'CUSTOM-BUS',
          name: 'Changed',
          version: '1',
          source: 'Other',
          routingClass: 'SIGNAL',
        ),
      ),
      throwsStateError,
    );
    await systems.saveFamily(
      const EngineeringSystemFamily(
        id: 'custom-v2',
        code: 'CUSTOM-BUS',
        name: 'New edition',
        version: '2',
        source: 'New authored reference',
        routingClass: 'SIGNAL',
      ),
    );
    final customSystem = EngineeringSystem(
      id: 'custom',
      projectId: project.id,
      code: 'BUS-01',
      name: 'Bus',
      familyId: custom.id,
      familyVersion: '1',
    );
    await systems.saveSystem(customSystem);
    // Other project cannot claim this placed device or re-use a network identity.
    final other = await hierarchyService.createProject(
      const ProjectFormDraft(
        name: 'Other',
        reference: 'OTHER',
        measurementSystem: MeasurementSystem.metric,
        defaultStructuralHeightMm: 3200,
        defaultFinishedCeilingHeightMm: 3000,
      ),
    );
    await systems.saveSystem(
      EngineeringSystem(
        id: 'other-system',
        projectId: other.id,
        code: 'CCTV-01',
        name: 'Other CCTV',
        familyId: cctv.familyId,
        familyVersion: cctv.familyVersion,
      ),
    );
    await expectLater(
      systems.assign(
        other.id,
        const ComponentSystemMembership(
          systemId: 'other-system',
          componentId: 'motor-001',
          role: 'SOURCE',
        ),
      ),
      throwsStateError,
    );
    await expectLater(
      systems.saveSystem(
        EngineeringSystem(
          id: cctv.id,
          projectId: other.id,
          code: 'MOVED',
          name: 'Moved',
          familyId: cctv.familyId,
          familyVersion: cctv.familyVersion,
        ),
      ),
      throwsStateError,
    );
    await database.close();
    database = openDatabase();
    systems = DriftEngineeringSystemRepository(
      database,
      originDeviceId: 'elv-restart',
    );
    data = await systems.load(project.id);
    expect(data.memberships.length, 2);
    expect(data.systems.firstWhere((s) => s.id == 'custom').familyVersion, '1');
    expect(data.components.single.id, instance.id);
    final before = await DriftDependencyRecalculationRepository(
      database,
      originDeviceId: 'elv-test',
    ).load(project.id);
    await systems.detach(project.id, cctv.id, instance.id);
    await systems.archiveSystem(project.id, cctv.id);
    data = await systems.load(project.id);
    expect(data.systems.any((s) => s.id == cctv.id), isFalse);
    expect(data.archivedSystems.single.id, cctv.id);
    expect(data.memberships.single.systemId, lan.id);
    final after = await DriftDependencyRecalculationRepository(
      database,
      originDeviceId: 'elv-test',
    ).load(project.id);
    expect(after.session.fingerprints, before.session.fingerprints);
    await systems.saveSystem(cctv);
    data = await systems.load(project.id);
    expect(data.memberships.where((m) => m.systemId == cctv.id), isEmpty);
    expect(data.archivedSystems, isEmpty);
    // Preserve legacy placement across v13 -> v14 upgrade.
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
    await database.customStatement('DROP TABLE component_reference_bindings');
    await database.customStatement('DROP TABLE engineering_reference_catalogs');
    await database.customStatement('PRAGMA user_version = 13');
    await database.close();
    database = openDatabase();
    systems = DriftEngineeringSystemRepository(
      database,
      originDeviceId: 'elv-migration',
    );
    data = await systems.load(project.id);
    expect(database.schemaVersion, 21);
    expect(data.systems, isEmpty);
    expect(data.components.single.id, instance.id);
    expect(data.families.length, 16);
    await database.close();
    await directory.delete(recursive: true);
  });
}
