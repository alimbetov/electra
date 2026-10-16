import 'dart:io';

import 'package:drift/native.dart';

import '../lib/data/database/app_database.dart';

Future<void> main(List<String> args) async {
  if (args.length != 2) {
    stderr.writeln('usage: export.dart <sqlite-path> <expected-schema-version>');
    exitCode = 64;
    return;
  }
  final output = File(args[0]);
  final expectedVersion = int.parse(args[1]);
  if (output.existsSync()) output.deleteSync();
  output.parent.createSync(recursive: true);

  final database = AppDatabase(NativeDatabase(output));
  try {
    await database.customSelect('SELECT 1').getSingle();
    if (database.schemaVersion != expectedVersion) {
      throw StateError(
        'Historical source schema is ${database.schemaVersion}, '
        'expected $expectedVersion.',
      );
    }
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
    if (userVersion != expectedVersion) {
      throw StateError(
        'Historical SQLite user_version is $userVersion, expected $expectedVersion.',
      );
    }
  } finally {
    await database.close();
  }
}
