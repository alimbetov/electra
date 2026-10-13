import 'dart:io';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
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
    'routing and CableRun round-trip with revision, live geometry and migration guards',
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
      final channel = PhysicalChannel(
        id: 'conduit',
        roomId: room.id,
        name: 'Shared conduit',
        kind: PhysicalChannelKind.conduit,
      );
      await repository.saveChannel(channel);
      var sequence = 0;
      String nextId() => 'route-id-${sequence++}';
      final draft = SurfaceRouteDraft(nextId: nextId)
        ..addPoint(patches[0], const Point2Mm(1000, 1000));
      draft.cross(
        adjacency: adjacency,
        nearPoint: const Point2Mm(4000, 1000),
        patches: patches,
        edges: edges,
        method: LayingMethod.conduit,
        channelId: channel.id,
      );
      draft.addPoint(
        patches[1],
        const Point2Mm(2000, 1000),
        method: LayingMethod.conduit,
        channelId: channel.id,
      );
      final route = draft.route(
        id: 'route',
        roomId: room.id,
        name: 'Wall to wall',
      );
      CableRun run({
        double reserve = 10,
        String circuitId = 'circuit',
        String routeId = 'route',
        String id = 'run',
      }) => CableRun(
        id: id,
        roomId: room.id,
        name: 'Workshop cable',
        circuitId: circuitId,
        routeId: routeId,
        reservePercent: reserve,
        terminationAllowanceMm: 250,
      );
      await repository.saveRouteWithRun(route: route, run: run());
      var snapshot = await repository.loadRoomRouting(room.id);
      expect(
        snapshot.calculate(snapshot.routes.single).geometricLengthMm,
        5000,
      );
      expect(snapshot.cableLength(snapshot.runs.single), 5750);
      await database.close();
      database = openDatabase();
      repository = DriftCableRoutingRepository(
        database,
        originDeviceId: 'route-test',
      );
      snapshot = await repository.loadRoomRouting(room.id);
      final restored = snapshot.routes.single;
      expect(
        restored.nodes.map((node) => node.id),
        route.nodes.map((node) => node.id),
      );
      expect(
        restored.nodes.map((node) => node.worldPosition),
        route.nodes.map((node) => node.worldPosition),
      );
      expect(
        restored.nodes.map((node) => node.anchor.localPosition),
        route.nodes.map((node) => node.anchor.localPosition),
      );
      expect(restored.nodes[1].otherAnchor!.patchId, 'b');
      expect(
        restored.nodes[1].otherAnchor!.localPosition,
        const Point2Mm(0, 1000),
      );
      expect(restored.nodes[1].adjacencyId, 'ab');
      expect(
        restored.segments.map((segment) => segment.id),
        route.segments.map((segment) => segment.id),
      );
      expect(
        restored.segments.map((segment) => segment.physicalChannelId),
        everyElement(channel.id),
      );
      expect(snapshot.runs.single.circuitId, 'circuit');
      expect(snapshot.runs.single.reservePercent, 10);
      expect(snapshot.runs.single.terminationAllowanceMm, 250);
      expect(snapshot.cableLength(snapshot.runs.single), 5750);
      final integerRows =
          await database
              .customSelect(
                "SELECT typeof(world_xmm) AS world_type, typeof(local_xmm) AS local_type FROM cable_route_nodes",
              )
              .get();
      expect(
        integerRows.map((row) => row.read<String>('world_type')),
        everyElement('integer'),
      );
      expect(
        integerRows.map((row) => row.read<String>('local_type')),
        everyElement('integer'),
      );

      final allowanceChange = repository
          .watchRoomRouting(room.id)
          .firstWhere(
            (snapshot) => snapshot.cableLength(snapshot.runs.single) == 6250,
          )
          .timeout(const Duration(seconds: 10));
      await repository.saveRouteWithRun(route: restored, run: run(reserve: 20));
      expect(
        (await allowanceChange).cableLength(
          (await repository.loadRoomRouting(room.id)).runs.single,
        ),
        6250,
      );
      final originalRow =
          await database.select(database.cableRoutes).getSingle();
      final editedDraft = SurfaceRouteDraft(
        nextId: nextId,
        nodes: restored.nodes,
        segments: restored.segments,
      )..removeLast();
      editedDraft.addPoint(
        patches[1],
        const Point2Mm(1000, 1000),
        method: LayingMethod.conduit,
        channelId: channel.id,
      );
      await repository.saveRouteWithRun(
        route: editedDraft.route(
          id: route.id,
          roomId: room.id,
          name: route.name,
        ),
        run: run(reserve: 20),
      );
      final oldNode =
          await (database.select(
            database.cableRouteNodes,
          )..where((row) => row.id.equals(restored.nodes.last.id))).getSingle();
      expect(oldNode.deletedAt, isNotNull);
      await repository.saveRouteWithRun(route: restored, run: run(reserve: 20));
      final restoredNode =
          await (database.select(
            database.cableRouteNodes,
          )..where((row) => row.id.equals(restored.nodes.last.id))).getSingle();
      expect(restoredNode.deletedAt, isNull);
      expect(restoredNode.createdAt, oldNode.createdAt);
      expect(restoredNode.revision, oldNode.revision + 1);
      final revised = await database.select(database.cableRoutes).getSingle();
      expect(revised.createdAt, originalRow.createdAt);
      expect(revised.revision, originalRow.revision + 2);
      expect(
        (await repository.loadRoomRouting(
          room.id,
        )).cableLength(run(reserve: 20)),
        6250,
      );

      final otherRoute = CableRoute(
        id: 'borrowed',
        roomId: room.id,
        name: 'Borrowed IDs',
        nodes: restored.nodes,
        segments: restored.segments,
      );
      await expectLater(
        repository.saveRouteWithRun(
          route: otherRoute,
          run: run(routeId: 'borrowed', id: 'borrowed-run'),
        ),
        throwsStateError,
      );
      expect(await database.select(database.cableRoutes).get(), hasLength(1));
      expect(await database.select(database.cableRuns).get(), hasLength(1));
      await expectLater(
        repository.saveRouteWithRun(
          route: restored,
          run: run(reserve: double.nan),
        ),
        throwsArgumentError,
      );
      final offEdgeNodes = [...restored.nodes];
      final transition = offEdgeNodes[1];
      offEdgeNodes[1] = RouteNode(
        id: transition.id,
        kind: transition.kind,
        worldPosition: transition.worldPosition,
        anchor: transition.anchor,
        otherAnchor: const SurfaceRouteAnchor(
          patchId: 'b',
          localPosition: Point2Mm(1, 1000),
        ),
        adjacencyId: transition.adjacencyId,
      );
      await expectLater(
        repository.saveRouteWithRun(
          route: CableRoute(
            id: route.id,
            roomId: room.id,
            name: route.name,
            nodes: offEdgeNodes,
            segments: restored.segments,
          ),
          run: run(),
        ),
        throwsStateError,
      );
      expect(
        (await database.select(database.cableRoutes).getSingle()).revision,
        revised.revision,
      );

      final otherHierarchy = DriftProjectHierarchyRepository(database);
      final otherService = ProjectHierarchyService(
        projects: otherHierarchy,
        floors: otherHierarchy,
        rooms: otherHierarchy,
        unitOfWork: DriftUnitOfWork(database),
        idGenerator: FixedSequenceIdGenerator(const ['foreign-room']),
        originDeviceId: 'route-test',
      );
      final other = await otherService.createRoom(
        floorId: floor.id,
        draft: const RoomFormDraft(
          name: 'Other',
          type: RoomType.workshop,
          category: RoomCategory.technical,
          widthMm: 4000,
          depthMm: 3000,
        ),
      );
      await DriftElectricalCircuitRepository(
        database,
        originDeviceId: 'route-test',
      ).saveCircuit(
        ElectricalCircuit(
          id: 'foreign-circuit',
          roomId: other.id,
          name: 'Other circuit',
          inputs: const ElectricalCircuitInputs(
            nominalVoltageV: 230,
            phases: 1,
            supplySystem: SupplySystem.singlePhaseAc,
          ),
          loadIds: const [],
        ),
      );
      await expectLater(
        repository.saveRouteWithRun(
          route: restored,
          run: run(circuitId: 'foreign-circuit'),
        ),
        throwsStateError,
      );
      await expectLater(
        repository.saveChannel(
          PhysicalChannel(
            id: channel.id,
            roomId: other.id,
            name: 'Other',
            kind: channel.kind,
          ),
        ),
        throwsStateError,
      );
      expect(
        (await database.select(database.cableRuns).getSingle()).circuitId,
        'circuit',
      );

      final geometryChange = repository
          .watchRoomRouting(room.id)
          .firstWhere(
            (snapshot) => snapshot
                .calculate(snapshot.routes.single)
                .issues
                .any((issue) => issue.code == 'STALE_WORLD_POSITION'),
          )
          .timeout(const Duration(seconds: 10));
      await DriftGeometryRepository(
        database,
        originDeviceId: 'route-test',
      ).replaceRoomGeometry(geometrySnapshot(shift: 10));
      final stale = await geometryChange;
      expect(stale.cableLength(stale.runs.single), isNull);
      await DriftGeometryRepository(
        database,
        originDeviceId: 'route-test',
      ).replaceRoomGeometry(geometrySnapshot());
      await repository.saveChannel(
        PhysicalChannel(
          id: channel.id,
          roomId: room.id,
          name: channel.name,
          kind: PhysicalChannelKind.tray,
        ),
      );
      expect(
        (await repository.loadRoomRouting(
          room.id,
        )).cableLength(run(reserve: 20)),
        isNull,
      );
      await repository.saveChannel(channel);
      expect(
        (await repository.loadRoomRouting(
          room.id,
        )).cableLength(run(reserve: 20)),
        6250,
      );

      // A v6 fixture retains existing circuits and geometry when v7 tables are created.
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
      await database.customStatement('PRAGMA user_version = 6');
      await database.close();
      database = openDatabase();
      repository = DriftCableRoutingRepository(
        database,
        originDeviceId: 'route-test',
      );
      snapshot = await repository.loadRoomRouting(room.id);
      expect(snapshot.routes, isEmpty);
      expect(snapshot.geometry.patches, hasLength(2));
      expect(snapshot.activeCircuitIds, contains('circuit'));
      await repository.saveChannel(channel);
      await repository.saveRouteWithRun(route: restored, run: run());
      expect(
        (await repository.loadRoomRouting(room.id)).cableLength(run()),
        5750,
      );
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
