import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/fire/fa04_source_requirement_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa04_source_requirement_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa04_source_requirement_contract_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps FA-04 requirement editions immutable and CAS-switches selector',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final store = DriftFa04SourceRequirementContractStore(
        db,
        originDeviceId: 'test',
        nowUtc: () => DateTime.utc(2026, 10, 17, 12),
      );

      await store.replace(
        ReplaceFa04SourceRequirementContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'fa04-binding-1',
          expectedBindingRevision: null,
          expectedDesignRevision: 1,
          contract: _contract(_hash('a')),
        ),
      );
      final first = await store.loadActiveForSource(
        projectId: 'p',
        designRevisionId: 'd',
        sourceId: 'psu-1',
      );
      expect(first, isNotNull);
      expect(first!.bindingRevision, 1);
      final firstEvidence = first.evidenceRef;

      await store.replace(
        ReplaceFa04SourceRequirementContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'fa04-binding-1',
          expectedBindingRevision: 1,
          expectedDesignRevision: 2,
          contract: _contract(_hash('e')),
        ),
      );
      final second = await store.loadActiveForSource(
        projectId: 'p',
        designRevisionId: 'd',
        sourceId: 'psu-1',
      );
      expect(second, isNotNull);
      expect(second!.bindingRevision, 2);
      expect(second.evidenceRef, isNot(firstEvidence));

      final evidence = await db
          .customSelect(
            "SELECT evidence_ref FROM elv_revision_aggregate_evidence_records "
            "WHERE aggregate_kind = 'FA04_SOURCE_REQUIREMENT_SET'",
          )
          .get();
      expect(evidence, hasLength(2));
    },
  );
}

Fa04SourceRequirementContract _contract(String fingerprint) =>
    Fa04SourceRequirementContract(
      sourceId: 'psu-1',
      sourceDefinitionContentHash: _hash('b'),
      contributors: [
        Fa04RequirementContributorRef(
          contributorId: 'acs',
          disciplineCode: 'ACS',
          policyCode: 'ACS-PSU',
          editionId: 'acs-v1',
          contentHash: _hash('c'),
        ),
        Fa04RequirementContributorRef(
          contributorId: 'fire',
          disciplineCode: 'FIRE',
          policyCode: 'FIRE-PSU',
          editionId: 'fire-v1',
          contentHash: _hash('d'),
        ),
      ],
      cases: [
        Fa04SourceCaseContract(
          caseId: 'alarm-w',
          scenarioId: 'ALARM',
          segmentId: 'S1',
          dimension: Fa04SourceDimension.watt,
          pwr01SubjectKind: 'SOURCE_AGGREGATE',
          pwr01SubjectId: 'psu-1',
          pwr02SubjectKind: 'CAPACITY_GROUP',
          pwr02SubjectId: 'psu-1',
          expectedPwr02InputFingerprint: fingerprint,
        ),
      ],
    );

Future<void> _seed(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  const now = '2026-10-17T00:00:00.000Z';
  await db.customStatement('''
INSERT INTO projects (
  id, name, measurement_system, default_structural_height_mm,
  default_finished_ceiling_height_mm, created_at, updated_at, origin_device_id
) VALUES ('p', 'Project', 'METRIC', 3000, 2700, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO project_design_revisions (
  id, project_id, code, sequence, state, revision,
  created_at, updated_at, origin_device_id
) VALUES ('d', 'p', 'R1', 1, 'WORKING', 1, '$now', '$now', 'test')
''');
}

String _hash(String char) => List<String>.filled(64, char).join();
