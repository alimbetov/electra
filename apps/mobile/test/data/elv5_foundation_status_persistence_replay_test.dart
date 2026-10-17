import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_current_evaluation_source.dart';
import 'package:electra_mobile/application/elv5/persistence/elv5_runtime_persistence.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_current_evaluation_source.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_runtime_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'persisted BLOCKED/INCOMPLETE replays as Foundation SUCCEEDED/BLOCKED',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final nodeSha = _hash('a');
      final evaluationId = _hash('b');
      final inputFingerprint = _hash('c');
      final outputSha = _hash('d');
      final evidenceSha = _hash('e');
      final now = DateTime.utc(2026, 10, 17, 11);
      final uow = DriftElv5RuntimeWriteUnitOfWork(
        db,
        originDeviceId: 'status-replay-test',
      );

      await uow.run((session) async {
        await session.evaluations.appendEvaluation(
          Elv5EvaluationRecord(
            projectId: 'project-1',
            designRevisionId: 'rev-1',
            logicalNodeKeyJson: '{"fixture":"node"}',
            logicalNodeKeySha256: nodeSha,
            evaluationId: evaluationId,
            scopeKind: 'DESIGN',
            scopeId: 'rev-1',
            scenarioKey: 'NONE',
            processCode: Elv5ProcessCode.fa03.wireCode,
            subjectKind: 'LOAD',
            subjectId: 'load-1',
            algorithmVersion: 'fixture-algorithm-v1',
            inputSchemaVersion: 'fixture-input-v1',
            outputSchemaVersion: 'fixture-output-v1',
            numericBackendVersion: 'fixture-numeric-v1',
            canonicalEncoderVersion:
                Elv5RuntimeContract.canonicalEncoderVersion,
            inputFingerprint: inputFingerprint,
            policyFingerprint: _hash('f'),
            execution: 'BLOCKED',
            completion: 'INCOMPLETE',
            assessment: 'UNRESOLVED',
            outputJson: '{}',
            outputSha256: outputSha,
            evidenceJson: '{}',
            evidenceSha256: evidenceSha,
            completedAtUtc: now,
          ),
        );
        final published = await session.pointers.compareAndSet(
          Elv5PointerWrite(
            projectId: 'project-1',
            designRevisionId: 'rev-1',
            logicalNodeKeyJson: '{"fixture":"node"}',
            logicalNodeKeySha256: nodeSha,
            freshness: Elv5PointerFreshness.current,
            expectedGeneration: 0,
            evaluationId: evaluationId,
            inputFingerprint: inputFingerprint,
            outputSha256: outputSha,
            updatedAtUtc: now,
          ),
        );
        expect(published, isTrue);
      });

      final rows = await DriftElv5CurrentEvaluationSource(db).loadCurrent(
        projectId: 'project-1',
        designRevisionId: 'rev-1',
        processCode: Elv5ProcessCode.fa03,
        subjectKind: 'LOAD',
        subjectId: 'load-1',
      );

      expect(rows, hasLength(1));
      final restored = rows.single;
      expect(restored.execution, 'BLOCKED');
      expect(restored.completion, 'INCOMPLETE');
      expect(restored.assessment, 'UNRESOLVED');
      expect(
        restored.foundationStatus.execution,
        Elv5FoundationExecution.succeeded,
      );
      expect(
        restored.foundationStatus.completion,
        Elv5FoundationCompletion.blocked,
      );
      expect(restored.foundationStatus.assessment, Elv5Assessment.unresolved);
      expect(restored.foundationStatus.freshness, Elv5Freshness.current);
    },
  );
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 17, 10);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project-1',
          name: 'Foundation status replay fixture',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'status-replay-test',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'rev-1',
          projectId: 'project-1',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'status-replay-test',
        ),
      );
}

String _hash(String char) => List<String>.filled(64, char).join();
