import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract.dart';
import 'package:electra_mobile/application/elv5/acs/acs03_electrical_contract_write.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_acs03_electrical_contract_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_acs_write_unit_of_work.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv5_f2_qualification_harness.dart';

void main() {
  test(
    'F2 ACS-03 Q6/Q7/Q8 qualifies persisted door, real PWR CURRENT evidence, publication, restart and freeze replay',
    () async {
      const harness = Elv5F2QualificationHarness();
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-acs03-full-runtime-',
      );
      final file = File('${directory.path}/qualification.sqlite');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      var db = AppDatabase(NativeDatabase(file));
      await _seedProjectAndLockReference(db);
      await _persistDoorFacts(db);

      final contractStore = DriftAcs03ElectricalContractStore(
        db,
        originDeviceId: 'f2-acs03',
        nowUtc: _now,
      );
      await contractStore.replace(
        ReplaceAcs03ElectricalContractCommand(
          projectId: 'p',
          designRevisionId: 'd',
          bindingId: 'acs03-contract',
          expectedBindingRevision: null,
          expectedDesignRevision: 1,
          contract: _contract(),
        ),
      );

      final powerRuntime = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'f2-acs03-power',
        now: _now,
      );
      for (final event in _events) {
        await _publishPwr01(
          powerRuntime,
          event: event,
          generationSeed: 'initial',
        );
        await _publishPwr03(
          powerRuntime,
          event: event,
          generationSeed: 'initial',
        );
      }

      // Q6: run the complete production ELV5 path. ACS-03 capture reads the
      // persisted door aggregate, immutable electrical contract and verified
      // ELV4 PWR01/PWR03 CURRENT pointers before publishing its own evaluation.
      var runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-acs03',
        nowUtc: _now,
      );
      final command = _calculationCommand(
        commandId: 'acs03-calc-1',
        expectedPointerGeneration: 0,
        expectedDesignRevision: 2,
      );
      final first = await runtime.service.execute(command);
      expect(first.replayed, isFalse);

      final pointerBeforeRestart = await _acsPointer(db);
      expect(pointerBeforeRestart.freshness, 'CURRENT');
      expect(pointerBeforeRestart.generation, 1);
      expect(pointerBeforeRestart.evaluationId, isNotNull);

      final persisted = await _acsEvaluation(
        db,
        pointerBeforeRestart.evaluationId!,
      );
      expect(persisted.execution, 'SUCCEEDED');
      expect(persisted.completion, 'COMPLETE');
      expect(persisted.assessment, 'PASS');
      expect(persisted.inputFingerprint, hasLength(64));
      expect(persisted.outputSha256, hasLength(64));
      final committedSnapshot = _snapshot(
        pointerBeforeRestart,
        persisted,
        first.logicalResultJson,
      );
      harness.assertQ6Initial('ACS-03', committedSnapshot);

      final dependencyRows =
          await db
              .customSelect(
                'SELECT dependency_key FROM discipline_dependency_index '
                'WHERE project_id = ? AND design_revision_id = ? '
                'AND logical_node_key_sha256 = ? ORDER BY dependency_key',
                variables: <Variable>[
                  Variable.withString('p'),
                  Variable.withString('d'),
                  Variable.withString(_acsNodeSha()),
                ],
              )
              .get();
      final dependencyJson =
          dependencyRows
              .map((row) => jsonDecode(row.read<String>('dependency_key')))
              .whereType<Map>()
              .map((value) => Map<String, Object?>.from(value))
              .toList();
      expect(
        dependencyJson.where(
          (value) => value['domain'] == 'ELV4_PWR01_CURRENT',
        ),
        hasLength(_events.length),
      );
      expect(
        dependencyJson.where(
          (value) => value['domain'] == 'ELV4_PWR03_CURRENT',
        ),
        hasLength(_events.length),
      );

      // Q7 restart: rebuild registry, resolvers, evidence readers and
      // publication stores from the durable file. Replay must happen before
      // recapture and preserve the exact logical result.
      final logicalBeforeRestart = first.logicalResultJson;
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-acs03-restarted',
        nowUtc: _now,
      );
      final replay = await runtime.service.execute(command);
      expect(replay.replayed, isTrue);
      expect(replay.logicalResultJson, logicalBeforeRestart);
      final pointerAfterRestart = await _acsPointer(db);
      expect(pointerAfterRestart.generation, 1);
      expect(
        pointerAfterRestart.evaluationId,
        pointerBeforeRestart.evaluationId,
      );
      harness.assertQ7Replay(
        'ACS-03',
        committedSnapshot,
        _snapshot(
          pointerAfterRestart,
          await _acsEvaluation(db, pointerAfterRestart.evaluationId!),
          replay.logicalResultJson,
        ),
      );

      // Q7 competing publication: a stale writer still expects generation 0.
      // The durable CURRENT generation is already 1, so publication fails closed.
      await harness.expectQ7StaleWriter('ACS-03', () async {
        await runtime.service.execute(
          _calculationCommand(
            commandId: 'acs03-stale-writer',
            expectedPointerGeneration: 0,
            expectedDesignRevision: 2,
          ),
        );
      });

      // Q8: freeze preserves historical replay, while new calculations are
      // forbidden even when the caller supplies the latest pointer generation.
      await db.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN', revision = 3 "
        "WHERE project_id = 'p' AND id = 'd'",
      );
      final frozenReplay = await runtime.service.execute(command);
      expect(frozenReplay.replayed, isTrue);
      expect(frozenReplay.logicalResultJson, logicalBeforeRestart);
      final frozenReplayPointer = await _acsPointer(db);
      harness.assertQ8Replay(
        'ACS-03',
        committedSnapshot,
        _snapshot(
          frozenReplayPointer,
          await _acsEvaluation(db, frozenReplayPointer.evaluationId!),
          frozenReplay.logicalResultJson,
        ),
      );

      await harness.expectQ8ReadOnly('ACS-03', () async {
        await runtime.service.execute(
          _calculationCommand(
            commandId: 'acs03-after-freeze',
            expectedPointerGeneration: 1,
            expectedDesignRevision: 3,
          ),
        );
      }, operation: 'new calculation');

      final frozenPointer = await _acsPointer(db);
      expect(frozenPointer.generation, 1);
      expect(frozenPointer.evaluationId, pointerBeforeRestart.evaluationId);
      await db.close();
    },
  );
}

