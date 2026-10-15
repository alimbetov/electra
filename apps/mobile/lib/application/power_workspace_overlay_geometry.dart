import 'package:engineering_core/engineering_core.dart';

final class PowerWorkspaceOverlaySegment {
  PowerWorkspaceOverlaySegment({
    required String segmentId,
    required String surfacePatchId,
    required this.from,
    required this.to,
  }) : segmentId = _text(segmentId, 'segmentId'),
       surfacePatchId = _text(surfacePatchId, 'surfacePatchId');

  final String segmentId;
  final String surfacePatchId;
  final Point2Mm from;
  final Point2Mm to;
}

/// Resolves canonical ELV3 CableRun traversals to existing editor route
/// geometry. This bridge performs no power calculation and never infers a path
/// from spatial proximity: only persisted traversal -> route-segment references
/// are eligible for the overlay.
abstract interface class PowerWorkspaceOverlayGeometryRepository {
  Future<List<PowerWorkspaceOverlaySegment>> load({
    required String projectId,
    required String designRevisionId,
    required Iterable<String> cableRunIds,
  });
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
