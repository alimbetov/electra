import 'dart:io';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_mutation_service.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv5_f2_qualification_harness.dart';

void main() {
  test(
    'F2 CCTV-03 Q6/Q7/Q8 qualifies persisted recording facts, invalidation, restart and freeze',
    () async {
      const harness = Elv5F2QualificationHarness();
      final directory = await Directory.systemTemp.createTemp(
        'electra-f2-cctv03-full-runtime-',
      );
      final file = File('${directory.path}/qualification.sqlite');
      addTearDown(() async {
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      });

      var db = AppDatabase(NativeDatabase(file));
      await _seedProject(db);

      var mutations = _mutationService(db);
      await _replaceRecordingPool(
        mutations,
        commandId: 'recording-pool-initial',
        payload: _recordingPayload(expectedBitrateBps: '4000000'),
      );

      // Q6: the production registry must capture the persisted recording pool,
      // pinned temporal policy and absolute UTC schedule before evaluating the
      // exact CCTV-03 storage kernel and publishing CURRENT.
      var runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-cctv03',
        nowUtc: _now,
      );
      final firstCommand = _calculationCommand(
        commandId: 'cctv03-calc-1',
        expectedPointerGeneration: 0,
        expectedDesignRevision: 2,
      );
      final first = await runtime.service.execute(firstCommand);
      expect(first.replayed, isFalse);

      final firstPointer = await _pointer(db);
      expect(firstPointer.freshness, 'CURRENT');
      expect(firstPointer.generation, 1);
      expect(firstPointer.evaluationId, isNotNull);
      final firstEvaluation = await _evaluation(db, firstPointer.evaluationId!);
      expect(firstEvaluation.execution, 'SUCCEEDED');
      expect(firstEvaluation.completion, 'COMPLETE');
      expect(firstEvaluation.inputFingerprint, hasLength(64));
      expect(firstEvaluation.outputSha256, hasLength(64));
      final firstSnapshot = _snapshot(
        firstPointer,
        firstEvaluation,
        first.logicalResultJson,
      );
      harness.assertQ6Initial('CCTV-03', firstSnapshot);

      final dependencyDomains = await _dependencyDomains(db);
      expect(dependencyDomains, contains('CCTV_RECORDING_POOL'));
      expect(dependencyDomains, contains('CCTV_RECORDING_STREAM'));
      expect(dependencyDomains, contains('CCTV_RECORDING_SCHEDULE'));

      // Q6 invalidation: mutate authoritative bitrate facts only through the
      // public replacement protocol. The mutation runner must mark the old
      // CURRENT result STALE in the same transaction that advances the design
      // revision; recalculation then publishes a different exact result.
      await _replaceRecordingPool(
        mutations,
        commandId: 'recording-pool-rate-change',
        payload: _recordingPayload(expectedBitrateBps: '8000000'),
      );
      final stalePointer = await _pointer(db);
      expect(stalePointer.freshness, 'STALE');
      expect(stalePointer.generation, 2);
      expect(stalePointer.evaluationId, firstPointer.evaluationId);

      final secondCommand = _calculationCommand(
        commandId: 'cctv03-calc-2',
        expectedPointerGeneration: 2,
        expectedDesignRevision: 3,
      );
      final second = await runtime.service.execute(secondCommand);
      expect(second.replayed, isFalse);
      final secondPointer = await _pointer(db);
      expect(secondPointer.freshness, 'CURRENT');
      expect(secondPointer.generation, 3);
      expect(secondPointer.evaluationId, isNot(firstPointer.evaluationId));
      final secondEvaluation = await _evaluation(
        db,
        secondPointer.evaluationId!,
      );
      expect(secondEvaluation.execution, 'SUCCEEDED');
      expect(secondEvaluation.completion, 'COMPLETE');
      expect(
        secondEvaluation.inputFingerprint,
        isNot(firstEvaluation.inputFingerprint),
      );
      expect(
        secondEvaluation.outputSha256,
        isNot(firstEvaluation.outputSha256),
      );
      final secondSnapshot = _snapshot(
        secondPointer,
        secondEvaluation,
        second.logicalResultJson,
      );
      harness.assertQ6Republished('CCTV-03', firstSnapshot, secondSnapshot);

      // Q7: reconstruct the complete production runtime from durable SQLite.
      // Ledger replay must not recapture or republish the committed result.
      final logicalBeforeRestart = second.logicalResultJson;
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-cctv03-restarted',
        nowUtc: _now,
      );
      mutations = _mutationService(db);

      final replay = await runtime.service.execute(secondCommand);
      expect(replay.replayed, isTrue);
      expect(replay.logicalResultJson, logicalBeforeRestart);
      final restartedPointer = await _pointer(db);
      expect(restartedPointer.generation, 3);
      expect(restartedPointer.evaluationId, secondPointer.evaluationId);
      harness.assertQ7Replay(
        'CCTV-03',
        secondSnapshot,
        _snapshot(restartedPointer, secondEvaluation, replay.logicalResultJson),
      );

      // Q7 competing publication: a stale client that still owns generation 2
      // cannot overwrite the generation-3 CURRENT pointer after restart.
      await harness.expectQ7StaleWriter('CCTV-03', () async {
        await runtime.service.execute(
          _calculationCommand(
            commandId: 'cctv03-stale-writer',
            expectedPointerGeneration: 2,
            expectedDesignRevision: 3,
          ),
        );
      });

      // Q8: committed historical result remains replayable after freeze while
      // both a new calculation and a new recording-pool mutation fail closed.
      await db.customUpdate(
        "UPDATE project_design_revisions SET state = 'FROZEN', revision = 4 "
        "WHERE project_id = 'p' AND id = 'd'",
      );
      final frozenReplay = await runtime.service.execute(secondCommand);
      expect(frozenReplay.replayed, isTrue);
      expect(frozenReplay.logicalResultJson, logicalBeforeRestart);
      final frozenReplayPointer = await _pointer(db);
      harness.assertQ8Replay(
        'CCTV-03',
        secondSnapshot,
        _snapshot(
          frozenReplayPointer,
          secondEvaluation,
          frozenReplay.logicalResultJson,
        ),
      );

      await harness.expectQ8ReadOnly('CCTV-03', () async {
        await runtime.service.execute(
          _calculationCommand(
            commandId: 'cctv03-after-freeze',
            expectedPointerGeneration: 3,
            expectedDesignRevision: 4,
          ),
        );
      }, operation: 'new calculation');
      await expectLater(
        mutations.preview(
          projectId: 'p',
          designRevisionId: 'd',
          operation: 'REPLACE_RECORDING_ASSIGNMENTS',
          payload: _recordingPayload(expectedBitrateBps: '12000000'),
        ),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('ELV5_DESIGN_REVISION_READ_ONLY'),
          ),
        ),
      );

      final frozenPointer = await _pointer(db);
      expect(frozenPointer.freshness, 'CURRENT');
      expect(frozenPointer.generation, 3);
      expect(frozenPointer.evaluationId, secondPointer.evaluationId);
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
  logicalResultJson: logicalResultJson,
);

