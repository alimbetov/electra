import 'geometry.dart';
import 'spatial_geometry.dart';

enum RouteNodeKind { endpoint, bend, surfaceTransition }

enum LayingMethod { surface, wallChase, conduit, tray, trunking }

enum PhysicalChannelKind { conduit, tray, trunking }

final class SurfaceRouteAnchor {
  const SurfaceRouteAnchor(
      {required this.patchId, required this.localPosition});
  final String patchId;
  final Point2Mm localPosition;
}

final class RouteNode {
  const RouteNode(
      {required this.id,
      required this.kind,
      required this.worldPosition,
      required this.anchor,
      this.otherAnchor,
      this.adjacencyId});
  final String id;
  final RouteNodeKind kind;
  final Point3Mm worldPosition;
  final SurfaceRouteAnchor anchor;
  final SurfaceRouteAnchor? otherAnchor;
  final String? adjacencyId;
  SurfaceRouteAnchor? anchorOn(String patchId) => anchor.patchId == patchId
      ? anchor
      : otherAnchor?.patchId == patchId
          ? otherAnchor
          : null;
}

final class RouteSegment {
  const RouteSegment(
      {required this.id,
      required this.fromNodeId,
      required this.toNodeId,
      required this.surfacePatchId,
      this.layingMethod = LayingMethod.surface,
      this.physicalChannelId});
  final String id;
  final String fromNodeId;
  final String toNodeId;
  final String surfacePatchId;
  final LayingMethod layingMethod;
  final String? physicalChannelId;
}

/// Ordered non-branching route; junction graphs are extended in FL10.
final class CableRoute {
  CableRoute(
      {required this.id,
      required this.roomId,
      required this.name,
      required Iterable<RouteNode> nodes,
      required Iterable<RouteSegment> segments})
      : nodes = List.unmodifiable(nodes),
        segments = List.unmodifiable(segments);
  final String id;
  final String roomId;
  final String name;
  final List<RouteNode> nodes;
  final List<RouteSegment> segments;
}

final class PhysicalChannel {
  const PhysicalChannel(
      {required this.id,
      required this.roomId,
      required this.name,
      required this.kind});
  final String id;
  final String roomId;
  final String name;
  final PhysicalChannelKind kind;
}

final class CableRun {
  const CableRun(
      {required this.id,
      required this.roomId,
      required this.name,
      required this.circuitId,
      required this.routeId,
      this.reservePercent = 0,
      this.terminationAllowanceMm = 0});
  final String id;
  final String roomId;
  final String name;
  final String circuitId;
  final String routeId;
  final double reservePercent;
  final int terminationAllowanceMm;
  List<String> validate() => [
        if ([id, roomId, name, circuitId, routeId]
            .any((value) => value.trim().isEmpty))
          'MISSING_RUN_REFERENCE',
        if (!reservePercent.isFinite || reservePercent < 0) 'INVALID_RESERVE',
        if (terminationAllowanceMm < 0) 'INVALID_ALLOWANCE',
      ];
}

final class RouteIssue {
  const RouteIssue(this.code, this.message, {this.objectId});
  final String code;
  final String message;
  final String? objectId;
}

final class RouteCalculation {
  RouteCalculation(
      {required this.routeId,
      required this.roomId,
      required this.geometricLengthMm,
      required Iterable<RouteIssue> issues})
      : issues = List.unmodifiable(issues);
  final String routeId;
  final String roomId;
  final double? geometricLengthMm;
  final List<RouteIssue> issues;
  bool get ready => geometricLengthMm != null && issues.isEmpty;
  double? cableLengthMm(CableRun run) {
    if (!ready ||
        run.routeId != routeId ||
        run.roomId != roomId ||
        run.validate().isNotEmpty) return null;
    final length = geometricLengthMm! * (1 + run.reservePercent / 100) +
        run.terminationAllowanceMm;
    return length.isFinite ? length : null;
  }
}

Point3Mm roundedWorldPosition(SurfacePatch patch, Point2Mm point) {
  final world = patch.worldPoint(point);
  return Point3Mm(world.x.round(), world.y.round(), world.z.round());
}

