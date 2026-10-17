import 'package:engineering_core/engineering_core_elv5.dart';

final class Elv5CurrentEvaluationSnapshot {
  Elv5CurrentEvaluationSnapshot({
    required this.logicalNodeKeySha256,
    required this.processCode,
    required this.scopeKind,
    required this.scopeId,
    required this.scenarioKey,
    required this.subjectKind,
    required this.subjectId,
    required this.evaluationId,
    required this.inputFingerprint,
    required this.outputSha256,
    required this.evidenceSha256,
    required this.pointerGeneration,
    required this.execution,
    required this.completion,
    required this.assessment,
    required Map<String,Object?> output,
    required Map<String,Object?> evidence,
  }) : output = Map.unmodifiable(output), evidence = Map.unmodifiable(evidence) {
    if (pointerGeneration < 1) throw ArgumentError('CURRENT ELV5 pointer generation must be >= 1.');
  }

  final String logicalNodeKeySha256;
  final Elv5ProcessCode processCode;
  final String scopeKind;
  final String scopeId;
  final String scenarioKey;
  final String subjectKind;
  final String subjectId;
  final String evaluationId;
  final String inputFingerprint;
  final String outputSha256;
  final String evidenceSha256;
  final int pointerGeneration;
  final String execution;
  final String completion;
  final String assessment;
  final Map<String,Object?> output;
  final Map<String,Object?> evidence;
}

abstract interface class Elv5CurrentEvaluationSource {
  Future<List<Elv5CurrentEvaluationSnapshot>> loadCurrent({
    required String projectId,
    required String designRevisionId,
    required Elv5ProcessCode processCode,
    String? scopeKind,
    String? scopeId,
    String? scenarioKey,
    String? subjectKind,
    String? subjectId,
  });
}
