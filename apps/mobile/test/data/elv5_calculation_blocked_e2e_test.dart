import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CALCULATE persists BLOCKED ACS-03 evaluation and CURRENT pointer', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seed(db);

    final runtime = DriftElv5CalculationRuntime.create(
      db,
      originDeviceId: 'test',
      nowUtc: () => DateTime.utc(2026, 10, 17, 12),
    );
    final scope = Elv5ScopeRef(
      kind: Elv5ScopeKind.design,
      scopeId: 'd',
      scenarioKey: 'NONE',
    );
    final subject = Elv5SubjectRef(kind: 'DOOR', id: 'door-1');
    final node = Elv5EngineeringNodeKeyV3(
      designRevisionId: 'd',
      scope: scope,
      processCode: Elv5ProcessCode.acs03,
      subject: subject,
    );
    const encoder = Elv5CanonicalJsonV1();
    final nodeHash = encoder.sha256(node.toCanonicalValue());
    final command = Elv5WireCommandEnvelope(
      operation: 'CALCULATE_DISCIPLINE_PROCESS',
      projectId: 'p',
      designRevisionId: 'd',
      commandId: 'calc-1',
      expectedDesignRowRevision: 1,
      expectedRows: const <String, int>{},
      reviewedImpactFingerprint: List<String>.filled(64, '0').join(),
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
        'expectedPointerGenerations': <String, Object?>{nodeHash: 0},
      },
    );

    final first = await runtime.service.execute(command);
    expect(first.replayed, isFalse);

    final evaluation =
        await db
            .customSelect(
              'SELECT execution, completion, assessment, output_json, evidence_json '
              'FROM discipline_evaluation_records WHERE logical_node_key_sha256 = ?',
              variables: <Variable>[Variable.withString(nodeHash)],
            )
            .getSingle();
    expect(evaluation.read<String>('execution'), 'BLOCKED');
    expect(evaluation.read<String>('completion'), 'INCOMPLETE');
    expect(evaluation.read<String>('assessment'), 'UNRESOLVED');
    final output =
        jsonDecode(evaluation.read<String>('output_json'))
            as Map<String, dynamic>;
    expect(
      output['reasonCode'],
      'ACS03_EXACT_ELECTRICAL_EVENT_CONTRACT_REQUIRED',
    );

    final pointer =
        await db
            .customSelect(
              'SELECT freshness, generation, evaluation_id FROM discipline_evaluation_pointers '
              'WHERE logical_node_key_sha256 = ?',
              variables: <Variable>[Variable.withString(nodeHash)],
            )
            .getSingle();
    expect(pointer.read<String>('freshness'), 'CURRENT');
    expect(pointer.read<int>('generation'), 1);
    expect(pointer.readNullable<String>('evaluation_id'), isNotNull);

    final replay = await runtime.service.execute(command);
    expect(replay.replayed, isTrue);
    expect(replay.logicalResultJson, first.logicalResultJson);
  });
}

Future<void> _seed(AppDatabase db) async {
  await db.customStatement('PRAGMA foreign_keys = OFF');
  const now = '2026-10-17T00:00:00.000Z';
  await db.customStatement('''
INSERT INTO projects (
  id, name, measurement_system, default_structural_height_mm,
  default_finished_ceiling_height_mm, created_at, updated_at, origin_device_id
) VALUES ('p', 'Project', 'METRIC', 3000, 2700, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO project_design_revisions (
  id, project_id, code, sequence, state, revision,
  created_at, updated_at, origin_device_id
) VALUES ('d', 'p', 'R1', 1, 'WORKING', 1, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO component_instances (
  id, definition_id, definition_version, room_id, host_surface_patch_id,
  local_xmm, local_ymm, revision, created_at, updated_at, origin_device_id
) VALUES ('lock-1', 'lock-def', 1, 'room-1', 'patch-1',
  0, 0, 1, '$now', '$now', 'test')
''');
  await db.customStatement('''
INSERT INTO door_calculation_bindings (
  project_id, design_revision_id, id, revision, created_at, updated_at,
  origin_device_id, door_assembly_id, topology_profile_ref_json, safety_mode
) VALUES ('p', 'd', 'door-binding-1', 1, '$now', '$now', 'test',
  'door-1', '{}', 'FAIL_SAFE')
''');
  await db.customStatement('''
INSERT INTO door_role_assignments (
  project_id, design_revision_id, binding_id, component_id, role_code, slot
) VALUES ('p', 'd', 'door-binding-1', 'lock-1', 'LOCK', 0)
''');
}
