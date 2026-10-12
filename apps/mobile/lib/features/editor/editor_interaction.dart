import 'package:engineering_core/engineering_core.dart';

import '../../application/geometry_repository.dart';

enum EditorSelectionKind { surfacePatch, opening, spatialFeature }

final class EditorSelection {
  const EditorSelection({
    required this.kind,
    required this.id,
    required this.hostPatchId,
  });

  final EditorSelectionKind kind;
  final String id;
  final String hostPatchId;

  @override
  bool operator ==(Object other) =>
      other is EditorSelection &&
      other.kind == kind &&
      other.id == id &&
      other.hostPatchId == hostPatchId;

  @override
  int get hashCode => Object.hash(kind, id, hostPatchId);
}

EditorSelection? hitTestSurface({
  required RoomGeometrySnapshot geometry,
  required SurfacePatch patch,
  required Point2Mm localPoint,
}) {
  for (final opening in geometry.openings.reversed) {
    if (opening.hostSurfacePatchId == patch.id &&
        opening.boundary.containsPointInclusive(localPoint)) {
      return EditorSelection(
        kind: EditorSelectionKind.opening,
        id: opening.id,
        hostPatchId: patch.id,
      );
    }
  }

  for (final feature in geometry.features.reversed) {
    if (feature.hostSurfacePatchId == patch.id &&
        feature.footprint.containsPointInclusive(localPoint)) {
      return EditorSelection(
        kind: EditorSelectionKind.spatialFeature,
        id: feature.id,
        hostPatchId: patch.id,
      );
    }
  }

  if (patch.boundary.containsPointInclusive(localPoint)) {
    return EditorSelection(
      kind: EditorSelectionKind.surfacePatch,
      id: patch.id,
      hostPatchId: patch.id,
    );
  }

  return null;
}

final class EditorMeasurement {
  const EditorMeasurement({required this.start, required this.end});

  final Point2Mm start;
  final Point2Mm end;

  double get lengthMm => Segment2Mm(start, end).lengthMm;
}

final class SurfaceViewportTransform {
  SurfaceViewportTransform({
    required Polygon2Mm boundary,
    required double viewportWidth,
    required double viewportHeight,
    this.padding = 24,
  }) {
    if (viewportWidth <= padding * 2 || viewportHeight <= padding * 2) {
      throw ArgumentError('Viewport must be larger than its drawing padding.');
    }

    final xs = boundary.vertices.map((point) => point.xMm);
    final ys = boundary.vertices.map((point) => point.yMm);
    minX = xs.reduce((a, b) => a < b ? a : b).toDouble();
    maxX = xs.reduce((a, b) => a > b ? a : b).toDouble();
    minY = ys.reduce((a, b) => a < b ? a : b).toDouble();
    maxY = ys.reduce((a, b) => a > b ? a : b).toDouble();

    final widthMm = (maxX - minX).abs();
    final heightMm = (maxY - minY).abs();
    if (widthMm == 0 || heightMm == 0) {
      throw ArgumentError(
        'Surface viewport requires non-zero width and height.',
      );
    }

    final horizontalScale = (viewportWidth - padding * 2) / widthMm;
    final verticalScale = (viewportHeight - padding * 2) / heightMm;
    scale = horizontalScale < verticalScale ? horizontalScale : verticalScale;
    offsetX = (viewportWidth - widthMm * scale) / 2 - minX * scale;
    offsetY = (viewportHeight - heightMm * scale) / 2 + maxY * scale;
  }

  final double padding;
  late final double minX;
  late final double maxX;
  late final double minY;
  late final double maxY;
  late final double scale;
  late final double offsetX;
  late final double offsetY;

  Point2D localToViewport(Point2Mm point) =>
      Point2D(offsetX + point.xMm * scale, offsetY - point.yMm * scale);

  Point2Mm viewportToLocal(double x, double y) => Point2Mm(
    ((x - offsetX) / scale).round(),
    ((offsetY - y) / scale).round(),
  );
}
