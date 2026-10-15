import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';

import '../../application/power_workspace_overlay_geometry.dart';
import '../../application/power_workspace_projection.dart';
import '../../application/power_workspace_state.dart';
import 'editor_interaction.dart';

final class PowerWorkspaceOverlayPainter extends CustomPainter {
  const PowerWorkspaceOverlayPainter({
    required this.surfacePatchId,
    required this.boundary,
    required this.components,
    required this.segments,
    required this.overlay,
    required this.mode,
    required this.colorScheme,
    this.selectedComponentId,
  });

  final String surfacePatchId;
  final Polygon2Mm boundary;
  final List<ComponentInstance> components;
  final List<PowerWorkspaceOverlaySegment> segments;
  final PowerWorkspaceOverlayProjection overlay;
  final PowerWorkspaceOverlayMode mode;
  final ColorScheme colorScheme;
  final String? selectedComponentId;

  @override
  void paint(Canvas canvas, Size size) {
    if (mode == PowerWorkspaceOverlayMode.none || size.isEmpty) return;
    final transform = SurfaceViewportTransform(
      boundary: boundary,
      viewportWidth: size.width,
      viewportHeight: size.height,
    );

    if (mode == PowerWorkspaceOverlayMode.paths ||
        mode == PowerWorkspaceOverlayMode.findings ||
        mode == PowerWorkspaceOverlayMode.backup) {
      final pathPaint =
          Paint()
            ..color = colorScheme.primary
            ..strokeWidth = 4
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round;
      for (final segment in segments) {
        if (segment.surfacePatchId != surfacePatchId) continue;
        final from = transform.localToViewport(segment.from);
        final to = transform.localToViewport(segment.to);
        canvas.drawLine(Offset(from.x, from.y), Offset(to.x, to.y), pathPaint);
      }
    }

    if (mode == PowerWorkspaceOverlayMode.sources ||
        mode == PowerWorkspaceOverlayMode.capacity ||
        mode == PowerWorkspaceOverlayMode.paths ||
        mode == PowerWorkspaceOverlayMode.findings ||
        mode == PowerWorkspaceOverlayMode.backup) {
      for (final component in components) {
        if (component.hostSurfacePatchId != surfacePatchId) continue;
        final highlighted = overlay.highlightedComponentIds.contains(
          component.id,
        );
        final source = overlay.sourceComponentIds.contains(component.id);
        final selected = selectedComponentId == component.id;
        if (!highlighted && !source && !selected) continue;
        final point = transform.localToViewport(component.localPosition);
        final fill =
            Paint()
              ..color = source ? colorScheme.tertiary : colorScheme.primary
              ..style = PaintingStyle.fill;
        final ring =
            Paint()
              ..color = colorScheme.onSurface
              ..style = PaintingStyle.stroke
              ..strokeWidth = selected ? 4 : 2;
        canvas.drawCircle(Offset(point.x, point.y), source ? 10 : 8, fill);
        canvas.drawCircle(Offset(point.x, point.y), selected ? 14 : 11, ring);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PowerWorkspaceOverlayPainter oldDelegate) =>
      surfacePatchId != oldDelegate.surfacePatchId ||
      boundary != oldDelegate.boundary ||
      !identical(components, oldDelegate.components) ||
      !identical(segments, oldDelegate.segments) ||
      overlay != oldDelegate.overlay ||
      mode != oldDelegate.mode ||
      colorScheme != oldDelegate.colorScheme ||
      selectedComponentId != oldDelegate.selectedComponentId;
}
