import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/application/elv_failure_probe.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _projectId = 'project-p8-outcome';
const _revisionId = 'REV-1';

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

final class _ThrowAt implements ElvFailureProbe {
  const _ThrowAt(this.point);

  final String point;

  @override
  Future<void> hit(String candidate) async {
    if (candidate == point) {
      throw StateError('Injected failure at $candidate');
    }
  }
}

DriftElvDesignRevisionRepository _repository(
  AppDatabase db, {
  ElvFailureProbe? failureProbe,
}) => DriftElvDesignRevisionRepository(
  db,
  originDeviceId: 'test',
  failureProbe: failureProbe,
  now: () => DateTime.utc(2026, 10, 15, 19),
);

Future<void> _seed(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 15, 18, 45);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: _projectId,
          name: 'P8 command outcome durability',
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

ElvFailure _failure(ElvCommandResult<ProjectDesignRevision> result) {
  expect(result, isA<ElvCommandFailureResult<ProjectDesignRevision>>());
  return (result as ElvCommandFailureResult<ProjectDesignRevision>).failure;
}

void _expectSameFailure(ElvFailure left, ElvFailure right) {
  expect(right.code, left.code);
  expect(right.category, left.category);
  expect(right.entityType, left.entityType);
  expect(right.entityId, left.entityId);
  expect(right.field, left.field);
  expect(right.expectedRevision, left.expectedRevision);
  expect(right.actualRevision, left.actualRevision);
  expect(right.details, left.details);
}

Future<void> _expectNoFreezeArtifacts(AppDatabase db) async {
  expect(
    await (db.select(db.designRevisionPhysicalSnapshots)
      ..where((row) => row.designRevisionId.equals(_revisionId))).get(),
    isEmpty,
  );
  expect(
    await (db.select(db.designRevisionPowerSnapshots)
      ..where((row) => row.designRevisionId.equals(_revisionId))).get(),
    isEmpty,
  );
  expect(
    await (db.select(db.designRevisionSnapshotManifests)
      ..where((row) => row.designRevisionId.equals(_revisionId))).get(),
    isEmpty,
  );
}

Future<List<CommandExecutionRecordRow>> _ledger(
  AppDatabase db,
  String commandId,
) =>
    (db.select(db.commandExecutionRecords)
          ..where((row) => row.projectId.equals(_projectId))
          ..where((row) => row.commandId.equals(commandId)))
        .get();

void main() {
  test(
    'P8 deterministic freeze rejection is durable and replays verbatim after reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('electra-p8-rejected-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');

      var db = AppDatabase(_native(file, configureWal: true));
      await _seed(db);
      final repository = _repository(db);

      const rejectedCommand = FreezeProjectDesignRevisionCommand(
        commandId: 'freeze-stale-durable',
        projectId: _projectId,
        designRevisionId: _revisionId,
        expectedRevision: 2,
      );
      final first = _failure(await repository.freeze(rejectedCommand));
      expect(first.code, 'ELV_DESIGN_REVISION_REVISION_CONFLICT');
      expect(first.category, ElvFailureCategory.revisionConflict);
      expect(first.expectedRevision, 2);
      expect(first.actualRevision, 1);
      await _expectNoFreezeArtifacts(db);

      final rejectedRows = await _ledger(db, rejectedCommand.commandId);
      expect(rejectedRows, hasLength(1));
      expect(rejectedRows.single.outcomeKind, 'REJECTED');
      expect(rejectedRows.single.commandType, 'FREEZE_PROJECT_DESIGN_REVISION');

      final successfulFreeze = await repository.freeze(
        const FreezeProjectDesignRevisionCommand(
          commandId: 'freeze-r1-valid',
          projectId: _projectId,
          designRevisionId: _revisionId,
          expectedRevision: 1,
        ),
      );
      expect(successfulFreeze, isA<ElvCommandSuccess<ProjectDesignRevision>>());

      await db.close();
      db = AppDatabase(_native(file));
      addTearDown(db.close);
      final replay = _failure(await _repository(db).freeze(rejectedCommand));
      _expectSameFailure(first, replay);
      expect(await _ledger(db, rejectedCommand.commandId), hasLength(1));
    },
  );

  test(
    'P8 same commandId with another command type is an envelope conflict',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'electra-p8-type-conflict-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');

      final db = AppDatabase(_native(file, configureWal: true));
      addTearDown(db.close);
      await _seed(db);
      final repository = _repository(db);

      const commandId = 'shared-command-id';
      final rejected = _failure(
        await repository.freeze(
          const FreezeProjectDesignRevisionCommand(
            commandId: commandId,
            projectId: _projectId,
            designRevisionId: _revisionId,
            expectedRevision: 2,
          ),
        ),
      );
      expect(rejected.code, 'ELV_DESIGN_REVISION_REVISION_CONFLICT');

      final conflict = _failure(
        await repository.createNext(
          const CreateNextWorkingDesignRevisionCommand(
            commandId: commandId,
            projectId: _projectId,
            newRevisionId: 'REV-2',
            code: 'R2',
            basedOnRevisionId: _revisionId,
          ),
        ),
      );
      expect(conflict.code, 'ELV_IDEMPOTENCY_CONFLICT');
      expect(conflict.category, ElvFailureCategory.commandEnvelope);
      final rows = await _ledger(db, commandId);
      expect(rows, hasLength(1));
      expect(rows.single.outcomeKind, 'REJECTED');
      expect(rows.single.commandType, 'FREEZE_PROJECT_DESIGN_REVISION');
    },
  );

  test(
    'P8 faulted freeze transaction leaves no false ledger outcome after reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'electra-p8-fault-ledger-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');

      var db = AppDatabase(_native(file, configureWal: true));
      await _seed(db);
      const commandId = 'freeze-fault-no-ledger';
      final repository = _repository(
        db,
        failureProbe: const _ThrowAt(
          ElvFailurePoints.p3FreezeAfterSnapshotInsert,
        ),
      );
      await expectLater(
        repository.freeze(
          const FreezeProjectDesignRevisionCommand(
            commandId: commandId,
            projectId: _projectId,
            designRevisionId: _revisionId,
            expectedRevision: 1,
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(await _ledger(db, commandId), isEmpty);
      await _expectNoFreezeArtifacts(db);

      await db.close();
      db = AppDatabase(_native(file));
      addTearDown(db.close);
      expect(await _ledger(db, commandId), isEmpty);
      await _expectNoFreezeArtifacts(db);
      final revision =
          await (db.select(db.projectDesignRevisions)
            ..where((row) => row.id.equals(_revisionId))).getSingle();
      expect(revision.state, 'WORKING');
      expect(revision.revision, 1);
    },
  );
}