Elv5CctvMutationService _mutationService(AppDatabase db) =>
    Elv5CctvMutationService(
      unitOfWork: DriftElv5CctvWriteUnitOfWork(db, originDeviceId: 'f2-cctv03'),
      originDeviceId: 'f2-cctv03',
      now: _now,
    );

Future<void> _replaceRecordingPool(
  Elv5CctvMutationService service, {
  required String commandId,
  required Map<String, Object?> payload,
}) async {
  final preview = await service.preview(
    projectId: 'p',
    designRevisionId: 'd',
    operation: 'REPLACE_RECORDING_ASSIGNMENTS',
    payload: payload,
  );
  final result = await service.execute(
    Elv5WireCommandEnvelope(
      operation: 'REPLACE_RECORDING_ASSIGNMENTS',
      projectId: 'p',
      designRevisionId: 'd',
      commandId: commandId,
      expectedDesignRowRevision: preview.designRowRevision,
      expectedRows: preview.expectedRows,
      reviewedImpactFingerprint: preview.reviewedImpactFingerprint,
      payload: payload,
    ),
  );
  expect(result.replayed, isFalse);
}

Map<String, Object?> _recordingPayload({required String expectedBitrateBps}) =>
    <String, Object?>{
      'poolId': 'pool-1',
      'horizon': <String, Object?>{
        'startUtc': '2026-10-17T00:00:00.000Z',
        'endUtc': '2026-10-18T00:00:00.000Z',
      },
      'temporalPolicy': <String, Object?>{
        'timeZoneId': 'Asia/Almaty',
        'tzdbVersion': '2026a',
        'gapRule': 'SHIFT_FORWARD',
        'overlapRule': 'EARLIER_OFFSET',
      },
      'assignments': <Object?>[
        <String, Object?>{
          'encodedStreamId': 'stream-main',
          'copyRole': 'PRIMARY',
          'scheduleProfileId': 'always',
          'expectedBitrateBps': expectedBitrateBps,
          'upperBoundBitrateBps': '12000000',
          'evidenceBasis': 'CONFIGURED_TARGET',
        },
        <String, Object?>{
          'encodedStreamId': 'stream-secondary',
          'copyRole': 'PRIMARY',
          'scheduleProfileId': 'business-hours',
          'expectedBitrateBps': '2000000',
          'upperBoundBitrateBps': '4000000',
          'evidenceBasis': 'CONFIGURED_TARGET',
        },
      ],
      'scheduleSegments': <Object?>[
        <String, Object?>{
          'scheduleProfileId': 'always',
          'segmentId': 'always-1',
          'absoluteWindow': <String, Object?>{
            'startUtc': '2026-10-17T00:00:00.000Z',
            'endUtc': '2026-10-18T00:00:00.000Z',
          },
          'recurrence': null,
        },
        <String, Object?>{
          'scheduleProfileId': 'business-hours',
          'segmentId': 'business-1',
          'absoluteWindow': <String, Object?>{
            'startUtc': '2026-10-17T04:00:00.000Z',
            'endUtc': '2026-10-17T13:00:00.000Z',
          },
          'recurrence': null,
        },
      ],
      'sizingBasis': 'EXPECTED_ESTIMATE',
      'reserveMultiplier': '1.20',
      'redundancyModel': <String, Object?>{
        'modelCode': 'MIRROR_2WAY',
        'usableFraction': '0.50',
        'contentHash': _hash('a'),
      },
      'policyRef': null,
    };

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
    'processCodes': <String>[Elv5ProcessCode.cctv03.wireCode],
    'subjects': <Object?>[
      <String, Object?>{'kind': 'RECORDING_POOL', 'id': 'pool-1'},
    ],
    'expectedPointerGenerations': <String, Object?>{
      _nodeSha(): expectedPointerGeneration,
    },
  },
);

