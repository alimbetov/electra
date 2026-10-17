import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv4_wire_command_dispatcher.dart';
import 'package:electra_mobile/application/elv4_wire_power_payload.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv4_wire_aggregate_service.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';

void main() {
  test(
    'aggregate wire load/transfer commands replace atomically and replay',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();

      const protocol = EngineeringProfileReference(id: 'POWER', version: '1');
      EngineeringPort port(String id, PortDirection direction) =>
          EngineeringPort(
            id: id,
            componentId: 'node',
            code: id.toUpperCase().replaceAll('-', '_'),
            kind: EngineeringPortKind.dataPower,
            direction: direction,
            capacity: 1,
            connector: 'WIRE',
            protocol: protocol,
            voltage: const PortVoltageDomain(
              currentKind: PortCurrentKind.dc,
              minimumV: 20,
              maximumV: 60,
            ),
            powerDirection: direction,
          );
      final input1 = port('in-1', PortDirection.input);
      final input2 = port('in-2', PortDirection.input);
      final output1 = port('out-1', PortDirection.output);
      final output2 = port('out-2', PortDirection.output);
      await builder.addComponent(
        'node',
        ports: [input1, input2, output1, output2],
      );

      final runtime = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'wire-aggregate-test',
        now: () => builder.instant,
      );
      final changedFact = PowerDependencyKey(
        projectId: builder.projectId,
        revisionId: builder.revisionId,
        kind: PowerDependencyKind.definition,
        entityId: 'node-load-profile',
        purpose: 'INPUT',
      );
      final nodeKey = PowerNodeKeyV2(
        revisionId: builder.revisionId,
        scenarioId: 'NORMAL',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'SEGMENT-1',
        processCode: PowerProcessCode.pwr01,
        subjectKind: 'COMPONENT',
        subjectId: 'node',
      );
      await _publish(runtime, builder, nodeKey, changedFact);

      final service = DriftElv4WireAggregateService(
        db,
        originDeviceId: 'wire-aggregate-test',
        now: () => builder.instant,
      );
      final load1 = Elv4WireLoadEntry(
        loadId: 'load-1',
        inputPortId: input1.id,
        stateCode: 'ON',
        accountingKind: 'CONSUMER_INPUT',
        originId: 'physical-origin-1',
        demand: DcConstantPowerDemand(PowerRational.fromWireDecimal('10')),
      );
      final load2 = Elv4WireLoadEntry(
        loadId: 'load-2',
        inputPortId: input2.id,
        stateCode: 'ON',
        accountingKind: 'TRANSFER_IDLE',
        originId: 'physical-origin-2',
        demand: DcConstantPowerDemand(PowerRational.fromWireDecimal('2')),
      );
      final firstLoadEnvelope = _envelope(
        builder,
        operation: 'SET_POWER_LOAD_PROFILE',
        commandId: 'wire-load-1',
        expectedRevision: 1,
        payload: {
          'componentId': 'node',
          'loads': [load1.toMap(), load2.toMap()],
        },
      );
      final firstLoad = await service.replaceLoadProfile(
        envelope: firstLoadEnvelope,
        changedDependencyRefs: [changedFact.encode()],
        componentId: 'node',
        loads: [load1, load2],
      );
      expect(firstLoad.previousRevision, 1);
      expect(firstLoad.currentRevision, 2);
      expect(firstLoad.replayed, isFalse);
      expect(await _pointerState(db, nodeKey), 'STALE');
      expect(await _revisionToken(db), 2);

      final loadRows = await db
          .customSelect(
            'SELECT id, origin_id FROM power_load_bindings '
            'WHERE design_revision_id = ? AND deleted_at IS NULL ORDER BY id',
            variables: [Variable.withString(builder.revisionId)],
          )
          .get();
      expect(loadRows.map((row) => row.read<String>('id')).toList(), [
        'load-1',
        'load-2',
      ]);
      expect(loadRows[0].read<String>('origin_id'), 'physical-origin-1');
      expect(loadRows[1].read<String>('origin_id'), 'physical-origin-2');

      final loadReplay = await service.replaceLoadProfile(
        envelope: firstLoadEnvelope,
        changedDependencyRefs: [changedFact.encode()],
        componentId: 'node',
        loads: [load1, load2],
      );
      expect(loadReplay.replayed, isTrue);
      expect(await _revisionToken(db), 2);

      final replacementLoad = Elv4WireLoadEntry(
        loadId: 'load-2',
        inputPortId: input2.id,
        stateCode: 'ON',
        accountingKind: 'TRANSFER_IDLE',
        originId: 'physical-origin-2b',
        demand: DcConstantPowerDemand(PowerRational.fromWireDecimal('3')),
      );
      await service.replaceLoadProfile(
        envelope: _envelope(
          builder,
          operation: 'SET_POWER_LOAD_PROFILE',
          commandId: 'wire-load-2',
          expectedRevision: 2,
          payload: {
            'componentId': 'node',
            'loads': [replacementLoad.toMap()],
          },
        ),
        changedDependencyRefs: const [],
        componentId: 'node',
        loads: [replacementLoad],
      );
      expect(await _revisionToken(db), 3);
      final activeAfterReplacement = await db
          .customSelect(
            'SELECT id, origin_id FROM power_load_bindings '
            'WHERE design_revision_id = ? AND deleted_at IS NULL ORDER BY id',
            variables: [Variable.withString(builder.revisionId)],
          )
          .get();
      expect(activeAfterReplacement, hasLength(1));
      expect(activeAfterReplacement.single.read<String>('id'), 'load-2');
      expect(
        activeAfterReplacement.single.read<String>('origin_id'),
        'physical-origin-2b',
      );

      await service.replaceLoadProfile(
        envelope: _envelope(
          builder,
          operation: 'SET_POWER_LOAD_PROFILE',
          commandId: 'wire-load-empty',
          expectedRevision: 3,
          payload: const {'componentId': 'node', 'loads': <Object?>[]},
        ),
        changedDependencyRefs: const [],
        componentId: 'node',
        loads: const [],
      );
      expect(await _activeCount(db, 'power_load_bindings'), 0);
      expect(await _revisionToken(db), 4);

      final transfer = Elv4WireTransferEntry(
        id: 'selector-1',
        componentId: 'node',
        inputPortId: input1.id,
        outputPortIds: [output1.id, output2.id],
        kind: 'SELECTOR',
        activeStates: const ['ON'],
        loss: PowerLossDefinition(
          efficiency: PowerRational.one,
          idleW: PowerRational.zero,
          idleAccounting: PowerIdleAccounting.includesIdle,
        ),
        capacityGroupIds: const [],
      );
      final transferEnvelope = _envelope(
        builder,
        operation: 'REPLACE_POWER_TRANSFERS',
        commandId: 'wire-transfer-1',
        expectedRevision: 4,
        payload: {
          'componentId': 'node',
          'transfers': [transfer.toMap()],
        },
      );
      final transferReceipt = await service.replaceTransfers(
        envelope: transferEnvelope,
        changedDependencyRefs: const [],
        componentId: 'node',
        transfers: [transfer],
      );
      expect(transferReceipt.currentRevision, 5);
      final transferRow = await db
          .customSelect(
            'SELECT transfer_kind, payload_json FROM power_transfer_bindings '
            'WHERE design_revision_id = ? AND id = ? AND deleted_at IS NULL',
            variables: [
              Variable.withString(builder.revisionId),
              Variable.withString('selector-1'),
            ],
          )
          .getSingle();
      expect(transferRow.read<String>('transfer_kind'), 'SELECTOR');
      final storedPayload = (jsonDecode(
        transferRow.read<String>('payload_json'),
      ) as Map).cast<String, Object?>();
      expect(storedPayload['capacityGroupIds'], isEmpty);
      expect(await _activeCount(db, 'power_transfer_outputs'), 2);

      final transferReplay = await service.replaceTransfers(
        envelope: transferEnvelope,
        changedDependencyRefs: const [],
        componentId: 'node',
        transfers: [transfer],
      );
      expect(transferReplay.replayed, isTrue);
      expect(await _revisionToken(db), 5);

      await service.replaceTransfers(
        envelope: _envelope(
          builder,
          operation: 'REPLACE_POWER_TRANSFERS',
          commandId: 'wire-transfer-empty',
          expectedRevision: 5,
          payload: const {'componentId': 'node', 'transfers': <Object?>[]},
        ),
        changedDependencyRefs: const [],
        componentId: 'node',
        transfers: const [],
      );
      expect(await _activeCount(db, 'power_transfer_bindings'), 0);
      expect(await _activeCount(db, 'power_transfer_outputs'), 0);
      expect(await _revisionToken(db), 6);

      final ledger = await db
          .customSelect(
            'SELECT command_type, payload_schema FROM power_operation_records '
            "WHERE command_type IN ('SET_POWER_LOAD_PROFILE', 'REPLACE_POWER_TRANSFERS') "
            'ORDER BY operation_id',
          )
          .get();
      expect(ledger, hasLength(5));
      expect(
        ledger.every(
          (row) => row
              .read<String>('payload_schema')
              .startsWith('electra.elv4-command.v1/'),
        ),
        isTrue,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}

Elv4WireCommandEnvelope _envelope(
  Elv4QualificationBuilder builder, {
  required String operation,
  required String commandId,
  required int expectedRevision,
  required Map<String, Object?> payload,
}) => Elv4WireCommandEnvelope(
  schema: Elv4WireCommandEnvelope.powerCommandSchema,
  operation: operation,
  payloadSchemaVersion: 1,
  projectId: builder.projectId,
  designRevisionId: builder.revisionId,
  commandId: commandId,
  expectedDesignRowRevision: expectedRevision,
  expectedRows: const {},
  reviewedImpactFingerprint: sha256HexUtf8('review-$commandId'),
  payload: payload,
);

Future<void> _publish(
  DriftPowerPublicationRuntime runtime,
  Elv4QualificationBuilder builder,
  PowerNodeKeyV2 node,
  PowerDependencyKey fact,
) async {
  final input = PowerConsumedInput(
    algorithmVersion: 'wire-test-v1',
    inputSchemaVersion: 'wire-input-v1',
    numericPolicyVersion: powerNumericPolicyVersion,
    facts: [
      PowerConsumedFact.present(
        key: fact,
        valueSchema: 'wire-fact-v1',
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
  await runtime.publishGuarded(
    capture: capture,
    evidence: PowerEvaluationEvidence(
      evaluationId: 'wire-evaluation',
      nodeKey: node,
      algorithmVersion: 'wire-test-v1',
      inputSchemaVersion: 'wire-input-v1',
      outputSchemaVersion: 'wire-output-v1',
      inputFingerprint: input.inputFingerprint,
      status: PowerEvaluationStatus.pass,
      applicability: PowerEvaluationApplicability.applicable,
      inputs: const {'value': 1},
      output: const {'value': 1},
    ),
    operationId: 'wire-publish',
    commandFingerprint: sha256HexUtf8('wire-publish'),
    recaptureInput: () async => input,
  );
}

Future<String> _pointerState(AppDatabase db, PowerNodeKeyV2 node) async =>
    (await db
            .customSelect(
              'SELECT state FROM power_evaluation_pointers '
              'WHERE logical_node_key_sha256 = ?',
              variables: [Variable.withString(node.sha256)],
            )
            .getSingle())
        .read<String>('state');

Future<int> _revisionToken(AppDatabase db) async =>
    (await db.select(db.projectDesignRevisions).getSingle()).revision;

Future<int> _activeCount(AppDatabase db, String table) async =>
    (await db
            .customSelect(
              table == 'power_transfer_outputs'
                  ? 'SELECT COUNT(*) AS c FROM power_transfer_outputs'
                  : 'SELECT COUNT(*) AS c FROM $table WHERE deleted_at IS NULL',
            )
            .getSingle())
        .read<int>('c');
