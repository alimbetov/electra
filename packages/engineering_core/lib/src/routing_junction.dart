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
  });

  final String runId;
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
  });

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
