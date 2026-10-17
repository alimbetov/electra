import 'package:electra_mobile/application/elv5/calculation/elv5_current_evaluation_source.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('historical BLOCKED/INCOMPLETE record projects without persisted rewrite', () {
    final snapshot = Elv5CurrentEvaluationSnapshot(
      logicalNodeKeySha256: List<String>.filled(64, 'a').join(),
      processCode: Elv5ProcessCode.fa03,
      scopeKind: 'DESIGN',
      scopeId: 'design-1',
      scenarioKey: 'NONE',
      subjectKind: 'LOAD',
      subjectId: 'load-1',
      evaluationId: List<String>.filled(64, 'b').join(),
      inputFingerprint: List<String>.filled(64, 'c').join(),
      outputSha256: List<String>.filled(64, 'd').join(),
      evidenceSha256: List<String>.filled(64, 'e').join(),
      pointerGeneration: 3,
      execution: 'BLOCKED',
      completion: 'INCOMPLETE',
      assessment: 'UNRESOLVED',
      output: const <String, Object?>{},
      evidence: const <String, Object?>{},
    );

    expect(snapshot.execution, 'BLOCKED');
    expect(snapshot.completion, 'INCOMPLETE');
    expect(snapshot.assessment, 'UNRESOLVED');
    expect(snapshot.foundationStatus.execution, Elv5FoundationExecution.succeeded);
    expect(snapshot.foundationStatus.completion, Elv5FoundationCompletion.blocked);
    expect(snapshot.foundationStatus.assessment, Elv5Assessment.unresolved);
    expect(snapshot.foundationStatus.freshness, Elv5Freshness.current);
  });

  test('unknown persisted status vocabulary fails closed', () {
    expect(
      () => Elv5CurrentEvaluationSnapshot(
        logicalNodeKeySha256: List<String>.filled(64, 'a').join(),
        processCode: Elv5ProcessCode.fa03,
        scopeKind: 'DESIGN',
        scopeId: 'design-1',
        scenarioKey: 'NONE',
        subjectKind: 'LOAD',
        subjectId: 'load-1',
        evaluationId: List<String>.filled(64, 'b').join(),
        inputFingerprint: List<String>.filled(64, 'c').join(),
        outputSha256: List<String>.filled(64, 'd').join(),
        evidenceSha256: List<String>.filled(64, 'e').join(),
        pointerGeneration: 1,
        execution: 'UNKNOWN',
        completion: 'INCOMPLETE',
        assessment: 'UNRESOLVED',
        output: const <String, Object?>{},
        evidence: const <String, Object?>{},
      ),
      throwsFormatException,
    );
  });
}
