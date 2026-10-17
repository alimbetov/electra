import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final fixturePath = Platform.environment['ELV4_HISTORICAL_FIXTURE'];
  final originVersion = int.tryParse(
    Platform.environment['ELV4_HISTORICAL_VERSION'] ?? '',
  );
  final skipReason = fixturePath == null || originVersion == null
      ? 'Executed by scripts/ci/run-elv4-historical-migration-matrix.sh.'
      : false;

  test('real historical origin migrates to v23 without inventing power facts', () async {
    final source = File(fixturePath!);
    expect(source.existsSync(), isTrue);
    final working = File(
      '${Directory.systemTemp.path}/elv4-migration-$originVersion-${DateTime.now().microsecondsSinceEpoch}.sqlite',
    );
    await source.copy(working.path);
    addTearDown(() async {
      if (working.existsSync()) await working.delete();
    });

    final db = AppDatabase(NativeDatabase(working));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').getSingle();

    final userVersion = await db
        .customSelect('PRAGMA user_version')
        .getSingle()
        .then((row) => row.read<int>('user_version'));
    expect(userVersion, 23);
    expect(db.schemaVersion, 23);

    final project = await db
        .customSelect("SELECT name FROM projects WHERE id = 'hist-project'")
        .getSingle();
    expect(project.read<String>('name'), 'Historical project');

    final revision = await db
        .customSelect(
          "SELECT code, sequence, state, revision FROM project_design_revisions WHERE id = 'hist-revision'",
        )
        .getSingle();
    expect(revision.read<String>('code'), 'R-HIST');
    expect(revision.read<int>('sequence'), 1);
    expect(revision.read<String>('state'), 'WORKING');
    expect(revision.read<int>('revision'), 7);

    final physical = await db
        .customSelect(
          "SELECT schema_version, payload_json, payload_sha256 FROM design_revision_physical_snapshots WHERE design_revision_id = 'hist-revision'",
        )
        .getSingle();
    expect(physical.read<int>('schema_version'), 9);
    expect(physical.read<String>('payload_json'), '{"legacy":"stable"}');
    expect(
      physical.read<String>('payload_sha256'),
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );

    final legacyResult = await db
        .customSelect(
          "SELECT fingerprint, result_json, state, revision FROM project_derived_results WHERE project_id = 'hist-project' AND node_key = 'legacy-result'",
        )
        .getSingle();
    expect(
      legacyResult.read<String>('fingerprint'),
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    );
    expect(legacyResult.read<String>('result_json'), '{"legacyResult":42}');
    expect(legacyResult.read<String>('state'), 'CURRENT');
    expect(legacyResult.read<int>('revision'), 5);

    final scenarioCount = await db
        .customSelect(
          "SELECT COUNT(*) AS c FROM power_operating_scenarios WHERE design_revision_id = 'hist-revision'",
        )
        .getSingle()
        .then((row) => row.read<int>('c'));
    if (originVersion == 21) {
      expect(scenarioCount, 0);
    } else {
      expect(originVersion, 22);
      expect(scenarioCount, 1);
      final scenario = await db
          .customSelect(
            "SELECT role, revision, policy_refs_json FROM power_operating_scenarios WHERE design_revision_id = 'hist-revision' AND id = 'HIST-NORMAL'",
          )
          .getSingle();
      expect(scenario.read<String>('role'), 'NORMAL');
      expect(scenario.read<int>('revision'), 3);
      expect(scenario.read<String>('policy_refs_json'), '[]');
    }

    final inventedPowerRows = await db
        .customSelect('''
SELECT
  (SELECT COUNT(*) FROM power_port_bindings) +
  (SELECT COUNT(*) FROM power_component_bindings) +
  (SELECT COUNT(*) FROM power_transfer_bindings) +
  (SELECT COUNT(*) FROM power_load_bindings) +
  (SELECT COUNT(*) FROM power_capacity_groups) +
  (SELECT COUNT(*) FROM power_supply_requirements) +
  (SELECT COUNT(*) FROM poe_delivery_bindings) +
  (SELECT COUNT(*) FROM backup_assemblies) +
  (SELECT COUNT(*) FROM battery_bank_bindings) +
  (SELECT COUNT(*) FROM power_evaluation_records) +
  (SELECT COUNT(*) FROM power_evaluation_pointers) AS c
''')
        .getSingle()
        .then((row) => row.read<int>('c'));
    expect(inventedPowerRows, 0);

    final historyRows = await db
        .customSelect('''
SELECT
  (SELECT COUNT(*) FROM elv_revision_aggregate_evidence_records) +
  (SELECT COUNT(*) FROM elv_revision_command_history_operations) +
  (SELECT COUNT(*) FROM elv_revision_command_history_cursors) +
  (SELECT COUNT(*) FROM elv_revision_command_history_executions) AS c
''')
        .getSingle()
        .then((row) => row.read<int>('c'));
    expect(historyRows, 0);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  }, skip: skipReason);
}
