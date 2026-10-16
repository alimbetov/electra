import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema 24 exposes ELV5 persistence and survives reopen', () async {
    final directory = await Directory.systemTemp.createTemp('elv5-p2-schema24-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/electra.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await db.customSelect('SELECT 1').getSingle();
    expect(db.schemaVersion, 24);

    final tables = await _tableNames(db);
    expect(
      tables,
      containsAll(<String>{
        'discipline_policy_bindings',
        'camera_stream_set_bindings',
        'camera_stream_bindings',
        'camera_stream_subscriptions',
        'recording_pool_bindings',
        'recording_assignments',
        'recording_schedule_segments',
        'recorder_capacity_bindings',
        'recorder_assignments',
        'link_composition_bindings',
        'link_section_assignments',
        'port_capacity_bindings',
        'port_capacity_assignments',
        'optical_link_bindings',
        'optical_loss_events',
        'rack_capacity_bindings',
        'rack_equipment_memberships',
        'patch_panel_bindings',
        'patch_panel_assignments',
        'door_calculation_bindings',
        'door_role_assignments',
        'door_release_truth_rows',
        'controller_resource_bindings',
        'controller_resource_assignments',
        'fire_loop_bindings',
        'fire_loop_device_assignments',
        'fire_address_claims',
        'notification_circuit_bindings',
        'notification_circuit_assignments',
        'discipline_evaluation_records',
        'discipline_evaluation_pointers',
        'discipline_dependency_index',
        'design_revision_discipline_snapshots',
      }),
    );

    final manifestColumns = await _columnNames(
      db,
      'design_revision_snapshot_manifests',
    );
    expect(manifestColumns, contains('discipline_section_schema'));
    expect(manifestColumns, contains('discipline_sha256'));

    await _seedProjectAndRevision(db);
    await _insertRecordingPool(
      db,
      id: 'pool-binding-1',
      projectId: 'project-a',
      revisionId: 'rev-a',
      poolId: 'pool-a',
    );
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    expect(
      await db
          .customSelect(
            "SELECT COUNT(*) AS c FROM recording_pool_bindings WHERE id = 'pool-binding-1'",
          )
          .getSingle()
          .then((row) => row.read<int>('c')),
      1,
    );
  });

  test('schema 24 enforces scope, identity and immutable evidence', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProjectAndRevision(db);
    await _seedProject(
      db,
      id: 'project-b',
      name: 'Other project',
    );

    await _insertRecordingPool(
      db,
      id: 'pool-binding-1',
      projectId: 'project-a',
      revisionId: 'rev-a',
      poolId: 'pool-a',
    );

    await expectLater(
      _insertRecordingPool(
        db,
        id: 'pool-binding-2',
        projectId: 'project-a',
        revisionId: 'rev-a',
        poolId: 'pool-a',
      ),
      throwsA(anything),
    );

    await expectLater(
      _insertRecordingPool(
        db,
        id: 'pool-binding-other-project',
        projectId: 'project-b',
        revisionId: 'rev-a',
        poolId: 'pool-b',
      ),
      throwsA(anything),
    );

    await _insertEvaluation(
      db,
      evaluationId: 'eval-global',
      revisionId: 'rev-a',
      nodeHash: _hash('a'),
    );
    await _seedRevision(
      db,
      id: 'rev-b',
      projectId: 'project-a',
      code: 'R2',
      sequence: 2,
    );
    await expectLater(
      _insertEvaluation(
        db,
        evaluationId: 'eval-global',
        revisionId: 'rev-b',
        nodeHash: _hash('b'),
      ),
      throwsA(anything),
    );

    await expectLater(
      db.customStatement(
        "UPDATE discipline_evaluation_records SET output_json = '{}' "
        "WHERE evaluation_id = 'eval-global'",
      ),
      throwsA(anything),
    );

    await db.customStatement('''
INSERT INTO discipline_evaluation_pointers (
  project_id, design_revision_id, logical_node_key_json,
  logical_node_key_sha256, freshness, generation, evaluation_id,
  input_fingerprint, output_sha256, updated_at, origin_device_id
) VALUES (
  'project-a', 'rev-a', '{}', '${_hash('p')}',
  'CURRENT', 2, 'eval-global', '${_hash('i')}', '${_hash('o')}', 0, 'test'
)
''');
    await expectLater(
      db.customStatement(
        "UPDATE discipline_evaluation_pointers SET generation = 1 "
        "WHERE design_revision_id = 'rev-a' AND logical_node_key_sha256 = '${_hash('p')}'",
      ),
      throwsA(anything),
    );
  });

  test('schema 23 shaped database migrates additively to schema 24', () async {
    final directory = await Directory.systemTemp.createTemp('elv5-p2-migration-');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/electra.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await db.customSelect('SELECT 1').getSingle();
    expect(db.schemaVersion, 24);

    await db.customStatement('PRAGMA foreign_keys = OFF');
    for (final table in _elv5Tables.reversed) {
      await db.customStatement('DROP TABLE IF EXISTS $table');
    }
    await db.customStatement(
      'ALTER TABLE design_revision_snapshot_manifests '
      'DROP COLUMN discipline_section_schema',
    );
    await db.customStatement(
      'ALTER TABLE design_revision_snapshot_manifests '
      'DROP COLUMN discipline_sha256',
    );
    await db.customStatement('PRAGMA user_version = 23');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').getSingle();

    final version = await db
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((row) => row.read<int>('user_version'));
    expect(version, 24);
    expect(await _tableNames(db), contains('discipline_evaluation_records'));
    expect(
      await _columnNames(db, 'design_revision_snapshot_manifests'),
      containsAll(<String>{'discipline_section_schema', 'discipline_sha256'}),
    );
  });
}

