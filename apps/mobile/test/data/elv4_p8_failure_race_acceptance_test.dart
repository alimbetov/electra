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

const _projectId = 'project-p8-race';
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

Future<void> _seedProject(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 15, 17);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: _projectId,
          name: 'ELV4 P8 failure race acceptance',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DriftElvDesignRevisionRepository _repository(
  AppDatabase db, {
  ElvFailureProbe? failureProbe,
}) => DriftElvDesignRevisionRepository(
  db,
  originDeviceId: 'test',
  failureProbe: failureProbe,
  now: () => DateTime.utc(2026, 10, 15, 17, 30),
);

Future<void> _bootstrap(AppDatabase db) async {
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

Future<void> _expectNoFreezeArtifacts(AppDatabase db) async {
  expect(
    await (db.select(
      db.designRevisionPhysicalSnapshots,
    )..where((row) => row.designRevisionId.equals(_revisionId))).get(),
    isEmpty,
  );
  expect(
    await (db.select(
      db.designRevisionPowerSnapshots,
    )..where((row) => row.designRevisionId.equals(_revisionId))).get(),
    isEmpty,
  );
  expect(
    await (db.select(
      db.designRevisionSnapshotManifests,
    )..where((row) => row.designRevisionId.equals(_revisionId))).get(),
    isEmpty,
  );
  final revision = await (db.select(
    db.projectDesignRevisions,
  )..where((row) => row.id.equals(_revisionId))).getSingle();
  expect(revision.state, 'WORKING');
  expect(revision.revision, 1);
}

void main() {
  test(
    'P8 stale freeze precondition leaves no physical/power/manifest artifacts',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'electra-elv4-p8-stale-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');

      var db = AppDatabase(_native(file, configureWal: true));
      await _seedProject(db);
      await _bootstrap(db);

      final result = await _repository(db).freeze(
        const FreezeProjectDesignRevisionCommand(
          commandId: 'freeze-stale',
          projectId: _projectId,
          designRevisionId: _revisionId,
          expectedRevision: 2,
        ),
      );

      expect(result, isA<ElvCommandFailureResult<ProjectDesignRevision>>());
      final failure =
          (result as ElvCommandFailureResult<ProjectDesignRevision>).failure;
      expect(failure.code, 'ELV_DESIGN_REVISION_REVISION_CONFLICT');
      expect(failure.category, ElvFailureCategory.revisionConflict);
      expect(failure.expectedRevision, 2);
      expect(failure.actualRevision, 1);
      await _expectNoFreezeArtifacts(db);

      await db.close();
      db = AppDatabase(_native(file));
      addTearDown(db.close);
      await _expectNoFreezeArtifacts(db);
    },
  );

  test('P8 injected freeze failure atomically rolls back physical, power and manifest', () async {
    final dir = await Directory.systemTemp.createTemp('electra-elv4-p8-fault-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/electra.sqlite');

    var db = AppDatabase(_native(file, configureWal: true));
    await _seedProject(db);
    await _bootstrap(db);

    final repository = _repository(
      db,
      failureProbe: const _ThrowAt(
        ElvFailurePoints.p3FreezeAfterSnapshotInsert,
      ),
    );
    await expectLater(
      repository.freeze(
        const FreezeProjectDesignRevisionCommand(
          commandId: 'freeze-fault',
          projectId: _projectId,
          designRevisionId: _revisionId,
          expectedRevision: 1,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    await _expectNoFreezeArtifacts(db);

    await db.close();
    db = AppDatabase(_native(file));
    addTearDown(db.close);
    await _expectNoFreezeArtifacts(db);
  });

  test(
    'P8 concurrent freeze/create-next has only serializable revision outcomes',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'electra-elv4-p8-race-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');

      final seedDb = AppDatabase(_native(file, configureWal: true));
      await _seedProject(seedDb);
      await _bootstrap(seedDb);
      await seedDb.close();

      final dbA = AppDatabase(_native(file));
      final dbB = AppDatabase(_native(file));
      addTearDown(dbA.close);
      addTearDown(dbB.close);
      final repoA = _repository(dbA);
      final repoB = _repository(dbB);

      final freezeFuture = repoA.freeze(
        const FreezeProjectDesignRevisionCommand(
          commandId: 'race-freeze',
          projectId: _projectId,
          designRevisionId: _revisionId,
          expectedRevision: 1,
        ),
      );
      final createFuture = repoB.createNext(
        const CreateNextWorkingDesignRevisionCommand(
          commandId: 'race-create-r2',
          projectId: _projectId,
          newRevisionId: 'REV-2',
          code: 'R2',
          basedOnRevisionId: _revisionId,
        ),
      );

      final freezeResult = await freezeFuture;
      final createResult = await createFuture;
      expect(freezeResult, isA<ElvCommandSuccess<ProjectDesignRevision>>());

      final revisionR1 = await (dbA.select(
        dbA.projectDesignRevisions,
      )..where((row) => row.id.equals(_revisionId))).getSingle();
      expect(revisionR1.state, 'FROZEN');
      expect(revisionR1.revision, 2);
      expect(
        await (dbA.select(
          dbA.designRevisionPhysicalSnapshots,
        )..where((row) => row.designRevisionId.equals(_revisionId))).get(),
        hasLength(1),
      );
      expect(
        await (dbA.select(
          dbA.designRevisionPowerSnapshots,
        )..where((row) => row.designRevisionId.equals(_revisionId))).get(),
        hasLength(1),
      );
      expect(
        await (dbA.select(
          dbA.designRevisionSnapshotManifests,
        )..where((row) => row.designRevisionId.equals(_revisionId))).get(),
        hasLength(1),
      );

      if (createResult is ElvCommandFailureResult<ProjectDesignRevision>) {
        expect(
          createResult.failure.code,
          anyOf(
            'ELV_DESIGN_REVISION_WORKING_EXISTS',
            'ELV_DESIGN_REVISION_BASE_NOT_FROZEN',
          ),
        );
        final retry = await repoB.createNext(
          const CreateNextWorkingDesignRevisionCommand(
            commandId: 'race-create-r2-retry',
            projectId: _projectId,
            newRevisionId: 'REV-2',
            code: 'R2',
            basedOnRevisionId: _revisionId,
          ),
        );
        expect(retry, isA<ElvCommandSuccess<ProjectDesignRevision>>());
      } else {
        expect(createResult, isA<ElvCommandSuccess<ProjectDesignRevision>>());
      }

      await dbA.close();
      await dbB.close();
      final reopened = AppDatabase(_native(file));
      addTearDown(reopened.close);
      final context = await _repository(reopened).context(_projectId);
      expect(context.latestFrozenRevisionId, _revisionId);
      expect(context.workingDesignRevisionId, 'REV-2');
      final r2Rows = await (reopened.select(
        reopened.projectDesignRevisions,
      )..where((row) => row.id.equals('REV-2'))).get();
      expect(r2Rows, hasLength(1));
    },
  );
}
