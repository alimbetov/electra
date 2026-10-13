import 'cable_routing.dart';
import 'geometry.dart';
import 'spatial_geometry.dart';

enum RoutingJunctionType {
  junctionBox,
  distributionBox,
  terminalBox,
  tee,
  splitter,
  cableTrayBranch,
  conduitBranch,
  floorBox,
  ceilingBox,
  riserTakeoff,
  panelEntry,
  transition,
  custom,
}

enum RoutingJunctionViewMode {
  inPlace,
  schematic,
  installationDetail,
}

enum RoutingConnectionDirection {
  incoming,
  outgoing,
}

class RoutingJunctionConnection {
  const RoutingJunctionConnection({
    required this.runId,
    required this.direction,
    this.circuitOrNetworkId,
    this.physicalChannelId,
    this.label,
    this.nodeId,
  });

  final String runId;
  final String? nodeId;
  final RoutingConnectionDirection direction;
  final String? circuitOrNetworkId;
  final String? physicalChannelId;
  final String? label;
}

class RoutingJunction {
  const RoutingJunction({
    required this.id,
    required this.code,
    required this.type,
    required this.xMm,
    required this.yMm,
    required this.zMm,
    required this.connections,
    this.floorId,
    this.roomId,
    this.surfacePatchId,
    this.physicalContainerId,
    this.notes,
    this.localPosition,
  });

  final Point2Mm? localPosition;
  final String id;
  final String code;
  final RoutingJunctionType type;
  final int xMm;
  final int yMm;
  final int zMm;
  final List<RoutingJunctionConnection> connections;
  final String? floorId;
  final String? roomId;
  final String? surfacePatchId;
  final String? physicalContainerId;
  final String? notes;

  Iterable<RoutingJunctionConnection> get incoming => connections.where(
        (connection) =>
            connection.direction == RoutingConnectionDirection.incoming,
      );

  Iterable<RoutingJunctionConnection> get outgoing => connections.where(
        (connection) =>
            connection.direction == RoutingConnectionDirection.outgoing,
      );

  bool get isBranching => outgoing.length > 1;
}

/// Connections terminate ordered routes; geometric crossings never imply connectivity.
class RoutingJunctionValidator {
  static List<String> validate({
    required RoutingJunction junction,
    required Iterable<CableRun> runs,
    required Iterable<CableRoute> routes,
    required Iterable<SurfacePatch> patches,
    required Set<String> activeCircuitIds,
    required bool Function(CableRoute) routeReady,
    Iterable<RoutingJunction> others = const [],
  }) {
    final issues = <String>[];
    final patch =
        patches.where((p) => p.id == junction.surfacePatchId).firstOrNull;
    final local = junction.localPosition;
    if (junction.id.trim().isEmpty || junction.code.trim().isEmpty) {
      issues.add('Junction ID and code are required.');
    }
    if (patch == null ||
        patch.roomId != junction.roomId ||
        local == null ||
        !patch.boundary.containsPointInclusive(local)) {
      issues.add('Choose a position on an active surface in this room.');
    } else {
      final world = roundedWorldPosition(patch, local);
      if (world != Point3Mm(junction.xMm, junction.yMm, junction.zMm)) {
        issues.add('Junction geometry changed; review its position.');
      }
    }
    if (junction.incoming.isEmpty || junction.outgoing.isEmpty) {
      issues.add('Connect at least one incoming and one outgoing run.');
    }
    final seen = <String>{};
    final circuits = <String>{};
    final physical = junction.type == RoutingJunctionType.cableTrayBranch ||
        junction.type == RoutingJunctionType.conduitBranch;
    for (final connection in junction.connections) {
      if (!seen.add(connection.runId)) issues.add('Duplicate run connection.');
      final run = runs.where((r) => r.id == connection.runId).firstOrNull;
      final route = routes.where((r) => r.id == run?.routeId).firstOrNull;
      if (run == null ||
          route == null ||
          route.nodes.isEmpty ||
          run.roomId != junction.roomId ||
          !activeCircuitIds.contains(run.circuitId) ||
          !routeReady(route)) {
        issues.add(
            'Connected run is missing, invalid or belongs to another room.');
        continue;
      }
      circuits.add(run.circuitId);
      if (connection.circuitOrNetworkId != run.circuitId) {
        issues.add('Connection circuit changed; review assignment.');
      }
      final node = connection.direction == RoutingConnectionDirection.incoming
          ? route.nodes.last
          : route.nodes.first;
      if (connection.nodeId != node.id ||
          node.kind != RouteNodeKind.endpoint ||
          node.anchor.patchId != junction.surfacePatchId ||
          node.anchor.localPosition != local ||
          node.worldPosition !=
              Point3Mm(junction.xMm, junction.yMm, junction.zMm)) {
        issues.add(
            'Connection must terminate at the junction on its host surface.');
      }
      final segment =
          connection.direction == RoutingConnectionDirection.incoming
              ? route.segments.last
              : route.segments.first;
      if (connection.physicalChannelId != segment.physicalChannelId) {
        issues.add('Connection channel changed; review assignment.');
      }
      if (physical &&
          segment.layingMethod !=
              (junction.type == RoutingJunctionType.cableTrayBranch
                  ? LayingMethod.tray
                  : LayingMethod.conduit)) {
        issues.add('Physical branch requires matching laying methods.');
      }
      if (others.any((j) =>
          j.id != junction.id &&
          j.connections.any((c) =>
              c.runId == connection.runId &&
              c.direction == connection.direction))) {
        issues.add('This run endpoint already belongs to another junction.');
      }
    }
    if (!physical && circuits.length > 1) {
      issues.add('Electrical junction connections must belong to one circuit.');
    }
    return List.unmodifiable(issues);
  }
}