String _nodeSha() => const Elv5CanonicalJsonV1().sha256(
  Elv5EngineeringNodeKeyV3(
    designRevisionId: 'd',
    scope: Elv5ScopeRef(
      kind: Elv5ScopeKind.design,
      scopeId: 'd',
      scenarioKey: 'NONE',
    ),
    processCode: Elv5ProcessCode.cctv03,
    subject: Elv5SubjectRef(kind: 'RECORDING_POOL', id: 'pool-1'),
  ).toCanonicalValue(),
);

Future<_PointerRow> _pointer(AppDatabase db) async {
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
              Variable.withString(_nodeSha()),
            ],
          )
          .getSingle();
  return _PointerRow(
    freshness: row.read<String>('freshness'),
    generation: row.read<int>('generation'),
    evaluationId: row.readNullable<String>('evaluation_id'),
  );
}

Future<_EvaluationRow> _evaluation(AppDatabase db, String evaluationId) async {
  final row =
      await db
          .customSelect(
            'SELECT execution, completion, input_fingerprint, output_sha256 '
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
    inputFingerprint: row.read<String>('input_fingerprint'),
    outputSha256: row.read<String>('output_sha256'),
  );
}

Future<Set<String>> _dependencyDomains(AppDatabase db) async {
  final rows =
      await db
          .customSelect(
            'SELECT dependency_key FROM discipline_dependency_index '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND logical_node_key_sha256 = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString('d'),
              Variable.withString(_nodeSha()),
            ],
          )
          .get();
  final result = <String>{};
  for (final row in rows) {
    final value = row.read<String>('dependency_key');
    for (final domain in const <String>[
      'CCTV_RECORDING_POOL',
      'CCTV_RECORDING_STREAM',
      'CCTV_RECORDING_SCHEDULE',
      'CCTV_RECORDING_POLICY',
    ]) {
      if (value.contains('"domain":"$domain"')) result.add(domain);
    }
  }
  return result;
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
    required this.inputFingerprint,
    required this.outputSha256,
  });

  final String execution;
  final String completion;
  final String inputFingerprint;
  final String outputSha256;
}

Future<void> _seedProject(AppDatabase db) async {
  final now = _now();
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'F2 CCTV03 runtime qualification',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-cctv03',
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
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-cctv03',
        ),
      );
}

DateTime _now() => DateTime.utc(2026, 10, 17, 15);
String _hash(String char) => List<String>.filled(64, char).join();
