import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_batch_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P7 batch publishes dependent PWR-01 and PWR-02 atomically', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);
    final batch = _batchRuntime(db);

    final leafNode = _node(PowerProcessCode.pwr01, 'LOAD-1');
    final capabilityNode = _node(PowerProcessCode.pwr02, 'SOURCE-1');
    final sourceFact = _factKey('SOURCE-1', 'DEMAND');
    final leafInput = _input([sourceFact]);
    final leafPlan = PowerBatchTargetPlan(
      nodeKey: leafNode,
      evaluationId: 'eval-leaf-1',
      consumedInput: leafInput,
    );
    final capabilityInput = _input(
      [_factKey('SOURCE-1', 'CAPACITY')],
      evaluations: [
        PowerConsumedEvaluationRef(
          logicalNodeKey: leafNode.encode(),
          evaluationId: leafPlan.evaluationId,
          inputFingerprint: leafInput.inputFingerprint,
        ),
      ],
    );
    final capabilityPlan = PowerBatchTargetPlan(
      nodeKey: capabilityNode,
      evaluationId: 'eval-capability-1',
      consumedInput: capabilityInput,
    );

    final capture = await batch.captureBatch(
      projectId: 'project',
      designRevisionId: 'rev-working',
      capturePlans: () async => [leafPlan, capabilityPlan],
    );
    final receipt = await batch.publishBatchGuarded(
      capture: capture,
      evaluations: [_evidence(leafPlan), _evidence(capabilityPlan)],
      operationId: 'op-batch-1',
      commandFingerprint: sha256HexUtf8('op-batch-1'),
      recapturePlans: () async => [capabilityPlan, leafPlan],
    );

    expect(receipt.items, hasLength(2));
    expect(await _pointerState(db, leafNode), 'CURRENT');
    expect(await _pointerState(db, capabilityNode), 'CURRENT');
    expect(await _pointerGeneration(db, leafNode), 1);
    expect(await _pointerGeneration(db, capabilityNode), 1);
    expect(await _count(db, 'power_evaluation_records'), 2);
    expect(await _count(db, 'power_operation_records'), 1);

    final dependencyEdge = await db
        .customSelect(
          'SELECT COUNT(*) AS c FROM power_dependency_index_records '
          "WHERE dependency_ref_type = 'EVALUATION' "
          'AND dependency_ref_sha256 = ? AND logical_node_key_sha256 = ?',
          variables: [
            Variable.withString(sha256HexUtf8(leafNode.encode())),
            Variable.withString(capabilityNode.sha256),
          ],
        )
        .getSingle();
    expect(dependencyEdge.read<int>('c'), 1);
  });

  test(
    'P7 batch CAS failure rolls back every evaluation and pointer publish',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final batch = _batchRuntime(db);
      final single = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'device-p7',
        now: () => _now,
      );

      final leafNode = _node(PowerProcessCode.pwr01, 'LOAD-1');
      final capabilityNode = _node(PowerProcessCode.pwr02, 'SOURCE-1');
      final sourceFact = _factKey('SOURCE-1', 'DEMAND');
      final firstPlans = _plans(
        leafNode: leafNode,
        capabilityNode: capabilityNode,
        sourceFact: sourceFact,
        suffix: '1',
      );
      final firstCapture = await batch.captureBatch(
        projectId: 'project',
        designRevisionId: 'rev-working',
        capturePlans: () async => firstPlans,
      );
      await batch.publishBatchGuarded(
        capture: firstCapture,
        evaluations: firstPlans.map(_evidence),
        operationId: 'op-first',
        commandFingerprint: sha256HexUtf8('op-first'),
        recapturePlans: () async => firstPlans,
      );

      await single.mutateAndInvalidate(
        projectId: 'project',
        designRevisionId: 'rev-working',
        oldClosure: [sourceFact],
        applyMutation: () => db.customUpdate(
          'UPDATE project_design_revisions SET revision = revision + 1 '
          'WHERE id = ?',
          variables: [Variable.withString('rev-working')],
        ),
        captureNewClosure: () async => [sourceFact],
      );
      expect(await _pointerState(db, leafNode), 'STALE');
      expect(await _pointerState(db, capabilityNode), 'STALE');

      final secondPlans = _plans(
        leafNode: leafNode,
        capabilityNode: capabilityNode,
        sourceFact: sourceFact,
        suffix: '2',
      );
      final secondCapture = await batch.captureBatch(
        projectId: 'project',
        designRevisionId: 'rev-working',
        capturePlans: () async => secondPlans,
      );

      await db.customUpdate(
        'UPDATE power_evaluation_pointers SET generation = generation + 1 '
        'WHERE logical_node_key_sha256 = ?',
        variables: [Variable.withString(capabilityNode.sha256)],
      );

      await expectLater(
        batch.publishBatchGuarded(
          capture: secondCapture,
          evaluations: secondPlans.map(_evidence),
          operationId: 'op-second',
          commandFingerprint: sha256HexUtf8('op-second'),
          recapturePlans: () async => secondPlans,
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_RESULT_INPUT_CHANGED',
          ),
        ),
      );

      expect(await _pointerState(db, leafNode), 'STALE');
      expect(await _pointerState(db, capabilityNode), 'STALE');
      final newEvaluations = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM power_evaluation_records "
            "WHERE evaluation_id IN ('eval-leaf-2','eval-capability-2')",
          )
          .getSingle();
      expect(newEvaluations.read<int>('c'), 0);
      final secondLedger = await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM power_operation_records "
            "WHERE operation_id = 'op-second'",
          )
          .getSingle();
      expect(secondLedger.read<int>('c'), 0);
    },
  );

  test(
    'P7 batch rejects an internal evaluation dependency cycle at capture',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seed(db);
      final batch = _batchRuntime(db);
      final a = _node(PowerProcessCode.pwr01, 'A');
      final b = _node(PowerProcessCode.pwr02, 'B');
      final bBase = _input([_factKey('B', 'FACT')]);
      final aInput = _input(
        [_factKey('A', 'FACT')],
        evaluations: [
          PowerConsumedEvaluationRef(
            logicalNodeKey: b.encode(),
            evaluationId: 'eval-b',
            inputFingerprint: bBase.inputFingerprint,
          ),
        ],
      );
      final bInput = _input(
        [_factKey('B', 'FACT')],
        evaluations: [
          PowerConsumedEvaluationRef(
            logicalNodeKey: a.encode(),
            evaluationId: 'eval-a',
            inputFingerprint: aInput.inputFingerprint,
          ),
        ],
      );
      final aPlan = PowerBatchTargetPlan(
        nodeKey: a,
        evaluationId: 'eval-a',
        consumedInput: PowerConsumedInput(
          algorithmVersion: aInput.algorithmVersion,
          inputSchemaVersion: aInput.inputSchemaVersion,
          numericPolicyVersion: aInput.numericPolicyVersion,
          facts: aInput.facts,
          evaluations: [
            PowerConsumedEvaluationRef(
              logicalNodeKey: b.encode(),
              evaluationId: 'eval-b',
              inputFingerprint: bInput.inputFingerprint,
            ),
          ],
        ),
      );
      final bPlan = PowerBatchTargetPlan(
        nodeKey: b,
        evaluationId: 'eval-b',
        consumedInput: bInput,
      );

      await expectLater(
        batch.captureBatch(
          projectId: 'project',
          designRevisionId: 'rev-working',
          capturePlans: () async => [aPlan, bPlan],
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_DEPENDENCY_CYCLE',
          ),
        ),
      );
    },
  );
}

