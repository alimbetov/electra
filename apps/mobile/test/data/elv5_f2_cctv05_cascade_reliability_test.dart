import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_service.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_write_unit_of_work.dart';
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv05_capability_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_contract_mutation_coordinator.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_current_evaluation_source.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_dependency_invalidator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_cctv_sources.dart';
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'CCTV05 rejects upstream republish after capture without partial consumer publication',
    () async {
      final dir = await Directory.systemTemp.createTemp('f2-upstream-cas-');
      final file = File('${dir.path}/db.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      final other = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await other.close();
        await db.close();
        await dir.delete(recursive: true);
      });
      final fp = await seedF2CctvCurrentDependencies(db);
      final consumer = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv05,
        subjectKind: 'RECORDER',
        subjectId: 'rec-1',
      )..db = db;
      final source = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv02,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      )..db = other;
      await _policy(db, fp.$1, fp.$2, await consumer.revision(), null);
      final runtime = consumer.runtime(db);
      final adapter = runtime.registry.require(Elv5ProcessCode.cctv05);
      final service = Elv5CalculationService(
        registry: Elv5ProcessCalculationRegistry([
          _BeforeExecute(adapter, () async {
            await source
                .runtime(other)
                .service
                .execute(
                  source.command(
                    'upstream-during-capture',
                    await source.revision(),
                    1,
                  ),
                );
          }),
        ]),
        publicationUnitOfWork: DriftElv5CalculationWriteUnitOfWork(
          db,
          originDeviceId: 'review',
        ),
        originDeviceId: 'review',
      );
      await expectLater(
        service.execute(
          consumer.command('stale-consumer', await consumer.revision(), 0),
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('ELV5_UPSTREAM_GENERATION_CONFLICT'),
          ),
        ),
      );
      for (final table in [
        'discipline_evaluation_records',
        'discipline_evaluation_pointers',
      ]) {
        expect(
          await db
              .customSelect(
                "SELECT * FROM $table WHERE logical_node_key_sha256='${consumer.nodeHash}'",
              )
              .get(),
          isEmpty,
        );
      }
      expect(
        await db
            .customSelect(
              "SELECT * FROM discipline_dependency_index WHERE logical_node_key_sha256='${consumer.nodeHash}'",
            )
            .get(),
        isEmpty,
      );
      expect(
        await db
            .customSelect(
              "SELECT * FROM command_execution_records WHERE command_id='stale-consumer'",
            )
            .get(),
        isEmpty,
      );
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        expect(
          await reopened
              .customSelect(
                "SELECT * FROM discipline_evaluation_pointers WHERE logical_node_key_sha256='${consumer.nodeHash}'",
              )
              .get(),
          isEmpty,
        );
      } finally {
        await reopened.close();
      }
    },
  );

  test(
    'F2 global CCTV05 source and publication cascades roll back atomically and reject frozen invalidation',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'f2-cctv-cascade-',
      );
      final file = File('${directory.path}/production.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await directory.delete(recursive: true);
      });
      final source = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv02,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      )..db = db;
      final consumer = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv05,
        subjectKind: 'RECORDER',
        subjectId: 'rec-1',
      )..db = db;
      final fingerprints = await seedF2CctvCurrentDependencies(db);
      await _policy(
        db,
        fingerprints.$1,
        fingerprints.$2,
        await consumer.revision(),
        null,
      );
      await consumer
          .runtime(db)
          .service
          .execute(
            consumer.command('consumer-first', await consumer.revision(), 0),
          );
      final before = await _state(db);
      await _fault(db, consumer.nodeHash);
      await expectLater(
        _changeStreams(db),
        throwsA(predicate((e) => e.toString().contains('F2_CASCADE_FAULT'))),
      );
      await db.customStatement('DROP TRIGGER f2_cascade_fault');
      expect(await _state(db), before);
      await _changeStreams(db);
      expect((await source.pointer()).read<String>('freshness'), 'STALE');
      expect((await consumer.pointer()).read<String>('freshness'), 'STALE');
      expect((await consumer.pointer()).read<int>('generation'), 2);
      await source
          .runtime(db)
          .service
          .execute(
            source.command('source-changed', await source.revision(), 2),
          );
      final camera =
          (await DriftElv5CurrentEvaluationSource(db).loadCurrent(
            projectId: 'p',
            designRevisionId: 'd',
            processCode: Elv5ProcessCode.cctv02,
          )).single;
      await _policy(
        db,
        camera.inputFingerprint,
        fingerprints.$2,
        await consumer.revision(),
        1,
      );
      final committed = consumer.command(
        'consumer-second',
        await consumer.revision(),
        2,
      );
      final logical =
          (await consumer
              .runtime(db)
              .service
              .execute(committed)).logicalResultJson;
      final output =
          jsonDecode((await consumer.evaluation()).read<String>('output_json'))
              as Map;
      expect(output['status'], 'fail');
      expect(
        output['ingressMarginBps'],
        Elv5Rational.integer(-4000000).toMap(),
      );
      final current = await _state(db);
      await _fault(db, consumer.nodeHash);
      final noOp = source.command(
        'source-unchanged-input',
        await source.revision(),
        3,
      );
      await expectLater(
        source.runtime(db).service.execute(noOp),
        throwsA(predicate((e) => e.toString().contains('F2_CASCADE_FAULT'))),
      );
      await db.customStatement('DROP TRIGGER f2_cascade_fault');
      expect(await _state(db), current);
      await source.runtime(db).service.execute(noOp);
      expect((await source.pointer()).read<int>('generation'), 4);
      expect((await consumer.pointer()).read<String>('freshness'), 'STALE');
      expect((await consumer.pointer()).read<int>('generation'), 4);
      await _policy(
        db,
        camera.inputFingerprint,
        fingerprints.$2,
        await consumer.revision(),
        2,
      );
      final latest = consumer.command(
        'consumer-third',
        await consumer.revision(),
        4,
      );
      final latestLogical =
          (await consumer
              .runtime(db)
              .service
              .execute(latest)).logicalResultJson;
      expect((await consumer.pointer()).read<int>('generation'), 5);
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      source.db = db;
      consumer.db = db;
      expect(
        (await consumer
            .runtime(db)
            .service
            .execute(committed)).logicalResultJson,
        logical,
      );
      expect(
        (await consumer.runtime(db).service.execute(latest)).logicalResultJson,
        latestLogical,
      );
      await db.customStatement(
        "UPDATE project_design_revisions SET state='FROZEN' WHERE id='d'",
      );
      final frozen = await _state(db);
      final invalidator = DriftElv5DependencyInvalidator(
        db,
        originDeviceId: 'f2-cascade',
      );
      await expectLater(
        invalidator.invalidateSubject(
          projectId: 'p',
          designRevisionId: 'd',
          relationKind: 'EVAL',
          domain: 'CCTV02_CURRENT',
          subjectId: camera.evaluationId,
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('ELV5_DESIGN_REVISION_READ_ONLY'),
          ),
        ),
      );
      await expectLater(
        invalidator.invalidate(
          projectId: 'p',
          designRevisionId: 'd',
          dependencies: const [],
        ),
        throwsA(
          predicate(
            (e) => e.toString().contains('ELV5_DESIGN_REVISION_READ_ONLY'),
          ),
        ),
      );
      expect(await _state(db), frozen);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}

