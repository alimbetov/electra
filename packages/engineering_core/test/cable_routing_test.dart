import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

SurfacePatch wall(String id,
        {Point3Mm origin = const Point3Mm(0, 0, 0),
        Vector3D u = const Vector3D(1, 0, 0),
        Vector3D v = const Vector3D(0, 0, 1),
        int width = 4000,
        int height = 3000,
        SurfaceOrientation orientation = SurfaceOrientation.vertical}) =>
    SurfacePatch(
        id: id,
        roomId: 'room',
        surfaceId: id,
        frame: LocalCoordinateFrame(origin: origin, uAxis: u, vAxis: v),
        boundary: Polygon2Mm([
          const Point2Mm(0, 0),
          Point2Mm(width, 0),
          Point2Mm(width, height),
          Point2Mm(0, height)
        ]),
        orientation: orientation);
int counter = 0;
String nextId() => 'id-${counter++}';

void main() {
  late List<SurfacePatch> patches;
  late List<SurfaceEdge> edges;
  late SurfaceAdjacency adjacency;
  setUp(() {
    counter = 0;
    patches = [
      wall('a'),
      wall('b',
          origin: const Point3Mm(4000, 0, 0),
          u: const Vector3D(0, 1, 0),
          width: 3000)
    ];
    edges = [
      SurfaceEdge(
          id: 'ea',
          patchId: 'a',
          start: const Point2Mm(4000, 0),
          end: const Point2Mm(4000, 3000),
          kind: SurfaceEdgeKind.fold),
      SurfaceEdge(
          id: 'eb',
          patchId: 'b',
          start: const Point2Mm(0, 0),
          end: const Point2Mm(0, 3000),
          kind: SurfaceEdgeKind.fold)
    ];
    adjacency = SurfaceAdjacency(
        id: 'ab',
        fromPatchId: 'a',
        fromEdgeId: 'ea',
        toPatchId: 'b',
        toEdgeId: 'eb');
  });
  CableRoute build({bool reverse = false}) {
    final draft = SurfaceRouteDraft(nextId: nextId);
    draft.addPoint(patches[reverse ? 1 : 0], const Point2Mm(1000, 1000));
    draft.cross(
        adjacency: adjacency,
        nearPoint: Point2Mm(reverse ? 0 : 4000, 1000),
        patches: patches,
        edges: edges);
    draft.addPoint(patches[reverse ? 0 : 1], const Point2Mm(2000, 1000));
    return draft.route(id: 'route', roomId: 'room', name: 'Route');
  }

  RouteCalculation calculate(CableRoute route,
          {List<Opening> openings = const [],
          List<PhysicalChannel> channels = const []}) =>
      CableRouteValidator.calculate(
          route: route,
          patches: patches,
          edges: edges,
          adjacencies: [adjacency],
          openings: openings,
          channels: channels);

  test('perpendicular surfaces preserve a 5000-mm path and explicit allowances',
      () {
    final route = build();
    final result = calculate(route);
    expect(result.issues, isEmpty);
    expect(result.geometricLengthMm, 5000);
    expect(route.nodes[1].worldPosition, const Point3Mm(4000, 0, 1000));
    expect(route.nodes[1].otherAnchor!.localPosition, const Point2Mm(0, 1000));
    expect(
        result.cableLengthMm(const CableRun(
            id: 'run',
            roomId: 'room',
            name: 'Cable',
            circuitId: 'circuit',
            routeId: 'route',
            reservePercent: 10,
            terminationAllowanceMm: 250)),
        5750);
    expect(
        result.cableLengthMm(const CableRun(
            id: 'run',
            roomId: 'room',
            name: 'Cable',
            circuitId: 'circuit',
            routeId: 'other')),
        isNull);
  });

  test('interior phantom folds cannot masquerade as surface boundaries', () {
    patches = [
      wall('a'),
      wall('b', origin: const Point3Mm(2000, 0, 0), u: const Vector3D(0, 1, 0))
    ];
    edges = [
      SurfaceEdge(
          id: 'ea',
          patchId: 'a',
          start: const Point2Mm(2000, 0),
          end: const Point2Mm(2000, 3000)),
      edges[1]
    ];
    final result = calculate(build());
    expect(result.geometricLengthMm, isNull);
    expect(result.issues.map((issue) => issue.code),
        contains('TRANSITION_NOT_BOUNDARY'));
  });
  test('broken chain and invalid run allowances never produce a total', () {
    final route = build();
    final broken = CableRoute(
        id: route.id,
        roomId: route.roomId,
        name: route.name,
        nodes: route.nodes,
        segments: [route.segments.last, route.segments.first]);
    expect(calculate(broken).issues.map((issue) => issue.code),
        contains('DISCONNECTED_SEGMENT'));
    final result = calculate(route);
    expect(
        result.cableLengthMm(const CableRun(
            id: 'run',
            roomId: 'room',
            name: 'Cable',
            circuitId: 'circuit',
            routeId: 'route',
            reservePercent: double.nan)),
        isNull);
    expect(
        result.cableLengthMm(const CableRun(
            id: 'run',
            roomId: 'room',
            name: 'Cable',
            circuitId: 'circuit',
            routeId: 'route',
            terminationAllowanceMm: -1)),
        isNull);
  });
  test('adjacency is traversable in reverse with the same physical seam', () {
    expect(calculate(build(reverse: true)).geometricLengthMm, 3000);
  });
  test('draft rejects teleportation and removal restores the previous surface',
      () {
    final draft = SurfaceRouteDraft(nextId: nextId);
    draft.addPoint(patches[0], const Point2Mm(1000, 1000));
    expect(() => draft.addPoint(patches[1], const Point2Mm(2000, 1000)),
        throwsStateError);
    expect(draft.nodes, hasLength(1));
    draft.cross(
        adjacency: adjacency,
        nearPoint: const Point2Mm(4000, 1000),
        patches: patches,
        edges: edges);
    draft.addPoint(patches[1], const Point2Mm(2000, 1000));
    draft.removeLast();
    expect(draft.activePatchId, 'b');
    draft.removeLast();
    expect(draft.activePatchId, 'a');
    expect(draft.nodes.single.kind, RouteNodeKind.endpoint);
  });
  test(
      'slope length uses exact local anchors instead of rounded world distances',
      () {
    final patch = wall('slope',
        u: const Vector3D(1, 0, 1),
        v: const Vector3D(0, 1, 0),
        orientation: SurfaceOrientation.sloped);
    final draft = SurfaceRouteDraft(nextId: nextId)
      ..addPoint(patch, const Point2Mm(0, 0))
      ..addPoint(patch, const Point2Mm(1000, 1000));
    final result = CableRouteValidator.calculate(
        route: draft.route(id: 'slope-route', roomId: 'room', name: 'Slope'),
        patches: [patch],
        edges: [],
        adjacencies: []);
    expect(result.geometricLengthMm, closeTo(1414.213562, 0.000001));
    expect(draft.nodes.last.worldPosition, const Point3Mm(707, 1000, 707));
  });
  test(
      'segments crossing concave cut-outs and openings never have a valid total',
      () {
    final route = build();
    final opening = Opening(
        id: 'window',
        hostSurfacePatchId: 'a',
        boundary: Polygon2Mm(const [
          Point2Mm(2000, 500),
          Point2Mm(2200, 500),
          Point2Mm(2200, 1500),
          Point2Mm(2000, 1500)
        ]),
        type: OpeningType.window);
    final blocked = calculate(route, openings: [opening]);
    expect(blocked.geometricLengthMm, isNull);
    expect(blocked.issues.map((issue) => issue.code),
        contains('SEGMENT_CROSSES_OPENING'));
    final concave = SurfacePatch(
        id: 'notch',
        roomId: 'room',
        surfaceId: 'Notch',
        frame: patches[0].frame,
        orientation: SurfaceOrientation.vertical,
        boundary: Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(6, 0),
          Point2Mm(6, 6),
          Point2Mm(4, 6),
          Point2Mm(4, 2),
          Point2Mm(2, 2),
          Point2Mm(2, 6),
          Point2Mm(0, 6)
        ]));
    final draft = SurfaceRouteDraft(nextId: nextId)
      ..addPoint(concave, const Point2Mm(1, 4))
      ..addPoint(concave, const Point2Mm(5, 4));
    expect(
        CableRouteValidator.calculate(
            route:
                draft.route(id: 'notch-route', roomId: 'room', name: 'Notch'),
            patches: [concave],
            edges: [],
            adjacencies: []).issues.map((issue) => issue.code),
        contains('SEGMENT_OUTSIDE_PATCH'));
  });
  test('stale frames and missing topology block length instead of hiding gaps',
      () {
    final route = build();
    patches = [wall('a', origin: const Point3Mm(100, 0, 0)), patches[1]];
    expect(calculate(route).issues.map((issue) => issue.code),
        contains('STALE_WORLD_POSITION'));
    expect(
        CableRouteValidator.calculate(
            route: route,
            patches: patches,
            edges: edges,
            adjacencies: []).issues.map((issue) => issue.code),
        contains('INVALID_TRANSITION'));
  });
  test(
      'channel references are typed, room-owned and independent from the cable',
      () {
    final route = build();
    final segments = [
      for (final segment in route.segments)
        RouteSegment(
            id: segment.id,
            fromNodeId: segment.fromNodeId,
            toNodeId: segment.toNodeId,
            surfacePatchId: segment.surfacePatchId,
            layingMethod: LayingMethod.conduit,
            physicalChannelId: 'channel')
    ];
    final bound = CableRoute(
        id: route.id,
        roomId: route.roomId,
        name: route.name,
        nodes: route.nodes,
        segments: segments);
    expect(
        calculate(bound, channels: const [
          PhysicalChannel(
              id: 'channel',
              roomId: 'room',
              name: 'Conduit',
              kind: PhysicalChannelKind.conduit)
        ]).ready,
        isTrue);
    expect(
        calculate(bound, channels: const [
          PhysicalChannel(
              id: 'channel',
              roomId: 'other',
              name: 'Conduit',
              kind: PhysicalChannelKind.conduit)
        ]).ready,
        isFalse);
    expect(
        calculate(bound, channels: const [
          PhysicalChannel(
              id: 'channel',
              roomId: 'room',
              name: 'Tray',
              kind: PhysicalChannelKind.tray)
        ]).issues.map((issue) => issue.code),
        contains('CHANNEL_METHOD_MISMATCH'));
  });
  test(
      'snap stays on the integer edge lattice, including primitive diagonal edges',
      () {
    final edge = SurfaceEdge(
        id: 'diagonal',
        patchId: 'a',
        start: const Point2Mm(0, 0),
        end: const Point2Mm(3, 2));
    expect(
        SurfaceRouteDraft.nearestIntegerPointOnEdge(const Point2Mm(1, 1), edge),
        const Point2Mm(0, 0));
    expect(
        SurfaceRouteDraft.nearestIntegerPointOnEdge(const Point2Mm(2, 1), edge),
        const Point2Mm(3, 2));
  });
  test('ceiling to beam side to underside to opposite side follows all folds',
      () {
    final sequence = [
      wall('ceiling',
          origin: const Point3Mm(0, 0, 3000),
          u: const Vector3D(1, 0, 0),
          v: const Vector3D(0, 1, 0),
          width: 1500,
          orientation: SurfaceOrientation.horizontal),
      wall('side',
          origin: const Point3Mm(1500, 0, 3000),
          u: const Vector3D(0, 1, 0),
          v: const Vector3D(0, 0, -1),
          width: 3000,
          height: 500),
      wall('underside',
          origin: const Point3Mm(1500, 0, 2500),
          u: const Vector3D(1, 0, 0),
          v: const Vector3D(0, 1, 0),
          width: 500,
          orientation: SurfaceOrientation.horizontal),
      wall('other-side',
          origin: const Point3Mm(2000, 0, 2500),
          u: const Vector3D(0, 1, 0),
          v: const Vector3D(0, 0, 1),
          width: 3000,
          height: 500),
      wall('other-ceiling',
          origin: const Point3Mm(2000, 0, 3000),
          u: const Vector3D(1, 0, 0),
          v: const Vector3D(0, 1, 0),
          width: 2000,
          orientation: SurfaceOrientation.horizontal),
    ];
    final pairs = const [
      (
        Point2Mm(1500, 0),
        Point2Mm(1500, 3000),
        Point2Mm(0, 0),
        Point2Mm(3000, 0),
        Point2Mm(1500, 1000)
      ),
      (
        Point2Mm(0, 500),
        Point2Mm(3000, 500),
        Point2Mm(0, 0),
        Point2Mm(0, 3000),
        Point2Mm(1000, 500)
      ),
      (
        Point2Mm(500, 0),
        Point2Mm(500, 3000),
        Point2Mm(0, 0),
        Point2Mm(3000, 0),
        Point2Mm(500, 1000)
      ),
      (
        Point2Mm(0, 500),
        Point2Mm(3000, 500),
        Point2Mm(0, 0),
        Point2Mm(0, 3000),
        Point2Mm(1000, 500)
      ),
    ];
    final folds = <SurfaceAdjacency>[];
    final boundaries = <SurfaceEdge>[];
    for (var i = 0; i < pairs.length; i++) {
      final p = pairs[i];
      boundaries.addAll([
        SurfaceEdge(
            id: 'from-$i',
            patchId: sequence[i].id,
            start: p.$1,
            end: p.$2,
            kind: SurfaceEdgeKind.fold),
        SurfaceEdge(
            id: 'to-$i',
            patchId: sequence[i + 1].id,
            start: p.$3,
            end: p.$4,
            kind: SurfaceEdgeKind.fold)
      ]);
      folds.add(SurfaceAdjacency(
          id: 'fold-$i',
          fromPatchId: sequence[i].id,
          fromEdgeId: 'from-$i',
          toPatchId: sequence[i + 1].id,
          toEdgeId: 'to-$i'));
    }
    final draft = SurfaceRouteDraft(nextId: nextId)
      ..addPoint(sequence.first, const Point2Mm(1000, 1000));
    for (var i = 0; i < folds.length; i++) {
      draft.cross(
          adjacency: folds[i],
          nearPoint: pairs[i].$5,
          patches: sequence,
          edges: boundaries);
    }
    draft.addPoint(sequence.last, const Point2Mm(1000, 1000));
    final result = CableRouteValidator.calculate(
        route:
            draft.route(id: 'beam-route', roomId: 'room', name: 'Beam route'),
        patches: sequence,
        edges: boundaries,
        adjacencies: folds);
    expect(result.issues, isEmpty);
    expect(result.geometricLengthMm, 3000);
    expect(
        draft.nodes
            .where((node) => node.kind == RouteNodeKind.surfaceTransition),
        hasLength(4));
  });
}
