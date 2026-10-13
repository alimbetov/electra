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
    'junction one-in two-out persists, rejects duplicate endpoint and reviews moved route',
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
      String nextId() => 'junction-node-${sequence++}';
      CableRoute path(String id, Point2Mm start, Point2Mm end) {
        final draft =
            SurfaceRouteDraft(nextId: nextId)
              ..addPoint(patches.first, start)
              ..addPoint(patches.first, end);
        return draft.route(id: id, roomId: room.id, name: id);
      }

      final paths = [
        path('in', const Point2Mm(100, 1000), const Point2Mm(1000, 1000)),
        path('out1', const Point2Mm(1000, 1000), const Point2Mm(2000, 1000)),
        path('out2', const Point2Mm(1000, 1000), const Point2Mm(1000, 2000)),
      ];
      CableRun run(CableRoute route) => CableRun(
        id: 'run-${route.id}',
        roomId: room.id,
        name: route.name,
        circuitId: 'circuit',
        routeId: route.id,
      );
      for (final route in paths) {
        await repository.saveRouteWithRun(route: route, run: run(route));
      }
      RoutingJunction junction({
        String id = 'junction',
        List<RoutingJunctionConnection>? connections,
      }) => RoutingJunction(
        id: id,
        code: id,
        type: RoutingJunctionType.junctionBox,
        roomId: room.id,
        surfacePatchId: 'a',
        localPosition: const Point2Mm(1000, 1000),
        xMm: 1000,
        yMm: 0,
        zMm: 1000,
        connections:
            connections ??
            [
              for (final route in paths)
                RoutingJunctionConnection(
                  runId: run(route).id,
                  direction:
                      route.id == 'in'
                          ? RoutingConnectionDirection.incoming
                          : RoutingConnectionDirection.outgoing,
                  nodeId:
                      (route.id == 'in' ? route.nodes.last : route.nodes.first)
                          .id,
                  circuitOrNetworkId: 'circuit',
                ),
            ],
      );
      await repository.saveJunction(junction());
      await database.close();
      database = openDatabase();
      repository = DriftCableRoutingRepository(
        database,
        originDeviceId: 'junction-test',
      );
      var snapshot = await repository.loadRoomRouting(room.id);
      final restored = snapshot.junctions.single;
      expect(restored.incoming.length, 1);
      expect(restored.outgoing.length, 2);
      expect(restored.isBranching, isTrue);
      expect(restored.localPosition, const Point2Mm(1000, 1000));
      expect(snapshot.junctionIssues(restored), isEmpty);
      await expectLater(
        repository.saveJunction(junction(id: 'duplicate')),
        throwsStateError,
      );
      await expectLater(
        repository.saveJunction(
          junction(connections: [restored.connections.first]),
        ),
        throwsStateError,
      );
      expect(
        (await repository.loadRoomRouting(
          room.id,
        )).junctions.single.connections.length,
        3,
      );
      await repository.saveJunction(
        junction(connections: restored.connections.take(2).toList()),
      );
      expect(
        (await repository.loadRoomRouting(
          room.id,
        )).junctions.single.connections.length,
        2,
      );
      await repository.saveJunction(junction());
      final moved = path(
        'out1',
        const Point2Mm(1100, 1000),
        const Point2Mm(2100, 1000),
      );
      final reviewEvent = repository
          .watchRoomRouting(room.id)
          .firstWhere(
            (state) =>
                state.junctions.isNotEmpty &&
                state.junctionIssues(state.junctions.single).isNotEmpty,
          )
          .timeout(const Duration(seconds: 5));
      await repository.saveRouteWithRun(route: moved, run: run(moved));
      expect((await reviewEvent).junctions.single.isBranching, isTrue);
      snapshot = await repository.loadRoomRouting(room.id);
      expect(snapshot.junctionIssues(snapshot.junctions.single), isNotEmpty);
      expect(snapshot.junctions.single.connections.length, 3);
      // v7 -> v8 upgrade preserves routing and creates first-class junction tables.
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
      await database.customStatement('PRAGMA user_version = 7');
      await database.close();
      database = openDatabase();
      repository = DriftCableRoutingRepository(
        database,
        originDeviceId: 'junction-test',
      );
      snapshot = await repository.loadRoomRouting(room.id);
      expect(snapshot.runs.length, 3);
      expect(snapshot.junctions, isEmpty);
      expect(database.schemaVersion, 12);
      await database.close();
      await directory.delete(recursive: true);
    },
  );
}
