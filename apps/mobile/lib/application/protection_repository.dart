import 'package:engineering_core/engineering_core.dart';

import 'dependency_recalculation_repository.dart';

class CircuitProtectionView {
  const CircuitProtectionView({
    required this.circuitId,
    required this.label,
    required this.settings,
    required this.fingerprint,
    this.checkpoint,
    this.reviewedFingerprint,
  });
  final String circuitId, label, fingerprint;
  final CircuitProtectionInputs settings;
  final RecalculationCache? checkpoint;
  final String? reviewedFingerprint;
  bool get stale => checkpoint?.fingerprint != fingerprint;
  String get status =>
      reviewedFingerprint != null && reviewedFingerprint != fingerprint
          ? 'Review required'
          : stale
          ? 'Recalculate'
          : checkpoint?.proposal.values['proposalState'] != 'proposed'
          ? (checkpoint?.proposal.values['proposalState'] as String? ??
              'Needs input')
          : checkpoint?.state != EngineeringDerivedState.current
          ? 'Review required'
          : reviewedFingerprint == fingerprint
          ? 'Confirmed requirement'
          : 'Proposed';
}

class ProjectProtectionSnapshot {
  const ProjectProtectionSnapshot({
    required this.recalculation,
    required this.documents,
    required this.rulesets,
    required this.circuits,
  });
  final ProjectRecalculationSnapshot recalculation;
  final List<NormativeDocument> documents;
  final List<ProtectionRuleset> rulesets;
  final List<CircuitProtectionView> circuits;
}

abstract interface class ProtectionRepository {
  Future<ProjectProtectionSnapshot> load(String projectId);
  Stream<ProjectProtectionSnapshot> watch(String projectId);
  Future<void> saveDocument(NormativeDocument document);
  Future<void> saveRuleset(ProtectionRuleset ruleset);
  Future<void> saveSettings(String projectId, CircuitProtectionInputs settings);
  Future<void> confirm(
    String projectId,
    String circuitId,
    String expectedFingerprint,
  );
  Future<void> recalculate(String projectId);
}
