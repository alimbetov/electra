import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'P8 T04/T07 frozen R1 power capture survives create-next and reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('electra-elv4-p8-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');
      final now = DateTime.utc(2026, 10, 15, 16);

      var db = AppDatabase(NativeDatabase(file));
      await _seedProject(db, now);
      var revisions = _revisionRepository(db, now);

      final bootstrap = await revisions.bootstrap(
        const BootstrapProjectDesignRevisionCommand(
          commandId: 'p8-bootstrap-r1',
          projectId: 'project-p8',
          revisionId: 'REV-1',
          code: 'R1',
        ),
      );
      expect(bootstrap, isA<ElvCommandSuccess<ProjectDesignRevision>>());

      final frozen = await revisions.freeze(
        const FreezeProjectDesignRevisionCommand(
          commandId: 'p8-freeze-r1',
          projectId: 'project-p8',
          designRevisionId: 'REV-1',
          expectedRevision: 1,
        ),
      );
      expect(frozen, isA<ElvCommandSuccess<ProjectDesignRevision>>());

      final r1PowerBefore =
          await (db.select(db.designRevisionPowerSnapshots)
            ..where((row) => row.designRevisionId.equals('REV-1'))).getSingle();
      final r1ManifestBefore =
          await (db.select(db.designRevisionSnapshotManifests)
            ..where((row) => row.designRevisionId.equals('REV-1'))).getSingle();
      final runtimeBefore = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'test',
        now: () => now,
      );
      final r1Before = await runtimeBefore.readRevision(
        projectId: 'project-p8',
        designRevisionId: 'REV-1',
      );
      expect(r1Before.kind, PowerRevisionReadKind.capturedEmpty);
      expect(r1Before.mutationAllowed, isFalse);

      final next = await revisions.createNext(
        const CreateNextWorkingDesignRevisionCommand(
          commandId: 'p8-create-r2',
          projectId: 'project-p8',
          newRevisionId: 'REV-2',
          code: 'R2',
          basedOnRevisionId: 'REV-1',
        ),
      );
      expect(next, isA<ElvCommandSuccess<ProjectDesignRevision>>());

      final r2BeforeReopen = await runtimeBefore.readRevision(
        projectId: 'project-p8',
        designRevisionId: 'REV-2',
      );
      expect(r2BeforeReopen.kind, PowerRevisionReadKind.working);
      expect(r2BeforeReopen.mutationAllowed, isTrue);

      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);
      revisions = _revisionRepository(db, now);

      final runtimeAfter = DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'test',
        now: () => now,
      );
      final r1After = await runtimeAfter.readRevision(
        projectId: 'project-p8',
        designRevisionId: 'REV-1',
      );
      final r2After = await runtimeAfter.readRevision(
        projectId: 'project-p8',
        designRevisionId: 'REV-2',
      );
      final r1PowerAfter =
          await (db.select(db.designRevisionPowerSnapshots)
            ..where((row) => row.designRevisionId.equals('REV-1'))).getSingle();
      final r1ManifestAfter =
          await (db.select(db.designRevisionSnapshotManifests)
            ..where((row) => row.designRevisionId.equals('REV-1'))).getSingle();

      expect(r1After.kind, PowerRevisionReadKind.capturedEmpty);
      expect(r1After.mutationAllowed, isFalse);
      expect(r2After.kind, PowerRevisionReadKind.working);
      expect(r2After.mutationAllowed, isTrue);
      expect(r1PowerAfter.powerSha256, r1PowerBefore.powerSha256);
      expect(r1PowerAfter.payloadJson, r1PowerBefore.payloadJson);
      expect(r1PowerAfter.physicalSha256, r1PowerBefore.physicalSha256);
      expect(r1ManifestAfter.powerSha256, r1ManifestBefore.powerSha256);
      expect(r1ManifestAfter.physicalSha256, r1ManifestBefore.physicalSha256);

      final context = await revisions.context('project-p8');
      expect(context.latestFrozenRevisionId, 'REV-1');
      expect(context.workingDesignRevisionId, 'REV-2');
    },
  );

  test(
    'P8 T03/T07 legacy frozen revision stays NOT_CAPTURED after reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('electra-elv4-p8-r0-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/electra.sqlite');
      final now = DateTime.utc(2026, 10, 15, 16, 30);

      var db = AppDatabase(NativeDatabase(file));
      await _seedProject(db, now);
      await db
          .into(db.projectDesignRevisions)
          .insert(
            ProjectDesignRevisionsCompanion.insert(
              id: 'LEGACY-R0',
              projectId: 'project-p8',
              code: 'R0',
              sequence: 1,
              state: 'FROZEN',
              revision: const Value(1),
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'legacy-seed',
            ),
          );

      final before = await DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'test',
        now: () => now,
      ).readRevision(projectId: 'project-p8', designRevisionId: 'LEGACY-R0');
      expect(before.kind, PowerRevisionReadKind.notCaptured);
      expect(before.mutationAllowed, isFalse);
      expect(before.capturedPayload, isNull);
      expect(before.reasonCode, 'ELV4_POWER_NOT_CAPTURED');
      expect(await db.select(db.designRevisionPowerSnapshots).get(), isEmpty);

      await db.close();
      db = AppDatabase(NativeDatabase(file));
      addTearDown(db.close);

      final after = await DriftPowerPublicationRuntime(
        db,
        originDeviceId: 'test',
        now: () => now,
      ).readRevision(projectId: 'project-p8', designRevisionId: 'LEGACY-R0');
      expect(after.kind, PowerRevisionReadKind.notCaptured);
      expect(after.mutationAllowed, isFalse);
      expect(after.capturedPayload, isNull);
      expect(after.reasonCode, 'ELV4_POWER_NOT_CAPTURED');
      expect(await db.select(db.designRevisionPowerSnapshots).get(), isEmpty);
    },
  );
}

Future<void> _seedProject(AppDatabase db, DateTime now) async {
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'project-p8',
          name: 'ELV4 P8 historical invariance',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DriftElvDesignRevisionRepository _revisionRepository(
  AppDatabase db,
  DateTime now,
) => DriftElvDesignRevisionRepository(
  db,
  originDeviceId: 'test',
  now: () => now,
);