Elv5F2PublicationSnapshot _snapshot(
  _PointerRow pointer,
  _EvaluationRow evaluation,
  String logicalResultJson,
) => Elv5F2PublicationSnapshot(
  generation: pointer.generation,
  evaluationId: pointer.evaluationId!,
  freshness: pointer.freshness,
  execution: evaluation.execution,
  completion: evaluation.completion,
  inputFingerprint: evaluation.inputFingerprint,
  outputSha256: evaluation.outputSha256,
  logicalResultJson: logicalResultJson,
);

final _events = <_AcsEventFixture>[
  const _AcsEventFixture(
    id: 'holding',
    state: Acs03StateCode.holding,
    currentA: '0.10',
    scenarioId: 'HOLDING',
    segmentId: 'segment-holding',
    loadOriginId: 'lock-load-holding',
  ),
  const _AcsEventFixture(
    id: 'active',
    state: Acs03StateCode.activeRelease,
    currentA: '0.20',
    scenarioId: 'ACTIVE_RELEASE',
    segmentId: 'segment-active',
    loadOriginId: 'lock-load-active',
  ),
  const _AcsEventFixture(
    id: 'startup',
    state: Acs03StateCode.startupInrush,
    currentA: '0.30',
    scenarioId: 'STARTUP_INRUSH',
    segmentId: 'segment-startup',
    loadOriginId: 'lock-load-startup',
  ),
];

final class _AcsEventFixture {
  const _AcsEventFixture({
    required this.id,
    required this.state,
    required this.currentA,
    required this.scenarioId,
    required this.segmentId,
    required this.loadOriginId,
  });

  final String id;
  final Acs03StateCode state;
  final String currentA;
  final String scenarioId;
  final String segmentId;
  final String loadOriginId;
}

