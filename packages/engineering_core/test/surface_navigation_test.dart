import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  SurfacePatch wallA() => SurfacePatch(
        id: 'wall-a',
        roomId: 'room-1',
        surfaceId: 'Wall A',
        frame: LocalCoordinateFrame(
          origin: const Point3Mm(0, 0, 0),
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

  SurfacePatch wallB() => SurfacePatch(
        id: 'wall-b',
        roomId: 'room-1',
        surfaceId: 'Wall B',
        frame: LocalCoordinateFrame(
          origin: const Point3Mm(4000, 0, 0),
          uAxis: const Vector3D(0, 1, 0),
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

  final edgeRightA = SurfaceEdge(
    id: 'edge-a-right',
    patchId: 'wall-a',
    start: const Point2Mm(4000, 0),
    end: const Point2Mm(4000, 3000),
    kind: SurfaceEdgeKind.fold,
  );
  final edgeLeftA = SurfaceEdge(
    id: 'edge-a-left',
    patchId: 'wall-a',
    start: const Point2Mm(0, 3000),
    end: const Point2Mm(0, 0),
  );
  final edgeLeftB = SurfaceEdge(
    id: 'edge-b-left',
    patchId: 'wall-b',
    start: const Point2Mm(0, 3000),
    end: const Point2Mm(0, 0),
    kind: SurfaceEdgeKind.fold,
  );
  final adjacency = SurfaceAdjacency(
    id: 'adj-a-b',
    fromPatchId: 'wall-a',
    fromEdgeId: 'edge-a-right',
    toPatchId: 'wall-b',
    toEdgeId: 'edge-b-left',
  );

  test('distanceToSegmentMm projects onto finite segment', () {
    expect(
      distanceToSegmentMm(
        const Point2Mm(3900, 1500),
        edgeRightA.segment,
      ),
      100,
    );
    expect(
      distanceToSegmentMm(
        const Point2Mm(4100, 3200),
        edgeRightA.segment,
      ),
      closeTo(223.6067977, 0.0001),
    );
  });

  test('proximity transitions from none to strong preview deterministically', () {
    const thresholds = SurfaceNavigationThresholds(
      highlightDistanceMm: 600,
      previewDistanceMm: 300,
      strongPreviewDistanceMm: 120,
    );

    expect(thresholds.classify(601), SurfaceEdgeProximity.none);
    expect(thresholds.classify(600), SurfaceEdgeProximity.highlight);
    expect(thresholds.classify(300), SurfaceEdgeProximity.preview);
    expect(thresholds.classify(120), SurfaceEdgeProximity.strongPreview);
  });

  test('resolver returns adjacent patch from either adjacency direction', () {
    const resolver = SurfaceNavigationResolver();

    expect(
      resolver.resolveAdjacentPatchId(
        activePatchId: 'wall-a',
        edgeId: 'edge-a-right',
        adjacencies: [adjacency],
      ),
      'wall-b',
    );
    expect(
      resolver.resolveAdjacentPatchId(
        activePatchId: 'wall-b',
        edgeId: 'edge-b-left',
        adjacencies: [adjacency],
      ),
      'wall-a',
    );
  });

  test('nearest edge prefers the physically nearest navigable candidate', () {
    const resolver = SurfaceNavigationResolver();
    final candidate = resolver.nearestCandidate(
      pointer: const Point2Mm(3900, 1500),
      activePatch: wallA(),
      edges: [edgeLeftA, edgeRightA, edgeLeftB],
      adjacencies: [adjacency],
    );

    expect(candidate, isNotNull);
    expect(candidate!.edge.id, 'edge-a-right');
    expect(candidate.adjacentPatchId, 'wall-b');
    expect(candidate.proximity, SurfaceEdgeProximity.strongPreview);
  });

  test('current preview receives bounded hysteresis near a corner', () {
    const resolver = SurfaceNavigationResolver(
      thresholds: SurfaceNavigationThresholds(previewHysteresisMm: 80),
    );
    final bottom = SurfaceEdge(
      id: 'edge-a-bottom',
      patchId: 'wall-a',
      start: const Point2Mm(0, 0),
      end: const Point2Mm(4000, 0),
      kind: SurfaceEdgeKind.fold,
    );

    final ranked = resolver.rankCandidates(
      pointer: const Point2Mm(3940, 70),
      activePatch: wallA(),
      edges: [edgeRightA, bottom],
      adjacencies: [adjacency],
      currentPreviewEdgeId: 'edge-a-bottom',
    );

    expect(ranked.first.edge.id, 'edge-a-bottom');
    expect(ranked.first.isCurrentPreview, isTrue);
  });

  test('wall adjacency fixture remains physically valid in world space', () {
    expect(
      SpatialGeometryValidator.validatePatchTopology(
        patches: [wallA(), wallB()],
        edges: [edgeRightA, edgeLeftB],
        adjacencies: [adjacency],
        openings: const [],
        features: const [],
      ),
      isEmpty,
    );
  });
}
