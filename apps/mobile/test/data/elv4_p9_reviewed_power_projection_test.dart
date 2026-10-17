import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_canonical_projection_write_store.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/drift_reviewed_power_port_binding_coordinator.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';
import '../support/elv4_power_qualification_topology.dart';

void main() {
  test(
    'RM03 reviewed bind projects and invalidates exact closure in one UoW',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();

      const protocol = EngineeringProfileReference(id: 'POE', version: '1');
      final source = EngineeringPort(
        id: 'source-out',
        componentId: 'source',
        code: 'OUT',
        kind: EngineeringPortKind.dataPower,
        direction: PortDirection.output,
        capacity: 1,
        connector: 'RJ45',
        protocol: protocol,
        voltage: const PortVoltageDomain(
          currentKind: PortCurrentKind.dc,
          minimumV: 20,
          maximumV: 50,
        ),
        powerDirection: PortDirection.output,
      );
      final consumer = EngineeringPort(
        id: 'consumer-in',
        componentId: 'consumer',
        code: 'IN',
        kind: EngineeringPortKind.dataPower,
        direction: PortDirection.input,
        capacity: 1,
        connector: 'RJ45',
        protocol: protocol,
        voltage: const PortVoltageDomain(
          currentKind: PortCurrentKind.dc,
          minimumV: 10,
          maximumV: 60,
        ),
        powerDirection: PortDirection.input,
      );
      await builder.addComponent('source', ports: [source]);
      await builder.addComponent('consumer', xMm: 1500, ports: [consumer]);
      await builder.connectDataPower(
        familyCode: 'CCTV',
        connectionId: 'source-consumer',
        fromPortId: source.id,
        toPortId: consumer.id,
      );

      final runtime = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'rm03-test',
        now: () => builder.instant,
      );
      final affectedFact = PowerDependencyKey(
        projectId: builder.projectId,
        revisionId: builder.revisionId,
        kind: PowerDependencyKind.definition,
        entityId: 'PORT-${source.id}',
        purpose: 'INPUT',
      );
      final unrelatedFact = PowerDependencyKey(
        projectId: builder.projectId,
        revisionId: builder.revisionId,
        kind: PowerDependencyKind.definition,
        entityId: 'UNRELATED',
        purpose: 'INPUT',
      );
      final affectedNode = _node(builder.revisionId, 'affected');
      final unrelatedNode = _node(builder.revisionId, 'unrelated');
      await _publish(runtime, builder, affectedNode, affectedFact, 'eval-a');
      await _publish(runtime, builder, unrelatedNode, unrelatedFact, 'eval-b');

      final candidate = EngineeringPort.fromMap({
        ...source.toMap(),
        'voltage':
            const PortVoltageDomain(
              currentKind: PortCurrentKind.dc,
              minimumV: 10,
              maximumV: 60,
            ).toMap(),
      });
      final binding = builder.portBinding(source.id, PowerPortRole.source);
      final store = DriftPowerCanonicalProjectionWriteStore(
        db,
        originDeviceId: 'rm03-test',
        now: () => builder.instant,
      );
      final review = await store.preview(
        projectId: builder.projectId,
        designRevisionId: builder.revisionId,
        candidate: candidate,
        binding: binding,
      );
      expect(review.affectedConnectionIds, ['source-consumer']);
      expect(review.reviewedImpactFingerprint, hasLength(64));

      final coordinator = DriftReviewedPowerPortBindingCoordinator(
        db,
        originDeviceId: 'rm03-test',
        now: () => builder.instant,
      );
      final command = BindPowerPortCommand(
        operationId: 'reviewed-bind-source',
        projectId: builder.projectId,
        designRevisionId: builder.revisionId,
        expectedRevision: 1,
        // Deliberately wrong caller input. The coordinator must ignore it and
        // replace it with the exact server-reviewed old/new closure.
        changedDependencies: [unrelatedFact],
        bindingId: 'binding-source-out',
        binding: binding,
      );
      final receipt = await coordinator.execute(
        command: command,
        candidate: candidate,
        review: review,
      );
      expect(receipt.previousRevision, 1);
      expect(receipt.currentRevision, 2);
      expect(receipt.replayed, isFalse);
      expect(
        receipt.invalidatedNodeKeys.map((value) => value.encode()),
        contains(affectedNode.encode()),
      );
      expect(
        receipt.invalidatedNodeKeys.map((value) => value.encode()),
        isNot(contains(unrelatedNode.encode())),
      );
      expect(await _pointerState(db, affectedNode), 'STALE');
      expect(await _pointerState(db, unrelatedNode), 'CURRENT');

      final stored =
          await db
              .customSelect(
                'SELECT revision, payload_json FROM engineering_port_instances '
                'WHERE id = ?',
                variables: [Variable.withString(source.id)],
              )
              .getSingle();
      expect(stored.read<int>('revision'), 2);
      expect(
        EngineeringPort.fromMap(
          (jsonDecode(stored.read<String>('payload_json')) as Map)
              .cast<String, dynamic>(),
        ).voltage!.minimumV,
        10,
      );
      expect(
        await db
            .customSelect(
              'SELECT COUNT(*) AS c FROM power_port_bindings '
              'WHERE design_revision_id = ? AND id = ? AND deleted_at IS NULL',
              variables: [
                Variable.withString(builder.revisionId),
                Variable.withString('binding-source-out'),
              ],
            )
            .map((row) => row.read<int>('c'))
            .getSingle(),
        1,
      );

      final replay = await coordinator.execute(
        command: command,
        candidate: candidate,
        review: review,
      );
      expect(replay.replayed, isTrue);
      expect(replay.currentRevision, 2);
      final revision = await (db.select(db.projectDesignRevisions)).getSingle();
      expect(revision.revision, 2);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}

