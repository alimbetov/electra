import 'package:engineering_core/engineering_core.dart';

import 'elv_reviewed_workspace_command.dart';

/// Exact reviewed canonical reroute command used by the P7 power workspace.
///
/// The review fingerprint binds the engineering business payload and its row
/// precondition, but deliberately excludes [commandId] so the final execution
/// envelope can receive a fresh id after an engineer has reviewed the route.
final class ReviewedRerouteCableRunWorkspaceCommand
    implements ElvReviewedWorkspaceCommand {
  ReviewedRerouteCableRunWorkspaceCommand({
    required String commandId,
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
    required this.expectedRevision,
    required Iterable<CableRunTraversal> traversals,
  }) : commandId = _text(commandId, 'commandId'),
       projectId = _text(projectId, 'projectId'),
       designRevisionId = _text(designRevisionId, 'designRevisionId'),
       cableRunId = _text(cableRunId, 'cableRunId'),
       traversals = List.unmodifiable(
         [...traversals]..sort((a, b) => a.sequence.compareTo(b.sequence)),
       ) {
    if (expectedRevision < 1) {
      throw ArgumentError.value(
        expectedRevision,
        'expectedRevision',
        'Must be >= 1.',
      );
    }
    final errors = validateTraversalChain(this.traversals);
    if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
    if (this.traversals.any((item) => item.cableRunId != this.cableRunId)) {
      throw ArgumentError(
        'Every traversal must reference the reviewed cable run.',
      );
    }
  }

  static const payloadSchema = 'electra.command.reviewed-reroute-cable-run.v1';

  @override
  final String commandId;
  @override
  final String projectId;
  @override
  final String designRevisionId;
  final String cableRunId;
  final int expectedRevision;
  final List<CableRunTraversal> traversals;

  Map<String, Object?> get reviewedPayload => <String, Object?>{
    'schema': payloadSchema,
    'projectId': projectId,
    'designRevisionId': designRevisionId,
    'cableRunId': cableRunId,
    'expectedRevision': expectedRevision,
    'traversals': [for (final item in traversals) _traversalMap(item)],
  };

  @override
  String get reviewedFingerprint =>
      sha256HexUtf8(canonicalEngineeringJsonV1(reviewedPayload));

  Map<String, Object?> get draftProjection => <String, Object?>{
    'kind': 'REROUTE_CABLE_RUN',
    'cableRunId': cableRunId,
    'expectedRevision': expectedRevision,
    'traversalCount': traversals.length,
    'routeSegmentIds': [for (final item in traversals) item.routeSegmentId],
  };
}

Map<String, Object?> _traversalMap(CableRunTraversal value) =>
    <String, Object?>{
      'id': value.id,
      'cableRunId': value.cableRunId,
      'sequence': value.sequence,
      'routeSegmentId': value.routeSegmentId,
      'direction': value.direction.name.toUpperCase(),
      'physicalCarrierId': value.physicalCarrierId,
      'carrierCompartmentId': value.carrierCompartmentId,
    };

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
