import 'package:engineering_core/engineering_core_elv5.dart';

import '../../elv_write_unit_of_work.dart';

enum Elv5PointerFreshness { current, stale }

final class Elv5EvaluationRecord {
  Elv5EvaluationRecord({
    required this.projectId,
    required this.designRevisionId,
    required this.logicalNodeKeyJson,
    required this.logicalNodeKeySha256,
    required this.evaluationId,
    required this.scopeKind,
    required this.scopeId,
    required this.scenarioKey,
    required this.processCode,
    required this.subjectKind,
    required this.subjectId,
    required this.algorithmVersion,
    required this.inputSchemaVersion,
    required this.outputSchemaVersion,
    required this.numericBackendVersion,
    required this.canonicalEncoderVersion,
    required this.inputFingerprint,
    required this.policyFingerprint,
    required this.execution,
    required this.completion,
    required this.assessment,
    required this.outputJson,
    required this.outputSha256,
    required this.evidenceJson,
    required this.evidenceSha256,
    required this.completedAtUtc,
    this.qualificationIdentity,
  }) {
    _text(projectId, 'projectId');
    _text(designRevisionId, 'designRevisionId');
    _text(logicalNodeKeyJson, 'logicalNodeKeyJson');
    _sha256(logicalNodeKeySha256, 'logicalNodeKeySha256');
    _text(evaluationId, 'evaluationId');
    _text(scopeKind, 'scopeKind');
    _text(scopeId, 'scopeId');
    _text(scenarioKey, 'scenarioKey');
    _text(processCode, 'processCode');
    _text(subjectKind, 'subjectKind');
    _text(subjectId, 'subjectId');
    _text(algorithmVersion, 'algorithmVersion');
    _text(inputSchemaVersion, 'inputSchemaVersion');
    _text(outputSchemaVersion, 'outputSchemaVersion');
    _text(numericBackendVersion, 'numericBackendVersion');
    _text(canonicalEncoderVersion, 'canonicalEncoderVersion');
    _sha256(inputFingerprint, 'inputFingerprint');
    _sha256(policyFingerprint, 'policyFingerprint');
    _text(execution, 'execution');
    _text(completion, 'completion');
    _text(assessment, 'assessment');
    _text(outputJson, 'outputJson');
    _sha256(outputSha256, 'outputSha256');
    _text(evidenceJson, 'evidenceJson');
    _sha256(evidenceSha256, 'evidenceSha256');
  }

  final String projectId;
  final String designRevisionId;
  final String logicalNodeKeyJson;
  final String logicalNodeKeySha256;
  final String evaluationId;
  final String scopeKind;
  final String scopeId;
  final String scenarioKey;
  final String processCode;
  final String subjectKind;
  final String subjectId;
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String numericBackendVersion;
  final String canonicalEncoderVersion;
  final String inputFingerprint;
  final String policyFingerprint;
  final String execution;
  final String completion;
  final String assessment;
  final String outputJson;
  final String outputSha256;
  final String evidenceJson;
  final String evidenceSha256;
  final DateTime completedAtUtc;
  final Elv5QualificationIdentity? qualificationIdentity;
}

final class Elv5EvaluationPointer {
  Elv5EvaluationPointer({
    required this.projectId,
    required this.designRevisionId,
    required this.logicalNodeKeyJson,
    required this.logicalNodeKeySha256,
    required this.freshness,
    required this.generation,
    required this.evaluationId,
    required this.inputFingerprint,
    required this.outputSha256,
    required this.updatedAtUtc,
  }) {
    _text(projectId, 'projectId');
    _text(designRevisionId, 'designRevisionId');
    _text(logicalNodeKeyJson, 'logicalNodeKeyJson');
    _sha256(logicalNodeKeySha256, 'logicalNodeKeySha256');
    if (generation < 0) {
      throw ArgumentError.value(generation, 'generation', 'Must be >= 0.');
    }
    if (evaluationId != null) _text(evaluationId!, 'evaluationId');
    if (inputFingerprint != null) _sha256(inputFingerprint!, 'inputFingerprint');
    if (outputSha256 != null) _sha256(outputSha256!, 'outputSha256');
    if (freshness == Elv5PointerFreshness.current &&
        (evaluationId == null || inputFingerprint == null || outputSha256 == null)) {
      throw ArgumentError(
        'CURRENT pointer requires evaluationId, inputFingerprint and outputSha256.',
      );
    }
  }

  final String projectId;
  final String designRevisionId;
  final String logicalNodeKeyJson;
  final String logicalNodeKeySha256;
  final Elv5PointerFreshness freshness;
  final int generation;
  final String? evaluationId;
  final String? inputFingerprint;
  final String? outputSha256;
  final DateTime updatedAtUtc;
}

