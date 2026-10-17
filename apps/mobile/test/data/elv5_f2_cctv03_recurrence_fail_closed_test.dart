import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/cctv/elv5_cctv_mutation_service.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F2 CCTV-03 persisted recurrence fails closed without pinned tzdb expander',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedProject(db);

      final mutations = Elv5CctvMutationService(
        unitOfWork: DriftElv5CctvWriteUnitOfWork(
          db,
          originDeviceId: 'f2-cctv03-recurrence',
        ),
        originDeviceId: 'f2-cctv03-recurrence',
        now: _now,
      );
      final payload = _recurrencePayload();
      final preview = await mutations.preview(
        projectId: 'p',
        designRevisionId: 'd',
        operation: 'REPLACE_RECORDING_ASSIGNMENTS',
        payload: payload,
      );
      await mutations.execute(
        Elv5WireCommandEnvelope(
          operation: 'REPLACE_RECORDING_ASSIGNMENTS',
          projectId: 'p',
          designRevisionId: 'd',
          commandId: 'recording-recurrence-1',
          expectedDesignRowRevision: preview.designRowRevision,
          expectedRows: preview.expectedRows,
          reviewedImpactFingerprint: preview.reviewedImpactFingerprint,
          payload: payload,
        ),
      );

      final runtime = DriftElv5CalculationRuntime.create(
        db,
        originDeviceId: 'f2-cctv03-recurrence',
        nowUtc: _now,
      );
      final command = _calculationCommand();
      final result = await runtime.service.execute(command);
      expect(result.replayed, isFalse);

      final evaluation = await db
          .customSelect(
            'SELECT execution, completion, assessment, output_json, evidence_json '
            'FROM discipline_evaluation_records '
            'WHERE project_id = ? AND logical_node_key_sha256 = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString(_nodeSha()),
            ],
          )
          .getSingle();
      expect(evaluation.read<String>('execution'), 'BLOCKED');
      expect(evaluation.read<String>('completion'), 'INCOMPLETE');
      expect(evaluation.read<String>('assessment'), 'UNRESOLVED');

      final output = Map<String, Object?>.from(
        jsonDecode(evaluation.read<String>('output_json')) as Map,
      );
      expect(output['reasonCode'], 'CCTV03_RECURRENCE_EXPANDER_REQUIRED');

      final evidence = Map<String, Object?>.from(
        jsonDecode(evaluation.read<String>('evidence_json')) as Map,
      );
      final processEvidence = Map<String, Object?>.from(
        evidence['processEvidence'] as Map,
      );
      expect(processEvidence['requiredCapability'], 'PINNED_TZDB_RECURRENCE_EXPANDER');
      expect(processEvidence['timeZoneId'], 'Asia/Almaty');
      expect(processEvidence['tzdbVersion'], '2026a');

      final pointer = await db
          .customSelect(
            'SELECT freshness, generation, evaluation_id '
            'FROM discipline_evaluation_pointers '
            'WHERE project_id = ? AND logical_node_key_sha256 = ?',
            variables: <Variable>[
              Variable.withString('p'),
              Variable.withString(_nodeSha()),
            ],
          )
          .getSingle();
      expect(pointer.read<String>('freshness'), 'CURRENT');
      expect(pointer.read<int>('generation'), 1);
      expect(pointer.readNullable<String>('evaluation_id'), isNotNull);

      final replay = await runtime.service.execute(command);
      expect(replay.replayed, isTrue);
      expect(replay.logicalResultJson, result.logicalResultJson);
    },
  );
}

Map<String, Object?> _recurrencePayload() => <String, Object?>{
  'poolId': 'pool-1',
  'horizon': <String, Object?>{
    'startUtc': '2026-10-17T00:00:00.000Z',
    'endUtc': '2026-10-24T00:00:00.000Z',
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
      'scheduleProfileId': 'weekday',
      'expectedBitrateBps': '4000000',
      'upperBoundBitrateBps': '8000000',
      'evidenceBasis': 'CONFIGURED_TARGET',
    },
  ],
  'scheduleSegments': <Object?>[
    <String, Object?>{
      'scheduleProfileId': 'weekday',
      'segmentId': 'weekday-1',
      'absoluteWindow': null,
      'recurrence': <String, Object?>{
        'rule': 'FREQ=DAILY;BYHOUR=9;BYMINUTE=0',
        'timeZoneLocal': true,
      },
    },
  ],
  'sizingBasis': 'EXPECTED_ESTIMATE',
  'reserveMultiplier': '1.10',
  'redundancyModel': null,
  'policyRef': null,
};

Elv5WireCommandEnvelope _calculationCommand() => Elv5WireCommandEnvelope(
  operation: 'CALCULATE_DISCIPLINE_PROCESS',
  projectId: 'p',
  designRevisionId: 'd',
  commandId: 'cctv03-recurrence-calc',
  expectedDesignRowRevision: 2,
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
    'expectedPointerGenerations': <String, Object?>{_nodeSha(): 0},
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

Future<void> _seedProject(AppDatabase db) async {
  final now = _now();
  await db.into(db.projects).insert(
    ProjectsCompanion.insert(
      id: 'p',
      name: 'F2 CCTV03 recurrence qualification',
      measurementSystem: 'metric',
      defaultStructuralHeightMm: 3000,
      defaultFinishedCeilingHeightMm: 2700,
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'f2-cctv03-recurrence',
    ),
  );
  await db.into(db.projectDesignRevisions).insert(
    ProjectDesignRevisionsCompanion.insert(
      id: 'd',
      projectId: 'p',
      code: 'R1',
      sequence: 1,
      state: 'WORKING',
      revision: const Value(1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'f2-cctv03-recurrence',
    ),
  );
}

DateTime _now() => DateTime.utc(2026, 10, 17, 15, 30);
String _hash(String char) => List<String>.filled(64, char).join();
