import 'dart:math' as math;

import 'geometry.dart';
import 'spatial_geometry.dart';

enum SurfaceEdgeProximity { none, highlight, preview, strongPreview }

final class SurfaceEdgeCandidate {
  const SurfaceEdgeCandidate({
    required this.edge,
    required this.distanceMm,
    required this.proximity,
    required this.adjacentPatchId,
    this.adjacencyId,
    this.isCurrentPreview = false,
  });

  final SurfaceEdge edge;
  final double distanceMm;
  final SurfaceEdgeProximity proximity;
  final String? adjacentPatchId;
  final String? adjacencyId;
  final bool isCurrentPreview;

  bool get isNavigable => adjacentPatchId != null;
}

final class SurfaceNavigationThresholds {
  const SurfaceNavigationThresholds({
    this.highlightDistanceMm = 600,
    this.previewDistanceMm = 300,
    this.strongPreviewDistanceMm = 120,
    this.previewHysteresisMm = 80,
  })  : assert(highlightDistanceMm >= previewDistanceMm),
        assert(previewDistanceMm >= strongPreviewDistanceMm),
        assert(strongPreviewDistanceMm >= 0),
        assert(previewHysteresisMm >= 0);

  final double highlightDistanceMm;
  final double previewDistanceMm;
  final double strongPreviewDistanceMm;
  final double previewHysteresisMm;

  SurfaceEdgeProximity classify(double distanceMm) {
    if (distanceMm <= strongPreviewDistanceMm) {
      return SurfaceEdgeProximity.strongPreview;
    }
    if (distanceMm <= previewDistanceMm) {
      return SurfaceEdgeProximity.preview;
    }
    if (distanceMm <= highlightDistanceMm) {
      return SurfaceEdgeProximity.highlight;
    }
    return SurfaceEdgeProximity.none;
  }
}

final class SurfaceNavigationResolver {
  const SurfaceNavigationResolver({
    this.thresholds = const SurfaceNavigationThresholds(),
  });

  final SurfaceNavigationThresholds thresholds;

  List<SurfaceEdgeCandidate> rankCandidates({
    required Point2Mm pointer,
    required SurfacePatch activePatch,
    required List<SurfaceEdge> edges,
    required List<SurfaceAdjacency> adjacencies,
    String? currentPreviewEdgeId,
  }) {
    final activeEdges = edges
        .where((edge) => edge.patchId == activePatch.id)
        .toList(growable: false);

    final candidates = <SurfaceEdgeCandidate>[
      for (final edge in activeEdges)
        _candidateFor(
          pointer: pointer,
          edge: edge,
          adjacencies: adjacencies,
          currentPreviewEdgeId: currentPreviewEdgeId,
        ),
    ];

    candidates.sort((a, b) {
      final aEffective = _effectiveDistance(a);
      final bEffective = _effectiveDistance(b);
      final byDistance = aEffective.compareTo(bEffective);
      if (byDistance != 0) return byDistance;

      if (a.isNavigable != b.isNavigable) {
        return a.isNavigable ? -1 : 1;
      }
      return a.edge.id.compareTo(b.edge.id);
    });
    return List.unmodifiable(candidates);
  }

  SurfaceEdgeCandidate? nearestCandidate({
    required Point2Mm pointer,
    required SurfacePatch activePatch,
    required List<SurfaceEdge> edges,
    required List<SurfaceAdjacency> adjacencies,
    String? currentPreviewEdgeId,
  }) {
    final ranked = rankCandidates(
      pointer: pointer,
      activePatch: activePatch,
      edges: edges,
      adjacencies: adjacencies,
      currentPreviewEdgeId: currentPreviewEdgeId,
    );
    if (ranked.isEmpty) return null;
    return ranked.first;
  }

  String? resolveAdjacentPatchId({
    required String activePatchId,
    required String edgeId,
    required List<SurfaceAdjacency> adjacencies,
  }) {
    for (final adjacency in adjacencies) {
      if (adjacency.fromPatchId == activePatchId &&
          adjacency.fromEdgeId == edgeId) {
        return adjacency.toPatchId;
      }
      if (adjacency.toPatchId == activePatchId &&
          adjacency.toEdgeId == edgeId) {
        return adjacency.fromPatchId;
      }
    }
    return null;
  }

  SurfaceEdgeCandidate _candidateFor({
    required Point2Mm pointer,
    required SurfaceEdge edge,
    required List<SurfaceAdjacency> adjacencies,
    required String? currentPreviewEdgeId,
  }) {
    final distance = distanceToSegmentMm(pointer, edge.segment);
    String? adjacencyId;
    String? adjacentPatchId;
    for (final adjacency in adjacencies) {
      if (adjacency.fromPatchId == edge.patchId &&
          adjacency.fromEdgeId == edge.id) {
        adjacencyId = adjacency.id;
        adjacentPatchId = adjacency.toPatchId;
        break;
      }
      if (adjacency.toPatchId == edge.patchId &&
          adjacency.toEdgeId == edge.id) {
        adjacencyId = adjacency.id;
        adjacentPatchId = adjacency.fromPatchId;
        break;
      }
    }

    return SurfaceEdgeCandidate(
      edge: edge,
      distanceMm: distance,
      proximity: thresholds.classify(distance),
      adjacentPatchId: adjacentPatchId,
      adjacencyId: adjacencyId,
      isCurrentPreview: currentPreviewEdgeId == edge.id,
    );
  }

  double _effectiveDistance(SurfaceEdgeCandidate candidate) {
    if (!candidate.isCurrentPreview) return candidate.distanceMm;
    return math.max(0, candidate.distanceMm - thresholds.previewHysteresisMm);
  }
}

double distanceToSegmentMm(Point2Mm point, Segment2Mm segment) {
  final ax = segment.start.xMm.toDouble();
  final ay = segment.start.yMm.toDouble();
  final bx = segment.end.xMm.toDouble();
  final by = segment.end.yMm.toDouble();
  final px = point.xMm.toDouble();
  final py = point.yMm.toDouble();

  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  if (lengthSquared == 0) return math.sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay));

  final projection = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
  final t = projection.clamp(0.0, 1.0);
  final nearestX = ax + t * dx;
  final nearestY = ay + t * dy;
  final offsetX = px - nearestX;
  final offsetY = py - nearestY;
  return math.sqrt(offsetX * offsetX + offsetY * offsetY);
}
