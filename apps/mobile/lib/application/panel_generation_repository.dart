import 'package:engineering_core/engineering_core.dart';

import 'protection_repository.dart';
import '../domain/project_models.dart';

class PanelGenerationView {
  const PanelGenerationView(this.policy, this.reviewedFingerprint);
  final PanelGenerationPolicy policy;
  final String? reviewedFingerprint;
  String get key => 'panelProposal:${policy.id}';
}

class ProjectPanelGenerationSnapshot {
  const ProjectPanelGenerationSnapshot({
    required this.protection,
    required this.floors,
    required this.panels,
  });
  final ProjectProtectionSnapshot protection;
  final List<FloorRecord> floors;
  final List<PanelGenerationView> panels;
  String status(PanelGenerationView panel) {
    final session = protection.recalculation.session;
    if (session.affectedKeys.contains(panel.key) ||
        !session.cache.containsKey(panel.key))
      return 'Stale';
    if (session.state(panel.key) != EngineeringDerivedState.current)
      return 'Needs input';
    return panel.reviewedFingerprint == session.fingerprints[panel.key]
        ? 'Confirmed'
        : panel.reviewedFingerprint != null
        ? 'Review required'
        : 'Proposed';
  }
}

abstract interface class PanelGenerationRepository {
  Future<ProjectPanelGenerationSnapshot> load(String projectId);
  Stream<ProjectPanelGenerationSnapshot> watch(String projectId);
  Future<void> save(PanelGenerationPolicy policy);
  Future<void> archive(String projectId, String panelId);
  Future<void> recalculate(String projectId);
  Future<void> confirm(
    String projectId,
    String panelId,
    String expectedFingerprint,
  );
}
