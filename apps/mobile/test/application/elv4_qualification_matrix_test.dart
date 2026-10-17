import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/elv4_qualification_matrix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Elv4QualificationMatrixContract loadContract() {
    final file = File(
      '../../docs/product/elv4-implementation/qualification.json',
    );
    expect(file.existsSync(), isTrue);
    final manifest =
        (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
    return Elv4QualificationMatrixContract.fromManifest(manifest);
  }

  test(
    'qualification manifest expands all seven cases into exact obligations',
    () {
      final contract = loadContract();
      expect(contract.requiredCaseIds, const [
        'Q-CCTV',
        'Q-LAN',
        'Q-ACS',
        'Q-FIRE',
        'Q-SHARED',
        'Q-GENERIC',
        'Q-CHARGE',
      ]);
      expect(contract.expectedRows, isNotEmpty);
      expect(
        contract.expectedRows.map((row) => row.caseId).toSet(),
        contract.requiredCaseIds.toSet(),
      );
      expect(
        contract.expectedRows.map((row) => row.key).toSet(),
        hasLength(contract.expectedRows.length),
      );
    },
  );

  test(
    'complete persisted evidence shape satisfies exact Cartesian matrix',
    () {
      final contract = loadContract();
      contract.validateEvidence(
        contract.expectedRows.map(
          (row) => Elv4QualificationEvidenceRow(
            caseId: row.caseId,
            processCode: row.processCode,
            context: row.context,
            dimension: row.dimension,
            completion: row.completion,
            assessment: row.assessment,
            execution: row.execution,
            evaluationId: 'evaluation:${row.key}',
          ),
        ),
      );
    },
  );

  test('missing, duplicate, extra and failed evidence are rejected', () {
    final contract = loadContract();
    final complete =
        contract.expectedRows
            .map(
              (row) => Elv4QualificationEvidenceRow(
                caseId: row.caseId,
                processCode: row.processCode,
                context: row.context,
                dimension: row.dimension,
                completion: row.completion,
                assessment: row.assessment,
                execution: row.execution,
                evaluationId: 'evaluation:${row.key}',
              ),
            )
            .toList();

    expect(
      () => contract.validateEvidence(complete.sublist(1)),
      throwsStateError,
    );
    expect(
      () => contract.validateEvidence([...complete, complete.first]),
      throwsStateError,
    );
    expect(
      () => contract.validateEvidence([
        ...complete,
        Elv4QualificationEvidenceRow(
          caseId: 'Q-CCTV',
          processCode: 'ELV-PWR-99',
          context: 'normal/steady',
          dimension: 'invented',
          completion: 'COMPLETE',
          assessment: 'PASS',
          execution: 'SUCCEEDED',
          evaluationId: 'extra',
        ),
      ]),
      throwsStateError,
    );

    final first = complete.first;
    final failed = [
      Elv4QualificationEvidenceRow(
        caseId: first.caseId,
        processCode: first.processCode,
        context: first.context,
        dimension: first.dimension,
        completion: first.completion,
        assessment: 'FAIL',
        execution: first.execution,
        evaluationId: first.evaluationId,
      ),
      ...complete.skip(1),
    ];
    expect(() => contract.validateEvidence(failed), throwsStateError);
  });
}
