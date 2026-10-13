import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  var sequence = 0;
  FloorRoutingRun run(String id, String room, Point2Mm start, Point2Mm end,
      {LayingMethod method = LayingMethod.conduit, bool ready = true}) {
    final patch = SurfacePatch(
        id: 'patch-$room',
        roomId: room,
        surfaceId: room,
        orientation: SurfaceOrientation.vertical,
        frame: LocalCoordinateFrame(
            origin: const Point3Mm(0, 0, 0),
            uAxis: const Vector3D(1, 0, 0),
            vAxis: const Vector3D(0, 0, 1)),
        boundary: Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(4000, 0),
          Point2Mm(4000, 3000),
          Point2Mm(0, 3000)
        ]));
    final draft = SurfaceRouteDraft(nextId: () => 'n-${sequence++}')
      ..addPoint(patch, start)
      ..addPoint(patch, end, method: method, channelId: 'channel-$room');
    return FloorRoutingRun(
        run: CableRun(
            id: id, roomId: room, name: id, circuitId: 'c-$room', routeId: id),
        route: draft.route(id: id, roomId: room, name: id),
        ready: ready);
  }

  final a =
      run('a', 'room-a', const Point2Mm(100, 100), const Point2Mm(1000, 100));
  final b =
      run('b', 'room-b', const Point2Mm(100, 100), const Point2Mm(1000, 100));
  final c =
      run('c', 'room-b', const Point2Mm(1000, 100), const Point2Mm(2000, 100));
  final d =
      run('d', 'room-b', const Point2Mm(1000, 100), const Point2Mm(1000, 2000));
  FloorRoutingHandoff handoff(
          {String id = 'h',
          FloorRoutingRun? from,
          FloorRoutingRun? to,
          String? signature}) =>
      FloorRoutingHandoff(
          id: id,
          floorId: 'floor',
          name: id,
          fromRunId: (from ?? a).run.id,
          toRunId: (to ?? b).run.id,
          fromSignature:
              signature ?? (from ?? a).endpointSignature(start: false),
          toSignature: (to ?? b).endpointSignature(start: true));
  final panel = FloorRoutingPanel(
      id: 'p',
      floorId: 'floor',
      code: 'DB-01',
      name: 'Floor panel',
      feeds: [
        FloorPanelFeed(
            runId: 'a', endpointSignature: a.endpointSignature(start: true))
      ]);
  final junction = RoutingJunction(
      id: 'j',
      code: 'J-01',
      type: RoutingJunctionType.junctionBox,
      roomId: 'room-b',
      xMm: 1000,
      yMm: 0,
      zMm: 100,
      connections: [
        const RoutingJunctionConnection(
            runId: 'b', direction: RoutingConnectionDirection.incoming),
        const RoutingJunctionConnection(
            runId: 'c', direction: RoutingConnectionDirection.outgoing),
        const RoutingJunctionConnection(
            runId: 'd', direction: RoutingConnectionDirection.outgoing),
      ]);
  FloorRoutingGraph graph(
          {List<FloorRoutingHandoff>? links,
          List<FloorRoutingRun>? runs,
          List<FloorRoutingPanel>? panels,
          List<String> junctionErrors = const []}) =>
      FloorRoutingGraph(
          floorId: 'floor',
          roomNames: {'room-a': 'Hall', 'room-b': 'Workshop'},
          runs: runs ?? [a, b, c, d],
          panels: panels ?? [panel],
          handoffs: links ?? [handoff()],
          junctions: [junction],
          junctionIssues: (_) => junctionErrors);
  test('panel through room handoff and junction reaches selected endpoint', () {
    final g = graph(), up = graph().trace('c', FloorTraceDirection.upstream);
    expect(up.runIds, {'a', 'b', 'c'});
    expect(up.panelIds, {'p'});
    expect(up.edges.length, 2);
    expect(up.issues, isEmpty);
    expect(g.trace('a', FloorTraceDirection.downstream).runIds,
        {'a', 'b', 'c', 'd'});
    expect(g.visibleRuns(FloorGraphMode.branch, selectedRunId: 'c'),
        {'a', 'b', 'c'});
  });
  test('stale endpoint and unavailable run break continuity visibly', () {
    final g = graph(links: [handoff(signature: 'old')]);
    expect(g.edges.where((e) => e.id == 'handoff:h'), isEmpty);
    final trace = g.trace('c', FloorTraceDirection.upstream);
    expect(trace.panelIds, isEmpty);
    expect(trace.issues, isNotEmpty);
    expect(graph(runs: [b, c, d]).issues['handoff:h'], isNotEmpty);
    expect(
        graph().trace('missing', FloorTraceDirection.upstream).runIds, isEmpty);
  });
  test('cycles terminate and are excluded, duplicates rejected', () {
    final g = graph(links: [handoff(), handoff(id: 'return', from: b, to: a)]);
    expect(g.issues['handoff:h'], contains('Directed cycle requires review.'));
    expect(g.trace('a', FloorTraceDirection.downstream).runIds, {'a'});
    final duplicates = graph(links: [handoff(), handoff(id: 'duplicate')]);
    expect(duplicates.issues['handoff:duplicate'], isNotEmpty);
  });
  test(
      'handoffs require same floor, different rooms and matching physical methods',
      () {
    expect(graph().handoffIssues(handoff(from: b, to: c)), isNotEmpty);
    final tray = run(
        'tray', 'room-b', const Point2Mm(100, 100), const Point2Mm(1000, 100),
        method: LayingMethod.tray);
    final g = graph(runs: [a, tray], links: []);
    expect(g.handoffIssues(handoff(to: tray)), isNotEmpty);
    final outside = FloorRoutingPanel(
        id: 'outside', floorId: 'other', code: 'x', name: 'x');
    expect(g.panelIssues(outside), isNotEmpty);
  });
  test('filters are derived from segment methods and retain branching', () {
    final g = graph();
    expect(g.visibleRuns(FloorGraphMode.conduit), {'a', 'b', 'c', 'd'});
    expect(g.visibleRuns(FloorGraphMode.tray), isEmpty);
    expect(g.visibleRuns(FloorGraphMode.branch), isEmpty);
    expect(
        graph(junctionErrors: ['stale'])
            .trace('b', FloorTraceDirection.downstream)
            .runIds,
        {'b'});
  });
  test('panel feed signature and source ownership are validated', () {
    final second = FloorRoutingPanel(
        id: 'p2',
        floorId: 'floor',
        code: 'DB-02',
        name: 'other',
        feeds: panel.feeds);
    expect(graph(panels: [panel, second]).issues['panel:p2'], isNotEmpty);
    final stale = FloorRoutingPanel(
        id: 'p',
        floorId: 'floor',
        code: 'DB-01',
        name: 'panel',
        feeds: const [FloorPanelFeed(runId: 'a', endpointSignature: 'stale')]);
    expect(
        graph(panels: [stale])
            .trace('a', FloorTraceDirection.upstream)
            .panelIds,
        isEmpty);
  });
}
