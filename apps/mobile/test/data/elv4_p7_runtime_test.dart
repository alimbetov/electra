import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P7 reverse index invalidates typed fact and transitive consumers only',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final runtime = _runtime(db);

    final sourceFact = _factKey('SOURCE-1', 'SOURCE_PROFILE');
    final unrelatedFact = _factKey('SOURCE-2', 'SOURCE_PROFILE');
    final pwr01 = await _publish(
      runtime,
      node: _node(PowerProcessCode.pwr01, 'LOAD-1'),
      input: _input(facts: [sourceFact]),
      evaluationId: 'eval-pwr01',
      operationId: 'op-pwr01',
    );
    final pwr02 = await _publish(
      runtime,
      node: _node(PowerProcessCode.pwr02, 'SOURCE-1'),
      input: _input(
        facts: [_factKey('SOURCE-1', 'CAPACITY')],
        evaluations: [pwr01],
      ),
      evaluationId: 'eval-pwr02',
      operationId: 'op-pwr02',
    );
    final unrelated = await _publish(
      runtime,
      node: _node(PowerProcessCode.pwr01, 'LOAD-2'),
      input: _input(facts: [unrelatedFact]),
      evaluationId: 'eval-unrelated',
      operationId: 'op-unrelated',
    );

    final beforeIndex = await _count(db, 'power_dependency_index_records');
    expect(beforeIndex, greaterThanOrEqualTo(4));

    final receipt = await runtime.mutateAndInvalidate(
      projectId: 'project',
      designRevisionId: 'rev-working',
      oldClosure: [sourceFact],
      applyMutation: () => db.customUpdate(
        'UPDATE project_design_revisions '
        'SET revision = revision + 1, updated_at = ? WHERE id = ?',
        variables: [
          Variable<DateTime>(_now.add(const Duration(minutes: 1))),
          Variable.withString('rev-working'),
        ],
      ),
      captureNewClosure: () async => [sourceFact],
    );

    expect(receipt.previousRevisionToken, 1);
    expect(receipt.currentRevisionToken, 2);
    expect(
      receipt.invalidatedNodeKeys.map((value) => value.encode()).toSet(),
      {
        pwr01.evidence.nodeKey.encode(),
        pwr02.evidence.nodeKey.encode(),
      },
    );
    expect(await _pointerState(db, pwr01.evidence.nodeKey), 'STALE');
    expect(await _pointerState(db, pwr02.evidence.nodeKey), 'STALE');
    expect(await _pointerState(db, unrelated.evidence.nodeKey), 'CURRENT');

    final indexedNodes = await db.customSelect(
      'SELECT DISTINCT logical_node_key_sha256 '
      'FROM power_dependency_index_records',
    ).get();
    expect(
      indexedNodes.map((row) => row.read<String>('logical_node_key_sha256')),
      contains(unrelated.evidence.nodeKey.sha256),
    );
    expect(
      indexedNodes.map((row) => row.read<String>('logical_node_key_sha256')),
      isNot(contains(pwr01.evidence.nodeKey.sha256)),
    );
    expect(await _count(db, 'power_evaluation_records'), 3);

    final stored = await db.customSelect(
      'SELECT evidence_json FROM power_evaluation_records '
      "WHERE evaluation_id = 'eval-pwr01'",
    ).getSingle();
    final envelope = (jsonDecode(stored.read<String>('evidence_json')) as Map)
        .cast<String, Object?>();
    expect(envelope['schema'], 'electra.elv4-published-evaluation.v1');
    expect(envelope['consumedInput'], isA<Map>());
    expect((envelope['dependencyKeys'] as List), isNotEmpty);
  });

  test('P7 late publisher cannot revive CURRENT after design token changes',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final runtime = _runtime(db);
    final input = _input(facts: [_factKey('LOAD-1', 'DEMAND')]);
    final node = _node(PowerProcessCode.pwr01, 'LOAD-1');
    final capture = await runtime.captureForCalculation(
      projectId: 'project',
      designRevisionId: 'rev-working',
      targetNodeKey: node,
      captureInput: () async => input,
    );
    final evidence = _evidence(node, 'eval-late', input);

    await db.customUpdate(
      'UPDATE project_design_revisions SET revision = revision + 1 '
      'WHERE id = ?',
      variables: [Variable.withString('rev-working')],
    );

    await expectLater(
      runtime.publishGuarded(
        capture: capture,
        evidence: evidence,
        operationId: 'op-late',
        commandFingerprint: sha256HexUtf8('op-late'),
        recaptureInput: () async => input,
      ),
      throwsA(
        isA<PowerRuntimeStorageException>().having(
          (error) => error.code,
          'code',
          'ELV4_RESULT_INPUT_CHANGED',
        ),
      ),
    );
    expect(await _count(db, 'power_evaluation_records'), 0);
    expect(await _count(db, 'power_evaluation_pointers'), 0);
    expect(await _count(db, 'power_operation_records'), 0);
  });

  test('P7 freeze after capture rejects late publication without side effects',
      () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final runtime = _runtime(db);
    final input = _input(facts: [_factKey('LOAD-1', 'DEMAND')]);
    final node = _node(PowerProcessCode.pwr01, 'LOAD-1');
    final capture = await runtime.captureForCalculation(
      projectId: 'project',
      designRevisionId: 'rev-working',
      targetNodeKey: node,
      captureInput: () async => input,
    );
    final evidence = _evidence(node, 'eval-freeze-race', input);

    await db.customUpdate(
      "UPDATE project_design_revisions SET state = 'FROZEN', "
      'revision = revision + 1, frozen_at = ? WHERE id = ?',
      variables: [
        Variable<DateTime>(_now.add(const Duration(minutes: 2))),
        Variable.withString('rev-working'),
      ],
    );

    await expectLater(
      runtime.publishGuarded(
        capture: capture,
        evidence: evidence,
        operationId: 'op-freeze-race',
        commandFingerprint: sha256HexUtf8('op-freeze-race'),
        recaptureInput: () async => input,
      ),
      throwsA(
        isA<PowerRuntimeStorageException>().having(
          (error) => error.code,
          'code',
          'ELV4_RESULT_INPUT_CHANGED',
        ),
      ),
    );
    expect(await _count(db, 'power_evaluation_records'), 0);
    expect(await _count(db, 'power_evaluation_pointers'), 0);
    expect(await _count(db, 'power_operation_records'), 0);
  });

  test('P7 publication CAS observes consumed pointer generation', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final runtime = _runtime(db);
    final leaf = await _publish(
      runtime,
      node: _node(PowerProcessCode.pwr01, 'LOAD-1'),
      input: _input(facts: [_factKey('LOAD-1', 'DEMAND')]),
      evaluationId: 'eval-leaf',
      operationId: 'op-leaf',
    );
    final targetNode = _node(PowerProcessCode.pwr02, 'SOURCE-1');
    final targetInput = _input(
      facts: [_factKey('SOURCE-1', 'CAPACITY')],
      evaluations: [leaf],
    );
    final capture = await runtime.captureForCalculation(
      projectId: 'project',
      designRevisionId: 'rev-working',
      targetNodeKey: targetNode,
      captureInput: () async => targetInput,
    );

    await db.customUpdate(
      'UPDATE power_evaluation_pointers SET generation = generation + 2 '
      'WHERE logical_node_key_sha256 = ?',
      variables: [Variable.withString(leaf.evidence.nodeKey.sha256)],
    );

    await expectLater(
      runtime.publishGuarded(
        capture: capture,
        evidence: _evidence(targetNode, 'eval-target', targetInput),
        operationId: 'op-target',
        commandFingerprint: sha256HexUtf8('op-target'),
        recaptureInput: () async => targetInput,
      ),
      throwsA(
        isA<PowerRuntimeStorageException>().having(
          (error) => error.code,
          'code',
          'ELV4_RESULT_INPUT_CHANGED',
        ),
      ),
    );
    expect(
      await db.customSelect(
        "SELECT COUNT(*) AS c FROM power_evaluation_records "
        "WHERE evaluation_id = 'eval-target'",
      ).getSingle().then((row) => row.read<int>('c')),
      0,
    );
  });

  test('P7 committed calculate operation replays without republishing', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final runtime = _runtime(db);
    final input = _input(facts: [_factKey('LOAD-1', 'DEMAND')]);
    final node = _node(PowerProcessCode.pwr01, 'LOAD-1');
    final capture = await runtime.captureForCalculation(
      projectId: 'project',
      designRevisionId: 'rev-working',
      targetNodeKey: node,
      captureInput: () async => input,
    );
    final evidence = _evidence(node, 'eval-replay', input);
    final fingerprint = sha256HexUtf8('op-replay');

    final first = await runtime.publishGuarded(
      capture: capture,
      evidence: evidence,
      operationId: 'op-replay',
      commandFingerprint: fingerprint,
      recaptureInput: () async => input,
    );
    final replay = await runtime.publishGuarded(
      capture: capture,
      evidence: evidence,
      operationId: 'op-replay',
      commandFingerprint: fingerprint,
      recaptureInput: () async => input,
    );

    expect(first.replayed, isFalse);
    expect(replay.replayed, isTrue);
    expect(replay.generation, 1);
    expect(await _count(db, 'power_evaluation_records'), 1);
    expect(await _pointerGeneration(db, node), 1);
    expect(await _count(db, 'power_operation_records'), 1);
  });

  test('P7 frozen reads distinguish NOT_CAPTURED and captured-empty', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final runtime = _runtime(db);

    await _insertRevision(
      db,
      id: 'rev-legacy',
      code: 'R2',
      sequence: 2,
      state: 'FROZEN',
    );
    final legacy = await runtime.readRevision(
      projectId: 'project',
      designRevisionId: 'rev-legacy',
    );
    expect(legacy.kind, PowerRevisionReadKind.notCaptured);
    expect(legacy.reasonCode, 'ELV4_POWER_NOT_CAPTURED');
    expect(legacy.mutationAllowed, isFalse);

    const physicalSha =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    final powerSha = await runtime.captureCommittedPowerSectionForFreeze(
      projectId: 'project',
      designRevisionId: 'rev-working',
      expectedRevisionToken: 1,
      physicalSha256: physicalSha,
    );
    expect(powerSha, hasLength(64));
    expect(await _count(db, 'design_revision_snapshot_manifests'), 1);
    await db.customUpdate(
      "UPDATE project_design_revisions SET state = 'FROZEN', "
      'revision = revision + 1, frozen_at = ? WHERE id = ?',
      variables: [
        Variable<DateTime>(_now.add(const Duration(minutes: 3))),
        Variable.withString('rev-working'),
      ],
    );

    final captured = await runtime.readRevision(
      projectId: 'project',
      designRevisionId: 'rev-working',
    );
    expect(captured.kind, PowerRevisionReadKind.capturedEmpty);
    expect(captured.reasonCode, isNull);
    expect(captured.mutationAllowed, isFalse);
    expect(captured.capturedPayload!['pointers'], isEmpty);
  });

  test('P7 mutation rolls back when design token is not advanced', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final runtime = _runtime(db);
    await db.customStatement(
      'CREATE TABLE p7_fixture(id TEXT PRIMARY KEY, value TEXT NOT NULL)',
    );
    await db.customStatement(
      "INSERT INTO p7_fixture(id, value) VALUES ('x', 'old')",
    );

    await expectLater(
      runtime.mutateAndInvalidate(
        projectId: 'project',
        designRevisionId: 'rev-working',
        oldClosure: const [],
        applyMutation: () => db.customUpdate(
          "UPDATE p7_fixture SET value = 'new' WHERE id = 'x'",
        ),
        captureNewClosure: () async => const [],
      ),
      throwsA(
        isA<PowerRuntimeStorageException>().having(
          (error) => error.code,
          'code',
          'ELV4_DESIGN_TOKEN_NOT_ADVANCED',
        ),
      ),
    );
    final value = await db.customSelect(
      "SELECT value FROM p7_fixture WHERE id = 'x'",
    ).getSingle();
    expect(value.read<String>('value'), 'old');
  });
}