abstract final class CableRouteValidator {
  static RouteCalculation calculate(
      {required CableRoute route,
      required Iterable<SurfacePatch> patches,
      required Iterable<SurfaceEdge> edges,
      required Iterable<SurfaceAdjacency> adjacencies,
      Iterable<PhysicalChannel> channels = const [],
      Iterable<Opening> openings = const []}) {
    final issues = <RouteIssue>[];
    void issue(String code, String message, String id) =>
        issues.add(RouteIssue(code, message, objectId: id));
    final patchById = {for (final patch in patches) patch.id: patch};
    final edgeById = {for (final edge in edges) edge.id: edge};
    final adjacencyById = {
      for (final adjacency in adjacencies) adjacency.id: adjacency
    };
    final channelById = {for (final channel in channels) channel.id: channel};
    final nodeById = <String, RouteNode>{};
    if ([route.id, route.roomId, route.name]
        .any((value) => value.trim().isEmpty))
      issue('MISSING_ROUTE_IDENTITY',
          'Route identity, room and name are required.', route.id);
    if (route.nodes.length < 2 ||
        route.segments.length != route.nodes.length - 1)
      issue(
          'INVALID_ROUTE_CHAIN',
          'A cable route requires a connected non-branching sequence of at least two nodes.',
          route.id);
    for (final node in route.nodes) {
      if (node.id.trim().isEmpty || nodeById.containsKey(node.id))
        issue('DUPLICATE_NODE', 'Node IDs must be non-empty and unique.',
            node.id);
      nodeById[node.id] = node;
      for (final anchor in [
        node.anchor,
        if (node.otherAnchor != null) node.otherAnchor!
      ]) {
        final patch = patchById[anchor.patchId];
        if (patch == null || patch.roomId != route.roomId) {
          issue('NODE_PATCH_UNAVAILABLE',
              'Node host patch must be active in the route room.', node.id);
          continue;
        }
        if (!patch.boundary.containsPointInclusive(anchor.localPosition))
          issue('NODE_OUTSIDE_PATCH', 'Node lies outside its host surface.',
              node.id);
      }
      final primary = patchById[node.anchor.patchId];
      if (primary != null) {
        final world = primary.worldPoint(node.anchor.localPosition);
        if (![world.x, world.y, world.z].every((value) => value.isFinite)) {
          issue('INVALID_FRAME',
              'Surface frame must produce finite world coordinates.', node.id);
        } else if (roundedWorldPosition(primary, node.anchor.localPosition) !=
            node.worldPosition) {
          issue(
              'STALE_WORLD_POSITION',
              'Surface frame changed; review the saved route coordinates.',
              node.id);
        }
      }
      if (node.kind == RouteNodeKind.surfaceTransition) {
        final adjacency = adjacencyById[node.adjacencyId];
        final other = node.otherAnchor;
        if (adjacency == null ||
            other == null ||
            other.patchId == node.anchor.patchId) {
          issue(
              'INVALID_TRANSITION',
              'Transition requires two host anchors and an active adjacency.',
              node.id);
          continue;
        }
        final forward = adjacency.fromPatchId == node.anchor.patchId &&
            adjacency.toPatchId == other.patchId;
        final backward = adjacency.toPatchId == node.anchor.patchId &&
            adjacency.fromPatchId == other.patchId;
        if (!forward && !backward) {
          issue('TRANSITION_PATCH_MISMATCH',
              'Transition must follow the declared adjacent patches.', node.id);
          continue;
        }
        final firstEdge =
            edgeById[forward ? adjacency.fromEdgeId : adjacency.toEdgeId];
        final secondEdge =
            edgeById[forward ? adjacency.toEdgeId : adjacency.fromEdgeId];
        if (firstEdge == null ||
            secondEdge == null ||
            firstEdge.patchId != node.anchor.patchId ||
            secondEdge.patchId != other.patchId ||
            !_onEdge(node.anchor.localPosition, firstEdge) ||
            !_onEdge(other.localPosition, secondEdge)) {
          issue(
              'TRANSITION_OFF_EDGE',
              'Both transition anchors must lie on the finite shared edges.',
              node.id);
          continue;
        }
        final second = patchById[other.patchId];
        if (primary != null &&
            second != null &&
            (!_edgeOnBoundary(firstEdge, primary.boundary) ||
                !_edgeOnBoundary(secondEdge, second.boundary))) {
          issue(
              'TRANSITION_NOT_BOUNDARY',
              'Transitions must use actual boundaries of both surface patches.',
              node.id);
        }

        if (primary != null && second != null) {
          final tolerance =
              primary.frame.tolerance.linearMm > second.frame.tolerance.linearMm
                  ? primary.frame.tolerance.linearMm
                  : second.frame.tolerance.linearMm;
          final world = primary.worldPoint(node.anchor.localPosition);
          if (world.distanceTo(second.worldPoint(other.localPosition)) >
                  tolerance ||
              !_coincidentEdges(
                  primary, firstEdge, second, secondEdge, tolerance))
            issue(
                'TRANSITION_WORLD_GAP',
                'Adjacent edges and the transition point must coincide in world space.',
                node.id);
        }
      } else if (node.otherAnchor != null || node.adjacencyId != null)
        issue('UNEXPECTED_TRANSITION_DATA',
            'Only transition nodes can carry another host anchor.', node.id);
    }
    final segmentIds = <String>{};
    var length = 0.0;
    for (var i = 0; i < route.segments.length; i++) {
      final segment = route.segments[i];
      if (segment.id.trim().isEmpty || !segmentIds.add(segment.id))
        issue('DUPLICATE_SEGMENT', 'Segment IDs must be non-empty and unique.',
            segment.id);
      if (i + 1 >= route.nodes.length ||
          segment.fromNodeId != route.nodes[i].id ||
          segment.toNodeId != route.nodes[i + 1].id)
        issue(
            'DISCONNECTED_SEGMENT',
            'Segments must follow the persisted node order without forks or gaps.',
            segment.id);
      final from =
          nodeById[segment.fromNodeId]?.anchorOn(segment.surfacePatchId);
      final to = nodeById[segment.toNodeId]?.anchorOn(segment.surfacePatchId);
      final patch = patchById[segment.surfacePatchId];
      if (patch == null ||
          patch.roomId != route.roomId ||
          from == null ||
          to == null) {
        issue(
            'SEGMENT_PATCH_MISMATCH',
            'Both segment endpoints must be bound to the same host patch.',
            segment.id);
        continue;
      }
      if (from.localPosition == to.localPosition) {
        issue('ZERO_SEGMENT', 'Route segments must have non-zero length.',
            segment.id);
        continue;
      }
      final local = Segment2Mm(from.localPosition, to.localPosition);
      if (!patch.boundary.containsSegment(local))
        issue(
            'SEGMENT_OUTSIDE_PATCH',
            'The entire route segment must remain inside its host patch.',
            segment.id);
      for (final opening in openings
          .where((opening) => opening.hostSurfacePatchId == patch.id)) {
        if (_intersectsOpening(local, opening.boundary))
          issue('SEGMENT_CROSSES_OPENING',
              'Route crosses an opening; choose a path around it.', segment.id);
      }
      final worldLength = patch
          .worldPoint(from.localPosition)
          .distanceTo(patch.worldPoint(to.localPosition));
      if (!worldLength.isFinite || worldLength <= 0)
        issue('INVALID_LENGTH',
            'Segment world length must be finite and positive.', segment.id);
      length += worldLength;
      if (segment.physicalChannelId != null) {
        final channel = channelById[segment.physicalChannelId];
        if (channel == null || channel.roomId != route.roomId)
          issue('CHANNEL_UNAVAILABLE',
              'Physical channel must belong to the route room.', segment.id);
        else if (segment.layingMethod.name != channel.kind.name)
          issue(
              'CHANNEL_METHOD_MISMATCH',
              'Laying method must match the physical channel kind.',
              segment.id);
      }
    }
    for (var i = 0; i < route.nodes.length; i++) {
      final node = route.nodes[i];
      final end = i == 0 || i == route.nodes.length - 1;
      if (end && node.kind != RouteNodeKind.endpoint)
        issue('INVALID_ENDPOINT', 'First and last nodes must be endpoints.',
            node.id);
      if (!end && node.kind == RouteNodeKind.endpoint)
        issue('INTERIOR_ENDPOINT',
            'An interior route node must be a bend or transition.', node.id);
      if (node.kind == RouteNodeKind.surfaceTransition &&
          i > 0 &&
          i < route.segments.length) {
        final hosts = {
          route.segments[i - 1].surfacePatchId,
          route.segments[i].surfacePatchId
        };
        if (hosts.length != 2 ||
            !hosts.contains(node.anchor.patchId) ||
            !hosts.contains(node.otherAnchor?.patchId))
          issue(
              'TRANSITION_NOT_TRAVERSED',
              'Transition must connect segments on its two adjacent surfaces.',
              node.id);
      }
    }
    if (!length.isFinite)
      issue(
          'INVALID_LENGTH', 'Aggregated route length is not finite.', route.id);
    return RouteCalculation(
        routeId: route.id,
        roomId: route.roomId,
        geometricLengthMm: issues.isEmpty ? length : null,
        issues: issues);
  }

