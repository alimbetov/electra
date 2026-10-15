import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _projectId = 'project-p8-idempotency';
const _revisionId = 'REV-1';
const _freezeCommandId = 'freeze-r1-idempotent';

QueryExecutor _native(File file, {bool configureWal = false}) =>
    NativeDatabase.createInBackground(
      file,
      setup: (raw) {
        if (configureWal) {
          raw.execute('PRAGMA journal_mode=WAL');
        }
        raw.execute('PRAGMA busy_timeout=30000');
      },
    );

DriftElvDesignRevisionRepository _repository(AppDatabase db) =>
    DriftElvDesignRevisionRepository(
      db,
      originDeviceId: 'test',
      now: () => DateTime.utc(2026, 10, 15, 18),
    );

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 15, 17, 45);
  await db.into(db.projects).insert(
        ProjectsCompanion.insert(
          id: _projectId,
          name: 'P8 idempotency acceptance',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
  final result = await _repository(db).bootstrap(
    const BootstrapProjectDesignRevisionCommand(
      commandId: 'bootstrap-r1',
      projectId: _projectId,
      revisionId: _revisionId,
      code: 'R1',
    ),
  );
  expect(result, isA<ElvCommandSuccess<ProjectDesignRevision>>());
}

const _freeze = FreezeProjectDesignRevisionCommand(
  commandId: _freezeCommandId,
  projectId: _projectId,
  designRevisionId: _revisionId,
  expectedRevision: 1,
);

ProjectDesignRevision _success(ElvCommandResult<ProjectDesignRevision> result) {
  expect(result, isA<ElvCommandSuccess<ProjectDesignRevision>>());
  return (result as ElvCommandSuccess<ProjectDesignRevision>).value;
}

Future<void> _expectSingleFreezePersistence(AppDatabase db) async {
  final revision = await (db.select(db.projectDesignRevisions)
        ..where((row) => row.id.equals(_revisionId)))
      .getSingle();
  expect(revision.state, 'FROZEN');
  expect(revision.revision, 2);

  expect(
    await (db.select(db.designRevisionPhysicalSnapshots)
          ..where((row) => row.designRevisionId.equals(_revisionId)))
        .get(),
    hasLength(1),
  );
  expect(
    await (db.select(db.designRevisionPowerSnapshots)
          ..where((row) => row.designRevisionId.equals(_revisionId)))
        .get(),
    hasLength(1),
  );
  expect(
    await (db.select(db.designRevisionSnapshotManifests)
          ..where((row) => row.designRevisionId.equals(_revisionId)))
        .get(),
    hasLength(1),
  );
  expect(
    await (db.select(db.commandExecutionRecords)
          ..where(
            (row) =>
                row.projectId.equals(_projectId) &
                row.commandId.equals(_freezeCommandId),
          ))
        .get(),
    hasLength(1),
  );
}

void _expectSameLogicalRevision(
  ProjectDesignRevision left,
  ProjectDesignRevision right,
) {
  expect(right.id, left.id);
  expect(right.projectId, left.projectId);
  expect(right.code, left.code);
  expect(right.sequence, left.sequence);
  expect(right.state, left.state);
  expect(right.basedOnRevisionId, left.basedOnRevisionId);
  expect(right.revision, left.revision);
}

void main() {
  test('P8 repeated freeze command replays the persisted logical result', () async {
    final dir = await Directory.systemTemp.createTemp('electra-p8-replay-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/electra.sqlite');

    var db = AppDatabase(_native(file, configureWal: true));
    await _seed(db);
    final repository = _repository(db);

    final first = _success(await repository.freeze(_freeze));
    await _expectSingleFreezePersistence(db);
    final ledgerBefore = await (db.select(db.commandExecutionRecords)
          ..where(
            (row) =>
                row.projectId.equals(_projectId) &
                row.commandId.equals(_freezeCommandId),
          ))
        .getSingle();
    final powerBefore = await (db.select(db.designRevisionPowerSnapshots)
          ..where((row) => row.designRevisionId.equals(_revisionId)))
        .getSingle();
    final manifestBefore = await (db.select(db.designRevisionSnapshotManifests)
          ..where((row) => row.designRevisionId.equals(_revisionId)))
        .getSingle();

    final replay = _success(await repository.freeze(_freeze));
    _expectSameLogicalRevision(first, replay);
    await _expectSingleFreezePersistence(db);

    final ledgerAfter = await (db.select(db.commandExecutionRecords)
          ..where(
            (row) =>
                row.projectId.equals(_projectId) &
                row.commandId.equals(_freezeCommandId),
          ))
        .getSingle();
    final powerAfter = await (db.select(db.designRevisionPowerSnapshots)
          ..where((row) => row.designRevisionId.equals(_revisionId)))
        .getSingle();
    final manifestAfter = await (db.select(db.designRevisionSnapshotManifests)
          ..where((row) => row.designRevisionId.equals(_revisionId)))
        .getSingle();

    expect(ledgerAfter.logicalResultJson, ledgerBefore.logicalResultJson);
    expect(ledgerAfter.normalizedPayloadSha256, ledgerBefore.normalizedPayloadSha256);
    expect(powerAfter.payloadJson, powerBefore.payloadJson);
    expect(powerAfter.powerSha256, powerBefore.powerSha256);
    expect(manifestAfter.manifestSha256, manifestBefore.manifestSha256);

    await db.close();
    db = AppDatabase(_native(file));
    addTearDown(db.close);
    final reopenedReplay = _success(await _repository(db).freeze(_freeze));
    _expectSameLogicalRevision(first, reopenedReplay);
    await _expectSingleFreezePersistence(db);
  });

  test('P8 same commandId with changed freeze payload is an idempotency conflict', () async {
    final dir = await Directory.systemTemp.createTemp('electra-p8-conflict-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/electra.sqlite');

    final db = AppDatabase(_native(file, configureWal: true));
    addTearDown(db.close);
    await _seed(db);
    final repository = _repository(db);

    _success(await repository.freeze(_freeze));
    final ledgerBefore = await (db.select(db.commandExecutionRecords)
          ..where(
            (row) =>
                row.projectId.equals(_projectId) &
                row.commandId.equals(_freezeCommandId),
          ))
        .getSingle();

    final conflict = await repository.freeze(
      const FreezeProjectDesignRevisionCommand(
        commandId: _freezeCommandId,
        projectId: _projectId,
        designRevisionId: _revisionId,
        expectedRevision: 2,
      ),
    );
    expect(conflict, isA<ElvCommandFailureResult<ProjectDesignRevision>>());
    final failure =
        (conflict as ElvCommandFailureResult<ProjectDesignRevision>).failure;
    expect(failure.code, 'ELV_IDEMPOTENCY_CONFLICT');
    expect(failure.category, ElvFailureCategory.commandEnvelope);

    await _expectSingleFreezePersistence(db);
    final ledgerAfter = await (db.select(db.commandExecutionRecords)
          ..where(
            (row) =>
                row.projectId.equals(_projectId) &
                row.commandId.equals(_freezeCommandId),
          ))
        .getSingle();
    expect(ledgerAfter.logicalResultJson, ledgerBefore.logicalResultJson);
    expect(ledgerAfter.normalizedPayloadSha256, ledgerBefore.normalizedPayloadSha256);
  });

  test('P8 concurrent duplicate freeze converges to one commit and one replay', () async {
    final dir = await Directory.systemTemp.createTemp('electra-p8-dup-race-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/electra.sqlite');

    final seedDb = AppDatabase(_native(file, configureWal: true));
    await _seed(seedDb);
    await seedDb.close();

    final dbA = AppDatabase(_native(file));
    final dbB = AppDatabase(_native(file));
    final repoA = _repository(dbA);
    final repoB = _repository(dbB);

    final results = await Future.wait([
      repoA.freeze(_freeze),
      repoB.freeze(_freeze),
    ]);
    final left = _success(results[0]);
    final right = _success(results[1]);
    _expectSameLogicalRevision(left, right);
    await _expectSingleFreezePersistence(dbA);

    await dbA.close();
    await dbB.close();
    final reopened = AppDatabase(_native(file));
    addTearDown(reopened.close);
    final replay = _success(await _repository(reopened).freeze(_freeze));
    _expectSameLogicalRevision(left, replay);
    await _expectSingleFreezePersistence(reopened);
  });
}
