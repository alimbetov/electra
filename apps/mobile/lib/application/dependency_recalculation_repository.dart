import 'package:engineering_core/engineering_core.dart';

import '../domain/project_models.dart';

class ProjectRecalculationSnapshot {
  const ProjectRecalculationSnapshot({
    required this.project,
    required this.session,
    this.retired = const [],
    this.revisions = const {},
  });
  final ProjectRecord? project;
  final RecalculationSession session;
  final List<RecalculationCache> retired;
  final Map<String, int> revisions;
}

abstract interface class DependencyRecalculationRepository {
  Future<ProjectRecalculationSnapshot> load(String projectId);
  Stream<ProjectRecalculationSnapshot> watch(String projectId);
  Future<Set<String>> recalculate(String projectId);
  Future<void> saveManualDecision({
    required String projectId,
    required String key,
    required String value,
    required String reason,
  });
  Future<void> reviewManualDecision(String projectId, String key);
  Future<void> clearManualDecision(String projectId, String key);
}
