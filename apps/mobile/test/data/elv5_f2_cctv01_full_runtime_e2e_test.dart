import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:electra_mobile/data/repositories/drift_component_instance_repository.dart';
import 'package:electra_mobile/data/repositories/drift_geometry_repository.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_cctv01_geometry_contract_store.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_discipline_snapshot_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv01_geometry_contract.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_cctv_contract_mutation_coordinator.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/elv5_f2_fire_sources.dart';
import '../support/elv5_f2_lan_sources.dart' show f2LanHash;
import '../support/elv5_f2_production_lifecycle.dart';

void main() {
  test(
    'CCTV01 create-next restores policy with revision-scoped evidence and no derived history',
    () async {
      final dir = await Directory.systemTemp.createTemp('f2-create-next-');
      final file = File('${dir.path}/db.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await _seedGeometry(db);
      await _replace(db, 1, null, false);
      final life = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv01,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      )..db = db;
      await life.runtime(db).service.execute(life.command('r1', 2, 0));
      final revisions = DriftElvDesignRevisionRepository(
        db,
        originDeviceId: 'review',
      );
      expect(
        await revisions.freeze(
          const FreezeProjectDesignRevisionCommand(
            commandId: 'freeze',
            projectId: 'p',
            designRevisionId: 'd',
            expectedRevision: 2,
          ),
        ),
        isA<ElvCommandSuccess<ProjectDesignRevision>>(),
      );
      final reader = DriftElv5DisciplineSnapshotStore(
        db,
        originDeviceId: 'review',
        nowUtc: Elv5F2ProductionLifecycle.now,
      );
      final frozen =
          (await reader.read(projectId: 'p', designRevisionId: 'd')).payload;
      expect(
        await revisions.createNext(
          const CreateNextWorkingDesignRevisionCommand(
            commandId: 'next',
            projectId: 'p',
            newRevisionId: 'd2',
            code: 'R2',
            basedOnRevisionId: 'd',
          ),
        ),
        isA<ElvCommandSuccess<ProjectDesignRevision>>(),
      );
      var store = DriftCctv01GeometryContractStore(
        db,
        originDeviceId: 'review',
      );
      final old =
          (await store.loadActiveForCamera(
            projectId: 'p',
            designRevisionId: 'd',
            cameraId: 'cam-1',
          ))!;
      final next =
          (await store.loadActiveForCamera(
            projectId: 'p',
            designRevisionId: 'd2',
            cameraId: 'cam-1',
          ))!;
      expect(next.contentHash, old.contentHash);
      expect(next.evidenceRef, isNot(old.evidenceRef));
      expect(next.bindingId, isNot(old.bindingId));
      for (final table in [
        'discipline_evaluation_records',
        'discipline_evaluation_pointers',
        'discipline_dependency_index',
        'elv_revision_command_history_operations',
      ]) {
        expect(
          await db
              .customSelect(
                "SELECT * FROM $table WHERE design_revision_id='d2'",
              )
              .get(),
          isEmpty,
        );
      }
      // Replacing the identical contract in R2 must find its own evidence row.
      await store.replace(
        ReplaceCctv01GeometryContractCommand(
          projectId: 'p',
          designRevisionId: 'd2',
          bindingId: next.bindingId,
          expectedBindingRevision: 1,
          expectedDesignRevision: 1,
          contract: next.contract,
        ),
      );
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      store = DriftCctv01GeometryContractStore(db, originDeviceId: 'review');
      expect(
        (await store.loadActiveForCamera(
          projectId: 'p',
          designRevisionId: 'd2',
          cameraId: 'cam-1',
        ))!.evidenceRef,
        next.evidenceRef,
      );
      expect(
        (await DriftElv5DisciplineSnapshotStore(
          db,
          originDeviceId: 'review',
          nowUtc: Elv5F2ProductionLifecycle.now,
        ).read(projectId: 'p', designRevisionId: 'd')).payload,
        frozen,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test(
    'CCTV01 canonical placement and geometry invalidate atomically with capture token',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await _seedGeometry(db);
      await _replace(db, 1, null, false);
      final life = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv01,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      )..db = db;
      await life.runtime(db).service.execute(life.command('first', 2, 0));
      final components = DriftComponentInstanceRepository(
        db,
        originDeviceId: 'review',
      );
      final moved = ComponentInstance(
        id: 'cam-1',
        definitionId: 'fictional-camera',
        definitionVersion: 1,
        roomId: 'room-1',
        hostSurfacePatchId: 'patch-x',
        localPosition: const Point2Mm(2100, 2000),
      );
      await db.customStatement(
        "CREATE TEMP TRIGGER reject_invalidation BEFORE UPDATE ON discipline_evaluation_pointers WHEN NEW.freshness='STALE' BEGIN SELECT RAISE(ABORT,'CANONICAL_ROLLBACK'); END",
      );
      await expectLater(
        components.saveComponent(moved),
        throwsA(predicate((e) => e.toString().contains('CANONICAL_ROLLBACK'))),
      );
      expect(await life.revision(), 2);
      expect(
        (await components.loadRoomComponents(
          'room-1',
        )).singleWhere((c) => c.id == 'cam-1').localPosition.xMm,
        2000,
      );
      expect((await life.pointer()).read<String>('freshness'), 'CURRENT');
      await db.customStatement('DROP TRIGGER reject_invalidation');
      await components.saveComponent(moved);
      expect(await life.revision(), 3);
      expect((await life.pointer()).read<String>('freshness'), 'STALE');
      await life.runtime(db).service.execute(life.command('moved', 3, 2));
      final geometry = DriftGeometryRepository(db, originDeviceId: 'review');
      final room = await geometry.loadRoomGeometry('room-1');
      await geometry.replaceRoomGeometry(
        RoomGeometrySnapshot(
          roomId: room.roomId,
          patches: [
            for (final patch in room.patches)
              if (patch.id != 'target-patch')
                patch
              else
                SurfacePatch(
                  id: patch.id,
                  roomId: patch.roomId,
                  surfaceId: patch.surfaceId,
                  frame: patch.frame,
                  orientation: patch.orientation,
                  boundary: Polygon2Mm(const [
                    Point2Mm(0, 0),
                    Point2Mm(3900, 0),
                    Point2Mm(3900, 3900),
                    Point2Mm(0, 3900),
                  ]),
                ),
          ],
          edges: room.edges,
          adjacencies: room.adjacencies,
          openings: room.openings,
          features: room.features,
        ),
      );
      expect(await life.revision(), 4);
      expect((await life.pointer()).read<String>('freshness'), 'STALE');
      expect((await life.pointer()).read<int>('generation'), 4);
    },
  );

  test(
    'CCTV01 first geometry contract invalidates missing-contract CURRENT after restart',
    () async {
      final life = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv01,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      );
      final dir = await Directory.systemTemp.createTemp('cctv01-missing-');
      final file = File('${dir.path}/db.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      life.db = db;
      addTearDown(() async {
        await db.close();
        await dir.delete(recursive: true);
      });
      await _seedGeometry(db);
      await life.runtime(db).service.execute(life.command('missing', 1, 0));
      expect((await life.evaluation()).read<String>('execution'), 'BLOCKED');
      await _replace(db, 1, null, false);
      expect((await life.pointer()).read<String>('freshness'), 'STALE');
      await db.close();
      db = AppDatabase(NativeDatabase(file));
      life.db = db;
      expect((await life.pointer()).read<String>('freshness'), 'STALE');
      await life.runtime(db).service.execute(life.command('present', 2, 2));
      expect((await life.evaluation()).read<String>('assessment'), 'PASS');
    },
  );

  test(
    'F2 CCTV-01 production Q6/Q7/Q8 immutable exact surface frames and optical contract survive restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv01,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      );
      await lifecycle.run(
        seed: (db) async {
          await _seedGeometry(db);
          await _replace(db, 1, null, false);
        },
        mutate: (db) => _replace(db, 2, 1, true),
        dependencyDomains: {
          'CCTV01_GEOMETRY_CONTRACT',
          'ELV3_COMPONENT_PLACEMENT',
          'ELV3_SURFACE_PATCH',
        },
        initialOutput: (o) {
          expect(o['status'], 'pass');
          expect(o['coverageRatio'], Elv5Rational.one.toMap());
          expect(o['coverageMargin'], Elv5Rational.zero.toMap());
        },
        changedOutput: (o) {
          expect(o['status'], 'fail');
          expect(
            o['coverageRatio'],
            Elv5Rational(BigInt.from(3), BigInt.from(16)).toMap(),
          );
          expect(
            o['coverageMargin'],
            Elv5Rational(BigInt.from(-13), BigInt.from(16)).toMap(),
          );
        },
        mutationAfterFreeze: (db) async {
          await expectLater(
            _replace(db, 4, 2, false),
            throwsA(
              predicate(
                (e) =>
                    e.toString().contains('CCTV01_DESIGN_REVISION_READ_ONLY'),
              ),
            ),
          );
        },
      );
    },
  );
}

