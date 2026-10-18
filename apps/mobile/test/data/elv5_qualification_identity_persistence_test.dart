import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_runtime_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'qualified evaluation restores typed build authority identity from SQLite',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);

      final descriptor = Elv5ProcessCatalog.require(Elv5ProcessCode.cctv01);
      final identity = Elv5QualificationIdentity(
        processVersion: descriptor.versions.processVersion,
        rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
        sourceSha: _hash('a'),
        authorityFingerprint:
            Elv5FoundationAuthorityManifest.instance.fingerprint(),
      );
      final base = Elv5ProcessEvaluationCandidate(
        nodeKey: Elv5EngineeringNodeKeyV3(
          designRevisionId: 'rev-1',
          scope: Elv5ScopeRef(
            kind: Elv5ScopeKind.design,
            scopeId: 'rev-1',
            scenarioKey: 'NONE',
          ),
          processCode: Elv5ProcessCode.cctv01,
          subject: Elv5SubjectRef(kind: 'CAMERA', id: 'cam-1'),
        ),
        algorithmVersion: descriptor.versions.algorithmVersion,
        inputSchemaVersion: descriptor.versions.inputSchemaVersion,
        outputSchemaVersion: descriptor.versions.outputSchemaVersion,
        numericBackendVersion: descriptor.versions.numericBackendVersion,
        canonicalEncoderVersion: Elv5RuntimeContract.canonicalEncoderVersion,
        inputFingerprint: _hash('b'),
        policyFingerprint: _hash('c'),
        execution: Elv5Execution.succeeded,
        completion: Elv5Completion.complete,
        assessment: Elv5Assessment.pass,
        output: const <String, Object?>{'status': 'PASS'},
        evidence: const <String, Object?>{'source': 'fixture'},
        dependencies: const <Never>[],
        completedAtUtc: DateTime.utc(2026, 10, 17, 10),
      );
      final qualified = base.withQualificationIdentity(identity);
      final record = qualified.toRecord(projectId: 'project-1');
      final uow = DriftElv5RuntimeWriteUnitOfWork(
        db,
        originDeviceId: 'qualification-test',
      );

      await uow.run((session) => session.evaluations.appendEvaluation(record));
      final restored = await uow.run(
        (session) => session.evaluations.loadEvaluationsByIdsBulk(
          projectId: 'project-1',
          evaluationIds: {qualified.evaluationId},
        ),
      );
      final persisted = restored[qualified.evaluationId]!;

      expect(persisted.qualificationIdentity, isNotNull);
      expect(persisted.qualificationIdentity!.sourceSha, identity.sourceSha);
      expect(
        persisted.qualificationIdentity!.authorityFingerprint,
        identity.authorityFingerprint,
      );
      expect(
        persisted.qualificationIdentity!.canonicalSha256(),
        identity.canonicalSha256(),
      );
      expect(persisted.evidenceSha256, qualified.evidenceSha256);
    },
  );
}

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 17, 9);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project-1',
          name: 'ELV5 qualification fixture',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'qualification-test',
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
          originDeviceId: 'qualification-test',
        ),
      );
}

String _hash(String char) => List<String>.filled(64, char).join();
