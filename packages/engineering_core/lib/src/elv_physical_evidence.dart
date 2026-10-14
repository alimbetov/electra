import 'elv_route_bend_evidence.dart';

final class BendRadiusEvidenceResult {
  const BendRadiusEvidenceResult({
    required this.routeNodeId,
    required this.minimumRadiusMm,
    required this.actualRadiusMm,
    required this.blocked,
    required this.intrinsicPass,
    this.blockingCode,
  });

  final String routeNodeId;
  final double minimumRadiusMm;
  final double? actualRadiusMm;
  final bool blocked;
  final bool? intrinsicPass;
  final String? blockingCode;
}

BendRadiusEvidenceResult evaluateBendRadiusEvidence({
  required String routeNodeId,
  required double minimumRadiusMm,
  required RouteBendEvidence? evidence,
}) {
  if (!minimumRadiusMm.isFinite || minimumRadiusMm <= 0) {
    throw ArgumentError.value(minimumRadiusMm, 'minimumRadiusMm');
  }
  if (evidence == null) {
    return BendRadiusEvidenceResult(
      routeNodeId: routeNodeId,
      minimumRadiusMm: minimumRadiusMm,
      actualRadiusMm: null,
      blocked: true,
      intrinsicPass: null,
      blockingCode: 'ELV_BEND_EVIDENCE_MISSING',
    );
  }
  if (evidence.routeNodeId != routeNodeId) {
    return BendRadiusEvidenceResult(
      routeNodeId: routeNodeId,
      minimumRadiusMm: minimumRadiusMm,
      actualRadiusMm: evidence.radiusMm,
      blocked: true,
      intrinsicPass: null,
      blockingCode: 'ELV_BEND_EVIDENCE_NODE_MISMATCH',
    );
  }
  return BendRadiusEvidenceResult(
    routeNodeId: routeNodeId,
    minimumRadiusMm: minimumRadiusMm,
    actualRadiusMm: evidence.radiusMm,
    blocked: false,
    intrinsicPass: evidence.radiusMm >= minimumRadiusMm,
  );
}

enum RouteSeparationEvidenceKind { measured, designedDimension, surveyed }

final class RouteSeparationEvidence {
  const RouteSeparationEvidence({
    required this.id,
    required this.projectId,
    required this.designRevisionId,
    required this.subjectAId,
    required this.subjectBId,
    required this.distanceMm,
    required this.kind,
    required this.provenance,
    required this.revision,
  });

  final String id;
  final String projectId;
  final String designRevisionId;
  final String subjectAId;
  final String subjectBId;
  final double distanceMm;
  final RouteSeparationEvidenceKind kind;
  final String provenance;
  final int revision;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Separation evidence id is required.',
        if (projectId.trim().isEmpty)
          'Separation evidence projectId is required.',
        if (designRevisionId.trim().isEmpty)
          'Separation evidence designRevisionId is required.',
        if (subjectAId.trim().isEmpty || subjectBId.trim().isEmpty)
          'Separation evidence requires both subjects.',
        if (subjectAId == subjectBId)
          'Separation evidence subjects must differ.',
        if (!distanceMm.isFinite || distanceMm < 0)
          'Separation evidence distance must be finite and non-negative.',
        if (provenance.trim().isEmpty)
          'Separation evidence provenance is required.',
        if (revision < 1) 'Separation evidence revision must be >= 1.',
      ];
}
