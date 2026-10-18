import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/database/drift_raw_statement.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'schema 22 exposes dedicated revision-scoped ELV4 persistence roots',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(db.schemaVersion, 24);
      final tables =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type = 'table'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(
        tables,
        containsAll({
          'power_port_bindings',
          'power_component_bindings',
          'power_transfer_bindings',
          'power_transfer_outputs',
          'power_load_bindings',
          'power_capacity_groups',
          'power_capacity_group_members',
          'power_supply_requirements',
          'power_supply_requirement_inputs',
          'power_operating_scenarios',
          'power_scenario_segments',
          'power_scenario_states',
          'power_scenario_source_selections',
          'power_scenario_unavailable_sources',
          'poe_delivery_bindings',
          'poe_delivery_path_members',
          'backup_assemblies',
          'backup_protected_outputs',
          'battery_bank_bindings',
          'design_revision_power_snapshots',
          'design_revision_snapshot_manifests',
          'power_evaluation_records',
          'power_evaluation_pointers',
          'power_operation_records',
        }),
      );
    },
  );

  test(
    'logical scenario identity may coexist across design revisions only',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedProjectAndRevisions(db);

      Future<void> insert(String revisionId) => runRawStatement(
        db,
        'INSERT INTO power_operating_scenarios '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, role, policy_refs_json) '
        "VALUES (?, ?, 'NORMAL', 1, ?, ?, NULL, 'test', 'NORMAL', '[]')",
        [
          Variable.withString('project'),
          Variable.withString(revisionId),
          Variable<DateTime>(_now),
          Variable<DateTime>(_now),
        ],
      );

      await insert('rev-frozen');
      await insert('rev-working');
      expect(
        await db
            .customSelect(
              "SELECT COUNT(*) AS c FROM power_operating_scenarios WHERE id = 'NORMAL'",
            )
            .getSingle()
            .then((row) => row.read<int>('c')),
        2,
      );
      await expectLater(insert('rev-working'), throwsA(anything));
    },
  );

  test('revision/project mismatch is rejected by database invariant', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProjectAndRevisions(db);
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: 'other-project',
            name: 'Other',
            measurementSystem: 'metric',
            defaultStructuralHeightMm: 3000,
            defaultFinishedCeilingHeightMm: 2700,
            createdAt: _now,
            updatedAt: _now,
            originDeviceId: 'test',
          ),
        );

    await expectLater(
      runRawStatement(
        db,
        'INSERT INTO power_operating_scenarios '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, role, policy_refs_json) '
        "VALUES ('other-project', 'rev-working', 'BAD', 1, ?, ?, NULL, 'test', 'NORMAL', '[]')",
        [Variable<DateTime>(_now), Variable<DateTime>(_now)],
      ),
      throwsA(anything),
    );
  });

  test('evaluation append is immutable and pointer CAS is monotonic', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProjectAndRevisions(db);
    final store = DriftPowerRuntimeStore(
      db,
      originDeviceId: 'device-a',
      now: () => _now,
    );

    final first = _evidence(
      evaluationId: 'eval-1',
      inputFingerprint:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      algorithmVersion: 'algo-1',
    );
    await store.appendEvaluation(
      projectId: 'project',
      designRevisionId: 'rev-working',
      evidence: first,
    );
    final pointer1 = await store.publishFirstCurrent(
      projectId: 'project',
      designRevisionId: 'rev-working',
      evidence: first,
    );
    expect(pointer1.state, PowerPointerState.current);
    expect(pointer1.generation, 1);
    expect(pointer1.evaluationId, 'eval-1');

    final stale = await store.markStale(
      projectId: 'project',
      designRevisionId: 'rev-working',
      nodeKey: first.nodeKey,
      expectedGeneration: 1,
    );
    expect(stale.state, PowerPointerState.stale);
    expect(stale.generation, 2);

    await expectLater(
      store.markStale(
        projectId: 'project',
        designRevisionId: 'rev-working',
        nodeKey: first.nodeKey,
        expectedGeneration: 1,
      ),
      throwsA(
        isA<PowerRuntimeStorageException>().having(
          (error) => error.code,
          'code',
          'ELV4_POINTER_STALE_CAS_FAILED',
        ),
      ),
    );

    final second = _evidence(
      evaluationId: 'eval-2',
      inputFingerprint:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      algorithmVersion: 'algo-1',
    );
    await store.appendEvaluation(
      projectId: 'project',
      designRevisionId: 'rev-working',
      evidence: second,
    );
    final pointer3 = await store.publishCurrent(
      projectId: 'project',
      designRevisionId: 'rev-working',
      evidence: second,
      expectedStaleGeneration: 2,
    );
    expect(pointer3.state, PowerPointerState.current);
    expect(pointer3.generation, 3);
    expect(pointer3.evaluationId, 'eval-2');

    await expectLater(
      db.customUpdate(
        "UPDATE power_evaluation_records SET evidence_json = '{}' "
        "WHERE evaluation_id = 'eval-1'",
      ),
      throwsA(anything),
    );
    final stored =
        await db
            .customSelect(
              'SELECT evidence_json FROM power_evaluation_records '
              "WHERE evaluation_id = 'eval-1'",
            )
            .getSingle();
    expect(stored.read<String>('evidence_json'), first.canonicalJson);
  });

  test(
    'evaluation identity replay accepts same evidence and rejects mutation',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedProjectAndRevisions(db);
      final store = DriftPowerRuntimeStore(
        db,
        originDeviceId: 'device-a',
        now: () => _now,
      );
      final original = _evidence(
        evaluationId: 'eval-1',
        inputFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        algorithmVersion: 'algo-1',
      );
      await store.appendEvaluation(
        projectId: 'project',
        designRevisionId: 'rev-working',
        evidence: original,
      );
      await store.appendEvaluation(
        projectId: 'project',
        designRevisionId: 'rev-working',
        evidence: original,
      );

      final changed = _evidence(
        evaluationId: 'eval-1',
        inputFingerprint:
            'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        algorithmVersion: 'algo-2',
        status: PowerEvaluationStatus.fail,
      );
      await expectLater(
        store.appendEvaluation(
          projectId: 'project',
          designRevisionId: 'rev-working',
          evidence: changed,
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_EVALUATION_IDENTITY_CONFLICT',
          ),
        ),
      );
    },
  );

  test(
    'replay-first operation commits once and rolls back failed PENDING row',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedProjectAndRevisions(db);
      final store = DriftPowerRuntimeStore(
        db,
        originDeviceId: 'device-a',
        now: () => _now,
      );
      var executions = 0;
      Future<String> execute() async {
        executions++;
        return '{"result":"ok"}';
      }

      const fingerprint =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
      final first = await store.executeReplayable(
        projectId: 'project',
        designRevisionId: 'rev-working',
        operationId: 'op-1',
        commandType: 'EDIT_SCENARIO',
        payloadSchema: 'electra.elv4-edit-scenario.v1',
        commandFingerprint: fingerprint,
        execute: execute,
      );
      final replay = await store.executeReplayable(
        projectId: 'project',
        designRevisionId: 'rev-working',
        operationId: 'op-1',
        commandType: 'EDIT_SCENARIO',
        payloadSchema: 'electra.elv4-edit-scenario.v1',
        commandFingerprint: fingerprint,
        execute: execute,
      );
      expect(first.replayed, isFalse);
      expect(replay.replayed, isTrue);
      expect(executions, 1);

      await expectLater(
        store.executeReplayable(
          projectId: 'project',
          designRevisionId: 'rev-working',
          operationId: 'op-1',
          commandType: 'EDIT_SCENARIO',
          payloadSchema: 'electra.elv4-edit-scenario.v1',
          commandFingerprint:
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          execute: execute,
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_OPERATION_FINGERPRINT_CONFLICT',
          ),
        ),
      );

      await expectLater(
        store.executeReplayable(
          projectId: 'project',
          designRevisionId: 'rev-working',
          operationId: 'op-fail',
          commandType: 'EDIT_SCENARIO',
          payloadSchema: 'electra.elv4-edit-scenario.v1',
          commandFingerprint:
              'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          execute: () async => throw StateError('injected failure'),
        ),
        throwsStateError,
      );
      final failedRows =
          await db
              .customSelect(
                "SELECT COUNT(*) AS c FROM power_operation_records WHERE operation_id = 'op-fail'",
              )
              .getSingle();
      expect(failedRows.read<int>('c'), 0);
    },
  );

  test(
    'committed operation replays after freeze but rejects type/schema reuse',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedProjectAndRevisions(db);
      final store = DriftPowerRuntimeStore(db, originDeviceId: 'test');
      var executions = 0;
      Future<PowerReplayResult> run({
        String type = 'EDIT',
        String schema = 'edit.v1',
        String id = 'op',
      }) => store.executeReplayable(
        projectId: 'project',
        designRevisionId: 'rev-working',
        operationId: id,
        commandType: type,
        payloadSchema: schema,
        commandFingerprint:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        execute: () async {
          executions++;
          return '{"ok":true}';
        },
      );
      final original = await run();
      await db.customStatement(
        "UPDATE project_design_revisions SET state = 'FROZEN' WHERE id = 'rev-working'",
      );
      final replay = await run();
      expect(replay.replayed, isTrue);
      expect(replay.resultJson, original.resultJson);
      expect(executions, 1);
      for (final args in [('OTHER', 'edit.v1'), ('EDIT', 'edit.v2')]) {
        await expectLater(
          run(type: args.$1, schema: args.$2),
          throwsA(
            isA<PowerRuntimeStorageException>().having(
              (e) => e.code,
              'code',
              'ELV4_OPERATION_FINGERPRINT_CONFLICT',
            ),
          ),
        );
      }
      await expectLater(
        run(id: 'new'),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (e) => e.code,
            'code',
            'ELV4_REVISION_NOT_WORKING',
          ),
        ),
      );
      expect(executions, 1);
    },
  );

  test(
    'revision mutation and evaluation append are rejected after freeze',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedProjectAndRevisions(db);
      final store = DriftPowerRuntimeStore(
        db,
        originDeviceId: 'device-a',
        now: () => _now,
      );

      await expectLater(
        store.executeReplayable(
          projectId: 'project',
          designRevisionId: 'rev-frozen',
          operationId: 'op-frozen',
          commandType: 'EDIT_SCENARIO',
          payloadSchema: 'electra.elv4-edit-scenario.v1',
          commandFingerprint:
              '1111111111111111111111111111111111111111111111111111111111111111',
          execute: () async => '{}',
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_REVISION_NOT_WORKING',
          ),
        ),
      );

      final frozenEvidence = PowerEvaluationEvidence(
        evaluationId: 'eval-frozen',
        nodeKey: PowerNodeKeyV2(
          revisionId: 'rev-frozen',
          scenarioId: 'NORMAL',
          scopeKind: PowerEvaluationScopeKind.segment,
          scopeId: 'S1',
          processCode: PowerProcessCode.pwr01,
          subjectKind: 'SOURCE',
          subjectId: 'SOURCE-1',
        ),
        algorithmVersion: 'algo-1',
        inputSchemaVersion: 'input-1',
        outputSchemaVersion: 'output-1',
        inputFingerprint:
            '2222222222222222222222222222222222222222222222222222222222222222',
        status: PowerEvaluationStatus.pass,
        applicability: PowerEvaluationApplicability.applicable,
        inputs: const {},
        output: const {},
      );
      await expectLater(
        store.appendEvaluation(
          projectId: 'project',
          designRevisionId: 'rev-frozen',
          evidence: frozenEvidence,
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_REVISION_NOT_WORKING',
          ),
        ),
      );
    },
  );
}

