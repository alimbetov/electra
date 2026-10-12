enum FloorRoutingDisplayMode {
  overview,
  powerBackbone,
  controlBackbone,
  branchDetail,
  installationSequence,
}

enum RouteVisualState {
  design,
  approved,
  installed,
  asBuilt,
  tested,
  commissioned,
}

class FloorRoutingRoomRef {
  const FloorRoutingRoomRef({
    required this.roomId,
    required this.name,
  });

  final String roomId;
  final String name;
}

class FloorRoutingPanelRef {
  const FloorRoutingPanelRef({
    required this.panelId,
    required this.name,
  });

  final String panelId;
  final String name;
}

class FloorRoutingBackboneRef {
  const FloorRoutingBackboneRef({
    required this.routeId,
    required this.name,
    required this.visualState,
  });

  final String routeId;
  final String name;
  final RouteVisualState visualState;
}

class FloorRoutingJunctionRef {
  const FloorRoutingJunctionRef({
    required this.junctionId,
    required this.name,
  });

  final String junctionId;
  final String name;
}

class FloorRoutingBranchRef {
  const FloorRoutingBranchRef({
    required this.branchId,
    required this.name,
    required this.fromRef,
    required this.toRef,
  });

  final String branchId;
  final String name;
  final String fromRef;
  final String toRef;
}

class FloorRoutingView {
  const FloorRoutingView({
    required this.floorId,
    required this.displayMode,
    this.rootPanels = const [],
    this.routeBackbones = const [],
    this.trayRuns = const [],
    this.conduitRuns = const [],
    this.routingJunctions = const [],
    this.roomReferences = const [],
    this.outgoingBranches = const [],
  });

  final String floorId;
  final FloorRoutingDisplayMode displayMode;
  final List<FloorRoutingPanelRef> rootPanels;
  final List<FloorRoutingBackboneRef> routeBackbones;
  final List<FloorRoutingBackboneRef> trayRuns;
  final List<FloorRoutingBackboneRef> conduitRuns;
  final List<FloorRoutingJunctionRef> routingJunctions;
  final List<FloorRoutingRoomRef> roomReferences;
  final List<FloorRoutingBranchRef> outgoingBranches;

  int get backboneCount =>
      routeBackbones.length + trayRuns.length + conduitRuns.length;

  bool get hasContent =>
      rootPanels.isNotEmpty ||
      routeBackbones.isNotEmpty ||
      trayRuns.isNotEmpty ||
      conduitRuns.isNotEmpty ||
      routingJunctions.isNotEmpty ||
      roomReferences.isNotEmpty ||
      outgoingBranches.isNotEmpty;
}
