import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  SurfacePatch buildPatch(
    String id, {
    Point3Mm origin = const Point3Mm(0, 0, 0),
  }) =>
      SurfacePatch(
        id: id,
        roomId: 'room-1',
        surfaceId: 'wall-$id',
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

  test('rejects an edge bridging the exterior of a concave patch', () {
    final patch = SurfacePatch(
      id: 'concave',
      roomId: 'room-1',
      surfaceId: 'wall',
      frame: buildPatch('frame').frame,
      orientation: SurfaceOrientation.vertical,
      boundary: Polygon2Mm(const [
        Point2Mm(0, 0),
        Point2Mm(6, 0),
        Point2Mm(6, 6),
        Point2Mm(4, 6),
        Point2Mm(4, 2),
        Point2Mm(2, 2),
        Point2Mm(2, 6),
        Point2Mm(0, 6),
      ]),
    );
    final violations = SpatialGeometryValidator.validatePatchTopology(
      patches: [patch],
      edges: [
        SurfaceEdge(
          id: 'bridge',
          patchId: patch.id,
          start: const Point2Mm(2, 6),
          end: const Point2Mm(4, 6),
        ),
      ],
      adjacencies: [],
      openings: [],
      features: [],
    );
    expect(violations.map((item) => item.code), ['EDGE_OUTSIDE_PATCH']);
    expect(violations.single.objectId, 'bridge');
  });

  test('spatial topology validates consistent patch graph', () {
    final patchA = buildPatch('patch-a');
    final patchB = buildPatch('patch-b', origin: const Point3Mm(4000, 0, 0));
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

    final violations = SpatialGeometryValidator.validatePatchTopology(
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
          type: OpeningType.door,
          boundary: Polygon2Mm(const [
            Point2Mm(500, 0),
            Point2Mm(1400, 0),
            Point2Mm(1400, 2100),
            Point2Mm(500, 2100),
          ]),
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

    expect(violations, isEmpty);
  });

  test('validator rejects adjacency between non-coincident world edges', () {
    final patchA = buildPatch('patch-a');
    final patchB = buildPatch('patch-b', origin: const Point3Mm(5000, 0, 0));
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

    final violations = SpatialGeometryValidator.validatePatchTopology(
      patches: [patchA, patchB],
      edges: [edgeA, edgeB],
      adjacencies: [
        SurfaceAdjacency(
          id: 'adj-mismatch',
          fromPatchId: patchA.id,
          fromEdgeId: edgeA.id,
          toPatchId: patchB.id,
          toEdgeId: edgeB.id,
        ),
      ],
      openings: const [],
      features: const [],
    );

    expect(
      violations.map((e) => e.code),
      contains('ADJACENCY_WORLD_EDGE_MISMATCH'),
    );
  });

  test('validator reports orphan spatial objects', () {
    final violations = SpatialGeometryValidator.validatePatchTopology(
      patches: const [],
      edges: [
        SurfaceEdge(
          id: 'edge-orphan',
          patchId: 'missing',
          start: const Point2Mm(0, 0),
          end: const Point2Mm(1000, 0),
        ),
      ],
      adjacencies: const [],
      openings: [
        Opening(
          id: 'opening-orphan',
          hostSurfacePatchId: 'missing',
          type: OpeningType.window,
          boundary: Polygon2Mm(const [
            Point2Mm(0, 0),
            Point2Mm(1000, 0),
            Point2Mm(1000, 1000),
            Point2Mm(0, 1000),
          ]),
        ),
      ],
      features: [
        SpatialFeature(
          id: 'feature-orphan',
          hostSurfacePatchId: 'missing',
          type: SpatialFeatureType.column,
          footprint: Polygon2Mm(const [
            Point2Mm(0, 0),
            Point2Mm(300, 0),
            Point2Mm(300, 300),
            Point2Mm(0, 300),
          ]),
          depthMm: 300,
          elevationMm: 0,
        ),
      ],
    );

    expect(
      violations.map((e) => e.code),
      containsAll([
        'EDGE_HOST_MISSING',
        'OPENING_HOST_MISSING',
        'FEATURE_HOST_MISSING',
      ]),
    );
  });

  test('validator reports opening and feature outside host patch', () {
    final patch = buildPatch('patch-a');
    final violations = SpatialGeometryValidator.validatePatchTopology(
      patches: [patch],
      edges: const [],
      adjacencies: const [],
      openings: [
        Opening(
          id: 'window-outside',
          hostSurfacePatchId: patch.id,
          type: OpeningType.window,
          boundary: Polygon2Mm(const [
            Point2Mm(3500, 500),
            Point2Mm(4500, 500),
            Point2Mm(4500, 1500),
            Point2Mm(3500, 1500),
          ]),
        ),
      ],
      features: [
        SpatialFeature(
          id: 'feature-outside',
          hostSurfacePatchId: patch.id,
          type: SpatialFeatureType.column,
          footprint: Polygon2Mm(const [
            Point2Mm(-100, 0),
            Point2Mm(300, 0),
            Point2Mm(300, 300),
            Point2Mm(-100, 300),
          ]),
          depthMm: 300,
          elevationMm: 0,
        ),
      ],
    );

    expect(
      violations.map((e) => e.code),
      containsAll(['OPENING_OUTSIDE_PATCH', 'FEATURE_OUTSIDE_PATCH']),
    );
  });

  test('validator reports orientation that disagrees with frame normal', () {
    final patch = SurfacePatch(
      id: 'patch-horizontal-declared',
      roomId: 'room-1',
      surfaceId: 'surface-1',
      frame: LocalCoordinateFrame(
        origin: const Point3Mm(0, 0, 0),
        uAxis: const Vector3D(1, 0, 0),
        vAxis: const Vector3D(0, 0, 1),
      ),
      boundary: Polygon2Mm(const [
        Point2Mm(0, 0),
        Point2Mm(1000, 0),
        Point2Mm(1000, 1000),
        Point2Mm(0, 1000),
      ]),
      orientation: SurfaceOrientation.horizontal,
    );

    final violations = SpatialGeometryValidator.validatePatchTopology(
      patches: [patch],
      edges: const [],
      adjacencies: const [],
      openings: const [],
      features: const [],
    );

    expect(
      violations.map((e) => e.code),
      contains('SURFACE_ORIENTATION_NORMAL_MISMATCH'),
    );
  });

  test('opening rejects inverted vertical bounds', () {
    expect(
      () => Opening(
        id: 'bad',
        hostSurfacePatchId: 'patch-a',
        type: OpeningType.window,
        boundary: Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(100, 0),
          Point2Mm(100, 100),
          Point2Mm(0, 100),
        ]),
        sillHeightMm: 1200,
        headHeightMm: 1000,
      ),
      throwsArgumentError,
    );
  });
}
