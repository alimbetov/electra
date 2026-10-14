import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema 18 upgrades to P2 schema 19 without losing P1 cable', () async {
    final dir = await Directory.systemTemp.createTemp('electra-elv3-p2-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/migration.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    final now = DateTime.utc(2026, 10, 14);
    await db.into(db.projects).insert(
          ProjectsCompanion.insert(
            id: 'existing-project',
            name: 'Existing project',
            measurementSystem: 'metric',
            defaultStructuralHeightMm: 3000,
            defaultFinishedCeilingHeightMm: 2700,
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'migration-test',
          ),
        );

    for (final table in [
      'cable_termination_mappings',
      'cable_resource_claims',
      'cable_allocation_resource_selections',
      'cable_allocations',
    ]) {
      await db.customStatement('DROP TABLE $table');
    }
    await db.customStatement('PRAGMA user_version = 18');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final project = await (db.select(db.projects)
          ..where((row) => row.id.equals('existing-project')))
        .getSingle();
    expect(project.name, 'Existing project');

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('cable_allocations','cable_allocation_resource_selections','cable_resource_claims','cable_termination_mappings') ORDER BY name",
    ).get();
    expect(tables.map((row) => row.read<String>('name')).toList(), [
      'cable_allocation_resource_selections',
      'cable_allocations',
      'cable_resource_claims',
      'cable_termination_mappings',
    ]);
    await db.close();
  });
}