Acs03ElectricalContract _contract() => Acs03ElectricalContract(
  doorId: 'door-1',
  lockId: 'lock-1',
  conductiveFeedPathId: 'feed-path-1',
  controlPathId: 'control-path-1',
  minimumTerminalVoltage: Voltage(Elv5Rational.integer(22)),
  maximumTerminalVoltage: Voltage(Elv5Rational.integer(28)),
  events: <Acs03ElectricalEventContract>[
    for (final event in _events)
      Acs03ElectricalEventContract(
        eventId: event.id,
        state: event.state,
        durationMicroseconds: BigInt.from(1000000),
        scenarioId: event.scenarioId,
        segmentId: event.segmentId,
        domainId: 'domain-1',
        lockLoadOriginId: event.loadOriginId,
        sharedTrunkSectionId: 'trunk-1',
        lockCurrent: Current(Elv5Rational.parseDecimal(event.currentA)),
      ),
  ],
);

Future<void> _persistDoorFacts(AppDatabase db) async {
  final uow = DriftElv5AcsWriteUnitOfWork(db, originDeviceId: 'f2-acs03');
  await uow.run(
    (session) => session.acs.replace(
      projectId: 'p',
      designRevisionId: 'd',
      operation: 'REPLACE_DOOR_ROLE_ASSIGNMENTS',
      subjectId: 'door-1',
      bindingId: 'door-binding-1',
      expectedRootRevision: null,
      payload: <String, Object?>{
        'doorAssemblyId': 'door-1',
        'topologyProfileRef': <String, Object?>{
          'profileCode': 'ACS_DOOR_STANDARD',
          'edition': '1',
        },
        'safetyMode': 'FAIL_SAFE',
        'roleAssignments': <Object?>[
          <String, Object?>{
            'roleCode': 'LOCK',
            'slot': 0,
            'componentId': 'lock-1',
          },
        ],
        'releaseTruthTable': const <Object?>[],
      },
      updatedAtUtc: _now(),
    ),
  );
}

Future<void> _publishPwr01(
  DriftPowerPublicationRuntime runtime, {
  required _AcsEventFixture event,
  required String generationSeed,
}) => _publishPower(
  runtime,
  node: PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: event.scenarioId,
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: event.segmentId,
    processCode: PowerProcessCode.pwr01,
    subjectKind: 'LOAD_ORIGIN',
    subjectId: event.loadOriginId,
  ),
  input: _powerInput(
    entityId: '${event.loadOriginId}:$generationSeed',
    purpose: 'ACS03_LOCK_DEMAND',
  ),
  evaluationId: 'pwr01-${event.id}-$generationSeed',
  operationId: 'op-pwr01-${event.id}-$generationSeed',
  output: <String, Object?>{
    'completeA': true,
    'knownA': PowerRational.parseDecimal(event.currentA).toMap(),
  },
);

Future<void> _publishPwr03(
  DriftPowerPublicationRuntime runtime, {
  required _AcsEventFixture event,
  required String generationSeed,
}) => _publishPower(
  runtime,
  node: PowerNodeKeyV2(
    revisionId: 'd',
    scenarioId: event.scenarioId,
    scopeKind: PowerEvaluationScopeKind.segment,
    scopeId: event.segmentId,
    processCode: PowerProcessCode.pwr03,
    subjectKind: 'DC_DOMAIN',
    subjectId: 'domain-1',
  ),
  input: _powerInput(
    entityId: 'physical-membership-1',
    purpose: 'ACS03_SHARED_PHYSICAL_CLOSURE',
  ),
  evaluationId: 'pwr03-${event.id}-$generationSeed',
  operationId: 'op-pwr03-${event.id}-$generationSeed',
  output: <String, Object?>{
    'physicalComplete': true,
    'terminals': <Object?>[
      <String, Object?>{
        'loadId': event.loadOriginId,
        'minimumV': PowerRational.parseDecimal('23.51').toMap(),
        'maximumV': PowerRational.integer(24).toMap(),
      },
    ],
    'sections': <Object?>[
      <String, Object?>{
        'sectionId': 'trunk-1',
        'currentA': PowerRational.parseDecimal(event.currentA).toMap(),
        'currentMarginA': PowerRational.parseDecimal('1.51').toMap(),
      },
    ],
  },
);

