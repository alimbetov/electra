import 'geometry.dart';

enum SurfaceOrientation { horizontal, vertical, sloped }

enum SurfaceEdgeKind { boundary, fold, openingBoundary, featureBoundary }

enum OpeningType { door, window, passage, technicalOpening }

enum SpatialFeatureType {
  beam,
  column,
  soffit,
  niche,
  shaft,
  step,
  platform,
  recess,
  protrusion,
  custom,
}

/// Exact bounded planar patch in a room-local engineering model.
final class SurfacePatch {
  SurfacePatch({
    required this.id,
    required this.roomId,
    required this.surfaceId,
    required this.frame,
    required this.boundary,
    required this.orientation,
  }) {
    if (id.isEmpty || roomId.isEmpty || surfaceId.isEmpty) {
      throw ArgumentError('SurfacePatch identifiers must be non-empty.');
    }
  }

  final String id;
  final String roomId;
  final String surfaceId;
  final LocalCoordinateFrame frame;
  final Polygon2Mm boundary;
  final SurfaceOrientation orientation;

  Point3D worldPoint(Point2Mm localPoint) => frame.localToWorld(localPoint);
}

final class SurfaceEdge {
  SurfaceEdge({
    required this.id,
    required this.patchId,
    required this.start,
    required this.end,
    this.kind = SurfaceEdgeKind.boundary,
  }) {
    if (id.isEmpty || patchId.isEmpty) {
      throw ArgumentError('SurfaceEdge identifiers must be non-empty.');
    }
    if (start == end) {
      throw ArgumentError('SurfaceEdge endpoints must be distinct.');
    }
  }

  final String id;
  final String patchId;
  final Point2Mm start;
  final Point2Mm end;
  final SurfaceEdgeKind kind;

  Segment2Mm get segment => Segment2Mm(start, end);
}

/// Explicit topological relationship between two patch edges.
final class SurfaceAdjacency {
  SurfaceAdjacency({
    required this.id,
    required this.fromPatchId,
    required this.fromEdgeId,
    required this.toPatchId,
    required this.toEdgeId,
  }) {
    if ({id, fromPatchId, fromEdgeId, toPatchId, toEdgeId}.any(
      (e) => e.isEmpty,
    )) {
      throw ArgumentError('SurfaceAdjacency identifiers must be non-empty.');
    }
    if (fromPatchId == toPatchId && fromEdgeId == toEdgeId) {
      throw ArgumentError('SurfaceAdjacency cannot connect an edge to itself.');
    }
  }

  final String id;
  final String fromPatchId;
  final String fromEdgeId;
  final String toPatchId;
  final String toEdgeId;
}

final class Opening {
  Opening({
    required this.id,
    required this.hostSurfacePatchId,
    required this.boundary,
    required this.type,
    this.depthMm,
    this.sillHeightMm,
    this.headHeightMm,
  }) {
    if (id.isEmpty || hostSurfacePatchId.isEmpty) {
      throw ArgumentError('Opening identifiers must be non-empty.');
    }
    if (depthMm != null && depthMm! < 0) {
      throw ArgumentError.value(depthMm, 'depthMm', 'Must be non-negative.');
    }
    if (sillHeightMm != null && sillHeightMm! < 0) {
      throw ArgumentError.value(
        sillHeightMm,
        'sillHeightMm',
        'Must be non-negative.',
      );
    }
    if (headHeightMm != null && headHeightMm! < 0) {
      throw ArgumentError.value(
        headHeightMm,
        'headHeightMm',
        'Must be non-negative.',
      );
    }
    if (sillHeightMm != null &&
        headHeightMm != null &&
        headHeightMm! <= sillHeightMm!) {
      throw ArgumentError('Opening head must be above sill.');
    }
  }

  final String id;
  final String hostSurfacePatchId;
  final Polygon2Mm boundary;
  final OpeningType type;
  final int? depthMm;
  final int? sillHeightMm;
  final int? headHeightMm;
}

final class SpatialFeature {
  SpatialFeature({
    required this.id,
    required this.hostSurfacePatchId,
    required this.type,
    required this.footprint,
    required this.depthMm,
    required this.elevationMm,
  }) {
    if (id.isEmpty || hostSurfacePatchId.isEmpty) {
      throw ArgumentError('SpatialFeature identifiers must be non-empty.');
    }
    if (depthMm <= 0) {
      throw ArgumentError.value(depthMm, 'depthMm', 'Must be positive.');
    }
    if (elevationMm < 0) {
      throw ArgumentError.value(
        elevationMm,
        'elevationMm',
        'Must be non-negative.',
      );
    }
  }

  final String id;
  final String hostSurfacePatchId;
  final SpatialFeatureType type;
  final Polygon2Mm footprint;
  final int depthMm;
  final int elevationMm;
}

final class GeometryInvariantViolation {
  const GeometryInvariantViolation({
    required this.code,
    required this.message,
    this.objectId,
  });