  static bool _onEdge(Point2Mm point, SurfaceEdge edge) =>
      _onSegment(point, edge.start, edge.end);
  static int _cross(Point2Mm a, Point2Mm b, Point2Mm c) =>
      (b.xMm - a.xMm) * (c.yMm - a.yMm) - (b.yMm - a.yMm) * (c.xMm - a.xMm);
  static bool _onSegment(Point2Mm p, Point2Mm a, Point2Mm b) =>
      _cross(a, b, p) == 0 &&
      p.xMm >= (a.xMm < b.xMm ? a.xMm : b.xMm) &&
      p.xMm <= (a.xMm > b.xMm ? a.xMm : b.xMm) &&
      p.yMm >= (a.yMm < b.yMm ? a.yMm : b.yMm) &&
      p.yMm <= (a.yMm > b.yMm ? a.yMm : b.yMm);
  static bool _opposite(int a, int b) => a < 0 && b > 0 || a > 0 && b < 0;
  static bool _intersectsOpening(Segment2Mm segment, Polygon2Mm opening) {
    if (opening.containsPointInclusive(segment.start) ||
        opening.containsPointInclusive(segment.end)) return true;
    for (final edge in opening.edges) {
      final a = _cross(segment.start, segment.end, edge.start);
      final b = _cross(segment.start, segment.end, edge.end);
      final c = _cross(edge.start, edge.end, segment.start);
      final d = _cross(edge.start, edge.end, segment.end);
      if (_opposite(a, b) && _opposite(c, d) ||
          a == 0 && _onSegment(edge.start, segment.start, segment.end) ||
          b == 0 && _onSegment(edge.end, segment.start, segment.end) ||
          c == 0 && _onSegment(segment.start, edge.start, edge.end) ||
          d == 0 && _onSegment(segment.end, edge.start, edge.end)) return true;
    }
    return false;
  }