Future<void> _publishPower(
  DriftPowerPublicationRuntime runtime, {
  required PowerNodeKeyV2 node,
  required PowerConsumedInput input,
  required String evaluationId,
  required String operationId,
  required Map<String, Object?> output,
}) async {
  final capture = await runtime.captureForCalculation(
    projectId: 'p',
    designRevisionId: 'd',
    targetNodeKey: node,
    captureInput: () async => input,
  );
  final evidence = PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: node,
    algorithmVersion: input.algorithmVersion,
    inputSchemaVersion: input.inputSchemaVersion,
    outputSchemaVersion: 'electra.elv5-acs03-power-fixture-output.v1',
    numericPolicyVersion: input.numericPolicyVersion,
    inputFingerprint: input.inputFingerprint,
    status: PowerEvaluationStatus.pass,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: <String, Object?>{'dependencyKeys': input.dependencyKeys},
    output: output,
    dependencies: const <PowerNodeKeyV2>[],
  );
  await runtime.publishGuarded(
    capture: capture,
    evidence: evidence,
    operationId: operationId,
    commandFingerprint: sha256HexUtf8(operationId),
    recaptureInput: () async => input,
  );
}

PowerConsumedInput _powerInput({
  required String entityId,
  required String purpose,
}) => PowerConsumedInput(
  algorithmVersion: 'acs03-f2-power-fixture-v1',
  inputSchemaVersion: 'electra.elv5-acs03-power-fixture-input.v1',
  numericPolicyVersion: powerNumericPolicyVersion,
  facts: <PowerConsumedFact>[
    PowerConsumedFact.present(
      key: PowerDependencyKey(
        projectId: 'p',
        revisionId: 'd',
        kind: PowerDependencyKind.definition,
        entityId: entityId,
        purpose: purpose,
      ),
      valueSchema: 'electra.elv5-acs03-power-fixture-fact.v1',
      value: <String, Object?>{'entityId': entityId, 'purpose': purpose},
    ),
  ],
  evaluations: const <PowerConsumedEvaluationRef>[],
);

Elv5WireCommandEnvelope _calculationCommand({
  required String commandId,
  required int expectedPointerGeneration,
  required int expectedDesignRevision,
}) => Elv5WireCommandEnvelope(
  operation: 'CALCULATE_DISCIPLINE_PROCESS',
  projectId: 'p',
  designRevisionId: 'd',
  commandId: commandId,
  expectedDesignRowRevision: expectedDesignRevision,
  expectedRows: const <String, int>{},
  reviewedImpactFingerprint: _hash('9'),
  payload: <String, Object?>{
    'scope': <String, Object?>{
      'kind': 'DESIGN',
      'scopeId': 'd',
      'scenarioKey': 'NONE',
    },
    'processCodes': <String>[Elv5ProcessCode.acs03.wireCode],
    'subjects': <Object?>[
      <String, Object?>{'kind': 'DOOR', 'id': 'door-1'},
    ],
    'expectedPointerGenerations': <String, Object?>{
      _acsNodeSha(): expectedPointerGeneration,
    },
  },
);

String _acsNodeSha() => const Elv5CanonicalJsonV1().sha256(
  Elv5EngineeringNodeKeyV3(
    designRevisionId: 'd',
    scope: Elv5ScopeRef(
      kind: Elv5ScopeKind.design,
      scopeId: 'd',
      scenarioKey: 'NONE',
    ),
    processCode: Elv5ProcessCode.acs03,
    subject: Elv5SubjectRef(kind: 'DOOR', id: 'door-1'),
  ).toCanonicalValue(),
);