final _now = DateTime.utc(2026, 10, 15, 8);

Future<void> _seedProjectAndRevisions(AppDatabase db) async {
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project',
          name: 'ELV4 persistence',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: _now,
          updatedAt: _now,
          originDeviceId: 'test',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'rev-frozen',
          projectId: 'project',
          code: 'R1',
          sequence: 1,
          state: 'FROZEN',
          createdAt: _now,
          updatedAt: _now,
          originDeviceId: 'test',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'rev-working',
          projectId: 'project',
          code: 'R2',
          sequence: 2,
          state: 'WORKING',
          basedOnRevisionId: const Value('rev-frozen'),
          createdAt: _now,
          updatedAt: _now,
          originDeviceId: 'test',
        ),
      );
}

PowerEvaluationEvidence _evidence({
  required String evaluationId,
  required String inputFingerprint,
  required String algorithmVersion,
  PowerEvaluationStatus status = PowerEvaluationStatus.pass,
}) => PowerEvaluationEvidence(
  evaluationId: evaluationId,
  nodeKey: PowerNodeKeyV2(
    revisionId: 'rev-working',
    scenarioId: 'NORMAL',
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: 'S1',
    processCode: PowerProcessCode.pwr02,
    subjectKind: 'CAPACITY_GROUP',
    subjectId: 'GROUP-1',
  ),
  algorithmVersion: algorithmVersion,
  inputSchemaVersion: 'electra.elv4-pwr02-input.v1',
  outputSchemaVersion: 'electra.elv4-pwr02-output.v1',
  inputFingerprint: inputFingerprint,
  status: status,
  applicability: PowerEvaluationApplicability.applicable,
  inputs: const {'demandW': '10'},
  output:
      status == PowerEvaluationStatus.pass
          ? const {'marginW': '5'}
          : const {'marginW': '-1'},
);
