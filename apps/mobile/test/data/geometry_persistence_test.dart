import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/application/project_hierarchy_service.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_project_hierarchy_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<String> createRoom(AppDatabase database) async {
    final hierarchy = DriftProjectHierarchyRepository(database);
    final service = ProjectHierarchyService(
      projects: hierarchy,
      floors: hierarchy,
      rooms: hierarchy,
      unitOfWork: DriftUnitOfWork(database),
      idGenerator: FixedSequenceIdGenerator(const [
        'project-geometry',
        'floor-geometry',
        'room-geometry',
      ]),
      originDeviceId: 'geometry-test-device',
      clock: () => DateTime.utc(2026, 10, 12, 12),
    );
    final project = await service.createProject(
      const ProjectFormDraft(
        name: 'Geometry Project',
        reference: 'G-01',
        measurementSystem: MeasurementSystem.metric,
        defaultStructuralHeightMm: 3500,
        defaultFinishedCeilingHeightMm: 3400,
      ),
    );
    final floor = await service.createFloor(
      projectId: project.id,
      draft: const FloorFormDraft(name: 'Floor 01', code: 'F01', sortOrder: 1),
    );
    final room = await service.createRoom(
      floorId: floor.id,
      draft: const RoomFormDraft(
        name: 'Workshop',
        type: RoomType.workshop,
        category: RoomCategory.technical,
        widthMm: 8000,
        depthMm: 6000,
      ),
    );
    return room.id;
  }

  SurfacePatch patch({
    required String id,
    required String roomId,
    Point3Mm origin = const Point3Mm(1000, 2000, 0),
  }) => SurfacePatch(
    id: id,
    roomId: roomId,
    surfaceId: 'surface-$id',
    frame: LocalCoordinateFrame(
      origin: origin,
      uAxis: const Vector3D(1, 0, 0),
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

  test('room geometry survives SQLite close and reopen exactly', () async {
    final directory = await Directory.systemTemp.createTemp('electra-fl3-');
    final file = File('${directory.path}/electra.sqlite');
    AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

    var database = openDatabase();
    final roomId = await createRoom(database);
    var geometry = DriftGeometryRepository(
      database,
      originDeviceId: 'geometry-test-device',
      clock: () => DateTime.utc(2026, 10, 12, 13),
    );

    final patchA = patch(id: 'patch-a', roomId: roomId);
    final patchB = patch(
      id: 'patch-b',
      roomId: roomId,
      origin: const Point3Mm(5000, 2000, 0),
    );
    final edgeA = SurfaceEdge(
      id: 'edge-a',
      patchId: patchA.id,
      start: const Point2Mm(4000, 0),
      end: const Point2Mm(4000, 3000),
      kind: SurfaceEdgeKind.fold,
    );
    final edgeB = SurfaceEdge(
      id: 'edge-b',
      patchId: patchB.id,
      start: const Point2Mm(0, 0),
      end: const Point2Mm(0, 3000),
      kind: SurfaceEdgeKind.fold,
    );
    final snapshot = RoomGeometrySnapshot(
      roomId: roomId,
      patches: [patchA, patchB],
      edges: [edgeA, edgeB],
      adjacencies: [
        SurfaceAdjacency(
          id: 'adj-1',
          fromPatchId: patchA.id,
          fromEdgeId: edgeA.id,
          toPatchId: patchB.id,
          toEdgeId: edgeB.id,
        ),
      ],
      openings: [
        Opening(
          id: 'door-1',
          hostSurfacePatchId: patchA.id,
          boundary: Polygon2Mm(const [
            Point2Mm(500, 0),
            Point2Mm(1400, 0),
            Point2Mm(1400, 2100),
            Point2Mm(500, 2100),
          ]),
          type: OpeningType.door,
          depthMm: 200,
          sillHeightMm: 0,
          headHeightMm: 2100,
        ),
      ],
      features: [
        SpatialFeature(
          id: 'beam-1',
          hostSurfacePatchId: patchA.id,
          type: SpatialFeatureType.beam,
          footprint: Polygon2Mm(const [
            Point2Mm(0, 2600),
            Point2Mm(4000, 2600),
            Point2Mm(4000, 3000),
            Point2Mm(0, 3000),
          ]),
          depthMm: 300,
          elevationMm: 2600,
        ),
      ],
    );

    await geometry.replaceRoomGeometry(snapshot);
    await database.close();

    database = openDatabase();
    geometry = DriftGeometryRepository(
      database,
      originDeviceId: 'geometry-test-device',
    );
    final restored = await geometry.loadRoomGeometry(roomId);

    expect(restored.validate(), isEmpty);
    expect(restored.patches, hasLength(2));
    expect(restored.edges, hasLength(2));
    expect(restored.adjacencies, hasLength(1));
    expect(restored.openings, hasLength(1));
    expect(restored.features, hasLength(1));

    final restoredPatch = restored.patches.firstWhere((e) => e.id == 'patch-a');
    expect(restoredPatch.frame.origin, const Point3Mm(1000, 2000, 0));
    expect(restoredPatch.boundary.vertices, patchA.boundary.vertices);
    expect(restoredPatch.frame.uAxis.x, patchA.frame.uAxis.x);
    expect(restoredPatch.frame.vAxis.z, patchA.frame.vAxis.z);

    final restoredOpening = restored.openings.single;
    expect(
      restoredOpening.boundary.vertices,
      snapshot.openings.single.boundary.vertices,
    );
    expect(restoredOpening.headHeightMm, 2100);

    await database.close();
    await directory.delete(recursive: true);
  });

  test('schema v1 upgrades through v3 without losing hierarchy data', () async {
    final directory = await Directory.systemTemp.createTemp('electra-v1-v3-');
    final file = File('${directory.path}/electra.sqlite');
    AppDatabase openDatabase() => AppDatabase(NativeDatabase(file));

    var database = openDatabase();
    final roomId = await createRoom(database);

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
    await database.customStatement('DROP TABLE surface_adjacencies');
    await database.customStatement('DROP TABLE openings');
    await database.customStatement('DROP TABLE spatial_features');
    await database.customStatement('DROP TABLE surface_edges');
    await database.customStatement('DROP TABLE surface_patches');
    await database.customStatement('DROP TABLE component_catalog_preferences');
    await database.customStatement('PRAGMA user_version = 1');
    await database.close();

    database = openDatabase();
    final hierarchy = DriftProjectHierarchyRepository(database);
    final restoredRoom = await hierarchy.findRoom(roomId);

    final tables =
        await database
            .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
            .get();
    final names = tables.map((row) => row.read<String>('name')).toSet();

    expect(restoredRoom?.name, 'Workshop');
    expect(database.schemaVersion, 12);
    expect(
      names,
      containsAll([
        'surface_patches',
        'surface_edges',
        'surface_adjacencies',
        'openings',
        'spatial_features',
        'component_instances',
      ]),
    );

    await database.close();
    await directory.delete(recursive: true);
  });
}
