import 'package:electra_mobile/data/repositories/drift_electrical_circuit_repository.dart';
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
    'group circuit proposal survives reopen and reacts to live loads with guarded assignments',
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
        originDeviceId: 'circuit-test',
      );
      const group = RoomConsumptionGroup(
        id: 'group-motors',
        roomId: 'room-components',
        name: 'Workshop sockets',
      );
      await loads.saveGroup(group);
      const profile = ElectricalLoadProfile(
        nominalVoltageV: 230,
        phases: 1,
        ratedPowerW: 2300,
        powerFactor: 1,
      );
      const load = EquipmentElectricalLoad(
        componentInstanceId: 'motor-001',
        consumptionGroupId: 'group-motors',
        profile: profile,
        powerBasis: ElectricalPowerBasis.electricalInput,
      );
      await loads.saveLoad(load);
      var circuits = DriftElectricalCircuitRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      await circuits.createFromGroup(
        circuitId: 'circuit-1',
        groupId: group.id,
        name: 'Workshop circuit',
        demandFactor: 0.8,
      );
      var snapshot = (await circuits.loadRoomCircuits(room.id)).single;
      expect(snapshot.circuit.loadIds, [instance.id]);
      expect(snapshot.circuit.sourceGroupId, group.id);
      expect(snapshot.calculation.designCurrentA, 8);
      expect(snapshot.status, CircuitStatus.proposed);
      await circuits.confirmCircuit('circuit-1');
      snapshot = (await circuits.loadRoomCircuits(room.id)).single;
      expect(snapshot.status, CircuitStatus.confirmed);
      final signature = snapshot.calculation.inputSignature;
      await database.close();
      database = openDatabase();
      circuits = DriftElectricalCircuitRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      loads = DriftElectricalLoadRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      snapshot = (await circuits.loadRoomCircuits(room.id)).single;
      expect(snapshot.status, CircuitStatus.confirmed);
      expect(snapshot.calculation.inputSignature, signature);
      expect(snapshot.calculation.designCurrentA, 8);
      expect(
        (await loads.loadRoomLoads(room.id)).single.powerBasis,
        ElectricalPowerBasis.electricalInput,
      );

      // Watch results must update even when the circuit row itself is unchanged.
      final changedFuture = circuits
          .watchRoomCircuits(room.id)
          .firstWhere((items) => items.single.calculation.designCurrentA == 16)
          .timeout(const Duration(seconds: 10));
      await loads.saveLoad(
        const EquipmentElectricalLoad(
          componentInstanceId: 'motor-001',
          consumptionGroupId: 'group-motors',
          profile: ElectricalLoadProfile(
            nominalVoltageV: 230,
            phases: 1,
            ratedPowerW: 4600,
            powerFactor: 1,
          ),
          powerBasis: ElectricalPowerBasis.electricalInput,
        ),
      );
      final changed = (await changedFuture).single;
      expect(changed.status, CircuitStatus.reviewRequired);
      await circuits.confirmCircuit('circuit-1');
      expect(
        (await circuits.loadRoomCircuits(room.id)).single.status,
        CircuitStatus.confirmed,
      );
      final componentRepo = DriftComponentInstanceRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      await componentRepo.removeComponent(instance.id);
      snapshot = (await circuits.loadRoomCircuits(room.id)).single;
      expect(snapshot.calculation.designCurrentA, isNull);
      expect(snapshot.calculation.issues.single.code, 'LOAD_UNAVAILABLE');
      expect(snapshot.circuit.loadIds, [instance.id]);
      await expectLater(circuits.confirmCircuit('circuit-1'), throwsStateError);
      await componentRepo.saveComponent(instance);
      expect(
        (await circuits.loadRoomCircuits(
          room.id,
        )).single.calculation.designCurrentA,
        16,
      );

      ElectricalCircuit draft(
        String id, {
        List<String> ids = const ['motor-001'],
        String? groupId,
        String? targetRoom,
      }) => ElectricalCircuit(
        id: id,
        roomId: targetRoom ?? room.id,
        name: 'New circuit',
        sourceGroupId: groupId,
        inputs: const ElectricalCircuitInputs(
          nominalVoltageV: 230,
          phases: 1,
          supplySystem: SupplySystem.singlePhaseAc,
        ),
        loadIds: ids,
      );
      await expectLater(
        circuits.saveCircuit(draft('conflict')),
        throwsStateError,
      );
      expect(
        await database.select(database.electricalCircuits).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.circuitLoadAssignments).get(),
        hasLength(1),
      );
      await expectLater(
        circuits.saveCircuit(
          draft('duplicate', ids: [instance.id, instance.id]),
        ),
        throwsArgumentError,
      );
      await expectLater(
        circuits.saveCircuit(draft('missing', ids: ['missing'])),
        throwsStateError,
      );
      expect(
        (await circuits.loadRoomCircuits(
          room.id,
        )).single.calculation.designCurrentA,
        16,
      );

      final otherHierarchy = DriftProjectHierarchyRepository(database);
      final otherService = ProjectHierarchyService(
        projects: otherHierarchy,
        floors: otherHierarchy,
        rooms: otherHierarchy,
        unitOfWork: DriftUnitOfWork(database),
        idGenerator: FixedSequenceIdGenerator(const ['room-other']),
        originDeviceId: 'circuit-test',
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
          id: 'other-group',
          roomId: otherRoom.id,
          name: 'Other group',
        ),
      );
      await expectLater(
        circuits.saveCircuit(draft('foreign-group', groupId: 'other-group')),
        throwsStateError,
      );
      await expectLater(
        circuits.saveCircuit(draft('foreign-load', targetRoom: otherRoom.id)),
        throwsStateError,
      );

      final originalRow =
          await database.select(database.electricalCircuits).getSingle();
      await circuits.saveCircuit(draft('circuit-1', ids: []));
      snapshot = (await circuits.loadRoomCircuits(room.id)).single;
      expect(snapshot.calculation.ready, isFalse);
      expect(snapshot.status, CircuitStatus.proposed);
      expect(
        await database.select(database.circuitLoadAssignments).get(),
        isEmpty,
      );
      final edited =
          await database.select(database.electricalCircuits).getSingle();
      expect(edited.revision, originalRow.revision + 1);
      expect(edited.createdAt, originalRow.createdAt);
      await circuits.saveCircuit(draft('circuit-2'));
      expect(
        (await circuits.loadRoomCircuits(room.id))
            .where((item) => item.circuit.id == 'circuit-2')
            .single
            .calculation
            .designCurrentA,
        20,
      );

      // Reconstruct a v5 database: legacy rated-power interpretation stays unknown.
      await DriftCatalogPreferencesRepository(
        database,
      ).setFavorite('motor', true);
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
      await database.customStatement(
        'ALTER TABLE equipment_electrical_loads DROP COLUMN power_basis',
      );
      await database.customStatement('PRAGMA user_version = 5');
      await database.close();
      database = openDatabase();
      loads = DriftElectricalLoadRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      expect((await loads.loadRoomLoads(room.id)).single.powerBasis, isNull);
      expect(
        (await DriftCatalogPreferencesRepository(database).load()).favoriteIds,
        {'motor'},
      );
      circuits = DriftElectricalCircuitRepository(
        database,
        originDeviceId: 'circuit-test',
      );
      await circuits.createFromGroup(
        circuitId: 'migrated-circuit',
        groupId: group.id,
        name: 'Migrated proposal',
      );
      snapshot = (await circuits.loadRoomCircuits(room.id)).single;
      expect(snapshot.calculation.designCurrentA, isNull);
      expect(snapshot.calculation.issues.single.code, 'MISSING_POWER_BASIS');
      await loads.saveLoad(load);
      expect(
        (await circuits.loadRoomCircuits(
          room.id,
        )).single.calculation.designCurrentA,
        10,
      );
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
