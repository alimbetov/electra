from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEST = ROOT / 'apps/mobile/test/data/elv4_p7_t06_history_test.dart'
text = TEST.read_text()

if "application/elv_cable_run_command.dart" not in text:
    text = text.replace(
        "import 'package:electra_mobile/application/elv_command_result.dart';\n",
        "import 'package:electra_mobile/application/elv_cable_run_command.dart';\n"
        "import 'package:electra_mobile/application/elv_command_result.dart';\n",
        1,
    )
if "drift_elv_cable_run_repository.dart" not in text:
    text = text.replace(
        "import 'package:electra_mobile/data/database/app_database.dart';\n",
        "import 'package:electra_mobile/data/database/app_database.dart';\n"
        "import 'package:electra_mobile/data/repositories/drift_elv_cable_run_repository.dart';\n",
        1,
    )
if "(3, 'seg-alt')" not in text:
    text = text.replace(
        "for (final (sequence, id) in const [(1, 'seg-old'), (2, 'seg-new')]) {",
        "for (final (sequence, id) in const [(1, 'seg-old'), (2, 'seg-new'), (3, 'seg-alt')]) {",
        1,
    )

if "new edit after undo abandons the old redo branch" not in text:
    anchor = "\nDateTime _clock() => DateTime.utc(2026, 10, 15, 13, 45);\n"
    if text.count(anchor) != 1:
        raise SystemExit('T06 acceptance insertion anchor missing')
    tests = r'''

  test('P7 T06 new edit after undo abandons the old redo branch', () async {
    final directory = await Directory.systemTemp.createTemp('electra-p7-branch-');
    final file = File('${directory.path}/history.sqlite');
    final harness = ElvDatabaseReopenHarness(file);
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final db = harness.open();
    await _seed(db);
    final firstRuntime = _runtime(
      db,
      const ['branch-1', 'before-1', 'after-1', 'inverse-1'],
    );
    expect(
      await firstRuntime.execute(_reviewed('edit-1', 1, 'seg-new')),
      isA<ElvCommandSuccess<Object?>>(),
    );
    expect(
      await firstRuntime.undo(
        projectId: 'project',
        designRevisionId: 'rev-1',
        executionCommandId: 'undo-1',
      ),
      isA<ElvCommandSuccess<Object?>>(),
    );

    final secondRuntime = _runtime(
      db,
      const ['branch-2', 'before-2', 'after-2', 'inverse-2'],
    );
    expect(
      await secondRuntime.execute(_reviewed('edit-2', 3, 'seg-alt')),
      isA<ElvCommandSuccess<Object?>>(),
    );
    await _expectRoute(db, 'seg-alt', revision: 4);
    final operations = await (db.select(db.elvRevisionCommandHistoryOperations)
          ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
        .get();
    expect(operations.map((row) => row.state).toList(), [
      'REDO_ABANDONED',
      'APPLIED',
    ]);
    final cursor = await db.select(db.elvRevisionCommandHistoryCursors).getSingle();
    expect(cursor.headSequence, 2);
    expect(cursor.generation, 3);
    expect(await secondRuntime.canRedo(projectId: 'project', designRevisionId: 'rev-1'), isFalse);
    final abandonedRedo = await secondRuntime.redo(
      projectId: 'project',
      designRevisionId: 'rev-1',
      executionCommandId: 'redo-abandoned',
    );
    expect(
      (abandonedRedo as ElvCommandFailureResult<Object?>).failure.code,
      'ELV4_HISTORY_REDO_NOT_AVAILABLE',
    );
    await _expectRoute(db, 'seg-alt', revision: 4);
    await db.close();
  });

  test('P7 T06 stale aggregate rejects undo without moving history cursor', () async {
    final directory = await Directory.systemTemp.createTemp('electra-p7-stale-');
    final file = File('${directory.path}/history.sqlite');
    final harness = ElvDatabaseReopenHarness(file);
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final db = harness.open();
    await _seed(db);
    final runtime = _runtime(
      db,
      const ['branch-1', 'before-1', 'after-1', 'inverse-1'],
    );
    expect(
      await runtime.execute(_reviewed('edit-1', 1, 'seg-new')),
      isA<ElvCommandSuccess<Object?>>(),
    );
    final external = DriftElvCableRunRepository(
      db,
      originDeviceId: 'external',
      now: _clock,
    );
    expect(
      await external.reroute(
        RerouteCableRunCommand(
          commandId: 'external-reroute',
          projectId: 'project',
          cableRunId: 'run-1',
          expectedRevision: 2,
          traversals: const [
            CableRunTraversal(
              id: 'tr-1',
              cableRunId: 'run-1',
              sequence: 1,
              routeSegmentId: 'seg-alt',
              direction: CableTraversalDirection.forward,
            ),
          ],
        ),
      ),
      isA<ElvCommandSuccess<CanonicalCableRun>>(),
    );

    final result = await runtime.undo(
      projectId: 'project',
      designRevisionId: 'rev-1',
      executionCommandId: 'stale-undo',
    );
    expect(
      (result as ElvCommandFailureResult<Object?>).failure.code,
      'ELV4_HISTORY_AGGREGATE_CHANGED',
    );
    await _expectRoute(db, 'seg-alt', revision: 3);
    await _expectHistory(
      db,
      state: 'APPLIED',
      headSequence: 1,
      generation: 1,
      executionKinds: const {'ORIGINAL'},
    );
    await db.close();
  });

  test('P7 T06 frozen revision rejects undo and preserves captured route', () async {
    final directory = await Directory.systemTemp.createTemp('electra-p7-frozen-');
    final file = File('${directory.path}/history.sqlite');
    final harness = ElvDatabaseReopenHarness(file);
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final db = harness.open();
    await _seed(db);
    final runtime = _runtime(
      db,
      const ['branch-1', 'before-1', 'after-1', 'inverse-1'],
    );
    expect(
      await runtime.execute(_reviewed('edit-1', 1, 'seg-new')),
      isA<ElvCommandSuccess<Object?>>(),
    );
    await (db.update(db.projectDesignRevisions)
          ..where((row) => row.id.equals('rev-1')))
        .write(ProjectDesignRevisionsCompanion(state: const Value('FROZEN')));

    expect(
      await runtime.canUndo(projectId: 'project', designRevisionId: 'rev-1'),
      isFalse,
    );
    final result = await runtime.undo(
      projectId: 'project',
      designRevisionId: 'rev-1',
      executionCommandId: 'frozen-undo',
    );
    expect(
      (result as ElvCommandFailureResult<Object?>).failure.code,
      'ELV4_POWER_WORKSPACE_READ_ONLY',
    );
    await _expectRoute(db, 'seg-new', revision: 2);
    await _expectHistory(
      db,
      state: 'APPLIED',
      headSequence: 1,
      generation: 1,
      executionKinds: const {'ORIGINAL'},
    );
    await db.close();
  });

  test('P7 T06 failed reviewed reroute leaves canonical and history DB unchanged', () async {
    final directory = await Directory.systemTemp.createTemp('electra-p7-failure-');
    final file = File('${directory.path}/history.sqlite');
    final harness = ElvDatabaseReopenHarness(file);
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final db = harness.open();
    await _seed(db);
    final runtime = _runtime(db, const []);
    final failed = await runtime.execute(_reviewed('invalid-edit', 1, 'seg-missing'));
    expect(failed, isA<ElvCommandFailureResult<Object?>>());
    await _expectRoute(db, 'seg-old', revision: 1);
    expect(await db.select(db.elvRevisionCommandHistoryOperations).get(), isEmpty);
    expect(await db.select(db.elvRevisionCommandHistoryCursors).get(), isEmpty);
    expect(await db.select(db.elvRevisionAggregateEvidenceRecords).get(), isEmpty);
    expect(await db.select(db.elvRevisionCommandHistoryExecutions).get(), isEmpty);
    await db.close();
  });
'''
    text = text.replace(anchor, tests + anchor, 1)

if 'DriftElvReviewedRoutingRuntime _runtime(' not in text:
    helper_anchor = "DateTime _clock() => DateTime.utc(2026, 10, 15, 13, 45);\n"
    helpers = r'''

DriftElvReviewedRoutingRuntime _runtime(AppDatabase db, List<String> ids) =>
    DriftElvReviewedRoutingRuntime(
      db,
      originDeviceId: 'test-runtime',
      idGenerator: FixedSequenceIdGenerator(ids),
      now: _clock,
    );

ReviewedRerouteCableRunWorkspaceCommand _reviewed(
  String commandId,
  int expectedRevision,
  String routeSegmentId,
) => ReviewedRerouteCableRunWorkspaceCommand(
  commandId: commandId,
  projectId: 'project',
  designRevisionId: 'rev-1',
  cableRunId: 'run-1',
  expectedRevision: expectedRevision,
  traversals: [
    CableRunTraversal(
      id: 'tr-1',
      cableRunId: 'run-1',
      sequence: 1,
      routeSegmentId: routeSegmentId,
      direction: CableTraversalDirection.forward,
    ),
  ],
);
'''
    text = text.replace(helper_anchor, helper_anchor + helpers, 1)

TEST.write_text(text)