PowerNodeKeyV2 _node(String revisionId, String subjectId) => PowerNodeKeyV2(
  revisionId: revisionId,
  scenarioId: 'NORMAL',
  scopeKind: PowerEvaluationScopeKind.segment,
  scopeId: 'SEGMENT-1',
  processCode: PowerProcessCode.pwr01,
  subjectKind: 'PORT',
  subjectId: subjectId,
);

Future<void> _publish(
  DriftPowerPublicationRuntime runtime,
  Elv4QualificationBuilder builder,
  PowerNodeKeyV2 node,
  PowerDependencyKey fact,
  String evaluationId,
) async {
  final input = PowerConsumedInput(
    algorithmVersion: 'rm03-test-v1',
    inputSchemaVersion: 'rm03-input-v1',
    numericPolicyVersion: powerNumericPolicyVersion,
    facts: [
      PowerConsumedFact.present(
        key: fact,
        valueSchema: 'rm03-fact-v1',
        value: const {'value': 1},
      ),
    ],
  );
  final capture = await runtime.captureForCalculation(
    projectId: builder.projectId,
    designRevisionId: builder.revisionId,
    targetNodeKey: node,
    captureInput: () async => input,
  );
  final evidence = PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: node,
    algorithmVersion: 'rm03-test-v1',
    inputSchemaVersion: 'rm03-input-v1',
    outputSchemaVersion: 'rm03-output-v1',
    inputFingerprint: input.inputFingerprint,
    status: PowerEvaluationStatus.pass,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: const {'value': 1},
    output: const {'value': 1},
  );
  await runtime.publishGuarded(
    capture: capture,
    evidence: evidence,
    operationId: 'publish-$evaluationId',
    commandFingerprint: sha256HexUtf8('publish-$evaluationId'),
    recaptureInput: () async => input,
  );
}

Future<String> _pointerState(AppDatabase db, PowerNodeKeyV2 node) async {
  final row =
      await db
          .customSelect(
            'SELECT state FROM power_evaluation_pointers '
            'WHERE logical_node_key_sha256 = ?',
            variables: [Variable.withString(node.sha256)],
          )
          .getSingle();
  return row.read<String>('state');
}