List<PowerBatchTargetPlan> _plans({
  required PowerNodeKeyV2 leafNode,
  required PowerNodeKeyV2 capabilityNode,
  required PowerDependencyKey sourceFact,
  required String suffix,
}) {
  final leafInput = _input([sourceFact]);
  final leaf = PowerBatchTargetPlan(
    nodeKey: leafNode,
    evaluationId: 'eval-leaf-$suffix',
    consumedInput: leafInput,
  );
  final capabilityInput = _input(
    [_factKey('SOURCE-1', 'CAPACITY')],
    evaluations: [
      PowerConsumedEvaluationRef(
        logicalNodeKey: leafNode.encode(),
        evaluationId: leaf.evaluationId,
        inputFingerprint: leafInput.inputFingerprint,
      ),
    ],
  );
  return [
    leaf,
    PowerBatchTargetPlan(
      nodeKey: capabilityNode,
      evaluationId: 'eval-capability-$suffix',
      consumedInput: capabilityInput,
    ),
  ];
}

PowerEvaluationEvidence _evidence(PowerBatchTargetPlan plan) =>
    PowerEvaluationEvidence(
      evaluationId: plan.evaluationId,
      nodeKey: plan.nodeKey,
      algorithmVersion: plan.consumedInput.algorithmVersion,
      inputSchemaVersion: plan.consumedInput.inputSchemaVersion,
      outputSchemaVersion: 'electra.elv4-p7-batch-output.v1',
      numericPolicyVersion: plan.consumedInput.numericPolicyVersion,
      inputFingerprint: plan.consumedInput.inputFingerprint,
      status: PowerEvaluationStatus.pass,
      applicability: PowerEvaluationApplicability.applicable,
      inputs: {'dependencyKeys': plan.consumedInput.dependencyKeys},
      output: const {'ok': true},
      dependencies: [
        for (final ref in plan.consumedInput.evaluations)
          PowerNodeKeyV2.decode(ref.logicalNodeKey),
      ],
    );

