import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_reviewed_reroute_command.dart';
import 'package:electra_mobile/application/id_generator.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_reviewed_routing_runtime.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv_database_reopen.dart';

void main() {
  test(
    'P7 T06 reviewed reroute survives restart undo and redo with durable evidence',
    () async {
      final directory = await Directory.systemTemp.createTemp('electra-p7-t06-');
      final file = File('${directory.path}/history.sqlite');
      final harness = ElvDatabaseReopenHarness(file);
      addTearDown(() async {
        if (await directory.exists()) await directory.delete(recursive: true);
      });

      var db = harness.open();
      await _seed(db);
      final reviewed = ReviewedRerouteCableRunWorkspaceCommand(
        commandId: 'reroute-original',
        projectId: 'project',
        designRevisionId: 'rev-1',
        cableRunId: 'run-1',
        expectedRevision: 1,
        traversals: const [
          CableRunTraversal(
            id: 'tr-1',
            cableRunId: 'run-1',
            sequence: 1,
            routeSegmentId: 'seg-new',
            direction: CableTraversalDirection.forward,
          ),
        ],
      );
      final firstRuntime = DriftElvReviewedRoutingRuntime(
        db,
        originDeviceId: 'test',
        idGenerator: FixedSequenceIdGenerator(const [
          'branch-1',
          'evidence-before-1',
          'evidence-after-1',
          'inverse-template-1',
        ]),
        now: _clock,
      );

      final committed = await firstRuntime.execute(reviewed);
      expect(committed, isA<ElvCommandSuccess<Object?>>());
      await _expectRoute(db, 'seg-new', revision: 2);
      await _expectHistory(
        db,
        state: 'APPLIED',
        headSequence: 1,
        generation: 1,
        executionKinds: const {'ORIGINAL'},
      );
      final evidence = await db.select(db.elvRevisionAggregateEvidenceRecords).get();
      expect(evidence, hasLength(2));
      expect(evidence.map((row) => row.payloadSha256).toSet(), hasLength(2));
      expect(
        evidence.every((row) => row.canonicalPayloadJson.contains('traversals')),
        isTrue,
      );

      db = await harness.reopen(db);
      final undoRuntime = DriftElvReviewedRoutingRuntime(
        db,
        originDeviceId: 'test-reopen-undo',
        idGenerator: FixedSequenceIdGenerator(const ['undo-execution-1']),
        now: _clock,
      );
      expect(
        await undoRuntime.canUndo(
          projectId: 'project',
          designRevisionId: 'rev-1',
        ),
        isTrue,
      );
      final undone = await undoRuntime.undo(
        projectId: 'project',
        designRevisionId: 'rev-1',
      );
      expect(undone, isA<ElvCommandSuccess<Object?>>());
      await _expectRoute(db, 'seg-old', revision: 3);
      await _expectHistory(
        db,
        state: 'UNDONE',
        headSequence: 0,
        generation: 2,
        executionKinds: const {'ORIGINAL', 'UNDO'},
      );

      db = await harness.reopen(db);
      final redoRuntime = DriftElvReviewedRoutingRuntime(
        db,
        originDeviceId: 'test-reopen-redo',
        idGenerator: FixedSequenceIdGenerator(const ['redo-execution-1']),
        now: _clock,
      );
      expect(
        await redoRuntime.canRedo(
          projectId: 'project',
          designRevisionId: 'rev-1',
        ),
        isTrue,
      );
      final redone = await redoRuntime.redo(
        projectId: 'project',
        designRevisionId: 'rev-1',
      );
      expect(redone, isA<ElvCommandSuccess<Object?>>());
      await _expectRoute(db, 'seg-new', revision: 4);
      await _expectHistory(
        db,
        state: 'APPLIED',
        headSequence: 1,
        generation: 3,
        executionKinds: const {'ORIGINAL', 'UNDO', 'REDO'},
      );

      await db.close();
    },
  );
}

DateTime _clock() => DateTime.utc(2026, 10, 15, 13, 45);