final class _Published {
  const _Published({required this.evidence, required this.receipt});

  final PowerEvaluationEvidence evidence;
  final PowerPublicationReceipt receipt;
}

DriftPowerPublicationRuntime _runtime(AppDatabase db) =>
    DriftPowerPublicationRuntime(
      db,
      originDeviceId: 'device-p7',
      now: () => _now,
    );

Future<_Published> _publish(
  DriftPowerPublicationRuntime runtime, {
  required PowerNodeKeyV2 node,
  required PowerConsumedInput input,
  required String evaluationId,
  required String operationId,
}) async {
  final capture = await runtime.captureForCalculation(
    projectId: 'project',
    designRevisionId: 'rev-working',
    targetNodeKey: node,
    captureInput: () async => input,
  );
  final evidence = _evidence(node, evaluationId, input);
  final receipt = await runtime.publishGuarded(
    capture: capture,
    evidence: evidence,
    operationId: operationId,
    commandFingerprint: sha256HexUtf8(operationId),
    recaptureInput: () async => input,
  );
  return _Published(evidence: evidence, receipt: receipt);
}

PowerEvaluationEvidence _evidence(
  PowerNodeKeyV2 node,
  String evaluationId,
  PowerConsumedInput input,
) =>
    PowerEvaluationEvidence(
      evaluationId: evaluationId,
      nodeKey: node,
      algorithmVersion: input.algorithmVersion,
      inputSchemaVersion: input.inputSchemaVersion,
      outputSchemaVersion: 'electra.elv4-p7-fixture-output.v1',
      numericPolicyVersion: input.numericPolicyVersion,
      inputFingerprint: input.inputFingerprint,
      status: PowerEvaluationStatus.pass,
      applicability: PowerEvaluationApplicability.applicable,
      inputs: {
        'dependencyKeys': input.dependencyKeys,
      },
      output: const {'ok': true},
      dependencies: [
        for (final dependency in input.evaluations)
          PowerNodeKeyV2.decode(dependency.logicalNodeKey),
      ],
    );

