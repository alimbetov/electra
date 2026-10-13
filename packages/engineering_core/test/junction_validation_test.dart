import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';
import 'cable_routing_test.dart' show wall;

void main() {
  final patch = wall('a');
  var sequence = 0;
  CableRoute path(String id, Point2Mm start, Point2Mm end) {
    final draft = SurfaceRouteDraft(nextId: () => 'node-${sequence++}')
      ..addPoint(patch, start)
      ..addPoint(patch, end);
    return draft.route(id: id, roomId: 'room', name: id);
  }

  final paths = [
    path('in', const Point2Mm(100, 1000), const Point2Mm(1000, 1000)),
    path('out1', const Point2Mm(1000, 1000), const Point2Mm(2000, 1000)),
    path('out2', const Point2Mm(1000, 1000), const Point2Mm(1000, 2000)),
  ];
  final runs = [
    for (final p in paths)
      CableRun(
          id: p.id, roomId: 'room', name: p.id, circuitId: 'c', routeId: p.id)
  ];
  final connections = [
    for (final p in paths)
      RoutingJunctionConnection(
          runId: p.id,
          nodeId: (p.id == 'in' ? p.nodes.last : p.nodes.first).id,
          direction: p.id == 'in'
              ? RoutingConnectionDirection.incoming
              : RoutingConnectionDirection.outgoing,
          circuitOrNetworkId: 'c')
  ];
  RoutingJunction junction(
          {List<RoutingJunctionConnection>? links, int x = 1000}) =>
      RoutingJunction(
          id: 'j',
          code: 'J-01',
          type: RoutingJunctionType.junctionBox,
          roomId: 'room',
          surfacePatchId: 'a',
          localPosition: const Point2Mm(1000, 1000),
          xMm: x,
          yMm: 0,
          zMm: 1000,
          connections: links ?? connections);
  List<String> issues(RoutingJunction j,
          {List<CableRun>? cables, List<RoutingJunction> others = const []}) =>
      RoutingJunctionValidator.validate(
          junction: j,
          runs: cables ?? runs,
          routes: paths,
          patches: [patch],
          activeCircuitIds: {'c', 'other'},
          routeReady: (_) => true,
          others: others);
  test('one incoming and two outgoing exact endpoints form a branch', () {
    expect(issues(junction()), isEmpty);
    expect(junction().isBranching, isTrue);
  });
  test('dangling, duplicate and stale placement are rejected', () {
    expect(issues(junction(links: [connections.first])), isNotEmpty);
    expect(issues(junction(links: [...connections, connections.last])),
        isNotEmpty);
    expect(issues(junction(x: 1001)), isNotEmpty);
  });
  test('electrical branch cannot join separate circuits or borrowed endpoints',
      () {
    final other = CableRun(
        id: 'out2',
        roomId: 'room',
        name: 'out2',
        circuitId: 'other',
        routeId: 'out2');
    expect(issues(junction(), cables: [...runs.take(2), other]), isNotEmpty);
    final owner = RoutingJunction(
        id: 'owner',
        code: 'owner',
        type: RoutingJunctionType.junctionBox,
        xMm: 1000,
        yMm: 0,
        zMm: 1000,
        connections: connections);
    expect(issues(junction(), others: [owner]), isNotEmpty);
  });
}
