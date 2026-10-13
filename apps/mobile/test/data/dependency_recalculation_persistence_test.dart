import 'package:electra_mobile/data/repositories/drift_electrical_circuit_repository.dart';
import 'package:electra_mobile/data/repositories/drift_electrical_load_repository.dart';
import 'package:electra_mobile/data/repositories/drift_dependency_recalculation_repository.dart';
import 'package:electra_mobile/data/repositories/drift_cable_routing_repository.dart';
import 'package:electra_mobile/data/repositories/drift_floor_routing_repository.dart';
import 'dart:async';
import 'dart:convert';

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
    'affected recalculation persists, isolates circuits, preserves manual decisions and migrates',
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

      await components.saveComponent(
        ComponentInstance(
          id: 'motor-002',
          definitionId: 'motor',
          definitionVersion: 1,
          roomId: room.id,
          hostSurfacePatchId: patch.id,
          localPosition: const Point2Mm(2000, 300),
        ),
      );
      await loads.saveLoad(
        const EquipmentElectricalLoad(
          componentInstanceId: 'motor-002',
          profile: ElectricalLoadProfile(
            nominalVoltageV: 230,
            phases: 1,
            ratedPowerW: 1150,
            powerFactor: 1,
          ),
          powerBasis: ElectricalPowerBasis.electricalInput,
        ),
      );
      await circuits.saveCircuit(
        ElectricalCircuit(
          id: 'circuit-2',
          roomId: room.id,
          name: 'Independent circuit',
          inputs: const ElectricalCircuitInputs(
            nominalVoltageV: 230,
            phases: 1,
            supplySystem: SupplySystem.singlePhaseAc,
          ),
          loadIds: const ['motor-002'],
        ),
      );
      await circuits.confirmCircuit('circuit-1');
      var sequence = 0;
      final routing = DriftCableRoutingRepository(
        database,
        originDeviceId: 'recalculation-test',
      );
      for (final index in [1, 2]) {
        final draft =
            SurfaceRouteDraft(nextId: () => 'recalc-node-${sequence++}')
              ..addPoint(patch, Point2Mm(100, 1000 * index))
              ..addPoint(patch, Point2Mm(2000, 1000 * index));
        final route = draft.route(
          id: 'route-$index',
          roomId: room.id,
          name: 'Route $index',
        );
        await routing.saveRouteWithRun(
          route: route,
          run: CableRun(
            id: 'run-$index',
            roomId: room.id,
            name: 'Cable $index',
            circuitId: 'circuit-$index',
            routeId: route.id,
          ),
        );
      }
      final floorRepository = DriftFloorRoutingRepository(
        database,
        originDeviceId: 'recalculation-test',
      );
      final graph = (await floorRepository.load(floor.id)).graph();
      for (final index in [1, 2]) {
        await floorRepository.savePanel(
          FloorRoutingPanel(
            id: 'panel-$index',
            floorId: floor.id,
            code: 'DB-$index',
            name: 'Panel $index',
            feeds: [
              FloorPanelFeed(
                runId: 'run-$index',
                endpointSignature: graph.runs['run-$index']!.endpointSignature(
                  start: true,
                ),
              ),
            ],
          ),
        );
      }
      var repository = DriftDependencyRecalculationRepository(
        database,
        originDeviceId: 'recalculation-test',
      );
      expect((await repository.recalculate(project.id)).length, 13);
      var snapshot = await repository.load(project.id);
      expect(snapshot.session.affectedKeys, isEmpty);
      expect(
        snapshot
            .session
            .cache['circuit:circuit-1']!
            .proposal
            .values['designCurrentA'],
        8,
      );
      expect(
        snapshot
            .session
            .cache['route:route-1']!
            .proposal
            .values['geometricLengthMm'],
        1900,
      );
      await repository.saveManualDecision(
        projectId: project.id,
        key: 'cable:run-1',
        value: 'Installation decision A',
        reason: 'Site requirement',
      );
      await repository.recalculate(project.id);
      final original =
          (await database.select(database.projectDerivedResults).get());
      final revisions = {for (final row in original) row.nodeKey: row.revision};
      await loads.saveLoad(load); // Same semantic input, new SQL revision.
      expect((await repository.load(project.id)).session.affectedKeys, isEmpty);
      final events = StreamIterator(repository.watch(project.id));
      expect(await events.moveNext(), isTrue);
      expect(events.current.session.affectedKeys, isEmpty);
      Future<void> waitForStale() async {
        while (await events.moveNext()) {
          if (events.current.session.affectedKeys.contains('circuit:circuit-1'))
            return;
        }
        throw StateError('No invalidation event.');
      }

      final stale = waitForStale().timeout(const Duration(seconds: 10));
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
      await stale;
      await events.cancel();
      snapshot = await repository.load(project.id);
      final expected = {
        'consumer:motor-001',
        'circuit:circuit-1',
        'cable:run-1',
        'protection:circuit-1',
        'panel:panel-1',
      };
      expect(snapshot.session.affectedKeys, expected);
      expect(
        snapshot.session.state('cable:run-1'),
        EngineeringDerivedState.reviewRequired,
      );
      await expectLater(
        repository.reviewManualDecision(project.id, 'cable:run-1'),
        throwsStateError,
      );
      expect(await repository.recalculate(project.id), expected);
      snapshot = await repository.load(project.id);
      expect(
        snapshot
            .session
            .cache['circuit:circuit-1']!
            .proposal
            .values['designCurrentA'],
        16,
      );
      expect(
        snapshot.session.cache['cable:run-1']!.manualValue,
        'Installation decision A',
      );
      expect(
        snapshot.session.state('cable:run-1'),
        EngineeringDerivedState.reviewRequired,
      );
      expect(
        snapshot.session.cache['protection:circuit-1']!.proposal.values
            .containsKey('breakerRatingA'),
        isFalse,
      );
      final after = await database.select(database.projectDerivedResults).get();
      for (final row in after.where((r) => !expected.contains(r.nodeKey))) {
        expect(row.revision, revisions[row.nodeKey]);
        final prior = original.firstWhere((p) => p.nodeKey == row.nodeKey);
        expect(row.resultJson, prior.resultJson);
        expect(row.updatedAt, prior.updatedAt);
      }
      final diff =
          jsonDecode(snapshot.session.cache['circuit:circuit-1']!.changesJson)
              as List;
      expect(
        diff.any(
          (change) =>
              change['field'] == 'ratedPowerW' &&
              change['before'] == 2300 &&
              change['after'] == 4600,
        ),
        isTrue,
      );
      await database.close();
      database = openDatabase();
      repository = DriftDependencyRecalculationRepository(
        database,
        originDeviceId: 'recalculation-test',
      );
      snapshot = await repository.load(project.id);
      expect(
        snapshot
            .session
            .cache['circuit:circuit-1']!
            .proposal
            .values['designCurrentA'],
        16,
      );
      expect(
        snapshot.session.cache['cable:run-1']!.manualReason,
        'Site requirement',
      );
      await repository.reviewManualDecision(project.id, 'cable:run-1');
      expect(
        (await repository.load(project.id)).session.state('cable:run-1'),
        EngineeringDerivedState.current,
      );
      await repository.recalculate(project.id);
      expect(await repository.recalculate(project.id), isEmpty);
      expect(
        (await DriftElectricalCircuitRepository(
          database,
          originDeviceId: 'recalculation-test',
        ).loadRoomCircuits(
          room.id,
        )).firstWhere((s) => s.circuit.id == 'circuit-1').status,
        CircuitStatus.reviewRequired,
      );
      // A deleted consumer prevents partial circuit/cable totals.
      await DriftComponentInstanceRepository(
        database,
        originDeviceId: 'recalculation-test',
      ).removeComponent('motor-001');
      await repository.recalculate(project.id);
      snapshot = await repository.load(project.id);
      expect(
        snapshot.session.cache['circuit:circuit-1']!.state,
        EngineeringDerivedState.error,
      );
      expect(snapshot.session.cache['cable:run-1']!.proposal.values, isEmpty);
      expect(
        snapshot
            .session
            .cache['circuit:circuit-2']!
            .proposal
            .values['designCurrentA'],
        5,
      );
      await database.customStatement('DROP TABLE engineering_port_connections');
      await database.customStatement(
        'DROP TABLE engineering_internal_mappings',
      );
      await database.customStatement(
        'DROP TABLE engineering_component_assemblies',
      );
      await database.customStatement('DROP TABLE engineering_topology_groups');
      await database.customStatement(
        'DROP TABLE engineering_compatibility_profiles',
      );
      await database.customStatement(
        'DROP TABLE engineering_topology_profiles',
      );
      await database.customStatement(
        'DROP TABLE engineering_assembly_profiles',
      );
      await database.customStatement('DROP TABLE engineering_port_instances');
      await database.customStatement(
        'DROP TABLE component_engineering_memberships',
      );
      await database.customStatement('DROP TABLE project_engineering_systems');
      await database.customStatement(
        'DROP TABLE engineering_family_definitions',
      );
      await database.customStatement('DROP TABLE panel_generation_configs');
      await database.customStatement('DROP TABLE circuit_product_selections');
      await database.customStatement('DROP TABLE manufacturer_policies');
      await database.customStatement('DROP TABLE manufacturer_products');
      await database.customStatement('DROP TABLE manufacturer_catalogs');
      await database.customStatement('DROP TABLE circuit_protection_settings');
      await database.customStatement('DROP TABLE protection_rulesets');
      await database.customStatement('DROP TABLE normative_documents');
      await database.customStatement('DROP TABLE project_derived_results');
      await database.customStatement('DROP TABLE component_reference_bindings');
      await database.customStatement(
        'DROP TABLE engineering_reference_catalogs',
      );
      await database.customStatement('PRAGMA user_version = 9');
      await database.close();
      database = openDatabase();
      repository = DriftDependencyRecalculationRepository(
        database,
        originDeviceId: 'recalculation-test',
      );
      snapshot = await repository.load(project.id);
      expect(snapshot.session.cache, isEmpty);
      expect(database.schemaVersion, 17);
      expect(
        (await DriftElectricalCircuitRepository(
          database,
          originDeviceId: 'recalculation-test',
        ).loadRoomCircuits(room.id)).length,
        2,
      );
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