const _elv5Tables = <String>[
  'discipline_policy_bindings',
  'camera_stream_set_bindings',
  'camera_stream_bindings',
  'camera_stream_subscriptions',
  'recording_pool_bindings',
  'recording_assignments',
  'recording_schedule_segments',
  'recorder_capacity_bindings',
  'recorder_assignments',
  'link_composition_bindings',
  'link_section_assignments',
  'port_capacity_bindings',
  'port_capacity_assignments',
  'optical_link_bindings',
  'optical_loss_events',
  'rack_capacity_bindings',
  'rack_equipment_memberships',
  'patch_panel_bindings',
  'patch_panel_assignments',
  'door_calculation_bindings',
  'door_role_assignments',
  'door_release_truth_rows',
  'controller_resource_bindings',
  'controller_resource_assignments',
  'fire_loop_bindings',
  'fire_loop_device_assignments',
  'fire_address_claims',
  'notification_circuit_bindings',
  'notification_circuit_assignments',
  'discipline_evaluation_records',
  'discipline_evaluation_pointers',
  'discipline_dependency_index',
  'design_revision_discipline_snapshots',
];

final _now = DateTime.utc(2026, 10, 16, 15);

Future<Set<String>> _tableNames(AppDatabase db) async =>
    (await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type = 'table'",
            )
            .get())
        .map((row) => row.read<String>('name'))
        .toSet();

Future<Set<String>> _columnNames(AppDatabase db, String table) async =>
    (await db.customSelect('PRAGMA table_info($table)').get())
        .map((row) => row.read<String>('name'))
        .toSet();

Future<void> _seedProjectAndRevision(AppDatabase db) async {
  await _seedProject(db, id: 'project-a', name: 'ELV5 P2');
  await _seedRevision(
    db,
    id: 'rev-a',
    projectId: 'project-a',
    code: 'R1',
    sequence: 1,
  );
}

Future<void> _seedProject(
  AppDatabase db, {
  required String id,
  required String name,
}) => db.into(db.projects).insert(
  ProjectsCompanion.insert(
    id: id,
    name: name,
    measurementSystem: 'metric',
    defaultStructuralHeightMm: 3000,
    defaultFinishedCeilingHeightMm: 2700,
    createdAt: _now,
    updatedAt: _now,
    originDeviceId: 'test',
  ),
);

Future<void> _seedRevision(
  AppDatabase db, {
  required String id,
  required String projectId,
  required String code,
  required int sequence,
}) => db.into(db.projectDesignRevisions).insert(
  ProjectDesignRevisionsCompanion.insert(
    id: id,
    projectId: projectId,
    code: code,
    sequence: sequence,
    state: 'WORKING',
    createdAt: _now,
    updatedAt: _now,
    originDeviceId: 'test',
  ),
);

Future<void> _insertRecordingPool(
  AppDatabase db, {
  required String id,
  required String projectId,
  required String revisionId,
  required String poolId,
}) => db.customStatement('''
INSERT INTO recording_pool_bindings (
  project_id, design_revision_id, id, revision, created_at, updated_at,
  deleted_at, origin_device_id, pool_id, horizon_json, temporal_policy_json,
  sizing_basis, reserve_multiplier_json, redundancy_model_json, policy_ref_json
) VALUES (
  '$projectId', '$revisionId', '$id', 1, 0, 0, NULL, 'test', '$poolId',
  '{}', '{}', 'GUARANTEED', '{"numerator":1,"denominator":1}', NULL, NULL
)
''');

Future<void> _insertEvaluation(
  AppDatabase db, {
  required String evaluationId,
  required String revisionId,
  required String nodeHash,
}) => db.customStatement('''
INSERT INTO discipline_evaluation_records (
  project_id, design_revision_id, logical_node_key_json,
  logical_node_key_sha256, evaluation_id, scope_kind, scope_id, scenario_key,
  process_code, subject_kind, subject_id, algorithm_version,
  input_schema_version, output_schema_version, numeric_backend_version,
  canonical_encoder_version, input_fingerprint, policy_fingerprint,
  execution, completion, assessment, output_json, output_sha256,
  evidence_json, evidence_sha256, completed_at_utc, origin_device_id
) VALUES (
  'project-a', '$revisionId', '{}', '$nodeHash', '$evaluationId',
  'DESIGN', 'design', 'NORMAL', 'CCTV-01', 'CAMERA', 'camera-a',
  'electra.elv5.cctv-01.algorithm.v1', '1', '1',
  'electra.elv5.exact-bounded-rational.v1', 'electra.canonical-json.v1',
  '${_hash('f')}', '${_hash('q')}', 'COMPLETED', 'COMPLETE', 'PASS',
  '{}', '${_hash('o')}', '{}', '${_hash('e')}', 0, 'test'
)
''');

String _hash(String seed) => List<String>.filled(64, seed).join();