Cctv01ExactVec3Contract _v(int x, int y, int z) => Cctv01ExactVec3Contract(
  x: Elv5Rational.integer(x),
  y: Elv5Rational.integer(y),
  z: Elv5Rational.integer(z),
);
Future<void> _replace(
  AppDatabase db,
  int revision,
  int? bindingRevision,
  bool changed,
) => DriftElv5CctvContractMutationCoordinator(
  db,
  originDeviceId: 'f2-cctv',
  nowUtc: Elv5F2ProductionLifecycle.now,
).replaceCctv01(
  ReplaceCctv01GeometryContractCommand(
    projectId: 'p',
    designRevisionId: 'd',
    bindingId: 'geometry-policy',
    expectedBindingRevision: bindingRevision,
    expectedDesignRevision: revision,
    contract: Cctv01GeometryContract(
      cameraId: 'cam-1',
      roomId: 'room-1',
      expectedDefinitionId: 'fictional-camera',
      expectedDefinitionVersion: 1,
      targetSurfacePatchId: 'target-patch',
      geometryModelEditionId: 'exact-geometry-v1',
      geometryModelContentHash: f2LanHash('a'),
      rectilinearPinholeSupported: true,
      targetIsPlanar: true,
      sensorWidthMm: Elv5Rational.integer(8),
      sensorHeightMm: Elv5Rational.integer(6),
      focalLengthMm: Elv5Rational.integer(changed ? 4 : 1),
      forward: _v(0, 0, 1),
      right: _v(1, 0, 0),
      up: _v(0, 1, 0),
      minimumCoverageRatio: Elv5Rational.one,
      expectedHostSurfacePatchId: 'patch-x',
      hostSurfaceFrame: Cctv01ExactSurfaceFrameContract(
        uAxis: _v(1, 0, 0),
        vAxis: _v(0, 1, 0),
      ),
      targetSurfaceFrame: Cctv01ExactSurfaceFrameContract(
        uAxis: _v(1, 0, 0),
        vAxis: _v(0, 1, 0),
      ),
      legacyFrameAxisTolerance: Elv5Rational.zero,
    ),
  ),
);

Future<void> _seedGeometry(AppDatabase db) async {
  await seedF2FireTopology(db);
  final now = Elv5F2ProductionLifecycle.now();
  await db
      .into(db.componentInstances)
      .insert(
        ComponentInstancesCompanion.insert(
          id: 'cam-1',
          definitionId: 'fictional-camera',
          definitionVersion: 1,
          roomId: 'room-1',
          hostSurfacePatchId: 'patch-x',
          localXmm: 2000,
          localYmm: 2000,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-cctv',
        ),
      );
  await db
      .into(db.surfacePatches)
      .insert(
        SurfacePatchesCompanion.insert(
          id: 'target-patch',
          roomId: 'room-1',
          surfaceId: 'ceiling',
          originXmm: 0,
          originYmm: 0,
          originZmm: 1000,
          uAxisX: 1,
          uAxisY: 0,
          uAxisZ: 0,
          vAxisX: 0,
          vAxisY: 1,
          vAxisZ: 0,
          orientation: 'horizontal',
          boundaryJson: '[[0,0],[4000,0],[4000,4000],[0,4000]]',
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'f2-cctv',
        ),
      );
}
