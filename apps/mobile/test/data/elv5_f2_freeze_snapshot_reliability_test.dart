import 'dart:io';
import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/application/elv_failure_probe.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:electra_mobile/data/repositories/drift_power_publication_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_discipline_snapshot_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_lan_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'F2 global real freeze rolls back all sections and preserves captured discipline across restart and live-source changes',
    () async {
      final dir = await Directory.systemTemp.createTemp('f2-freeze-sections-');
      final file = File('${dir.path}/database.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await seedF2LanTopology(db);
      await seedF2LanRoute(db);
      await replaceF2LanAggregate(
        db,
        operation: 'REPLACE_LINK_COMPOSITION',
        commandId: 'seed-link',
        payload: {
          'linkId': 'link-1',
          'orderedSections': [
            {
              'ordinal': 0,
              'realizedSectionId': 'traversal-1',
              'classification': 'PERMANENT',
            },
          ],
          'policyBindingId': 'unresolved-policy',
        },
      );
      final life = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.lan01,
        subjectKind: 'LINK',
        subjectId: 'link-1',
      )..db = db;
      final command = life.command('first', 2, 0);
      final logical =
          (await life.runtime(db).service.execute(command)).logicalResultJson;
      final before = (await life.evaluation()).data;
      final probe = _FreezeFault(db);
      await expectLater(
        _revision(db, probe).freeze(_freeze(2)),
        throwsA(predicate((e) => e.toString().contains('F2_FREEZE_FAULT'))),
      );
      expect(probe.observedAllSections, true);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      life.db = db;
      for (final table in [
        'design_revision_physical_snapshots',
        'design_revision_power_snapshots',
        'design_revision_discipline_snapshots',
        'design_revision_snapshot_manifests',
      ]) {
        expect(await db.customSelect('SELECT * FROM $table').get(), isEmpty);
      }
      expect(await life.revision(), 2);
      expect((await life.evaluation()).data, before);
      final result = await _revision(db).freeze(_freeze(2));
      expect(result, isA<ElvCommandSuccess<ProjectDesignRevision>>());
      final captured = await _store(
        db,
      ).read(projectId: 'p', designRevisionId: 'd');
      expect(captured.kind, Elv5FrozenDisciplineReadKind.captured);
      expect(
        (captured.payload!['facts'] as Map)['link_section_assignments'],
        isNotEmpty,
      );
      final manifest =
          (await db
                  .customSelect(
                    "SELECT * FROM design_revision_snapshot_manifests WHERE design_revision_id='d'",
                  )
                  .getSingle())
              .data;
      expect(manifest['manifest_schema'], elv5SnapshotManifestSchema);
      expect(manifest['manifest_sha256'], elvSnapshotManifestHash(manifest));
      await db.customStatement(
        "UPDATE link_section_assignments SET section_role='PATCH'",
      );
      await db.customStatement(
        "UPDATE surface_patches SET boundary_json='[[0,0],[1,0],[1,1],[0,1]]'",
      );
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      life.db = db;
      expect(
        (await _store(db).read(projectId: 'p', designRevisionId: 'd')).payload,
        captured.payload,
      );
      expect(
        (await life.runtime(db).service.execute(command)).logicalResultJson,
        logical,
      );
      expect((await life.evaluation()).data, before);
      expect(
        (await DriftPowerPublicationRuntime(
          db,
          originDeviceId: 'f2',
        ).readRevision(projectId: 'p', designRevisionId: 'd')).mutationAllowed,
        false,
      );
      final snapshot = (await db
              .customSelect(
                "SELECT payload_json FROM design_revision_discipline_snapshots WHERE design_revision_id='d'",
              )
              .getSingle())
          .read<String>('payload_json');
      await db.customStatement(
        "UPDATE design_revision_discipline_snapshots SET payload_json='{}' WHERE design_revision_id='d'",
      );
      await expectLater(
        _store(db).read(projectId: 'p', designRevisionId: 'd'),
        throwsA(
          predicate(
            (e) => e.toString().contains('ELV5_FROZEN_SECTION_HASH_MISMATCH'),
          ),
        ),
      );
      await db.customStatement(
        "UPDATE design_revision_discipline_snapshots SET payload_json=? WHERE design_revision_id='d'",
        [snapshot],
      );
      expect(
        (await _store(db).read(projectId: 'p', designRevisionId: 'd')).payload,
        captured.payload,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
  test(
    'F2 global new empty discipline capture is distinct from legacy ELV5_NOT_CAPTURED',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await seedF2FireTopology(db);
      expect(
        await _revision(db).freeze(_freeze(1)),
        isA<ElvCommandSuccess<ProjectDesignRevision>>(),
      );
      final captured = await _store(
        db,
      ).read(projectId: 'p', designRevisionId: 'd');
      expect(captured.kind, Elv5FrozenDisciplineReadKind.capturedEmpty);
      expect(captured.reasonCode, isNull);
      final row =
          (await db
                  .customSelect(
                    "SELECT * FROM design_revision_snapshot_manifests WHERE design_revision_id='d'",
                  )
                  .getSingle())
              .data;
      final legacy = <String, Object?>{
        ...row,
        'manifest_schema': 'electra.elv4-snapshot-manifest.v1',
        'discipline_section_schema': null,
        'discipline_sha256': null,
      };
      await db.customStatement(
        "DELETE FROM design_revision_discipline_snapshots WHERE design_revision_id='d'",
      );
      await db.customUpdate(
        "UPDATE design_revision_snapshot_manifests SET manifest_schema=?,manifest_sha256=?,discipline_section_schema=NULL,discipline_sha256=NULL WHERE design_revision_id='d'",
        variables: [
          Variable.withString('electra.elv4-snapshot-manifest.v1'),
          Variable.withString(elvSnapshotManifestHash(legacy)),
        ],
      );
      final historical =
          (await db
                  .customSelect(
                    "SELECT * FROM design_revision_snapshot_manifests WHERE design_revision_id='d'",
                  )
                  .getSingle())
              .data;
      final read = await _store(db).read(projectId: 'p', designRevisionId: 'd');
      expect(read.kind, Elv5FrozenDisciplineReadKind.notCaptured);
      expect(read.reasonCode, 'ELV5_NOT_CAPTURED');
      expect(
        (await DriftPowerPublicationRuntime(
          db,
          originDeviceId: 'f2',
        ).readRevision(projectId: 'p', designRevisionId: 'd')).mutationAllowed,
        false,
      );
      expect(
        (await db
                .customSelect(
                  "SELECT * FROM design_revision_snapshot_manifests WHERE design_revision_id='d'",
                )
                .getSingle())
            .data,
        historical,
      );
    },
  );
}

