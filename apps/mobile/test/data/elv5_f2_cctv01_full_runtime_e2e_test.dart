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
    'F2 CCTV-01 production Q6/Q7/Q8 immutable exact surface frames and optical contract survive restart and freeze',
    () async {
      final lifecycle = Elv5F2ProductionLifecycle(
        process: Elv5ProcessCode.cctv01,
        subjectKind: 'CAMERA',
        subjectId: 'cam-1',
      );
      await lifecycle.run(
        seed: (db) async {
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
