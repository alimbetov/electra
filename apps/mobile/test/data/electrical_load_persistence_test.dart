import 'package:electra_mobile/data/repositories/drift_electrical_load_repository.dart';
import 'package:electra_mobile/data/repositories/drift_catalog_preferences_repository.dart';

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
  test(
    'loads and groups survive restart, enforce room ownership and restore with equipment',
    () async {
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
        draft: const FloorFormDraft(
          name: 'Floor 01',
          code: 'F01',
          sortOrder: 1,
        ),
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
      var loads = DriftElectricalLoadRepository(
        database,
        originDeviceId: 'load-test',
      );
      const group = RoomConsumptionGroup(
        id: 'group-motors',
        roomId: 'room-components',
        name: 'Motors',
      );
      await loads.saveGroup(group);
      const profile = ElectricalLoadProfile(
        nominalVoltageV: 400,
        phases: 3,
        supplySystem: SupplySystem.threePhaseAc,
        phaseConfiguration: PhaseConfiguration.l1L2L3,
        frequencyHz: 50,
        ratedPowerW: 7500,
        ratedCurrentA: 15.2,
        powerFactor: 0.87,
        efficiency: 0.92,
        startingMethod: StartingMethod.vfd,
        startingCurrentFactor: 1.5,
        loadType: 'MOTOR',
        dedicatedCircuitRecommended: true,
        requiresNeutral: false,
        requiresProtectiveEarth: true,
      );
      const load = EquipmentElectricalLoad(
        componentInstanceId: 'motor-001',
        profile: profile,
        consumptionGroupId: 'group-motors',
      );
      await loads.saveLoad(load);
      await database.close();
      database = openDatabase();
      loads = DriftElectricalLoadRepository(
        database,
        originDeviceId: 'load-test',
      );
      final restored = (await loads.loadRoomLoads(room.id)).single;
      expect(restored.componentInstanceId, instance.id);
      expect(restored.consumptionGroupId, group.id);
      expect((await loads.loadRoomGroups(room.id)).single.name, group.name);
      final restoredProfile = restored.profile;
      expect(restoredProfile.nominalVoltageV, profile.nominalVoltageV);
      expect(restoredProfile.phases, profile.phases);
      expect(restoredProfile.supplySystem, profile.supplySystem);
      expect(restoredProfile.phaseConfiguration, profile.phaseConfiguration);
      expect(restoredProfile.frequencyHz, profile.frequencyHz);
      expect(restoredProfile.ratedPowerW, profile.ratedPowerW);
      expect(restoredProfile.ratedCurrentA, profile.ratedCurrentA);
      expect(restoredProfile.powerFactor, profile.powerFactor);
      expect(restoredProfile.efficiency, profile.efficiency);
      expect(restoredProfile.startingMethod, profile.startingMethod);
      expect(
        restoredProfile.startingCurrentFactor,
        profile.startingCurrentFactor,
      );
      expect(restoredProfile.loadType, profile.loadType);
      expect(
        restoredProfile.dedicatedCircuitRecommended,
        profile.dedicatedCircuitRecommended,
      );
      expect(restoredProfile.requiresNeutral, profile.requiresNeutral);
      expect(
        restoredProfile.requiresProtectiveEarth,
        profile.requiresProtectiveEarth,
      );
      final reopenedComponents = DriftComponentInstanceRepository(
        database,
        originDeviceId: 'load-test',
      );
      final activeEvents = loads
          .watchRoomLoads(room.id)
          .map((values) => values.length);
      final subscription = activeEvents.listen((_) {});
      await reopenedComponents.removeComponent(instance.id);
      expect(await loads.loadRoomLoads(room.id), isEmpty);
      expect(
        await database.select(database.equipmentElectricalLoads).get(),
        hasLength(1),
      );
      await expectLater(loads.saveLoad(load), throwsStateError);
      await reopenedComponents.saveComponent(instance);
      expect(
        (await loads.loadRoomLoads(room.id)).single.profile.ratedPowerW,
        7500,
      );
      await subscription.cancel();

      await expectLater(
        loads.saveLoad(
          const EquipmentElectricalLoad(
            componentInstanceId: 'motor-001',
            profile: ElectricalLoadProfile(
              nominalVoltageV: 230,
              phases: 1,
              ratedPowerW: -1,
            ),
          ),
        ),
        throwsArgumentError,
      );
      expect(
        (await loads.loadRoomLoads(room.id)).single.profile.ratedPowerW,
        7500,
      );
      // Seed another room through the same hierarchy repository on the reopened DB.
      final otherHierarchy = DriftProjectHierarchyRepository(database);
      final otherService = ProjectHierarchyService(
        projects: otherHierarchy,
        floors: otherHierarchy,
        rooms: otherHierarchy,
        unitOfWork: DriftUnitOfWork(database),
        idGenerator: FixedSequenceIdGenerator(const ['room-other']),
        originDeviceId: 'load-test',
      );
      final otherRoom = await otherService.createRoom(
        floorId: floor.id,
        draft: const RoomFormDraft(
          name: 'Other room',
          type: RoomType.workshop,
          category: RoomCategory.technical,
          widthMm: 4000,
          depthMm: 3000,
        ),
      );
      await loads.saveGroup(
        RoomConsumptionGroup(
          id: 'group-other',
          roomId: otherRoom.id,
          name: 'Other',
        ),
      );
      await expectLater(
        loads.saveLoad(
          const EquipmentElectricalLoad(
            componentInstanceId: 'motor-001',
            profile: profile,
            consumptionGroupId: 'group-other',
          ),
        ),
        throwsStateError,
      );
      await expectLater(
        loads.saveLoad(
          const EquipmentElectricalLoad(
            componentInstanceId: 'missing',
            profile: profile,
          ),
        ),
        throwsStateError,
      );
      await loads.saveLoad(
        const EquipmentElectricalLoad(
          componentInstanceId: 'motor-001',
          profile: profile,
        ),
      );
      final updated =
          await database.select(database.equipmentElectricalLoads).getSingle();
      expect(updated.revision, 2);
      expect(updated.consumptionGroupId, isNull);

      // Upgrade a v4 fixture, preserving preferences and the equipment instance.
      await DriftCatalogPreferencesRepository(
        database,
      ).setFavorite('motor', true);
      await database.customStatement('DROP TABLE equipment_electrical_loads');
      await database.customStatement('DROP TABLE consumption_groups');
      await database.customStatement('PRAGMA user_version = 4');
      await database.close();
      database = openDatabase();
      expect(
        (await DriftCatalogPreferencesRepository(database).load()).favoriteIds,
        {'motor'},
      );
      expect(
        (await DriftComponentInstanceRepository(
          database,
          originDeviceId: 'load-test',
        ).loadRoomComponents(room.id)).single.id,
        instance.id,
      );
      loads = DriftElectricalLoadRepository(
        database,
        originDeviceId: 'load-test',
      );
      await loads.saveGroup(group);
      await loads.saveLoad(load);
      expect(
        (await loads.loadRoomLoads(room.id)).single.componentInstanceId,
        instance.id,
      );
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