PowerConsumedInput _input({
  Iterable<PowerDependencyKey> facts = const [],
  Iterable<_Published> evaluations = const [],
}) =>
    PowerConsumedInput(
      algorithmVersion: 'elv4-p7-fixture-v1',
      inputSchemaVersion: 'electra.elv4-p7-fixture-input.v1',
      numericPolicyVersion: powerNumericPolicyVersion,
      facts: [
        for (final key in facts)
          PowerConsumedFact.present(
            key: key,
            valueSchema: 'electra.elv4-p7-fixture-fact.v1',
            value: {'entityId': key.entityId, 'purpose': key.purpose},
          ),
      ],
      evaluations: [
        for (final published in evaluations)
          PowerConsumedEvaluationRef(
            logicalNodeKey: published.evidence.nodeKey.encode(),
            evaluationId: published.evidence.evaluationId,
            inputFingerprint: published.evidence.inputFingerprint,
          ),
      ],
    );

PowerDependencyKey _factKey(String entityId, String purpose) =>
    PowerDependencyKey(
      projectId: 'project',
      revisionId: 'rev-working',
      kind: PowerDependencyKind.definition,
      entityId: entityId,
      purpose: purpose,
    );

PowerNodeKeyV2 _node(PowerProcessCode process, String subjectId) =>
    PowerNodeKeyV2(
      revisionId: 'rev-working',
      scenarioId: 'NORMAL',
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: 'SEG-1',
      processCode: process,
      subjectKind: 'FIXTURE',
      subjectId: subjectId,
    );

