import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _projectId = 'project-p8-rejection-race';
const _revisionId = 'REV-1';

QueryExecutor _native(File file, {bool configureWal = false}) =>
    NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        if (configureWal) raw.execute('PRAGMA journal_mode=WAL');
        raw.execute('PRAGMA busy_timeout=30000');
      },
    );

DriftElvDesignRevisionRepository _repo(AppDatabase db) =>
    DriftElvDesignRevisionRepository(
      db,
      originDeviceId: 'test',
      now: () => DateTime.utc(2026, 10, 15, 21, 30),
    );

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 15, 21);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: _projectId,
          name: 'P8 rejection concurrency',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  final bootstrap = await _repo(db).bootstrap(
    const BootstrapProjectDesignRevisionCommand(
      commandId: 'bootstrap-r1',
      projectId: _projectId,
      revisionId: _revisionId,
      code: 'R1',
    ),
  );
  expect(bootstrap, isA<ElvCommandSuccess<ProjectDesignRevision>>());
}

ElvFailure _failure(ElvCommandResult<ProjectDesignRevision> result) {
  expect(result, isA<ElvCommandFailureResult<ProjectDesignRevision>>());
  return (result as ElvCommandFailureResult<ProjectDesignRevision>).failure;
}

void main() {
  test('P8 concurrent duplicate rejection persists exactly one verbatim outcome', () async {
    final dir = await Directory.systemTemp.createTemp('electra-p8-reject-dup-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/electra.sqlite');
    final seed = AppDatabase(_native(file, configureWal: true));
    await _seed(seed);
    await seed.close();

    final dbA = AppDatabase(_native(file));
    final dbB = AppDatabase(_native(file));
    const command = FreezeProjectDesignRevisionCommand(
      commandId: 'duplicate-rejected-freeze',
      projectId: _projectId,
      designRevisionId: _revisionId,
      expectedRevision: 2,
    );
    final results = await Future.wait([
      _repo(dbA).freeze(command),
      _repo(dbB).freeze(command),
    ]);
    final first = _failure(results[0]);
    final second = _failure(results[1]);
    expect(first.code, 'ELV_DESIGN_REVISION_REVISION_CONFLICT');
    expect(second.code, first.code);
    expect(second.category, first.category);
    expect(second.expectedRevision, first.expectedRevision);
    expect(second.actualRevision, first.actualRevision);

    final exactLedger = await dbA
        .customSelect(
          "SELECT outcome_kind FROM command_execution_records "
          "WHERE project_id = '$_projectId' AND command_id = 'duplicate-rejected-freeze'",
        )
        .get();
    expect(exactLedger, hasLength(1));
    expect(exactLedger.single.read<String>('outcome_kind'), 'REJECTED');
    expect(
      await dbA
          .customSelect(
            "SELECT state, revision FROM project_design_revisions WHERE id = '$_revisionId'",
          )
          .getSingle()
          .then(
            (row) => (row.read<String>('state'), row.read<int>('revision')),
          ),
      ('WORKING', 1),
    );
    await dbA.close();
    await dbB.close();

    final reopened = AppDatabase(_native(file));
    addTearDown(reopened.close);
    final replay = _failure(await _repo(reopened).freeze(command));
    expect(replay.code, first.code);
    expect(replay.expectedRevision, 2);
    expect(replay.actualRevision, 1);
  });

  test('P8 competing rejected and successful envelopes serialize to one command winner', () async {
    final dir = await Directory.systemTemp.createTemp(
      'electra-p8-reject-success-',
    );
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/electra.sqlite');
    final seed = AppDatabase(_native(file, configureWal: true));
    await _seed(seed);
    await seed.close();

    final dbA = AppDatabase(_native(file));
    final dbB = AppDatabase(_native(file));
    const rejectedEnvelope = FreezeProjectDesignRevisionCommand(
      commandId: 'competing-freeze-envelope',
      projectId: _projectId,
      designRevisionId: _revisionId,
      expectedRevision: 2,
    );
    const successfulEnvelope = FreezeProjectDesignRevisionCommand(
      commandId: 'competing-freeze-envelope',
      projectId: _projectId,
      designRevisionId: _revisionId,
      expectedRevision: 1,
    );

    final outcomes = await Future.wait([
      _repo(dbA).freeze(rejectedEnvelope),
      _repo(dbB).freeze(successfulEnvelope),
    ]);
    final ledger = await dbA
        .customSelect(
          "SELECT outcome_kind, normalized_payload_sha256 FROM command_execution_records "
          "WHERE project_id = '$_projectId' AND command_id = 'competing-freeze-envelope'",
        )
        .get();
    expect(ledger, hasLength(1));

    final successCount = outcomes
        .whereType<ElvCommandSuccess<ProjectDesignRevision>>()
        .length;
    final failures = outcomes
        .whereType<ElvCommandFailureResult<ProjectDesignRevision>>()
        .toList();
    expect(successCount, anyOf(0, 1));
    expect(failures, hasLength(2 - successCount));
    if (successCount == 1) {
      expect(failures.single.failure.code, 'ELV_IDEMPOTENCY_CONFLICT');
      expect(ledger.single.read<String>('outcome_kind'), 'SUCCESS');
      final revision = await dbA
          .customSelect(
            "SELECT state, revision FROM project_design_revisions WHERE id = '$_revisionId'",
          )
          .getSingle();
      expect(revision.read<String>('state'), 'FROZEN');
      expect(revision.read<int>('revision'), 2);
      expect(
        await dbA
            .customSelect(
              "SELECT COUNT(*) AS c FROM design_revision_physical_snapshots WHERE design_revision_id = '$_revisionId'",
            )
            .getSingle()
            .then((row) => row.read<int>('c')),
        1,
      );
    } else {
      expect(
        failures.map((value) => value.failure.code).toSet(),
        containsAll({
          'ELV_DESIGN_REVISION_REVISION_CONFLICT',
          'ELV_IDEMPOTENCY_CONFLICT',
        }),
      );
      expect(ledger.single.read<String>('outcome_kind'), 'REJECTED');
      final revision = await dbA
          .customSelect(
            "SELECT state, revision FROM project_design_revisions WHERE id = '$_revisionId'",
          )
          .getSingle();
      expect(revision.read<String>('state'), 'WORKING');
      expect(revision.read<int>('revision'), 1);
      expect(
        await dbA
            .customSelect(
              "SELECT COUNT(*) AS c FROM design_revision_physical_snapshots WHERE design_revision_id = '$_revisionId'",
            )
            .getSingle()
            .then((row) => row.read<int>('c')),
        0,
      );
    }

    await dbA.close();
    await dbB.close();
  });
}
