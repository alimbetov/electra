import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/component_placement_history.dart';
import 'package:electra_mobile/application/engineering_placement_command.dart';
import 'package:electra_mobile/application/engineering_placement_repository.dart';
import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_component_instance_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_aggregate.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_placement_repository.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_topology_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/engineering_placement_fixture.dart';

Future<void> seedAtomic(AppDatabase db) async {
  await seedPlacementParents(db);
  await seedPlacementSystemAndCatalog(db);
  for (final code in ['LAN', 'ACS', 'FIRE']) {
    await seedEngineeringSystem(db, id: code, code: code, familyCode: code);
  }
}

PlaceEngineeringProfileCommand atomicCommand(String code, {String? operation}) {
  final initial = placementCommand();
  return PlaceEngineeringProfileCommand.fromMap({
    ...initial.toMap(),
    'operationId': operation ?? 'place-$code',
    'profileCode': code,
    'systemId': switch (code) {
      'CAMERA' => 'system-1',
      'OUTLET' => 'LAN',
      'READER' || 'LOCK' => 'ACS',
      _ => 'FIRE',
    },
    'placementContext': {
      ...initial.placementContext.toMap(),
      'installationSurface': code == 'DETECTOR' ? 'ceiling' : 'wall',
      'mountingMethod': switch (code) {
        'CAMERA' => 'bracket',
        'OUTLET' => 'flush',
        _ => 'surface',
      },
      'topologyShape': code == 'DETECTOR' ? 'loop' : 'star',
    },
  });
}

Future<String> aggregateRows(AppDatabase db) async {
  final m = <String, Object?>{};
  for (final table in [
    ...DriftEngineeringPlacementAggregate.aggregateTables.keys,
    'engineering_placement_operations',
  ]) {
    m[table] =
        (await db.customSelect('SELECT * FROM $table ORDER BY 1').get())
            .map((r) => r.data)
            .toList();
  }
  return canonicalEngineeringJson(m);
}