PowerConsumedInput _input(
  Iterable<PowerDependencyKey> factKeys, {
  Iterable<PowerConsumedEvaluationRef> evaluations = const [],
}) => PowerConsumedInput(
  algorithmVersion: 'elv4-p7-batch-fixture-v1',
  inputSchemaVersion: 'electra.elv4-p7-batch-input.v1',
  numericPolicyVersion: powerNumericPolicyVersion,
  facts: [
    for (final key in factKeys)
      PowerConsumedFact.present(
        key: key,
        valueSchema: 'electra.elv4-p7-batch-fact.v1',
        value: {'entityId': key.entityId, 'purpose': key.purpose},
      ),
  ],
  evaluations: evaluations,
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

DriftPowerBatchPublicationRuntime _batchRuntime(AppDatabase db) =>
    DriftPowerBatchPublicationRuntime(
      db,
      originDeviceId: 'device-p7',
      now: () => _now,
    );

Future<String?> _pointerState(AppDatabase db, PowerNodeKeyV2 node) async {
  final row = await db
      .customSelect(
        'SELECT state FROM power_evaluation_pointers '
        'WHERE logical_node_key_sha256 = ?',
        variables: [Variable.withString(node.sha256)],
      )
      .getSingleOrNull();
  return row?.read<String>('state');
}

Future<int?> _pointerGeneration(AppDatabase db, PowerNodeKeyV2 node) async {
  final row = await db
      .customSelect(
        'SELECT generation FROM power_evaluation_pointers '
        'WHERE logical_node_key_sha256 = ?',
        variables: [Variable.withString(node.sha256)],
      )
      .getSingleOrNull();
  return row?.read<int>('generation');
}

Future<int> _count(AppDatabase db, String table) => db
    .customSelect('SELECT COUNT(*) AS c FROM $table')
    .getSingle()
    .then((row) => row.read<int>('c'));

final _now = DateTime.utc(2026, 10, 15, 13);

Future<void> _seed(AppDatabase db) async {
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project',
          name: 'ELV4 P7 batch',
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
          id: 'rev-working',
          projectId: 'project',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          createdAt: _now,
          updatedAt: _now,
          originDeviceId: 'test',
        ),
      );
}