  static bool _edgeOnBoundary(SurfaceEdge edge, Polygon2Mm polygon) {
    final dx = edge.end.xMm - edge.start.xMm,
        dy = edge.end.yMm - edge.start.yMm;
    final extent = dx * dx + dy * dy;
    int project(Point2Mm point) =>
        ((point.xMm - edge.start.xMm) * dx + (point.yMm - edge.start.yMm) * dy)
            .clamp(0, extent)
            .toInt();
    final intervals = <(int, int)>[];
    for (final boundary in polygon.edges) {
      if (_cross(edge.start, edge.end, boundary.start) != 0 ||
          _cross(edge.start, edge.end, boundary.end) != 0) continue;
      final a = project(boundary.start), b = project(boundary.end);
      intervals.add(a <= b ? (a, b) : (b, a));
    }
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    var covered = 0;
    for (final interval in intervals) {
      if (interval.$1 > covered) return false;
      if (interval.$2 > covered) covered = interval.$2;
    }
    return covered == extent;
  }

  static bool _coincidentEdges(SurfacePatch first, SurfaceEdge a,
      SurfacePatch second, SurfaceEdge b, double tolerance) {
    final a1 = first.worldPoint(a.start),
        a2 = first.worldPoint(a.end),
        b1 = second.worldPoint(b.start),
        b2 = second.worldPoint(b.end);
    return a1.distanceTo(b1) <= tolerance && a2.distanceTo(b2) <= tolerance ||
        a1.distanceTo(b2) <= tolerance && a2.distanceTo(b1) <= tolerance;
  }
}