Future<void> _seed(AppDatabase db) async {
  final now = _clock();
  await db.into(db.projects).insert(
    ProjectsCompanion.insert(
      id: 'project',
      name: 'P7 T06',
      measurementSystem: 'metric',
      defaultStructuralHeightMm: 3000,
      defaultFinishedCeilingHeightMm: 2700,
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.floors).insert(
    FloorsCompanion.insert(
      id: 'floor-1',
      projectId: 'project',
      name: 'F1',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.rooms).insert(
    RoomsCompanion.insert(
      id: 'room-1',
      floorId: 'floor-1',
      name: 'Room',
      roomType: 'technical',
      roomCategory: 'technical',
      widthMm: 4000,
      depthMm: 3000,
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.surfacePatches).insert(
    SurfacePatchesCompanion.insert(
      id: 'patch-1',
      roomId: 'room-1',
      surfaceId: 'wall-a',
      originXmm: 0,
      originYmm: 0,
      originZmm: 0,
      uAxisX: 1,
      uAxisY: 0,
      uAxisZ: 0,
      vAxisX: 0,
      vAxisY: 0,
      vAxisZ: 1,
      orientation: 'vertical',
      boundaryJson: '[[0,0],[4000,0],[4000,3000],[0,3000]]',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.cableRoutes).insert(
    CableRoutesCompanion.insert(
      id: 'route-1',
      roomId: 'room-1',
      name: 'Route',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.cableRouteNodes).insert(
    CableRouteNodesCompanion.insert(
      id: 'node-a',
      routeId: 'route-1',
      sequence: 1,
      kind: 'POINT',
      patchId: 'patch-1',
      localXmm: 0,
      localYmm: 0,
      worldXmm: 0,
      worldYmm: 0,
      worldZmm: 0,
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.cableRouteNodes).insert(
    CableRouteNodesCompanion.insert(
      id: 'node-b',
      routeId: 'route-1',
      sequence: 2,
      kind: 'POINT',
      patchId: 'patch-1',
      localXmm: 1000,
      localYmm: 0,
      worldXmm: 1000,
      worldYmm: 0,
      worldZmm: 0,
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  for (final (sequence, id) in const [(1, 'seg-old'), (2, 'seg-new')]) {
    await db.into(db.cableRouteSegments).insert(
      CableRouteSegmentsCompanion.insert(
        id: id,
        routeId: 'route-1',
        sequence: sequence,
        fromNodeId: 'node-a',
        toNodeId: 'node-b',
        surfacePatchId: 'patch-1',
        layingMethod: 'TRAY',
        createdAt: now,
        updatedAt: now,
        originDeviceId: 'seed',
      ),
    );
  }
  await db.into(db.engineeringReferenceCatalogs).insert(
    EngineeringReferenceCatalogsCompanion.insert(
      id: 'catalog-1',
      projectId: 'project',
      code: 'TEST',
      catalogVersion: '1',
      payloadJson: '{}',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.elvCables).insert(
    ElvCablesCompanion.insert(
      id: 'cable-1',
      projectId: 'project',
      label: 'C1',
      normalizedLabel: 'C1',
      name: 'Cable',
      definitionCatalogId: 'catalog-1',
      definitionCatalogVersion: '1',
      definitionCode: 'TEST-CABLE',
      definitionContentHash: List.filled(64, 'a').join(),
      lifecycleState: 'ACTIVE',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.projectDesignRevisions).insert(
    ProjectDesignRevisionsCompanion.insert(
      id: 'rev-1',
      projectId: 'project',
      code: 'R1',
      sequence: 1,
      state: 'WORKING',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.canonicalCableRuns).insert(
    CanonicalCableRunsCompanion.insert(
      id: 'run-1',
      projectId: 'project',
      cableId: 'cable-1',
      designRevisionId: 'rev-1',
      lifecycleState: 'ACTIVE',
      reservePercent: const Value(0),
      terminationAllowanceMm: const Value(0),
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
  await db.into(db.cableRunTraversals).insert(
    CableRunTraversalsCompanion.insert(
      id: 'tr-1',
      cableRunId: 'run-1',
      sequence: 1,
      routeSegmentId: 'seg-old',
      direction: 'FORWARD',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'seed',
    ),
  );
}

Future<void> _expectRoute(
  AppDatabase db,
  String routeSegmentId, {
  required int revision,
}) async {
  final run = await (db.select(db.canonicalCableRuns)
        ..where((row) => row.id.equals('run-1')))
      .getSingle();
  final traversal = await (db.select(db.cableRunTraversals)
        ..where((row) => row.cableRunId.equals('run-1')))
      .getSingle();
  expect(run.revision, revision);
  expect(traversal.routeSegmentId, routeSegmentId);
}

Future<void> _expectHistory(
  AppDatabase db, {
  required String state,
  required int headSequence,
  required int generation,
  required Set<String> executionKinds,
}) async {
  final operation = await db.select(db.elvRevisionCommandHistoryOperations).getSingle();
  final cursor = await db.select(db.elvRevisionCommandHistoryCursors).getSingle();
  final executions = await db.select(db.elvRevisionCommandHistoryExecutions).get();
  expect(operation.state, state);
  expect(cursor.headSequence, headSequence);
  expect(cursor.generation, generation);
  expect(executions, hasLength(executionKinds.length));
  expect(executions.map((row) => row.executionKind).toSet(), executionKinds);
}
