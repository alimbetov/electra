import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/commands/elv5_replacement_command_runner.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import 'elv5_f2_qualification_harness.dart';
import 'elv5_f2_execution_witness.dart';

/// File-backed production qualification. Callbacks supply authoritative source
/// writes and domain assertions only; resolvers/executors are never injected.
final class Elv5F2ProductionLifecycle {
  Elv5F2ProductionLifecycle({
    required this.process,
    required this.subjectKind,
    required this.subjectId,
  });
  final Elv5ProcessCode process;
  final String subjectKind;
  final String subjectId;
  static const encoder = Elv5CanonicalJsonV1();
  static DateTime now() => DateTime.utc(2026, 10, 17, 15);
  late AppDatabase db;

  String get nodeHash => encoder.sha256(
    Elv5EngineeringNodeKeyV3(
      designRevisionId: 'd',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'd',
        scenarioKey: 'NONE',
      ),
      processCode: process,
      subject: Elv5SubjectRef(kind: subjectKind, id: subjectId),
    ).toCanonicalValue(),
  );

  DriftElv5CalculationRuntime runtime(AppDatabase database) =>
      DriftElv5CalculationRuntime.create(
        database,
        originDeviceId: 'f2-fire',
        nowUtc: now,
      );

  Future<int> revision() async => (await db
          .customSelect(
            "SELECT revision FROM project_design_revisions WHERE id = 'd'",
          )
          .getSingle())
      .read<int>('revision');

  Elv5WireCommandEnvelope command(String id, int revision, int generation) =>
      Elv5WireCommandEnvelope(
        operation: 'CALCULATE_DISCIPLINE_PROCESS',
        projectId: 'p',
        designRevisionId: 'd',
        commandId: id,
        expectedDesignRowRevision: revision,
        expectedRows: const {},
        reviewedImpactFingerprint: List.filled(64, '9').join(),
        payload: {
          'scope': {'kind': 'DESIGN', 'scopeId': 'd', 'scenarioKey': 'NONE'},
          'processCodes': [process.wireCode],
          'subjects': [
            {'kind': subjectKind, 'id': subjectId},
          ],
          'expectedPointerGenerations': {nodeHash: generation},
        },
      );

  Future<QueryRow> pointer() =>
      db
          .customSelect(
            'SELECT * FROM discipline_evaluation_pointers WHERE logical_node_key_sha256 = ?',
            variables: [Variable.withString(nodeHash)],
          )
          .getSingle();

  Future<QueryRow> evaluation() async =>
      db
          .customSelect(
            'SELECT * FROM discipline_evaluation_records WHERE evaluation_id = ?',
            variables: [
              Variable.withString(
                (await pointer()).read<String>('evaluation_id'),
              ),
            ],
          )
          .getSingle();

  Future<Elv5F2PublicationSnapshot> snapshot(
    String logical,
    String assessment,
    void Function(Map<String, dynamic>) checkOutput,
  ) async {
    final p = await pointer();
    final e = await evaluation();
    expect(e.read<String>('execution'), 'SUCCEEDED');
    expect(e.read<String>('completion'), 'COMPLETE');
    expect(e.read<String>('assessment'), assessment);
    expect(
      e.read<String>('input_fingerprint'),
      p.read<String>('input_fingerprint'),
    );
    expect(e.read<String>('output_sha256'), p.read<String>('output_sha256'));
    final output =
        jsonDecode(e.read<String>('output_json')) as Map<String, dynamic>;
    expect(encoder.sha256(output), e.read<String>('output_sha256'));
    expect(
      encoder.sha256(jsonDecode(e.read<String>('evidence_json'))),
      e.read<String>('evidence_sha256'),
    );
    checkOutput(output);
    return Elv5F2PublicationSnapshot(
      generation: p.read<int>('generation'),
      evaluationId: e.read<String>('evaluation_id'),
      freshness: p.read<String>('freshness'),
      execution: e.read<String>('execution'),
      completion: e.read<String>('completion'),
      inputFingerprint: e.read<String>('input_fingerprint'),
      outputSha256: e.read<String>('output_sha256'),
      logicalResultJson: logical,
    );
  }

  Future<void> run({
    required Future<void> Function(AppDatabase) seed,
    required Future<void> Function(AppDatabase) mutate,
    required Future<void> Function(AppDatabase) mutationAfterFreeze,
    required Set<String> dependencyDomains,
    required void Function(Map<String, dynamic>) initialOutput,
    required void Function(Map<String, dynamic>) changedOutput,
    String initialAssessment = 'PASS',
    String changedAssessment = 'FAIL',
  }) async {
    const harness = Elv5F2QualificationHarness();
    final directory = await Directory.systemTemp.createTemp(
      'f2-${process.wireCode}-',
    );
    final file = File('${directory.path}/production.sqlite');
    db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await directory.delete(recursive: true);
    });
    await seed(db);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await emitF2PersistedWitness(db, process.wireCode);
    final initial = await runtime(
      db,
    ).service.execute(command('initial', await revision(), 0));
    final first = await snapshot(
      initial.logicalResultJson,
      initialAssessment,
      initialOutput,
    );
    harness.assertQ6Initial(process.wireCode, first);
    expect(first.generation, 1);
    final dependencies =
        await db
            .customSelect(
              'SELECT dependency_key, dependency_key_sha256 FROM discipline_dependency_index WHERE logical_node_key_sha256 = ?',
              variables: [Variable.withString(nodeHash)],
            )
            .get();
    final domains = <String>{};
    for (final dependency in dependencies) {
      final value =
          jsonDecode(dependency.read<String>('dependency_key'))
              as Map<String, dynamic>;
      expect(
        encoder.sha256(value),
        dependency.read<String>('dependency_key_sha256'),
      );
      domains.add(value['domain'] as String);
    }
    expect(domains, containsAll(dependencyDomains));
    await mutate(db);
    expect((await pointer()).read<String>('freshness'), 'STALE');
    expect((await pointer()).read<int>('generation'), 2);
    final designRevision = await revision();
    final second = await runtime(
      db,
    ).service.execute(command('changed', designRevision, 2));
    final changed = await snapshot(
      second.logicalResultJson,
      changedAssessment,
      changedOutput,
    );
    harness.assertQ6Republished(process.wireCode, first, changed);
    expect(changed.generation, 3);

    // Separate SQLite connections and production runtimes contend for one CAS.
    // SQLite can reject one BEGIN IMMEDIATE with SQLITE_BUSY before ELV5 reaches
    // its pointer-generation precondition. In that case, retry the exact same
    // immutable envelope after the winner committed and require the domain CAS
    // verdict. Any non-BUSY infrastructure error still fails immediately.
    final competingDb = AppDatabase(NativeDatabase(file));
    await db.customStatement('PRAGMA busy_timeout = 5000');
    await competingDb.customStatement('PRAGMA busy_timeout = 5000');
    Future<
      ({
        AppDatabase database,
        Elv5WireCommandEnvelope command,
        String? logical,
        Object? error,
      })
    >
    attempt(AppDatabase database, Elv5WireCommandEnvelope cmd) async {
      try {
        final result = await runtime(database).service.execute(cmd);
        return (
          database: database,
          command: cmd,
          logical: result.logicalResultJson,
          error: null,
        );
      } catch (error) {
        return (database: database, command: cmd, logical: null, error: error);
      }
    }

    late Elv5WireCommandEnvelope committedCommand;
    late String committedLogical;
    try {
      // Open both connections before starting the writers.
      await competingDb.customSelect('SELECT 1').get();
      final raceA = command('race-a', designRevision, 3);
      final raceB = command('race-b', designRevision, 3);
      final outcomes = await Future.wait([
        attempt(db, raceA),
        attempt(competingDb, raceB),
      ]);
      expect(outcomes.where((v) => v.error == null), hasLength(1));
      final winner = outcomes.singleWhere((v) => v.error == null);
      final loser = outcomes.singleWhere((v) => v.error != null);
      var loserError = loser.error!;
      if (_isTransientSqliteBusy(loserError)) {
        final retry = await attempt(loser.database, loser.command);
        if (retry.logical != null) {
          fail('SQLite BUSY retry unexpectedly committed a second writer.');
        }
        if (retry.error == null) {
          fail('SQLite BUSY retry did not expose the logical CAS verdict.');
        }
        loserError = retry.error!;
      }
      expect(
        loserError,
        isA<Elv5ReplacementCommandException>().having(
          (e) => e.code,
          'code',
          'ELV5_POINTER_GENERATION_CONFLICT',
        ),
      );
      committedCommand = winner.command;
      committedLogical = winner.logical!;
    } finally {
      await competingDb.close();
    }
    final committed = await snapshot(
      committedLogical,
      changedAssessment,
      changedOutput,
    );
    expect(committed.generation, 4);
    expect(committed.evaluationId, changed.evaluationId);
    await harness.expectQ7StaleWriter(process.wireCode, () async {
      await runtime(
        db,
      ).service.execute(command('stale-pointer', designRevision, 3));
    });
    await expectLater(
      runtime(
        db,
      ).service.execute(command('stale-design', designRevision - 1, 4)),
      throwsA(
        isA<Elv5ReplacementCommandException>().having(
          (e) => e.code,
          'code',
          'ELV5_DESIGN_REVISION_CONFLICT',
        ),
      ),
    );
    final records = (await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM discipline_evaluation_records WHERE logical_node_key_sha256 = ?',
              variables: [Variable.withString(nodeHash)],
            )
            .getSingle())
        .read<int>('n');
    expect(records, 2);
    final identity = Map<String, Object?>.from((await evaluation()).data);
    final ledger =
        await db
            .customSelect(
              'SELECT * FROM command_execution_records ORDER BY command_id',
            )
            .get();
    await db.close();
    db = AppDatabase(NativeDatabase(file));
    final replay = await runtime(db).service.execute(committedCommand);
    expect(replay.replayed, isTrue);
    harness.assertQ7Replay(
      process.wireCode,
      committed,
      await snapshot(
        replay.logicalResultJson,
        changedAssessment,
        changedOutput,
      ),
    );
    expect((await evaluation()).data, identity);
    await db.customStatement(
      "UPDATE project_design_revisions SET state = 'FROZEN', revision = revision + 1 WHERE id = 'd'",
    );
    final frozenReplay = await runtime(db).service.execute(committedCommand);
    expect(frozenReplay.replayed, isTrue);
    harness.assertQ8Replay(
      process.wireCode,
      committed,
      await snapshot(
        frozenReplay.logicalResultJson,
        changedAssessment,
        changedOutput,
      ),
    );
    expect((await evaluation()).data, identity);
    await harness.expectQ8ReadOnly(process.wireCode, () async {
      await runtime(
        db,
      ).service.execute(command('frozen-new', designRevision + 1, 4));
    });
    await mutationAfterFreeze(db);
    expect((await pointer()).read<int>('generation'), 4);
    expect((await pointer()).read<String>('freshness'), 'CURRENT');
    expect((await evaluation()).data, identity);
    expect(
      (await db
              .customSelect(
                'SELECT * FROM command_execution_records ORDER BY command_id',
              )
              .get())
          .map((r) => r.data)
          .toList(),
      ledger.map((r) => r.data).toList(),
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await emitF2PersistedWitness(db, process.wireCode);
  }
}

bool _isTransientSqliteBusy(Object error) {
  final text = error.toString();
  return error.runtimeType.toString() == 'SqliteException' &&
      text.contains('SqliteException(5)') &&
      text.contains('database is locked') &&
      text.contains('BEGIN IMMEDIATE');
}