  final String code;
  final String message;
  final String? objectId;
}

abstract final class SpatialGeometryValidator {
  static List<GeometryInvariantViolation> validatePatchTopology({
    required List<SurfacePatch> patches,
    required List<SurfaceEdge> edges,
    required List<SurfaceAdjacency> adjacencies,
    required List<Opening> openings,
    required List<SpatialFeature> features,
  }) {
    final violations = <GeometryInvariantViolation>[];
    final patchById = <String, SurfacePatch>{};
    final edgeById = <String, SurfaceEdge>{};

    for (final patch in patches) {
      if (patchById.containsKey(patch.id)) {
        violations.add(
          GeometryInvariantViolation(
            code: 'DUPLICATE_PATCH_ID',
            message: 'Surface patch identifiers must be unique.',
            objectId: patch.id,
          ),
        );
      } else {
        patchById[patch.id] = patch;
      }
      if (!_orientationMatchesFrame(patch)) {
        violations.add(
          GeometryInvariantViolation(
            code: 'SURFACE_ORIENTATION_NORMAL_MISMATCH',
            message:
                'Surface orientation does not match the local frame normal.',
            objectId: patch.id,
          ),
        );
      }
    }

    for (final edge in edges) {
      if (edgeById.containsKey(edge.id)) {
        violations.add(
          GeometryInvariantViolation(
            code: 'DUPLICATE_EDGE_ID',
            message: 'Surface edge identifiers must be unique.',
            objectId: edge.id,
          ),
        );
      } else {
        edgeById[edge.id] = edge;
      }
      final patch = patchById[edge.patchId];
      if (patch == null) {
        violations.add(
          GeometryInvariantViolation(
            code: 'EDGE_HOST_MISSING',
            message: 'Surface edge references a missing patch.',
            objectId: edge.id,
          ),
        );
      } else if (!patch.boundary.containsPointInclusive(edge.start) ||
          !patch.boundary.containsPointInclusive(edge.end)) {
        violations.add(
          GeometryInvariantViolation(
            code: 'EDGE_OUTSIDE_PATCH',
            message: 'Surface edge endpoints must lie on or inside its patch.',
            objectId: edge.id,
          ),
        );
      }
    }

    for (final adjacency in adjacencies) {
      final from = edgeById[adjacency.fromEdgeId];
      final to = edgeById[adjacency.toEdgeId];
      if (from == null || to == null) {
        violations.add(
          GeometryInvariantViolation(
            code: 'ADJACENCY_EDGE_MISSING',
            message: 'Surface adjacency references a missing edge.',
            objectId: adjacency.id,
          ),
        );
        continue;
      }
      if (from.patchId != adjacency.fromPatchId ||
          to.patchId != adjacency.toPatchId) {
        violations.add(
          GeometryInvariantViolation(
            code: 'ADJACENCY_PATCH_EDGE_MISMATCH',
            message: 'Adjacency patch and edge references do not match.',
            objectId: adjacency.id,
          ),
        );
      }
    }

    for (final opening in openings) {
      final host = patchById[opening.hostSurfacePatchId];
      if (host == null) {
        violations.add(
          GeometryInvariantViolation(
            code: 'OPENING_HOST_MISSING',
            message: 'Opening references a missing surface patch.',
            objectId: opening.id,
          ),
        );
      } else if (!host.boundary.containsPolygon(opening.boundary)) {
        violations.add(
          GeometryInvariantViolation(
            code: 'OPENING_OUTSIDE_PATCH',
            message: 'Opening boundary must be contained by its host patch.',
            objectId: opening.id,
          ),
        );
      }
    }

    for (final feature in features) {
      final host = patchById[feature.hostSurfacePatchId];
      if (host == null) {
        violations.add(
          GeometryInvariantViolation(
            code: 'FEATURE_HOST_MISSING',
            message: 'Spatial feature references a missing surface patch.',
            objectId: feature.id,
          ),
        );
      } else if (!host.boundary.containsPolygon(feature.footprint)) {
        violations.add(
          GeometryInvariantViolation(
            code: 'FEATURE_OUTSIDE_PATCH',
            message: 'Spatial feature footprint must be contained by its host.',
            objectId: feature.id,
          ),
        );
      }
    }

    return List.unmodifiable(violations);
  }

  static bool _orientationMatchesFrame(SurfacePatch patch) {
    final normal = patch.frame.normal;
    final tolerance = patch.frame.tolerance;
    final isHorizontal = tolerance.vectorsParallel(
      normal,
      const Vector3D(0, 0, 1),
    );
    final isVertical = normal.z.abs() <= tolerance.angularRadians;
    return switch (patch.orientation) {
      SurfaceOrientation.horizontal => isHorizontal,
      SurfaceOrientation.vertical => isVertical,
      SurfaceOrientation.sloped => !isHorizontal && !isVertical,
    };
  }
}
