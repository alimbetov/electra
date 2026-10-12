import 'cable_routing.dart';
import 'routing_junction.dart';

enum FloorTraceDirection { upstream, downstream }

enum FloorGraphMode { overview, tray, conduit, branch }

class FloorRoutingPanel {
  const FloorRoutingPanel(
      {required this.id,
      required this.floorId,
      required this.code,
      required this.name,
      this.feeds = const []});
  final String id, floorId, code, name;
  final List<FloorPanelFeed> feeds;
}

class FloorPanelFeed {
  const FloorPanelFeed({required this.runId, required this.endpointSignature});
  final String runId, endpointSignature;
}

/// A declared physical handoff is not an electrical splice or measured segment.
class FloorRoutingHandoff {
  const FloorRoutingHandoff(
      {required this.id,
      required this.floorId,
      required this.name,
      required this.fromRunId,
      required this.toRunId,
      required this.fromSignature,
      required this.toSignature});
  final String id,
      floorId,
      name,
      fromRunId,
      toRunId,
      fromSignature,
      toSignature;
}

class FloorRoutingRun {
  const FloorRoutingRun(
      {required this.run, required this.route, required this.ready});
  final CableRun run;
  final CableRoute route;
  final bool ready;
  String endpointSignature({required bool start}) {
    if (route.nodes.isEmpty || route.segments.isEmpty) return '';
    final n = start ? route.nodes.first : route.nodes.last;
    final s = start ? route.segments.first : route.segments.last;
    return [
      run.id,
      run.roomId,
      run.circuitId,
      route.id,
      n.id,
      n.anchor.patchId,
      n.anchor.localPosition.xMm,
      n.anchor.localPosition.yMm,
      n.worldPosition.xMm,
      n.worldPosition.yMm,
      n.worldPosition.zMm,
      s.layingMethod.name,
      s.physicalChannelId
    ].join('|');
  }
}

class FloorGraphEdge {
  const FloorGraphEdge(
      {required this.id,
      required this.from,
      required this.to,
      required this.label,
      required this.physical});
  final String id, from, to, label;
  final bool physical;
}

class FloorRoutingTrace {
  FloorRoutingTrace(
      {required Iterable<String> runIds,
      required Iterable<String> panelIds,
      required Iterable<FloorGraphEdge> edges,
      required Iterable<String> issues})
      : runIds = Set.unmodifiable(runIds),
        panelIds = Set.unmodifiable(panelIds),
        edges = List.unmodifiable(edges),
        issues = List.unmodifiable(issues);
  final Set<String> runIds, panelIds;
  final List<FloorGraphEdge> edges;
  final List<String> issues;
}

/// Derived only from active canonical records and explicit directed connections.
class FloorRoutingGraph {
  FloorRoutingGraph(
      {required this.floorId,
      required Map<String, String> roomNames,
      required Iterable<FloorRoutingRun> runs,
      Iterable<FloorRoutingPanel> panels = const [],
      Iterable<FloorRoutingHandoff> handoffs = const [],
      Iterable<RoutingJunction> junctions = const [],
      required List<String> Function(RoutingJunction) junctionIssues})
      : roomNames = Map.unmodifiable(roomNames),
        runs = Map.unmodifiable({for (final r in runs) r.run.id: r}),
        panels = List.unmodifiable(panels),
        handoffs = List.unmodifiable(handoffs) {
    for (final r in this.runs.values) {
      if (!r.ready || !this.roomNames.containsKey(r.run.roomId)) {
        issues['run:${r.run.id}'] = ['Run requires review.'];
      }
    }
    for (final panel in this.panels) {
      final errors = panelIssues(panel);
      if (errors.isNotEmpty) issues['panel:${panel.id}'] = errors;
    }
    for (final junction in junctions) {
      final errors = junctionIssues(junction);
      if (errors.isNotEmpty) {
        issues['junction:${junction.id}'] = errors;
        continue;
      }
      for (final incoming in junction.incoming) {
        for (final outgoing in junction.outgoing) {
          if (!this.runs.containsKey(incoming.runId) ||
              !this.runs.containsKey(outgoing.runId)) continue;
          _edges.add(FloorGraphEdge(
              id: 'junction:${junction.id}',
              from: incoming.runId,
              to: outgoing.runId,
              label: junction.code,
              physical: junction.type == RoutingJunctionType.cableTrayBranch ||
                  junction.type == RoutingJunctionType.conduitBranch));
        }
      }
    }
    for (final handoff in this.handoffs) {
      final errors = handoffIssues(handoff);
      if (errors.isNotEmpty) {
        issues['handoff:${handoff.id}'] = errors;
      } else {
        _edges.add(FloorGraphEdge(
            id: 'handoff:${handoff.id}',
            from: handoff.fromRunId,
            to: handoff.toRunId,
            label: handoff.name,
            physical: true));
      }
    }
    final cyclic = _edges.where((e) => _reachable(e.to, e.from)).toList();
    for (final edge in cyclic) {
      issues
          .putIfAbsent(edge.id, () => [])
          .add('Directed cycle requires review.');
    }
    _edges.removeWhere((e) => cyclic.contains(e));
  }
  final String floorId;
  final Map<String, String> roomNames;
  final Map<String, FloorRoutingRun> runs;
  final List<FloorRoutingPanel> panels;
  final List<FloorRoutingHandoff> handoffs;
  final Map<String, List<String>> issues = {};
  final List<FloorGraphEdge> _edges = [];
  List<FloorGraphEdge> get edges => List.unmodifiable(_edges);

