import 'cable_routing.dart';
import 'geometry.dart';
import 'spatial_geometry.dart';

/// Editable sketch only; a validated repository snapshot is canonical state.
final class SurfaceRouteDraft {
  SurfaceRouteDraft(
      {required this.nextId,
      Iterable<RouteNode> nodes = const [],
      Iterable<RouteSegment> segments = const []})
      : nodes = [...nodes],
        segments = [...segments];
  final String Function() nextId;
  final List<RouteNode> nodes;
  final List<RouteSegment> segments;
  String? get activePatchId => nodes.isEmpty
      ? null
      : nodes.last.otherAnchor?.patchId ?? nodes.last.anchor.patchId;

  void addPoint(SurfacePatch patch, Point2Mm point,
      {LayingMethod method = LayingMethod.surface, String? channelId}) {
    if (!patch.boundary.containsPointInclusive(point))
      throw StateError('Choose a point inside the surface.');
    final previous = nodes.isEmpty ? null : nodes.last;
    if (previous != null) {
      final anchor = previous.anchorOn(patch.id);
      if (activePatchId != patch.id || anchor == null)
        throw StateError(
            'Cross a declared surface edge before drawing on another patch.');
      if (anchor.localPosition == point)
        throw StateError('Choose a distinct point.');
    }
    final node = RouteNode(
        id: nextId(),
        kind: RouteNodeKind.endpoint,
        worldPosition: roundedWorldPosition(patch, point),
        anchor: SurfaceRouteAnchor(patchId: patch.id, localPosition: point));
    if (previous != null) {
      if (nodes.length > 1 && previous.kind == RouteNodeKind.endpoint)
        nodes[nodes.length - 1] = _copy(previous, kind: RouteNodeKind.bend);
      segments.add(RouteSegment(
          id: nextId(),
          fromNodeId: previous.id,
          toNodeId: node.id,
          surfacePatchId: patch.id,
          layingMethod: method,
          physicalChannelId: channelId));
    }
    nodes.add(node);
  }

  String cross(
      {required SurfaceAdjacency adjacency,
      required Point2Mm nearPoint,
      required Iterable<SurfacePatch> patches,
      required Iterable<SurfaceEdge> edges,
      LayingMethod method = LayingMethod.surface,
      String? channelId}) {
    if (nodes.isEmpty)
      throw StateError('Choose a starting point before crossing a surface.');
    final current = activePatchId;
    final forward = adjacency.fromPatchId == current;
    if (!forward && adjacency.toPatchId != current)
      throw StateError('Adjacency does not belong to the active surface.');
    final sourceId = forward ? adjacency.fromPatchId : adjacency.toPatchId;
    final targetId = forward ? adjacency.toPatchId : adjacency.fromPatchId;
    final source = patches.firstWhere((patch) => patch.id == sourceId);
    final target = patches.firstWhere((patch) => patch.id == targetId);
    final edge = edges.firstWhere((edge) =>
        edge.id == (forward ? adjacency.fromEdgeId : adjacency.toEdgeId));
    final targetEdge = edges.firstWhere((edge) =>
        edge.id == (forward ? adjacency.toEdgeId : adjacency.fromEdgeId));
    final point = nearestIntegerPointOnEdge(nearPoint, edge);
    final world = source.worldPoint(point);
    final projected = target.frame.worldToLocal(world);
    final targetPoint = nearestIntegerPointOnEdge(
        Point2Mm(projected.x.round(), projected.y.round()), targetEdge);
    final tolerance =
        source.frame.tolerance.linearMm > target.frame.tolerance.linearMm
            ? source.frame.tolerance.linearMm
            : target.frame.tolerance.linearMm;
    if (world.distanceTo(target.worldPoint(targetPoint)) > tolerance)
      throw StateError(
          'No coincident integer-millimetre transition point at this edge location.');
    final previous = nodes.last;
    final samePoint = previous.anchorOn(sourceId)?.localPosition == point;
    if (samePoint &&
        (nodes.length == 1 || previous.kind == RouteNodeKind.surfaceTransition))
      throw StateError('Add a segment on the surface before crossing again.');
    if (!samePoint)
      addPoint(source, point, method: method, channelId: channelId);
    final node = nodes.last;
    nodes[nodes.length - 1] = RouteNode(
        id: node.id,
        kind: RouteNodeKind.surfaceTransition,
        worldPosition: node.worldPosition,
        anchor: node.anchor,
        otherAnchor:
            SurfaceRouteAnchor(patchId: targetId, localPosition: targetPoint),
        adjacencyId: adjacency.id);
    return targetId;
  }

  void removeLast() {
    if (nodes.isEmpty) return;
    nodes.removeLast();
    if (segments.isNotEmpty) segments.removeLast();
    if (nodes.length > 1 && nodes.last.kind == RouteNodeKind.bend)
      nodes[nodes.length - 1] = _copy(nodes.last, kind: RouteNodeKind.endpoint);
  }

  CableRoute route(
          {required String id, required String roomId, required String name}) =>
      CableRoute(
          id: id, roomId: roomId, name: name, nodes: nodes, segments: segments);

  static RouteNode _copy(RouteNode node, {required RouteNodeKind kind}) =>
      RouteNode(
          id: node.id,
          kind: kind,
          worldPosition: node.worldPosition,
          anchor: node.anchor,
          otherAnchor: node.otherAnchor,
          adjacencyId: node.adjacencyId);

  /// Snap to the nearest representable lattice point, not a rounded off-edge point.
  static Point2Mm nearestIntegerPointOnEdge(Point2Mm point, SurfaceEdge edge) {
    final dx = edge.end.xMm - edge.start.xMm,
        dy = edge.end.yMm - edge.start.yMm;
    final steps = dx.abs().gcd(dy.abs());
    final parameter = ((point.xMm - edge.start.xMm) * dx +
            (point.yMm - edge.start.yMm) * dy) /
        (dx * dx + dy * dy);
    final index = (parameter * steps).round().clamp(0, steps).toInt();
    return Point2Mm(edge.start.xMm + (dx ~/ steps) * index,
        edge.start.yMm + (dy ~/ steps) * index);
  }
}
