import 'package:engineering_core/engineering_core.dart';

/// Immutable projection of one verified CURRENT ELV4 evaluation and pointer.
///
/// Consumers must treat [evidence] as authoritative only together with the
/// pointer identity/generation captured here. A later pointer generation makes
/// the ELV5 capture stale through its dependency marker.
final class Elv4CurrentEvaluationSnapshot {
  Elv4CurrentEvaluationSnapshot({
    required this.nodeKey,
    required this.evaluationId,
    required this.inputFingerprint,
    required this.evidenceSha256,
    required this.pointerGeneration,
    required Map<String, Object?> evidence,
  }) : evidence = Map.unmodifiable(evidence);

  final PowerNodeKeyV2 nodeKey;
  final String evaluationId;
  final String inputFingerprint;
  final String evidenceSha256;
  final int pointerGeneration;
  final Map<String, Object?> evidence;

  Map<String, Object?> get output {
    final raw = evidence['output'];
    if (raw is! Map) {
      throw StateError('ELV4_CURRENT_EVIDENCE_OUTPUT_MISSING:$evaluationId');
    }
    return Map<String, Object?>.unmodifiable(
      raw.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

abstract interface class Elv4CurrentEvidenceSource {
  /// Returns all verified CURRENT evaluations matching the exact persisted
  /// identity filters. Ordering must be canonical by logical node key.
  Future<List<Elv4CurrentEvaluationSnapshot>> loadCurrent({
    required String projectId,
    required String designRevisionId,
    required PowerProcessCode processCode,
    String? scenarioId,
    PowerEvaluationScopeKind? scopeKind,
    String? scopeId,
    String? subjectKind,
    String? subjectId,
  });
}
