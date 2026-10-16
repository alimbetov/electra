import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports a real historical ELV4 migration fixture', () async {
    final outputPath = Platform.environment['ELV4_HISTORICAL_FIXTURE_OUT'];
    final expectedVersion = int.tryParse(
      Platform.environment['ELV4_HISTORICAL_VERSION'] ?? '',
    );
    if (outputPath == null || expectedVersion == null) {
      fail('Historical fixture output path and schema version are required.');
    }

    final output = File(outputPath);
    if (output.existsSync()) output.deleteSync();
    output.parent.createSync(recursive: true);

    final database = AppDatabase(NativeDatabase(output));
    addTearDown(database.close);
    await database.customSelect('SELECT 1').getSingle();
    expect(database.schemaVersion, expectedVersion);

    await database.customStatement('''
INSERT INTO projects (
  id, name, measurement_system, default_structural_height_mm,
  default_finished_ceiling_height_mm, created_at, updated_at, origin_device_id
) VALUES (
  'hist-project', 'Historical project', 'metric', 3000, 2700,
  1700000000, 1700000000, 'historical-fixture'
)
''');
    await database.customStatement('''
INSERT INTO project_design_revisions (
  id, project_id, code, sequence, state, revision,
  created_at, updated_at, origin_device_id
) VALUES (
  'hist-revision', 'hist-project', 'R-HIST', 1, 'WORKING', 7,
  1700000000, 1700000000, 'historical-fixture'
)
''');
    await database.customStatement('''
INSERT INTO design_revision_physical_snapshots (
  design_revision_id, project_id, schema_version, payload_json,
  payload_sha256, created_at, origin_device_id
) VALUES (
  'hist-revision', 'hist-project', 9, '{"legacy":"stable"}',
  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  1700000000, 'historical-fixture'
)
''');
    await database.customStatement('''
INSERT INTO project_derived_results (
  project_id, node_key, fingerprint, inputs_json, dependencies_json,
  result_json, state, revision, created_at, updated_at, origin_device_id
) VALUES (
  'hist-project', 'legacy-result',
  'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  '{"legacyInput":1}', '[]', '{"legacyResult":42}', 'CURRENT', 5,
  1700000000, 1700000000, 'historical-fixture'
)
''');
    if (expectedVersion >= 22) {
      await database.customStatement('''
INSERT INTO power_operating_scenarios (
  project_id, design_revision_id, id, revision, created_at, updated_at,
  deleted_at, origin_device_id, role, policy_refs_json
) VALUES (
  'hist-project', 'hist-revision', 'HIST-NORMAL', 3,
  1700000000, 1700000000, NULL, 'historical-fixture', 'NORMAL', '[]'
)
''');
    }

    final userVersion = await database
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((row) => row.read<int>('user_version'));
    expect(userVersion, expectedVersion);
    expect(await database.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
