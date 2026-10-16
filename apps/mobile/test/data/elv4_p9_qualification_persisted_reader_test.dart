import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv4_qualification_matrix.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv4_qualification_evidence_reader.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';

void main() {
  test('qualification expands only immutable CURRENT PASS evidence', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final builder = Elv4QualificationBuilder(db);
    await builder.createStructuralBaseline();

    final capability = PowerCapabilityDimension(
      dimension: PowerQuantityDimension.watt,
      demand: PowerRational.integer(20),
      nameplate: PowerRational.integer(100),
      reserveMultiplier: PowerRational.one,
      deratingFactor: PowerRational.one,
    );
    final evidence = buildPowerCapabilityEvidence(
      evaluationId: 'eval-pwr02-normal',
      revisionId: builder.revisionId,
      scenarioId: 'normal',
      segmentId: 'steady',
      subjectKind: 'SOURCE',
      subjectId: 'aggregate-source',
      input: capability,
      assessment: evaluateSupplyCapability(capability),
    );
    expect(evidence.status, PowerEvaluationStatus.pass);

    final store = DriftPowerRuntimeStore(
      db,
      originDeviceId: 'qualification-reader-test',
      now: () => builder.instant,
    );
    await store.appendEvaluation(
      projectId: builder.projectId,
      designRevisionId: builder.revisionId,
      evidence: evidence,
    );
    await store.publishFirstCurrent(
      projectId: builder.projectId,
      designRevisionId: builder.revisionId,
      evidence: evidence,
    );

    final manifest = _manifest(builder);
    final contract = Elv4QualificationMatrixContract.fromManifest(manifest);
    final reader = DriftElv4QualificationEvidenceReader(db);
    final rows = await reader.collect(
      contract: contract,
      caseScopes:
          DriftElv4QualificationEvidenceReader.caseScopesFromManifest(manifest),
    );

    expect(rows, hasLength(2));
    expect(
      rows.map((value) => value.row.dimension).toSet(),
      {'continuous-capacity', 'reserve-derating'},
    );
    expect(rows.every((value) => value.row.evaluationId == evidence.evaluationId), isTrue);
    expect(rows.every((value) => value.evidenceSha256 == evidence.evidenceSha256), isTrue);
    expect(rows.every((value) => value.inputFingerprint == evidence.inputFingerprint), isTrue);
    expect(rows.every((value) => value.pointerGeneration == 1), isTrue);

    await db.customUpdate(
      "UPDATE power_evaluation_pointers SET state = 'STALE' "
      'WHERE design_revision_id = ? AND logical_node_key_sha256 = ?',
      variables: [
        Variable.withString(builder.revisionId),
        Variable.withString(evidence.nodeKey.sha256),
      ],
    );

    await expectLater(
      reader.collect(
        contract: contract,
        caseScopes:
            DriftElv4QualificationEvidenceReader.caseScopesFromManifest(
              manifest,
            ),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('requires exactly one CURRENT aggregate evaluation'),
        ),
      ),
    );
  });
}

Map<String, Object?> _manifest(Elv4QualificationBuilder builder) => {
  'schema': 'electra.elv4-qualification.v1',
  'requiredPositiveCaseIds': ['Q-TEST'],
  'positiveCases': [
    {
      'id': 'Q-TEST',
      'facts': {
        'projectId': builder.projectId,
        'designRevisionId': builder.revisionId,
      },
      'requiredResults': [
        {
          'processCode': 'ELV-PWR-02',
          'requiredDimensions': [
            'continuous-capacity',
            'reserve-derating',
          ],
          'completion': 'COMPLETE',
          'assessment': 'PASS',
          'execution': 'SUCCEEDED',
        },
      ],
      'requiredContexts': {
        'ELV-PWR-02': ['normal/steady'],
      },
    },
  ],
};
