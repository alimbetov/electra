import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/acs/acs05_autonomy_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs05_autonomy_contract_write.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_acs05_autonomy_contract_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'keeps ACS-05 autonomy editions immutable and CAS-switches selector',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final store = DriftAcs05AutonomyContractStore(
        db,
        originDeviceId: 'test',
        nowUtc: () => DateTime.utc(2026, 10, 17, 12),
      );

      await store.replace(
        ReplaceAcs05AutonomyContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'acs05-binding-1',
          expectedBindingRevision: null,
          expectedDesignRevision: 1,
          contract: _contract(_hash('a'), duration: 3600000000),
        ),
      );
      final first = await store.loadActiveForBank(
        projectId: 'p',
        designRevisionId: 'd',
        bankId: 'bank-1',
      );
      expect(first, isNotNull);
      expect(first!.bindingRevision, 1);
      final firstEvidenceRef = first.evidenceRef;
      final firstSequence = first.contract.sequenceFingerprint;

      await store.replace(
        ReplaceAcs05AutonomyContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'acs05-binding-1',
          expectedBindingRevision: 1,
          expectedDesignRevision: 2,
          contract: _contract(_hash('b'), duration: 7200000000),
        ),
      );
      final second = await store.loadActiveForBank(
        projectId: 'p',
        designRevisionId: 'd',
        bankId: 'bank-1',
      );
      expect(second, isNotNull);
      expect(second!.bindingRevision, 2);
      expect(second.evidenceRef, isNot(firstEvidenceRef));
      expect(second.contract.sequenceFingerprint, isNot(firstSequence));

      final evidence = await db
          .customSelect(
            "SELECT evidence_ref FROM elv_revision_aggregate_evidence_records "
            "WHERE aggregate_kind = 'ACS05_AUTONOMY_CONTRACT' ORDER BY evidence_ref",
          )
          .get();
      expect(evidence, hasLength(2));

      final revision = await db
          .customSelect(
            "SELECT revision FROM project_design_revisions WHERE id = 'd'",
          )
          .getSingle();
      expect(revision.read<int>('revision'), 3);
    },
  );
}

Acs05AutonomyContract _contract(
  String pwr04InputHash, {
  required int duration,
}) => Acs05AutonomyContract(
  bankId: 'bank-1',
  scenarioId: 'BACKUP',
  sequenceId: 'sequence-1',
  expectedPwr04InputFingerprint: pwr04InputHash,
  segments: <Acs05SequenceSegmentContract>[
    Acs05SequenceSegmentContract(
      segmentId: 'standby',
      durationMicroseconds: BigInt.from(duration),
    ),
  ],
  globalProtectedLoadIds: const <String>{'acs-lock', 'fire-loop'},
  acsProtectedLoadIds: const <String>{'acs-lock'},
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
  await db.customStatement('''
INSERT INTO component_instances (
  id, definition_id, definition_version, room_id, host_surface_patch_id,
  local_xmm, local_ymm, revision, created_at, updated_at, origin_device_id
) VALUES ('bank-1', 'battery-bank', 1, 'room-1', 'patch-1',
  0, 0, 1, '$now', '$now', 'test')
''');
}

String _hash(String char) => List<String>.filled(64, char).join();
