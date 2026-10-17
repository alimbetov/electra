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

  /// Scenario-independent physical membership closure derived from the exact
  /// PWR consumed dependency keys already persisted in ELV4 evidence.
  ///
  /// Scenario/segment-scoped keys are deliberately excluded; domain, load,
  /// section, allocation, cable-run, traversal, installed-resource and
  /// termination identities remain. Therefore two operating scenarios can only
  /// share this fingerprint when they were solved against the same physical
  /// closure, while their current/voltage values may legitimately differ.
  String get physicalMembershipFingerprint {
    final raw = evidence['dependencyKeys'];
    if (raw is! List) {
      throw StateError('ELV4_CURRENT_DEPENDENCY_KEYS_MISSING:$evaluationId');
    }
    final stable = <String>[];
    for (final value in raw) {
      if (value is! String) {
        throw StateError('ELV4_CURRENT_DEPENDENCY_KEY_INVALID:$evaluationId');
      }
      final key = PowerDependencyKey.decode(value);
      if (key.scenarioId == null && key.segmentId == null)
        stable.add(key.encode());
    }
    if (stable.isEmpty) {
      throw StateError('ELV4_CURRENT_PHYSICAL_MEMBERSHIP_EMPTY:$evaluationId');
    }
    stable.sort();
    return sha256HexUtf8(
      canonicalEngineeringJsonV1(<String, Object?>{
        'schema': 'electra.elv4-physical-membership-closure.v1',
        'revisionId': nodeKey.revisionId,
        'processCode': nodeKey.processCode.name,
        'subjectKind': nodeKey.subjectKind,
        'subjectId': nodeKey.subjectId,
        'stableDependencyKeys': stable,
      }),
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