Future<void> _changeStreams(AppDatabase db) => replaceF2CctvAggregate(
  db,
  operation: 'REPLACE_CAMERA_STREAMS',
  payload: f2CctvStreams(expected: 16000000, peak: 24000000),
  commandId: 'raise-streams',
);
Future<void> _fault(AppDatabase db, String consumer) => db.customStatement(
  "CREATE TEMP TRIGGER f2_cascade_fault BEFORE UPDATE ON discipline_evaluation_pointers WHEN NEW.logical_node_key_sha256='$consumer' AND NEW.freshness='STALE' BEGIN SELECT RAISE(ABORT,'F2_CASCADE_FAULT'); END",
);
Future<Map<String, Object?>> _state(AppDatabase db) async {
  final result = <String, Object?>{};
  for (final table in [
    'project_design_revisions',
    'camera_stream_set_bindings',
    'camera_stream_bindings',
    'camera_stream_subscriptions',
    'discipline_policy_bindings',
    'elv_revision_aggregate_evidence_records',
    'discipline_evaluation_records',
    'discipline_evaluation_pointers',
    'discipline_dependency_index',
    'command_execution_records',
    'elv_revision_command_history_operations',
    'elv_revision_command_history_executions',
    'elv_revision_command_history_cursors',
  ]) {
    result[table] =
        (await db.customSelect('SELECT * FROM $table ORDER BY rowid').get())
            .map((r) => r.data)
            .toList();
  }
  return result;
}

Future<void> _policy(
  AppDatabase db,
  String camera,
  String pool,
  int revision,
  int? bindingRevision,
) => DriftElv5CctvContractMutationCoordinator(
  db,
  originDeviceId: 'f2-cascade',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceCctv05(
  ReplaceCctv05CapabilityContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'recorder-policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Cctv05CapabilityContract(
      recorderId: 'rec-1',
      expectedDefinitionId: 'fictional-rec-1',
      expectedDefinitionVersion: 1,
      channelLimit: 2,
      peakIngressCapacityBps: Elv5Rational.integer(20000000),
      usableStorageCapacityBytes: Elv5Rational.integer(200000000000),
      supportedCodecProfiles: const ['H264'],
      requireGuaranteedStorage: true,
      expectedCctv02InputFingerprintByCamera: {'cam-1': camera},
      expectedCctv03InputFingerprintByPool: {'pool-1': pool},
    ),
  ),
);

final class _BeforeExecute implements Elv5ProcessCalculationAdapter {
  _BeforeExecute(this.inner, this.before);
  final Elv5ProcessCalculationAdapter inner;
  final Future<void> Function() before;
  @override
  Elv5ProcessCode get processCode => inner.processCode;
  @override
  Elv5WorkloadClass get workloadClass => inner.workloadClass;
  @override
  Future<Elv5CapturedProcess> capture(Elv5CalculationRequest request) =>
      inner.capture(request);
  @override
  Future<Elv5ProcessEvaluationCandidate> execute(
    Elv5CapturedProcess captured,
  ) async {
    await before();
    return inner.execute(captured);
  }
}
