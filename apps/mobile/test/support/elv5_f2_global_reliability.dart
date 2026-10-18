import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/application/elv_failure_probe.dart';
import 'package:electra_mobile/application/elv5/commands/elv5_replacement_command_runner.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_discipline_snapshot_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _enabled = bool.fromEnvironment('ELECTRA_F2_GLOBAL_QUALIFICATION');
const _publicationTables = [
  'discipline_evaluation_records',
  'discipline_dependency_index',
  'discipline_evaluation_pointers',
  'command_execution_records',
];
const _freezeTables = [
  'project_design_revisions',
  ..._publicationTables,
  'design_revision_physical_snapshots',
  'design_revision_power_snapshots',
  'design_revision_discipline_snapshots',
  'design_revision_snapshot_manifests',
];
DateTime _now() => DateTime.utc(2026, 10, 17, 15);
DriftElv5CalculationRuntime _runtime(AppDatabase db) =>
    DriftElv5CalculationRuntime.create(
      db,
      originDeviceId: 'f2-global',
      nowUtc: _now,
    );
Future<Map<String, Object?>> _state(AppDatabase db, List<String> tables) async {
  final state = <String, Object?>{};
  for (final table in tables) {
    state[table] =
        (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
            .map((r) => Map<String, Object?>.from(r.data))
            .toList();
  }
  return state;
}

Future<(Directory, File)> _clone(AppDatabase source) async {
  final dir = await Directory.systemTemp.createTemp('f2-global-');
  final file = File('${dir.path}/qualified.sqlite');
  try {
    await source.customStatement('VACUUM INTO ?', [file.path]);
    return (dir, file);
  } catch (_) {
    await dir.delete(recursive: true);
    rethrow;
  }
}

void _emit(String code, String stage, Map<String, Object?> evidence) {
  const source = String.fromEnvironment('ELECTRA_SOURCE_SHA');
  expect(
    source,
    isNotEmpty,
    reason: 'Global qualification must have an exact build source',
  );
  print(
    'ELV5_F2_WITNESS:${jsonEncode({'schema': 'electra.elv5-f2-lifecycle-event.v1', 'processCode': code, 'sourceSha': source, 'stage': stage, ...evidence})}',
  );
}

Elv5WireCommandEnvelope _copy(Elv5WireCommandEnvelope c, String id) =>
    Elv5WireCommandEnvelope(
      operation: c.operation,
      projectId: c.projectId,
      designRevisionId: c.designRevisionId,
      commandId: id,
      expectedDesignRowRevision: c.expectedDesignRowRevision,
      expectedRows: c.expectedRows,
      reviewedImpactFingerprint: c.reviewedImpactFingerprint,
      payload: c.payload,
    );

/// Clone the actual authoritative seeded SQLite dataset, preserving the main
/// lifecycle's generations. Every failing publication is reopened before the
/// next fault; no fake resolver, executor or pointer adapter participates.
Future<void> verifyF2GlobalPublication(
  AppDatabase source,
  Elv5WireCommandEnvelope command,
  String code,
) async {
  if (!_enabled) return;
  final (dir, file) = await _clone(source);
  var db = AppDatabase(NativeDatabase(file));
  try {
    final baseline = await _state(db, _publicationTables);
    for (final table in _publicationTables) {
      await db.customStatement(
        "CREATE TEMP TRIGGER f2_publication_fault BEFORE INSERT ON $table BEGIN SELECT RAISE(ABORT,'F2_PUBLICATION_FAULT'); END",
      );
      await expectLater(
        _runtime(db).service.execute(command),
        throwsA(
          predicate((e) => e.toString().contains('F2_PUBLICATION_FAULT')),
        ),
      );
      await db.customStatement('DROP TRIGGER f2_publication_fault');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      expect(
        await _state(db, _publicationTables),
        baseline,
        reason: '$code must roll back $table fault durably',
      );
    }
    _emit(code, 'GLOBAL_PUBLICATION_ROLLBACK', {
      'faultTables': _publicationTables,
      'reopenedAfterEveryFault': true,
    });
    final other = AppDatabase(NativeDatabase(file));
    try {
      await db.customStatement('PRAGMA busy_timeout=5000');
      await other.customStatement('PRAGMA busy_timeout=5000');
      await other.customSelect('SELECT 1').get();
      Future<({AppDatabase db, Elv5WireCommandEnvelope command, Object? error})>
      attempt(AppDatabase database, Elv5WireCommandEnvelope c) async {
        try {
          await _runtime(database).service.execute(c);
          return (db: database, command: c, error: null);
        } catch (e) {
          return (db: database, command: c, error: e);
        }
      }

      final results = await Future.wait([
        attempt(db, _copy(command, 'global-race-a')),
        attempt(other, _copy(command, 'global-race-b')),
      ]);
      expect(results.where((r) => r.error == null), hasLength(1));
      final loser = results.singleWhere((r) => r.error != null);
      var error = loser.error!;
      if (error.toString().contains('SQLITE_BUSY') ||
          error.toString().contains('database is locked')) {
        error =
            (await attempt(loser.db, loser.command)).error ??
            StateError('Second race writer committed');
      }
      expect(
        error,
        isA<Elv5ReplacementCommandException>().having(
          (e) => e.code,
          'code',
          'ELV5_POINTER_GENERATION_CONFLICT',
        ),
      );
      final hash =
          (command.payload['expectedPointerGenerations'] as Map).keys.single
              as String;
      final row =
          (await db
              .customSelect(
                "SELECT generation FROM discipline_evaluation_pointers WHERE logical_node_key_sha256='$hash'",
              )
              .getSingle());
      expect(row.read<int>('generation'), 1);
      _emit(code, 'GLOBAL_INDEPENDENT_CAS', {
        'connections': 2,
        'committedWriters': 1,
        'loserCode': 'ELV5_POINTER_GENERATION_CONFLICT',
        'pointerGeneration': 1,
      });
    } finally {
      await other.close();
    }
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  } finally {
    await db.close();
    await dir.delete(recursive: true);
  }
}

/// The public revision freeze is faulted after all sections exist, then retried
/// on durable state. Captured discipline/physical/power manifests survive reopen
/// and committed replay, while a new calculation fails closed.
Future<void> verifyF2GlobalFreeze(
  AppDatabase source,
  Elv5WireCommandEnvelope committed,
  String logical,
  String code,
) async {
  if (!_enabled) return;
  final (dir, file) = await _clone(source);
  var db = AppDatabase(NativeDatabase(file));
  try {
    final revision = (await db
            .customSelect(
              "SELECT revision FROM project_design_revisions WHERE id='d'",
            )
            .getSingle())
        .read<int>('revision');
    final before = await _state(db, _freezeTables);
    final command = FreezeProjectDesignRevisionCommand(
      commandId: 'global-freeze',
      projectId: 'p',
      designRevisionId: 'd',
      expectedRevision: revision,
    );
    final probe = _FreezeFault();
    await expectLater(
      DriftElvDesignRevisionRepository(
        db,
        originDeviceId: 'f2-global',
        now: _now,
        failureProbe: probe,
      ).freeze(command),
      throwsA(
        predicate((e) => e.toString().contains('F2_GLOBAL_FREEZE_FAULT')),
      ),
    );
    expect(probe.hitExpectedPoint, true);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    expect(await _state(db, _freezeTables), before);
    expect(
      await DriftElvDesignRevisionRepository(
        db,
        originDeviceId: 'f2-global',
        now: _now,
      ).freeze(command),
      isA<ElvCommandSuccess<ProjectDesignRevision>>(),
    );
    final reader = DriftElv5DisciplineSnapshotStore(
      db,
      originDeviceId: 'f2-global',
      nowUtc: _now,
    );
    final captured = await reader.read(projectId: 'p', designRevisionId: 'd');
    expect(captured.kind, Elv5FrozenDisciplineReadKind.captured);
    final manifest =
        (await db
                .customSelect(
                  "SELECT * FROM design_revision_snapshot_manifests WHERE design_revision_id='d'",
                )
                .getSingle())
            .data;
    final section =
        (await db
                .customSelect(
                  "SELECT * FROM design_revision_discipline_snapshots WHERE design_revision_id='d'",
                )
                .getSingle())
            .data;
    expect(manifest['manifest_schema'], 'electra.elv4-snapshot-manifest.v1');
    expect(manifest['manifest_sha256'], elvSnapshotManifestHash(manifest));
    expect(manifest['discipline_sha256'], isNull);
    expect(section['physical_sha256'], manifest['physical_sha256']);
    expect(section['power_sha256'], manifest['power_sha256']);
    expect(section['section_schema'], elv5DisciplineSectionSchema);
    await expectLater(
      reader.capture(
        projectId: 'p',
        designRevisionId: 'd',
        expectedRevision: revision,
        physicalSha256: manifest['physical_sha256']! as String,
        powerSha256: manifest['power_sha256']! as String,
      ),
      throwsA(
        predicate(
          (e) => e.toString().contains('ELV5_DESIGN_REVISION_READ_ONLY'),
        ),
      ),
    );
    final after = await _state(db, _freezeTables);
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    expect(
      (await DriftElv5DisciplineSnapshotStore(
        db,
        originDeviceId: 'f2-global',
        nowUtc: _now,
      ).read(projectId: 'p', designRevisionId: 'd')).payload,
      captured.payload,
    );
    final replay = await _runtime(db).service.execute(committed);
    expect(replay.replayed, true);
    expect(replay.logicalResultJson, logical);
    final hash =
        (committed.payload['expectedPointerGenerations'] as Map).keys.single
            as String;
    final generation = (await db
            .customSelect(
              "SELECT generation FROM discipline_evaluation_pointers WHERE logical_node_key_sha256='$hash'",
            )
            .getSingle())
        .read<int>('generation');
    final frozenCommand = Elv5WireCommandEnvelope(
      operation: committed.operation,
      projectId: 'p',
      designRevisionId: 'd',
      commandId: 'global-frozen-new',
      expectedDesignRowRevision: revision + 1,
      expectedRows: const {},
      reviewedImpactFingerprint: committed.reviewedImpactFingerprint,
      payload: {
        ...committed.payload,
        'expectedPointerGenerations': {hash: generation},
      },
    );
    await expectLater(
      _runtime(db).service.execute(frozenCommand),
      throwsA(
        isA<Elv5ReplacementCommandException>().having(
          (e) => e.code,
          'code',
          'ELV5_DESIGN_REVISION_READ_ONLY',
        ),
      ),
    );
    expect(await _state(db, _freezeTables), after);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    _emit(code, 'GLOBAL_FREEZE_MANIFEST', {
      'publicFreezeApi': true,
      'faultAfterAllSections': true,
      'restartReplayIdentical': true,
      'newCalculationRejected': true,
      'disciplineSectionSchema': section['section_schema'],
      'manifestSchema': manifest['manifest_schema'],
      'manifestImmutable': true,
      'disciplineAppendOnly': true,
      'physicalHashLinked':
          section['physical_sha256'] == manifest['physical_sha256'],
      'powerHashLinked': section['power_sha256'] == manifest['power_sha256'],
    });
  } finally {
    await db.close();
    await dir.delete(recursive: true);
  }
}

final class _FreezeFault implements ElvFailureProbe {
  bool hitExpectedPoint = false;
  @override
  Future<void> hit(String point) async {
    if (point == ElvFailurePoints.p3FreezeAfterSnapshotInsert) {
      hitExpectedPoint = true;
      throw StateError('F2_GLOBAL_FREEZE_FAULT');
    }
  }
}
