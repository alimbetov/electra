enum CanonicalCableRunState { active, superseded, archived }

enum CableTraversalDirection { forward, reverse }

final class CanonicalCableRun {
  const CanonicalCableRun({
    required this.id,
    required this.projectId,
    required this.cableId,
    required this.designRevisionId,
    required this.state,
    required this.reservePercent,
    required this.terminationAllowanceMm,
    required this.revision,
    this.basedOnCableRunId,
  });

  final String id;
  final String projectId;
  final String cableId;
  final String designRevisionId;
  final String? basedOnCableRunId;
  final CanonicalCableRunState state;
  final double reservePercent;
  final int terminationAllowanceMm;
  final int revision;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Canonical cable run id is required.',
        if (projectId.trim().isEmpty)
          'Canonical cable run projectId is required.',
        if (cableId.trim().isEmpty) 'Canonical cable run cableId is required.',
        if (designRevisionId.trim().isEmpty)
          'Canonical cable run designRevisionId is required.',
        if (!reservePercent.isFinite || reservePercent < 0)
          'Reserve percent must be finite and nonnegative.',
        if (terminationAllowanceMm < 0)
          'Termination allowance must be nonnegative.',
        if (revision < 1) 'Canonical cable run revision must be >= 1.',
      ];
}

final class CableRunTraversal {
  const CableRunTraversal({
    required this.id,
    required this.cableRunId,
    required this.sequence,
    required this.routeSegmentId,
    required this.direction,
    this.physicalCarrierId,
    this.carrierCompartmentId,
  });

  final String id;
  final String cableRunId;
  final int sequence;
  final String routeSegmentId;
  final CableTraversalDirection direction;
  final String? physicalCarrierId;
  final String? carrierCompartmentId;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Traversal id is required.',
        if (cableRunId.trim().isEmpty) 'Traversal cableRunId is required.',
        if (routeSegmentId.trim().isEmpty)
          'Traversal routeSegmentId is required.',
        if (sequence < 1) 'Traversal sequence must be 1-based.',
        if (carrierCompartmentId != null && physicalCarrierId == null)
          'Carrier compartment requires a physical carrier.',
      ];
}

List<String> validateTraversalChain(Iterable<CableRunTraversal> traversals) {
  final list = traversals.toList(growable: false);
  final errors = <String>[
    for (final traversal in list) ...traversal.validate()
  ];
  if (list.isEmpty) {
    errors.add('Traversal chain must not be empty.');
    return errors;
  }
  final sorted = [...list]..sort((a, b) => a.sequence.compareTo(b.sequence));
  for (var i = 0; i < sorted.length; i++) {
    if (sorted[i].sequence != i + 1) {
      errors
          .add('Traversal sequence must be unique and gap-free starting at 1.');
      break;
    }
  }
  if (list.map((e) => e.id).toSet().length != list.length) {
    errors.add('Traversal ids must be unique.');
  }
  if (list.map((e) => e.routeSegmentId).length != list.length) {
    errors.add('Traversal route references are invalid.');
  }
  return errors;
}
