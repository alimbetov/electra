import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_dependency_invalidator.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_fa08_invalidation_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'environment edition change marks dependent FA08 pointer stale once',
    () async {
      final db = await _db();
      addTearDown(db.close);
      final dependency = Elv5InvalidationDependency(
        relationKind: 'POLICY',
        domain: 'ELV5_ENVIRONMENT_PROFILE',
        subjectId: 'ENV:ROOM:room-1:old-hash',
      );
      await _seedDependency(db, dependency);
      final coordinator = _coordinator(db);

      expect(
        await coordinator.environmentEditionChanged(
          projectId: 'p',
          designRevisionId: 'd',
          oldEvidenceRef: 'ENV:ROOM:room-1:old-hash',
        ),
        1,
      );
      await _expectPointer(db, freshness: 'STALE', generation: 2);
      expect(
        await coordinator.environmentEditionChanged(
          projectId: 'p',
          designRevisionId: 'd',
          oldEvidenceRef: 'ENV:ROOM:room-1:old-hash',
        ),
        0,
      );
      await _expectPointer(db, freshness: 'STALE', generation: 2);
    },
  );

  test(
    'grouping 1 to N invalidates old grouping evidence dependency',
    () async {
      final db = await _db();
      addTearDown(db.close);
      final dependency = Elv5InvalidationDependency(
        relationKind: 'POLICY',
        domain: 'AMPACITY_GROUPING_CORRECTION',
        subjectId: 'GROUPING:section-1:single',
      );
      await _seedDependency(db, dependency);

      expect(
        await _coordinator(db).groupingEvidenceChanged(
          projectId: 'p',
          designRevisionId: 'd',
          oldEvidenceRef: 'GROUPING:section-1:single',
        ),
        1,
      );
      await _expectPointer(db, freshness: 'STALE', generation: 2);
    },
  );

  test(
    'route section add or remove invalidates cable-run route dependency',
    () async {
      final db = await _db();
      addTearDown(db.close);
      final dependency = Elv5InvalidationDependency(
        relationKind: 'SET',
        domain: 'CABLE_RUN_ROUTE',
        subjectId: 'run-1',
      );
      await _seedDependency(db, dependency);

      expect(
        await _coordinator(db).routeChanged(
          projectId: 'p',
          designRevisionId: 'd',
          cableRunId: 'run-1',
        ),
        1,
      );
      await _expectPointer(db, freshness: 'STALE', generation: 2);
    },
  );

  test(
    'cable definition change invalidates every active run using cable',
    () async {
      final db = await _db(withRun: true);
      addTearDown(db.close);
      final dependency = Elv5InvalidationDependency(
        relationKind: 'SET',
        domain: 'CABLE_RUN_ROUTE',
        subjectId: 'run-1',
      );
      await _seedDependency(db, dependency);

      expect(
        await _coordinator(db).cableDefinitionChanged(
          projectId: 'p',
          designRevisionId: 'd',
          cableId: 'cable-1',
        ),
        1,
      );
      await _expectPointer(db, freshness: 'STALE', generation: 2);
    },
  );
}

DriftFa08InvalidationCoordinator _coordinator(AppDatabase db) =>
    DriftFa08InvalidationCoordinator(
      db,
      originDeviceId: 'test',
      nowUtc: () => DateTime.utc(2026, 10, 17, 12),
    );

Future<AppDatabase> _db({bool withRun = false}) async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.customStatement('PRAGMA foreign_keys = OFF');
  final now = DateTime.utc(2026, 10, 17, 12);
  await db
      .into(db.projects)
      .insert(
        ProjectsCompanion.insert(
          id: 'p',
          name: 'P',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'seed',
        ),
      );
  await db
      .into(db.projectDesignRevisions)
      .insert(
        ProjectDesignRevisionsCompanion.insert(
          id: 'd',
          projectId: 'p',
          code: 'R1',
          sequence: 1,
          state: 'WORKING',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'seed',
        ),
      );
  if (withRun) {
    await db
        .into(db.canonicalCableRuns)
        .insert(
          CanonicalCableRunsCompanion.insert(
            id: 'run-1',
            projectId: 'p',
            cableId: 'cable-1',
            designRevisionId: 'd',
            lifecycleState: 'ACTIVE',
            reservePercent: const Value(0),
            terminationAllowanceMm: const Value(0),
            createdAt: now,
            updatedAt: now,
            originDeviceId: 'seed',
          ),
        );
  }
  return db;
}

Future<void> _seedDependency(
  AppDatabase db,
  Elv5InvalidationDependency dependency,
) async {
  final now = DateTime.utc(2026, 10, 17, 12);
  final node = _hash('1');
  await db.customStatement(
    "INSERT INTO discipline_evaluation_pointers (project_id,design_revision_id,logical_node_key_json,logical_node_key_sha256,freshness,generation,evaluation_id,input_fingerprint,output_sha256,updated_at,origin_device_id) VALUES ('p','d','{}','$node','CURRENT',1,'eval-1','${_hash('2')}','${_hash('3')}','${now.toIso8601String()}','seed')",
  );
  await db.customStatement(
    "INSERT INTO discipline_dependency_index (project_id,design_revision_id,dependency_key,dependency_key_sha256,logical_node_key_sha256,relation_kind,updated_at) VALUES ('p','d','${dependency.json.replaceAll("'", "''")}','${dependency.sha256}','$node','${dependency.relationKind}','${now.toIso8601String()}')",
  );
}

Future<void> _expectPointer(
  AppDatabase db, {
  required String freshness,
  required int generation,
}) async {
  final row = await db
      .customSelect(
        "SELECT freshness, generation FROM discipline_evaluation_pointers WHERE project_id = 'p' AND design_revision_id = 'd'",
      )
      .getSingle();
  expect(row.read<String>('freshness'), freshness);
  expect(row.read<int>('generation'), generation);
}

String _hash(String char) => List<String>.filled(64, char).join();
