import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/application/power_mutation_command.dart';
import 'package:electra_mobile/application/power_workspace_state.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_command_service.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/drift_power_snapshot_facts.dart';
import 'package:electra_mobile/data/repositories/drift_power_workspace_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';

void main() {
  test('nonempty R1 facts survive R2 materialization, operational changes and reopen', () async {
    final dir = await Directory.systemTemp.createTemp('elv4-snapshot-facts-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/state.sqlite');
    var db = AppDatabase(NativeDatabase(file));
    final b = Elv4QualificationBuilder(db);
    await b.createStructuralBaseline();
    await b.addComponent(
      'load',
      ports: [
        b.powerPort('load', 'IN'),
        b.powerPort('load', 'OUT', direction: PortDirection.output),
      ],
    );
    var token = (await b.bindComponent('load', [
      PowerComponentCapability.consumer,
    ], expectedRevision: 1)).currentRevision;
    token = (await b.bindPort(
      'load-IN',
      PowerPortRole.consumer,
      expectedRevision: token,
    )).currentRevision;
    token = (await b.power.execute(
      SetPowerLoadCommand(
        operationId: 'load',
        projectId: b.projectId,
        designRevisionId: b.revisionId,
        expectedRevision: token,
        changedDependencies: [],
        contribution: PowerOwnLoadContribution(
          id: 'LOAD',
          componentId: 'load',
          inputPortId: 'load-IN',
          accountingKind: PowerAccountingKind.consumerInput,
          stateCode: 'NORMAL',
          demand: DcConstantPowerDemand(PowerRational.integer(12)),
        ),
      ),
    )).currentRevision;
    token = (await b.power.execute(
      ReplacePowerScenarioCommand(
        operationId: 'scenario',
        projectId: b.projectId,
        designRevisionId: b.revisionId,
        expectedRevision: token,
        changedDependencies: [],
        scenario: PowerOperatingScenario(
          scenarioId: 'NORMAL',
          role: PowerScenarioRole.normal,
          rowRevision: 1,
          segments: [
            PowerScenarioSegment(
              segmentId: 'STEADY',
              ordinal: 1,
              componentStates: const {'load': PowerDeviceState.normal},
            ),
          ],
        ),
      ),
    )).currentRevision;
    token = (await b.power.execute(
      ReplacePowerCapacityGroupCommand(
        operationId: 'group',
        projectId: b.projectId,
        designRevisionId: b.revisionId,
        expectedRevision: token,
        changedDependencies: [],
        group: PowerCapacityGroup(
          id: 'GROUP',
          ownerComponentId: 'load',
          memberOutputPortIds: ['load-OUT'],
          limits: [
            PowerCapacityLimit(
              dimension: PowerCapacityDimension.watt,
              limit: PowerRational.integer(100),
            ),
          ],
          applicabilityStateCodes: ['NORMAL'],
        ),
      ),
    )).currentRevision;
    final runtime = DriftPowerPublicationRuntime(db, originDeviceId: 'test');
    final calculated = buildPowerDemandEvidence(
      evaluationId: 'load-eval',
      revisionId: b.revisionId,
      scenarioId: 'NORMAL',
      segmentId: 'STEADY',
      subjectKind: 'COMPONENT',
      subjectId: 'load',
      demand: aggregatePowerDemand([
        PowerDemandContribution(
          originId: 'LOAD',
          componentId: 'load',
          inputPortId: 'load-IN',
          stateCode: 'NORMAL',
          demand: DcConstantPowerDemand(PowerRational.integer(12)),
        ),
      ]),
    );
    final input = PowerConsumedInput(
      algorithmVersion: calculated.algorithmVersion,
      inputSchemaVersion: calculated.inputSchemaVersion,
      numericPolicyVersion: calculated.numericPolicyVersion,
      facts: [
        PowerConsumedFact.present(
          key: b.dependency('LOAD'),
          valueSchema: 'test-load.v1',
          value: calculated.inputs,
        ),
      ],
      evaluations: [],
    );
    final capture = await runtime.captureForCalculation(
      projectId: b.projectId,
      designRevisionId: b.revisionId,
      targetNodeKey: calculated.nodeKey,
      captureInput: () async => input,
    );
    await runtime.publishGuarded(
      capture: capture,
      operationId: 'calculate',
      commandFingerprint: sha256HexUtf8('calculate'),
      recaptureInput: () async => input,
      evidence: PowerEvaluationEvidence(
        evaluationId: calculated.evaluationId,
        nodeKey: calculated.nodeKey,
        algorithmVersion: calculated.algorithmVersion,
        inputSchemaVersion: calculated.inputSchemaVersion,
        outputSchemaVersion: calculated.outputSchemaVersion,
        numericPolicyVersion: calculated.numericPolicyVersion,
        inputFingerprint: input.inputFingerprint,
        status: calculated.status,
        applicability: calculated.applicability,
        inputs: calculated.inputs,
        output: calculated.output,
        arithmeticSteps: calculated.arithmeticSteps,
        findings: calculated.findings,
      ),
    );
    final freeze = await b.revisions.freeze(
      FreezeProjectDesignRevisionCommand(
        commandId: 'freeze',
        projectId: b.projectId,
        designRevisionId: b.revisionId,
        expectedRevision: token,
      ),
    );
    expect(freeze, isA<ElvCommandSuccess<ProjectDesignRevision>>());
    final before = await runtime.readRevision(
      projectId: b.projectId,
      designRevisionId: b.revisionId,
    );
    expect(before.kind, PowerRevisionReadKind.captured);
    expect(
      before.capturedPayload!['schema'],
      'electra.elv4-power-freeze-section.v2',
    );
    expect(
      capturedPowerRows(before.capturedPayload, 'power_port_bindings'),
      hasLength(1),
    );
    expect(
      capturedPowerRows(before.capturedPayload, 'evaluation_records'),
      hasLength(1),
    );
    final state = PowerWorkspaceState(
      context: PowerWorkspaceReadContext(
        projectId: b.projectId,
        designRevisionId: b.revisionId,
        lifecycleState: 'FROZEN',
        scenarioId: 'NORMAL',
        segmentId: 'STEADY',
        generation: 1,
      ),
      cards: PowerWorkspaceCardCode.values,
      scope: PowerWorkspaceScope.floor(b.floorId),
    );
    final original = await DriftPowerWorkspaceRepository(
      db,
      originDeviceId: 'test',
    ).load(state);
    final originalMetrics = [
      for (final card in original.cards.values)
        for (final m in card.metrics) '${m.key}:${m.value}',
    ];
    expect(originalMetrics, contains(contains('12')));
    final next = await b.revisions.createNext(
      CreateNextWorkingDesignRevisionCommand(
        commandId: 'next',
        projectId: b.projectId,
        basedOnRevisionId: b.revisionId,
        newRevisionId: 'R2',
        code: 'R2',
      ),
    );
    expect(next, isA<ElvCommandSuccess<ProjectDesignRevision>>());
    final r2Loads = await db
        .customSelect(
          "SELECT typed_demand_json FROM power_load_bindings WHERE design_revision_id = 'R2'",
        )
        .get();
    expect(r2Loads, hasLength(1));
    expect(
      (await db
          .customSelect(
            "SELECT * FROM power_evaluation_pointers WHERE design_revision_id = 'R2'",
          )
          .get()),
      isEmpty,
    );
    await DriftPowerCommandService(db, originDeviceId: 'test').execute(
      SetPowerLoadCommand(
        operationId: 'edit-r2',
        projectId: b.projectId,
        designRevisionId: 'R2',
        expectedRevision: 1,
        changedDependencies: [],
        contribution: PowerOwnLoadContribution(
          id: 'LOAD',
          componentId: 'load',
          inputPortId: 'load-IN',
          accountingKind: PowerAccountingKind.consumerInput,
          stateCode: 'NORMAL',
          demand: DcConstantPowerDemand(PowerRational.integer(99)),
        ),
      ),
    );
    // Adversarial operational-row corruption: v2 history must not consult these
    // mutable tables even if another writer/old client changes them directly.
    await db.customStatement(
      "UPDATE power_capacity_groups SET limits_json = '{\"limits\":[]}' WHERE design_revision_id = ?",
      [b.revisionId],
    );
    await db.customStatement(
      'UPDATE component_instances SET deleted_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch ~/ 1000, 'load'],
    );
    await db.customStatement(
      'UPDATE power_operating_scenarios SET deleted_at = ? WHERE design_revision_id = ?',
      [DateTime.now().millisecondsSinceEpoch ~/ 1000, b.revisionId],
    );
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final reopened = await DriftPowerPublicationRuntime(
      db,
      originDeviceId: 'test',
    ).readRevision(projectId: b.projectId, designRevisionId: b.revisionId);
    expect(
      canonicalEngineeringJsonV1(reopened.capturedPayload!),
      canonicalEngineeringJsonV1(before.capturedPayload!),
    );
    final historical = await DriftPowerWorkspaceRepository(
      db,
      originDeviceId: 'test',
    ).load(state);
    expect([
      for (final card in historical.cards.values)
        for (final m in card.metrics) '${m.key}:${m.value}',
    ], originalMetrics);
    expect(
      historical.scenarios.map((s) => s.key),
      original.scenarios.map((s) => s.key),
    );
    expect(
      historical.budgets.single.metrics.map((m) => m.value),
      original.budgets.single.metrics.map((m) => m.value),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
