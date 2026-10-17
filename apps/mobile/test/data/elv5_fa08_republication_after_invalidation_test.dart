import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/persistence/elv5_runtime_persistence.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_dependency_invalidator.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_runtime_write_unit_of_work.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stale FA08 pointer republishes only through the next generation CAS', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.utc(2026, 10, 17, 13);
    final node = _hash('1');
    final dependency = Elv5InvalidationDependency(
      relationKind: 'SET',
      domain: 'CABLE_RUN_ROUTE',
      subjectId: 'run-1',
    );

    await db.customStatement(
      "INSERT INTO discipline_evaluation_pointers (project_id,design_revision_id,logical_node_key_json,logical_node_key_sha256,freshness,generation,evaluation_id,input_fingerprint,output_sha256,updated_at,origin_device_id) VALUES ('p','d','{}','$node','CURRENT',1,'eval-old','${_hash('2')}','${_hash('3')}','${now.toIso8601String()}','seed')",
    );
    await db.customStatement(
      "INSERT INTO discipline_dependency_index (project_id,design_revision_id,dependency_key,dependency_key_sha256,logical_node_key_sha256,relation_kind,updated_at) VALUES ('p','d','${dependency.json.replaceAll("'", "''")}','${dependency.sha256}','$node','SET','${now.toIso8601String()}')",
    );

    final invalidator = DriftElv5DependencyInvalidator(
      db,
      originDeviceId: 'test',
      nowUtc: () => now,
    );
    expect(
      await invalidator.invalidate(
        projectId: 'p',
        designRevisionId: 'd',
        dependencies: <Elv5InvalidationDependency>[dependency],
      ),
      1,
    );

    final uow = DriftElv5RuntimeWriteUnitOfWork(db, originDeviceId: 'test');
    final staleGenerationRejected = await uow.run(
      (session) => session.pointers.compareAndSet(
        Elv5PointerWrite(
          projectId: 'p',
          designRevisionId: 'd',
          logicalNodeKeyJson: '{}',
          logicalNodeKeySha256: node,
          freshness: Elv5PointerFreshness.current,
          expectedGeneration: 1,
          evaluationId: 'eval-wrong-generation',
          inputFingerprint: _hash('4'),
          outputSha256: _hash('5'),
          updatedAtUtc: now,
        ),
      ),
    );
    expect(staleGenerationRejected, isFalse);

    final republished = await uow.run(
      (session) => session.pointers.compareAndSet(
        Elv5PointerWrite(
          projectId: 'p',
          designRevisionId: 'd',
          logicalNodeKeyJson: '{}',
          logicalNodeKeySha256: node,
          freshness: Elv5PointerFreshness.current,
          expectedGeneration: 2,
          evaluationId: 'eval-new',
          inputFingerprint: _hash('4'),
          outputSha256: _hash('5'),
          updatedAtUtc: now.add(const Duration(seconds: 1)),
        ),
      ),
    );
    expect(republished, isTrue);

    final row = await db
        .customSelect(
          "SELECT freshness,generation,evaluation_id FROM discipline_evaluation_pointers WHERE project_id='p' AND design_revision_id='d' AND logical_node_key_sha256='$node'",
        )
        .getSingle();
    expect(row.read<String>('freshness'), 'CURRENT');
    expect(row.read<int>('generation'), 3);
    expect(row.read<String>('evaluation_id'), 'eval-new');
  });
}

String _hash(String char) => List<String>.filled(64, char).join();