Future<_PointerRow> _acsPointer(AppDatabase db) async {
  final row =
      await db
          .customSelect(
            'SELECT freshness, generation, evaluation_id '
            'FROM discipline_evaluation_pointers '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND logical_node_key_sha256 = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString('d'),
              Variable.withString(_acsNodeSha()),
            ],
          )
          .getSingle();
  return _PointerRow(
    freshness: row.read<String>('freshness'),
    generation: row.read<int>('generation'),
    evaluationId: row.readNullable<String>('evaluation_id'),
  );
}

Future<_EvaluationRow> _acsEvaluation(
  AppDatabase db,
  String evaluationId,
) async {
  final row =
      await db
          .customSelect(
            'SELECT execution, completion, assessment, input_fingerprint, output_sha256 '
            'FROM discipline_evaluation_records '
            'WHERE project_id = ? AND evaluation_id = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString(evaluationId),
            ],
          )
          .getSingle();
  return _EvaluationRow(
    execution: row.read<String>('execution'),
    completion: row.read<String>('completion'),
    assessment: row.read<String>('assessment'),
    inputFingerprint: row.read<String>('input_fingerprint'),
    outputSha256: row.read<String>('output_sha256'),
  );
}

final class _PointerRow {
  const _PointerRow({
    required this.freshness,
    required this.generation,
    required this.evaluationId,
  });

  final String freshness;
  final int generation;
  final String? evaluationId;
}

final class _EvaluationRow {
  const _EvaluationRow({
    required this.execution,
    required this.completion,
    required this.assessment,
    required this.inputFingerprint,
    required this.outputSha256,
  });

  final String execution;
  final String completion;
  final String assessment;
  final String inputFingerprint;
  final String outputSha256;
}

Future<void> _seedProjectAndLockReference(AppDatabase db) async {
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'F2 ACS03 runtime qualification',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'f2-acs03',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'd',
          projectId: 'p',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          revision: const Value(1),
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'f2-acs03',
        ),
      );
  await db
      .into(db.floors)
      .insert(
        FloorsCompanion.insert(
          id: 'floor-1',
          projectId: 'p',
          name: 'Qualification floor',
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'seed',
        ),
      );
  await db
      .into(db.rooms)
      .insert(
        RoomsCompanion.insert(
          id: 'room-1',
          floorId: 'floor-1',
          name: 'Qualification room',
          roomType: 'technical',
          roomCategory: 'technical',
          widthMm: 4000,
          depthMm: 4000,
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'seed',
        ),
      );
  await db
      .into(db.surfacePatches)
      .insert(
        SurfacePatchesCompanion.insert(
          id: 'patch-1',
          roomId: 'room-1',
          surfaceId: 'wall',
          originXmm: 0,
          originYmm: 0,
          originZmm: 0,
          uAxisX: 1,
          uAxisY: 0,
          uAxisZ: 0,
          vAxisX: 0,
          vAxisY: 0,
          vAxisZ: 1,
          orientation: 'vertical',
          boundaryJson: '[[0,0],[4000,0],[4000,3000],[0,3000]]',
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'seed',
        ),
      );
  await db
      .into(db.componentInstances)
      .insert(
        ComponentInstancesCompanion.insert(
          id: 'lock-1',
          definitionId: 'lock-def',
          definitionVersion: 1,
          roomId: 'room-1',
          hostSurfacePatchId: 'patch-1',
          localXmm: 0,
          localYmm: 0,
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'seed',
        ),
      );
  await db
      .into(db.engineeringReferenceCatalogs)
      .insert(
        EngineeringReferenceCatalogsCompanion.insert(
          id: 'fixture-catalog',
          projectId: 'p',
          code: 'ACS',
          catalogVersion: '1',
          payloadJson: '{}',
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'seed',
        ),
      );
  await db
      .into(db.componentReferenceBindings)
      .insert(
        ComponentReferenceBindingsCompanion.insert(
          componentId: 'lock-1',
          projectId: 'p',
          catalogId: 'fixture-catalog',
          profileCode: 'ACS_LOCK',
          payloadJson: '{}',
          createdAt: _now(),
          updatedAt: _now(),
          originDeviceId: 'f2-acs03',
        ),
      );
}

DateTime _now() => DateTime.utc(2026, 10, 17, 14);
String _hash(String char) => List<String>.filled(64, char).join();