Future<String?> _pointerState(AppDatabase db, PowerNodeKeyV2 node) async {
  final row = await db.customSelect(
    'SELECT state FROM power_evaluation_pointers '
    'WHERE logical_node_key_sha256 = ?',
    variables: [Variable.withString(node.sha256)],
  ).getSingleOrNull();
  return row?.read<String>('state');
}

Future<int?> _pointerGeneration(AppDatabase db, PowerNodeKeyV2 node) async {
  final row = await db.customSelect(
    'SELECT generation FROM power_evaluation_pointers '
    'WHERE logical_node_key_sha256 = ?',
    variables: [Variable.withString(node.sha256)],
  ).getSingleOrNull();
  return row?.read<int>('generation');
}

Future<int> _count(AppDatabase db, String table) => db
    .customSelect('SELECT COUNT(*) AS c FROM $table')
    .getSingle()
    .then((row) => row.read<int>('c'));

final _now = DateTime.utc(2026, 10, 15, 12);

Future<void> _seedProject(AppDatabase db) async {
  await db.into(db.projects).insert(
        ProjectsCompanion.insert(
          id: 'project',
          name: 'ELV4 P7 runtime',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: _now,
          updatedAt: _now,
          originDeviceId: 'test',
        ),
      );
  await _insertRevision(
    db,
    id: 'rev-working',
    code: 'R1',
    sequence: 1,
    state: 'WORKING',
  );
}

Future<void> _insertRevision(
  AppDatabase db, {
  required String id,
  required String code,
  required int sequence,
  required String state,
}) =>
    db.into(db.projectDesignRevisions).insert(
          ProjectDesignRevisionsCompanion.insert(
            id: id,
            projectId: 'project',
            code: code,
            sequence: sequence,
            state: state,
            createdAt: _now,
            updatedAt: _now,
            originDeviceId: 'test',
          ),
        );