final class Elv5PointerWrite {
  Elv5PointerWrite({
    required this.projectId,
    required this.designRevisionId,
    required this.logicalNodeKeyJson,
    required this.logicalNodeKeySha256,
    required this.freshness,
    required this.expectedGeneration,
    required this.evaluationId,
    required this.inputFingerprint,
    required this.outputSha256,
    required this.updatedAtUtc,
  }) {
    _text(projectId, 'projectId');
    _text(designRevisionId, 'designRevisionId');
    _text(logicalNodeKeyJson, 'logicalNodeKeyJson');
    _sha256(logicalNodeKeySha256, 'logicalNodeKeySha256');
    if (expectedGeneration < 0) {
      throw ArgumentError.value(expectedGeneration, 'expectedGeneration', 'Must be >= 0.');
    }
    if (evaluationId != null) _text(evaluationId!, 'evaluationId');
    if (inputFingerprint != null) _sha256(inputFingerprint!, 'inputFingerprint');
    if (outputSha256 != null) _sha256(outputSha256!, 'outputSha256');
    if (freshness == Elv5PointerFreshness.current &&
        (evaluationId == null || inputFingerprint == null || outputSha256 == null)) {
      throw ArgumentError(
        'CURRENT pointer requires evaluationId, inputFingerprint and outputSha256.',
      );
    }
  }

  final String projectId;
  final String designRevisionId;
  final String logicalNodeKeyJson;
  final String logicalNodeKeySha256;
  final Elv5PointerFreshness freshness;
  final int expectedGeneration;
  final String? evaluationId;
  final String? inputFingerprint;
  final String? outputSha256;
  final DateTime updatedAtUtc;
}

final class Elv5DependencyMarker {
  Elv5DependencyMarker({
    required this.projectId,
    required this.designRevisionId,
    required this.dependencyKey,
    required this.dependencyKeySha256,
    required this.logicalNodeKeySha256,
    required String relationKind,
    required this.updatedAtUtc,
  }) : relationKind = _canonicalRelationKind(relationKind) {
    _text(projectId, 'projectId');
    _text(designRevisionId, 'designRevisionId');
    _text(dependencyKey, 'dependencyKey');
    _sha256(dependencyKeySha256, 'dependencyKeySha256');
    _sha256(logicalNodeKeySha256, 'logicalNodeKeySha256');
  }

  final String projectId;
  final String designRevisionId;
  final String dependencyKey;
  final String dependencyKeySha256;
  final String logicalNodeKeySha256;
  final String relationKind;
  final DateTime updatedAtUtc;
}

abstract interface class Elv5EvaluationStore {
  Future<Map<String, Elv5EvaluationRecord>> loadEvaluationsByIdsBulk({
    required String projectId,
    required Set<String> evaluationIds,
  });

  Future<void> appendEvaluation(Elv5EvaluationRecord record);
}

abstract interface class Elv5PointerStore {
  Future<Map<String, Elv5EvaluationPointer>> loadPointersBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> logicalNodeKeySha256s,
  });

  Future<bool> compareAndSet(Elv5PointerWrite write);

  Future<int> markStaleBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> logicalNodeKeySha256s,
    required DateTime updatedAtUtc,
  });
}

abstract interface class Elv5DependencyStore {
  Future<Map<String, List<Elv5DependencyMarker>>> loadDependencyMarkersBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> dependencyKeySha256s,
  });

  Future<Set<String>> loadDependentNodeHashesBulk({
    required String projectId,
    required String designRevisionId,
    required Set<String> dependencyKeySha256s,
  });

  Future<void> replaceNodeDependencies({
    required String projectId,
    required String designRevisionId,
    required String logicalNodeKeySha256,
    required Iterable<Elv5DependencyMarker> markers,
  });
}

abstract interface class Elv5RuntimeWriteSession extends ElvWriteSession {
  Elv5EvaluationStore get evaluations;
  Elv5PointerStore get pointers;
  Elv5DependencyStore get dependencies;
}

typedef Elv5RuntimeWriteUnitOfWork = ElvWriteUnitOfWork<Elv5RuntimeWriteSession>;

String _canonicalRelationKind(String value) {
  final kind = _text(value, 'relationKind').toUpperCase();
  if (kind == 'UPSTREAM_EVALUATION') return 'EVAL';
  if (!const {'FACT', 'SET', 'POLICY', 'EVAL', 'POINTER', 'MISSING'}.contains(kind)) {
    throw ArgumentError.value(value, 'relationKind', 'Unsupported kind.');
  }
  return kind;
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha256(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}
