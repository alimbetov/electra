enum RouteBendEvidenceKind { designedRadius, fittingRadius, measuredRadius }

final class RouteBendEvidence {
  const RouteBendEvidence({
    required this.id,
    required this.projectId,
    required this.routeNodeId,
    required this.radiusMm,
    required this.kind,
    required this.provenance,
  });

  final String id;
  final String projectId;
  final String routeNodeId;
  final double radiusMm;
  final RouteBendEvidenceKind kind;
  final String provenance;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Bend evidence id is required.',
        if (projectId.trim().isEmpty) 'Bend evidence projectId is required.',
        if (routeNodeId.trim().isEmpty)
          'Bend evidence routeNodeId is required.',
        if (!radiusMm.isFinite || radiusMm <= 0)
          'Bend evidence radius must be positive and finite.',
        if (provenance.trim().isEmpty) 'Bend evidence provenance is required.',
      ];
}
