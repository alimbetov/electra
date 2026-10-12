import 'package:engineering_core/engineering_core.dart';

import 'geometry_repository.dart';

final class RoomRoutingSnapshot {
  const RoomRoutingSnapshot({
    required this.geometry,
    this.routes = const [],
    this.junctions = const [],
    this.runs = const [],
    this.channels = const [],
    this.activeCircuitIds = const {},
  });
  final RoomGeometrySnapshot geometry;
  final List<CableRoute> routes;
  final List<RoutingJunction> junctions;
  List<String> junctionIssues(RoutingJunction junction) =>
      RoutingJunctionValidator.validate(
        junction: junction,
        runs: runs,
        routes: routes,
        patches: geometry.patches,
        activeCircuitIds: activeCircuitIds,
        routeReady: (route) => calculate(route).ready,
        others: junctions,
      );
  final List<CableRun> runs;
  final List<PhysicalChannel> channels;
  final Set<String> activeCircuitIds;
  double? cableLength(CableRun run) {
    final route = routes.where((route) => route.id == run.routeId).firstOrNull;
    return route == null || !activeCircuitIds.contains(run.circuitId)
        ? null
        : calculate(route).cableLengthMm(run);
  }

  RouteCalculation calculate(CableRoute route) => CableRouteValidator.calculate(
    route: route,
    patches: geometry.patches,
    edges: geometry.edges,
    adjacencies: geometry.adjacencies,
    channels: channels,
    openings: geometry.openings,
  );
}

abstract interface class CableRoutingRepository {
  Future<RoomRoutingSnapshot> loadRoomRouting(String roomId);
  Stream<RoomRoutingSnapshot> watchRoomRouting(String roomId);
  Future<void> saveRouteWithRun({
    required CableRoute route,
    required CableRun run,
  });
  Future<void> saveJunction(RoutingJunction junction);
  Future<void> saveChannel(PhysicalChannel channel);
}