  List<String> panelIssues(FloorRoutingPanel panel) {
    final result = <String>[];
    if (panel.floorId != floorId ||
        panel.id.trim().isEmpty ||
        panel.code.trim().isEmpty ||
        panel.name.trim().isEmpty) {
      result.add('Panel ID, floor, code and name are required.');
    }
    final seen = <String>{};
    for (final feed in panel.feeds) {
      final r = runs[feed.runId];
      if (!seen.add(feed.runId)) result.add('Duplicate panel feed.');
      if (r == null ||
          !r.ready ||
          !roomNames.containsKey(r.run.roomId) ||
          feed.endpointSignature != r.endpointSignature(start: true)) {
        result.add('Panel feed endpoint changed or is unavailable.');
      }
      if (panels.any((p) =>
          p.id != panel.id && p.feeds.any((f) => f.runId == feed.runId))) {
        result.add('Run already has a different source panel.');
      }
    }
    return result;
  }

  List<String> handoffIssues(FloorRoutingHandoff h) {
    final result = <String>[];
    final from = runs[h.fromRunId], to = runs[h.toRunId];
    if (h.id.trim().isEmpty ||
        h.name.trim().isEmpty ||
        h.floorId != floorId ||
        h.fromRunId == h.toRunId)
      result
          .add('Choose a named handoff between different runs on this floor.');
    if (from == null ||
        to == null ||
        !from.ready ||
        !to.ready ||
        !roomNames.containsKey(from.run.roomId) ||
        !roomNames.containsKey(to.run.roomId)) {
      result.add('Both handoff runs must be active and valid on this floor.');
      return result;
    }
    if (from.run.roomId == to.run.roomId)
      result.add('Use a junction for connections inside one room.');
    if (h.fromSignature != from.endpointSignature(start: false) ||
        h.toSignature != to.endpointSignature(start: true)) {
      result.add('Handoff endpoint or channel changed; review assignment.');
    }
    if (from.route.segments.isEmpty || to.route.segments.isEmpty) return result;
    final method = from.route.segments.last.layingMethod;
    if ((method != LayingMethod.tray && method != LayingMethod.conduit) ||
        method != to.route.segments.first.layingMethod) {
      result.add(
          'A physical handoff requires matching tray or conduit endpoints.');
    }
    if (handoffs.any((other) =>
        other.id != h.id &&
        other.fromRunId == h.fromRunId &&
        other.toRunId == h.toRunId)) {
      result.add('Duplicate handoff.');
    }
    return result;
  }

  bool _reachable(String start, String target) {
    final queue = [start], seen = <String>{};
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (id == target) return true;
      if (!seen.add(id)) continue;
      queue.addAll(_edges.where((e) => e.from == id).map((e) => e.to));
    }
    return false;
  }

  Set<String> visibleRuns(FloorGraphMode mode, {String? selectedRunId}) {
    if (mode == FloorGraphMode.branch) {
      if (selectedRunId == null) return {};
      return {
        ...trace(selectedRunId, FloorTraceDirection.upstream).runIds,
        ...trace(selectedRunId, FloorTraceDirection.downstream).runIds
      };
    }
    return runs.values
        .where((r) =>
            mode == FloorGraphMode.overview ||
            r.route.segments.any((s) =>
                s.layingMethod ==
                (mode == FloorGraphMode.tray
                    ? LayingMethod.tray
                    : LayingMethod.conduit)))
        .map((r) => r.run.id)
        .toSet();
  }

  FloorRoutingTrace trace(String runId, FloorTraceDirection direction) {
    final seen = <String>{},
        queue = [runId],
        selectedEdges = <FloorGraphEdge>[];
    final errors = <String>[];
    if (!runs.containsKey(runId)) errors.add('Selected run is unavailable.');
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!runs.containsKey(id) || !seen.add(id)) continue;
      for (final edge in _edges.where((e) =>
          direction == FloorTraceDirection.upstream
              ? e.to == id
              : e.from == id)) {
        selectedEdges.add(edge);
        queue.add(
            direction == FloorTraceDirection.upstream ? edge.from : edge.to);
      }
    }
    final sources = panels
        .where((p) =>
            !issues.containsKey('panel:${p.id}') &&
            p.feeds.any((f) => seen.contains(f.runId)))
        .map((p) => p.id)
        .toSet();
    // Include blocked topology diagnostics rather than presenting a truncated path as complete.
    errors.addAll(issues.entries
        .map((entry) => '${entry.key}: ${entry.value.join(" ")}'));
    if (direction == FloorTraceDirection.upstream && sources.isEmpty)
      errors.add('No valid source panel reached.');
    return FloorRoutingTrace(
        runIds: seen, panelIds: sources, edges: selectedEdges, issues: errors);
  }
}
