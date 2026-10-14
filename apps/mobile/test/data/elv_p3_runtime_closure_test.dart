import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seedProject(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14, 11);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project-1',
          name: 'ELV3 runtime',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DriftElvDesignRevisionRepository _repository(AppDatabase db) =>
    DriftElvDesignRevisionRepository(
      db,
      originDeviceId: 'test',
      now: () => DateTime.utc(2026, 10, 14, 11, 30),
    );

void main() {
  test(
    'schema 20 exposes canonical P3 tables and keeps legacy CableRuns',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 20);
      final names =
          (await db
                  .customSelect(
                    "SELECT name FROM sqlite_master WHERE type='table'",
                  )
                  .get())
              .map((row) => row.read<String>('name'))
              .toSet();
      expect(
        names,
        containsAll({
          'project_design_revisions',
          'design_revision_physical_snapshots',
          'canonical_cable_runs',
          'cable_run_traversals',
          'route_handoffs',
          'route_bend_evidence',
          'legacy_route_adoptions',
          'cable_runs',
        }),
      );
    },
  );

  test(
    'bootstrap freeze close/reopen preserves frozen snapshot exactly',
    () async {
      final dir = await Directory.systemTemp.createTemp('electra-elv3-p3-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');

      var db = AppDatabase(NativeDatabase(file));
      await _seedProject(db);
      final repo = _repository(db);
      final boot = await repo.bootstrap(
        const BootstrapProjectDesignRevisionCommand(
          commandId: 'cmd-bootstrap',
          projectId: 'project-1',
          revisionId: 'REV-1',
          code: 'R1',
        ),
      );
      expect(boot, isA<ElvCommandSuccess<ProjectDesignRevision>>());
      final frozen = await repo.freeze(
        const FreezeProjectDesignRevisionCommand(
          commandId: 'cmd-freeze',
          projectId: 'project-1',
          designRevisionId: 'REV-1',
          expectedRevision: 1,
        ),
      );
      expect(frozen, isA<ElvCommandSuccess<ProjectDesignRevision>>());
      final before =
          await db.select(db.designRevisionPhysicalSnapshots).getSingle();
      expect(before.payloadSha256, isNotEmpty);
      expect(jsonDecode(before.payloadJson), {'runs': []});
      await db.close();

      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      final after =
          await db.select(db.designRevisionPhysicalSnapshots).getSingle();
      expect(after.designRevisionId, before.designRevisionId);
      expect(after.payloadJson, before.payloadJson);
      expect(after.payloadSha256, before.payloadSha256);
      final context = await _repository(db).context('project-1');
      expect(context.workingDesignRevisionId, isNull);
      expect(context.latestFrozenRevisionId, 'REV-1');
    },
  );

  test('create-next materializes an independent WORKING revision', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final repo = _repository(db);
    await repo.bootstrap(
      const BootstrapProjectDesignRevisionCommand(
        commandId: 'b',
        projectId: 'project-1',
        revisionId: 'REV-1',
        code: 'R1',
      ),
    );
    await repo.freeze(
      const FreezeProjectDesignRevisionCommand(
        commandId: 'f',
        projectId: 'project-1',
        designRevisionId: 'REV-1',
        expectedRevision: 1,
      ),
    );
    final next = await repo.createNext(
      const CreateNextWorkingDesignRevisionCommand(
        commandId: 'n',
        projectId: 'project-1',
        newRevisionId: 'REV-2',
        code: 'R2',
        basedOnRevisionId: 'REV-1',
      ),
    );
    expect(next, isA<ElvCommandSuccess<ProjectDesignRevision>>());
    final context = await repo.context('project-1');
    expect(context.workingDesignRevisionId, 'REV-2');
    expect(context.latestFrozenRevisionId, 'REV-1');
    final old =
        await (db.select(db.projectDesignRevisions)
          ..where((row) => row.id.equals('REV-1'))).getSingle();
    expect(old.state, 'FROZEN');
  });
}