DriftElv5DisciplineSnapshotStore _store(AppDatabase db) =>
    DriftElv5DisciplineSnapshotStore(
      db,
      originDeviceId: 'f2-freeze',
      nowUtc: Elv5F2ProductionLifecycle.now,
    );
DriftElvDesignRevisionRepository _revision(
  AppDatabase db, [
  ElvFailureProbe? probe,
]) => DriftElvDesignRevisionRepository(
  db,
  originDeviceId: 'f2-freeze',
  now: Elv5F2ProductionLifecycle.now,
  failureProbe: probe,
);
FreezeProjectDesignRevisionCommand _freeze(int expected) =>
    FreezeProjectDesignRevisionCommand(
      commandId: 'freeze',
      projectId: 'p',
      designRevisionId: 'd',
      expectedRevision: expected,
    );

final class _FreezeFault implements ElvFailureProbe {
  _FreezeFault(this.db);
  final AppDatabase db;
  bool observedAllSections = false;
  @override
  Future<void> hit(String point) async {
    if (point != ElvFailurePoints.p3FreezeAfterSnapshotInsert) return;
    for (final table in [
      'design_revision_physical_snapshots',
      'design_revision_power_snapshots',
      'design_revision_discipline_snapshots',
    ]) {
      expect(await db.customSelect('SELECT * FROM $table').get(), hasLength(1));
    }
    expect(
      (await db
              .customSelect(
                'SELECT discipline_sha256 FROM design_revision_snapshot_manifests',
              )
              .getSingle())
          .readNullable<String>('discipline_sha256'),
      isNotNull,
    );
    observedAllSections = true;
    throw StateError('F2_FREEZE_FAULT');
  }
}
