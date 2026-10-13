import 'package:engineering_core/engineering_core.dart';
import '../domain/project_models.dart';
import 'cable_routing_repository.dart';

class FloorRoutingSnapshot {
  const FloorRoutingSnapshot({
    this.project,
    this.floor,
    this.rooms = const [],
    this.routing = const {},
    this.panels = const [],
    this.handoffs = const [],
  });
  final ProjectRecord? project;
  final FloorRecord? floor;
  final List<RoomRecord> rooms;
  final Map<String, RoomRoutingSnapshot> routing;
  final List<FloorRoutingPanel> panels;
  final List<FloorRoutingHandoff> handoffs;
  FloorRoutingGraph graph({
    List<FloorRoutingPanel>? panels,
    List<FloorRoutingHandoff>? handoffs,
  }) => FloorRoutingGraph(
    floorId: floor?.id ?? '',
    roomNames: {for (final room in rooms) room.id: room.name},
    runs: [
      for (final snapshot in routing.values)
        for (final run in snapshot.runs)
          FloorRoutingRun(
            run: run,
            route:
                snapshot.routes.where((r) => r.id == run.routeId).firstOrNull ??
                CableRoute(
                  id: run.routeId,
                  roomId: run.roomId,
                  name: "Unavailable route",
                  nodes: const [],
                  segments: const [],
                ),
            ready: snapshot.cableLength(run) != null,
          ),
    ],
    panels: panels ?? this.panels,
    handoffs: handoffs ?? this.handoffs,
    junctions: routing.values.expand((s) => s.junctions),
    junctionIssues:
        (j) =>
            routing[j.roomId]?.junctionIssues(j) ??
            ['Junction room is unavailable.'],
  );
}

abstract interface class FloorRoutingRepository {
  Future<FloorRoutingSnapshot> load(String floorId);
  Stream<FloorRoutingSnapshot> watch(String floorId);
  Future<void> savePanel(FloorRoutingPanel panel);
  Future<void> saveHandoff(FloorRoutingHandoff handoff);
  Future<void> deletePanel(String id);
  Future<void> deleteHandoff(String id);
}
