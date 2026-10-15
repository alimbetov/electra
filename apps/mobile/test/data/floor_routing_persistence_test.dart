import 'dart:io';
import 'dart:async';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/floor_routing_repository.dart';
import 'package:electra_mobile/data/repositories/drift_floor_routing_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_cable_routing_repository.dart';
import 'package:electra_mobile/data/repositories/drift_electrical_circuit_repository.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'floor source and inter-room physical trace survives restart and invalidates live',
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
          'floor-other',
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

      SurfacePatch patch(String id, {int shift = 0}) => SurfacePatch(
        id: id,
        roomId: room.id,
        surfaceId: id,
        frame: LocalCoordinateFrame(
          origin: Point3Mm((id == 'a' ? 0 : 4000) + shift, 0, 0),
          uAxis: id == 'a' ? const Vector3D(1, 0, 0) : const Vector3D(0, 1, 0),
          vAxis: const Vector3D(0, 0, 1),
        ),
        boundary: Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(4000, 0),
          Point2Mm(4000, 3000),
          Point2Mm(0, 3000),
        ]),
        orientation: SurfaceOrientation.vertical,
      );
      final patches = [patch('a'), patch('b')];
      final edges = [
        SurfaceEdge(
          id: 'ea',
          patchId: 'a',
          start: const Point2Mm(4000, 0),
          end: const Point2Mm(4000, 3000),
          kind: SurfaceEdgeKind.fold,
        ),
        SurfaceEdge(
          id: 'eb',
          patchId: 'b',
          start: const Point2Mm(0, 0),
          end: const Point2Mm(0, 3000),
          kind: SurfaceEdgeKind.fold,
        ),
      ];
      final adjacency = SurfaceAdjacency(
        id: 'ab',
        fromPatchId: 'a',
        fromEdgeId: 'ea',
        toPatchId: 'b',
        toEdgeId: 'eb',
      );
      RoomGeometrySnapshot geometrySnapshot({int shift = 0}) =>
          RoomGeometrySnapshot(
            roomId: room.id,
            patches: [patch('a', shift: shift), patch('b', shift: shift)],
            edges: edges,
            adjacencies: [adjacency],
          );
      await DriftGeometryRepository(
        database,
        originDeviceId: 'route-test',
      ).replaceRoomGeometry(geometrySnapshot());
      await DriftElectricalCircuitRepository(
        database,
        originDeviceId: 'route-test',
      ).saveCircuit(
        ElectricalCircuit(
          id: 'circuit',
          roomId: room.id,
          name: 'Workshop circuit',
          inputs: const ElectricalCircuitInputs(
            nominalVoltageV: 230,
            phases: 1,
            supplySystem: SupplySystem.singlePhaseAc,
          ),
          loadIds: const [],
        ),
      );
      var repository = DriftCableRoutingRepository(
        database,
        originDeviceId: 'route-test',
      );

      final secondRoom = await hierarchyService.createRoom(
        floorId: floor.id,
        draft: const RoomFormDraft(
          name: 'Hall',
          type: RoomType.workshop,
          category: RoomCategory.technical,
          widthMm: 6000,
          depthMm: 5000,
        ),
      );
      final otherFloor = await hierarchyService.createFloor(
        projectId: project.id,
        draft: const FloorFormDraft(
          name: 'Other floor',
          code: 'F02',
          sortOrder: 2,
        ),
      );
      final secondPatch = SurfacePatch(
        id: 'second-wall',
        roomId: secondRoom.id,
        surfaceId: 'second-wall',
        frame: patches.first.frame,
        boundary: patches.first.boundary,
        orientation: SurfaceOrientation.vertical,
      );
      await DriftGeometryRepository(
        database,
        originDeviceId: 'floor-test',
      ).replaceRoomGeometry(
        RoomGeometrySnapshot(roomId: secondRoom.id, patches: [secondPatch]),
      );
      await DriftElectricalCircuitRepository(
        database,
        originDeviceId: 'floor-test',
      ).saveCircuit(
        ElectricalCircuit(
          id: 'second-circuit',
          roomId: secondRoom.id,
          name: 'Hall circuit',
          inputs: const ElectricalCircuitInputs(
            nominalVoltageV: 230,
            demandFactor: 1,
            phases: 1,
            supplySystem: SupplySystem.singlePhaseAc,
          ),
          loadIds: const [],
        ),
      );
      final channelA = PhysicalChannel(
        id: 'channel-a',
        roomId: room.id,
        name: 'Conduit A',
        kind: PhysicalChannelKind.conduit,
      );
      final channelB = PhysicalChannel(
        id: 'channel-b',
        roomId: secondRoom.id,
        name: 'Conduit B',
        kind: PhysicalChannelKind.conduit,
      );
      await repository.saveChannel(channelA);
      await repository.saveChannel(channelB);
      var sequence = 0;
      CableRoute path(
        String id,
        SurfacePatch patch,
        PhysicalChannel channel, {
        int start = 100,
      }) {
        final draft =
            SurfaceRouteDraft(nextId: () => 'floor-node-${sequence++}')
              ..addPoint(patch, Point2Mm(start, 1000))
              ..addPoint(
                patch,
                const Point2Mm(2000, 1000),
                method: LayingMethod.conduit,
                channelId: channel.id,
              );
        return draft.route(id: id, roomId: patch.roomId, name: id);
      }

      final a = path('a-run', patches.first, channelA),
          b = path('b-run', secondPatch, channelB);
      CableRun run(CableRoute route) => CableRun(
        id: route.id,
        roomId: route.roomId,
        name: route.name,
        circuitId: route.roomId == room.id ? 'circuit' : 'second-circuit',
        routeId: route.id,
      );
      await repository.saveRouteWithRun(route: a, run: run(a));
      await repository.saveRouteWithRun(route: b, run: run(b));
      var floorRepository = DriftFloorRoutingRepository(
        database,
        originDeviceId: 'floor-test',
      );
      var snapshot = await floorRepository.load(floor.id);
      final graph = snapshot.graph();
      final panel = FloorRoutingPanel(
        id: 'panel',
        floorId: floor.id,
        code: 'DB-01',
        name: 'Floor source',
        feeds: [
          FloorPanelFeed(
            runId: a.id,
            endpointSignature: graph.runs[a.id]!.endpointSignature(start: true),
          ),
        ],
      );
      final handoff = FloorRoutingHandoff(
        id: 'handoff',
        floorId: floor.id,
        name: 'Hall handoff',
        fromRunId: a.id,
        toRunId: b.id,
        fromSignature: graph.runs[a.id]!.endpointSignature(start: false),
        toSignature: graph.runs[b.id]!.endpointSignature(start: true),
      );
      await floorRepository.savePanel(panel);
      await floorRepository.saveHandoff(handoff);
      await database.close();
      database = openDatabase();
      repository = DriftCableRoutingRepository(
        database,
        originDeviceId: 'floor-test',
      );
      floorRepository = DriftFloorRoutingRepository(
        database,
        originDeviceId: 'floor-test',
      );
      snapshot = await floorRepository.load(floor.id);
      expect(snapshot.project!.id, project.id);
      expect(snapshot.floor!.id, floor.id);
      expect(snapshot.rooms.length, 2);
      expect(
        snapshot.panels.single.feeds.single.endpointSignature,
        panel.feeds.single.endpointSignature,
      );
      expect(snapshot.handoffs.single.toSignature, handoff.toSignature);
      final trace = snapshot.graph().trace(b.id, FloorTraceDirection.upstream);
      expect(trace.runIds, {a.id, b.id});
      expect(trace.panelIds, {'panel'});
      expect(trace.issues, isEmpty);
      await expectLater(
        floorRepository.savePanel(
          FloorRoutingPanel(
            id: 'bad',
            floorId: otherFloor.id,
            code: 'bad',
            name: 'bad',
            feeds: panel.feeds,
          ),
        ),
        throwsStateError,
      );
      final cycle = FloorRoutingHandoff(
        id: 'cycle',
        floorId: floor.id,
        name: 'Cycle',
        fromRunId: b.id,
        toRunId: a.id,
        fromSignature: snapshot.graph().runs[b.id]!.endpointSignature(
          start: false,
        ),
        toSignature: snapshot.graph().runs[a.id]!.endpointSignature(
          start: true,
        ),
      );
      await expectLater(floorRepository.saveHandoff(cycle), throwsStateError);
      expect((await floorRepository.load(floor.id)).handoffs.length, 1);
      await floorRepository.savePanel(panel);
      final panelRow =
          await (database.select(database.floorRoutingPanels)
            ..where((r) => r.id.equals('panel'))).getSingle();
      expect(panelRow.revision, 2);
      final events = StreamIterator(floorRepository.watch(floor.id));
      expect(await events.moveNext(), isTrue);
      expect(events.current.graph().issues, isEmpty);
      Future<FloorRoutingSnapshot> waitForReview() async {
        while (await events.moveNext()) {
          if (events.current.graph().issues.containsKey('handoff:handoff'))
            return events.current;
        }
        throw StateError('Floor watch ended without review.');
      }

      final review = waitForReview().timeout(const Duration(seconds: 5));
      final moved = path(b.id, secondPatch, channelB, start: 200);
      await repository.saveRouteWithRun(route: moved, run: run(moved));
      expect(
        (await review)
            .graph()
            .trace(b.id, FloorTraceDirection.upstream)
            .panelIds,
        isEmpty,
      );
      await events.cancel();
      await floorRepository.deleteHandoff('handoff');
      await floorRepository.deletePanel('panel');
      snapshot = await floorRepository.load(floor.id);
      expect(snapshot.panels, isEmpty);
      expect(snapshot.handoffs, isEmpty);
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
      await database.customStatement('DROP TABLE floor_panel_feeds');
      await database.customStatement('DROP TABLE floor_routing_handoffs');
      await database.customStatement('DROP TABLE floor_routing_panels');
      await database.customStatement('DROP TABLE component_reference_bindings');
      await database.customStatement(
        'DROP TABLE engineering_reference_catalogs',
      );
      await database.customStatement('PRAGMA user_version = 8');
      await database.close();
      database = openDatabase();
      floorRepository = DriftFloorRoutingRepository(
        database,
        originDeviceId: 'floor-test',
      );
      snapshot = await floorRepository.load(floor.id);
      expect(snapshot.graph().runs.length, 2);
      expect(snapshot.panels, isEmpty);
      expect(database.schemaVersion, 21);
      await DriftProjectHierarchyRepository(database).deleteProject(project.id);
      expect((await floorRepository.load(floor.id)).floor, isNull);
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
