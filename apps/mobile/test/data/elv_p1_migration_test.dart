import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema 17 upgrades to P1 schema 18 without losing existing project', () async {
    final dir = await Directory.systemTemp.createTemp('electra-elv3-p1-migration-');
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

    await db.customStatement('DROP TABLE command_execution_records');
    await db.customStatement('DROP TABLE elv_cables');
    await db.customStatement('PRAGMA user_version = 17');
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    final project = await (db.select(db.projects)
          ..where((row) => row.id.equals('existing-project')))
        .getSingle();
    expect(project.name, 'Existing project');

    final tables = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('elv_cables','command_execution_records') ORDER BY name",
    ).get();
    expect(tables.map((row) => row.read<String>('name')).toList(), [
      'command_execution_records',
      'elv_cables',
    ]);
    await db.close();
  });
}