void main() {
  late AppDatabase db;
  late DriftEngineeringPlacementRepository repo;
  var now = DateTime.utc(2026, 10, 13, 18);
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await seedAtomic(db);
    repo = DriftEngineeringPlacementRepository(
      db,
      originDeviceId: 'atomic',
      clock: () => now,
    );
  });
  tearDown(() => db.close());

  for (final code in ['CAMERA', 'OUTLET', 'READER', 'LOCK', 'DETECTOR']) {
    test(
      '$code persists one exact aggregate and replays without writes',
      () async {
        final command = atomicCommand(code);
        final result = await repo.place(command);
        final component =
            await (db.select(db.componentInstances)
              ..where((r) => r.id.equals(result.componentId))).getSingle();
        expect(component.definitionId, canonicalElvComponentDefinitionId);
        expect(component.definitionVersion, 1);
        expect(component.localXmm, command.localPosition.xMm);
        final membership =
            await (db.select(db.componentEngineeringMemberships)..where(
              (r) => r.componentId.equals(result.componentId),
            )).getSingle();
        expect(membership.role, 'DEVICE');
        expect(membership.systemId, command.systemId);
        final row =
            await (db.select(db.componentReferenceBindings)..where(
              (r) => r.componentId.equals(result.componentId),
            )).getSingle();
        final binding = ComponentReferenceBinding.fromMap(
          jsonDecode(row.payloadJson) as Map<String, dynamic>,
        );
        expect(binding.catalogVersion, command.catalogVersion);
        expect(
          binding.placementCommand!.placementContext.toMap(),
          command.placementContext.toMap(),
        );
        expect(binding.portIds.toSet(), result.portIds.toSet());
        final ports =
            await (db.select(db.engineeringPortInstances)
              ..where((r) => r.componentId.equals(result.componentId))).get();
        expect(ports.length, binding.profile.portTemplates.length);
        for (final p in ports) {
          final port = EngineeringPort.fromMap(
            jsonDecode(p.payloadJson) as Map<String, dynamic>,
          );
          expect(port.templateProvenance!.id, 'catalog-1/$code/${port.code}');
          expect(port.templateProvenance!.version, '1.0.0');
          expect(port.interfaceProvenance, isNotNull);
          expect(port.interfaceProvenance!.version, '1.0.0');
          expect(p.revision, 1);
          expect(p.createdAt.isAtSameMomentAs(p.updatedAt), isTrue);
        }
        final before = await aggregateRows(db);
        final replay = await repo.place(command);
        expect(
          engineeringPlacementResultJson(replay),
          engineeringPlacementResultJson(result),
        );
        expect(await aggregateRows(db), before);
      },
    );
  }

  for (final point in EngineeringPlacementFailurePoint.values) {
    final codes =
        [
              EngineeringPlacementFailurePoint.beforePort,
              EngineeringPlacementFailurePoint.afterPort,
            ].contains(point)
            ? ['IN', 'OUT']
            : [null];
    for (final code in codes) {
      test('rollback at ${point.name} $code restores every row', () async {
        final before = await aggregateRows(db);
        final failing = DriftEngineeringPlacementRepository(
          db,
          originDeviceId: 'fault',
          fault: (p, c) {
            if (p == point && c == code) throw StateError('injected');
          },
        );
        await expectLater(
          failing.place(atomicCommand('DETECTOR')),
          throwsA(isA<EngineeringPlacementFailure>()),
        );
        expect(await aggregateRows(db), before);
        expect(
          (await repo.place(atomicCommand('DETECTOR'))).portIds,
          hasLength(2),
        );
      });
    }
  }

  test(
    'commit rejects missing evidence, stale topology and exact-version mismatch without writes',
    () async {
      final before = await aggregateRows(db);
      final command = atomicCommand('CAMERA');
      for (final patch in [
        {'catalogVersion': 'missing'},
        {
          'placementContext': {
            ...command.placementContext.toMap(),
            'mountingMethod': 'flush',
          },
        },
        {
          'placementContext': {
            ...command.placementContext.toMap(),
            'environmentExposure': null,
          },
        },
        {
          'placementContext': {
            ...command.placementContext.toMap(),
            'availableClearanceMm': -1,
          },
        },
      ]) {
        await expectLater(
          repo.place(
            PlaceEngineeringProfileCommand.fromMap({
              ...command.toMap(),
              ...patch,
            }),
          ),
          throwsA(isA<EngineeringPlacementFailure>()),
        );
        expect(await aggregateRows(db), before);
      }
      final systemRow =
          await (db.select(db.projectEngineeringSystems)
            ..where((r) => r.id.equals('system-1'))).getSingle();
      await (db.update(db.projectEngineeringSystems)
        ..where((r) => r.id.equals('system-1'))).write(
        ProjectEngineeringSystemsCompanion(
          payloadJson: Value(
            canonicalEngineeringJson({
              ...jsonDecode(systemRow.payloadJson) as Map<String, dynamic>,
              'topologyProfile': {'id': 'missing', 'version': '1'},
            }),
          ),
        ),
      );
      await expectLater(
        repo.place(command),
        throwsA(
          isA<EngineeringPlacementFailure>().having(
            (e) => e.code,
            'code',
            EngineeringPlacementFailureCode.placementUnresolved,
          ),
        ),
      );
      expect(await aggregateRows(db), before);
    },
  );

  test(
    'concurrent same-operation submissions converge on the same component and ports',
    () async {
      final command = atomicCommand('CAMERA');
      final results = await Future.wait([
        repo.place(command),
        repo.place(command),
      ]);
      expect(results.first.componentId, results.last.componentId);
      expect(results.first.portIds, results.last.portIds);
      expect(
        await db.select(db.engineeringPlacementOperations).get(),
        hasLength(1),
      );
    },
  );

  test(
    'generated port collision rolls back component and membership',
    () async {
      final before = await aggregateRows(db);
      final failing = DriftEngineeringPlacementRepository(
        db,
        originDeviceId: 'fault',
        idGenerator: FixedSequenceIdGenerator([
          'new-component',
          'duplicate',
          'duplicate',
        ]),
      );
      await expectLater(
        failing.place(atomicCommand('DETECTOR')),
        throwsA(
          isA<EngineeringPlacementFailure>().having(
            (e) => e.code,
            'code',
            EngineeringPlacementFailureCode.portConflict,
          ),
        ),
      );
      expect(await aggregateRows(db), before);
    },
  );

  test(
    'one session entry undoes and redoes all identities with monotonic audit revisions',
    () async {
      final command = atomicCommand('DETECTOR');
      final result = await repo.place(command);
      final history = ComponentPlacementHistory(
        DriftComponentInstanceRepository(db, originDeviceId: 'history'),
      );
      final entry = EngineeringPlacementHistoryEntry(
        command: command,
        result: result,
      );
      history.recordEngineering(entry, repo);
      history.recordEngineering(entry, repo);
      now = now.add(const Duration(seconds: 1));
      await history.undo();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isTrue);
      expect(
        (await repo.findOperation(command.operationId))!.status,
        EngineeringPlacementOperationStatus.undone,
      );
      await expectLater(
        repo.place(command),
        throwsA(
          isA<EngineeringPlacementFailure>().having(
            (e) => e.code,
            'code',
            EngineeringPlacementFailureCode.operationUndone,
          ),
        ),
      );
      for (final table
          in DriftEngineeringPlacementAggregate.aggregateTables.entries) {
        final rows =
            await db
                .customSelect(
                  'SELECT * FROM ${table.key} WHERE ${table.value} = ?',
                  variables: [Variable.withString(result.componentId)],
                )
                .get();
        for (final row in rows) {
          expect(row.data['deleted_at'], isNotNull);
          expect(row.read<int>('revision'), 2);
          expect(row.data['created_at'], isNot(row.data['updated_at']));
        }
      }
      now = now.add(const Duration(seconds: 1));
      await history.redo();
      expect(history.canRedo, isFalse);
      expect(history.canUndo, isTrue);
      for (final table
          in DriftEngineeringPlacementAggregate.aggregateTables.entries) {
        final rows =
            await db
                .customSelect(
                  'SELECT * FROM ${table.key} WHERE ${table.value} = ?',
                  variables: [Variable.withString(result.componentId)],
                )
                .get();
        for (final row in rows) {
          expect(row.data['deleted_at'], isNull);
          expect(row.read<int>('revision'), 3);
        }
      }
      expect(
        engineeringPlacementResultJson(
          (await repo.findOperation(command.operationId))!.result,
        ),
        engineeringPlacementResultJson(result),
      );
    },
  );

  test(
    'later topology attachment blocks undo and preserves the history entry',
    () async {
      final command = atomicCommand('CAMERA');
      final result = await repo.place(command);
      final topology = DriftEngineeringTopologyRepository(
        db,
        originDeviceId: 'later',
      );
      await topology.saveTopologyProfile(
        TopologyProfile(
          identity: const ProfileIdentity(
            id: 'star',
            projectId: 'project-1',
            code: 'STAR',
            version: '1',
            source: 'fixture',
          ),
          shape: TopologyShape.star,
          layer: TraceLayer.data,
        ),
      );
      await topology.saveGroup(
        'project-1',
        TopologyGroup(
          id: 'group',
          code: 'G',
          systemId: 'system-1',
          profileId: 'star',
          startPortId: result.portIds.single,
        ),
      );
      final before = await aggregateRows(db);
      final history = ComponentPlacementHistory(
        DriftComponentInstanceRepository(db, originDeviceId: 'history'),
      );
      history.recordEngineering(
        EngineeringPlacementHistoryEntry(command: command, result: result),
        repo,
      );
      await expectLater(
        history.undo(),
        throwsA(
          isA<EngineeringPlacementFailure>().having(
            (e) => e.code,
            'code',
            EngineeringPlacementFailureCode.historyConflict,
          ),
        ),
      );
      expect(history.canUndo, isTrue);
      expect(await aggregateRows(db), before);
    },
  );

  test(
    'redo revalidates current surface and fails without changing retired aggregate',
    () async {
      final command = atomicCommand('CAMERA');
      final result = await repo.place(command);
      await repo.undo(result.operationId);
      final before = await aggregateRows(db);
      await (db.update(db.surfacePatches)
        ..where((r) => r.id.equals('patch-1'))).write(
        const SurfacePatchesCompanion(
          boundaryJson: Value('[[0,0],[10,0],[10,10],[0,10]]'),
        ),
      );
      await expectLater(
        repo.redo(
          EngineeringPlacementHistoryEntry(command: command, result: result),
        ),
        throwsA(
          isA<EngineeringPlacementFailure>().having(
            (e) => e.code,
            'code',
            EngineeringPlacementFailureCode.historyConflict,
          ),
        ),
      );
      expect(await aggregateRows(db), before);
    },
  );

  test(
    'four disciplines retain exact aggregate and idempotency after SQLite restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'elv2-p4-restart-',
      );
      final file = File('${directory.path}/project.sqlite');
      var persistent = AppDatabase(NativeDatabase(file));
      try {
        await seedAtomic(persistent);
        var writer = DriftEngineeringPlacementRepository(
          persistent,
          originDeviceId: 'restart',
        );
        final commands = [
          for (final code in ['CAMERA', 'OUTLET', 'READER', 'DETECTOR'])
            atomicCommand(code),
        ];
        final results = [
          for (final command in commands) await writer.place(command),
        ];
        final before = await aggregateRows(persistent);
        await persistent.close();
        persistent = AppDatabase(NativeDatabase(file));
        writer = DriftEngineeringPlacementRepository(
          persistent,
          originDeviceId: 'reopened',
        );
        expect(await aggregateRows(persistent), before);
        for (var i = 0; i < commands.length; i++) {
          expect(
            engineeringPlacementResultJson(await writer.place(commands[i])),
            engineeringPlacementResultJson(results[i]),
          );
        }
        expect(await aggregateRows(persistent), before);
      } finally {
        await persistent.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
