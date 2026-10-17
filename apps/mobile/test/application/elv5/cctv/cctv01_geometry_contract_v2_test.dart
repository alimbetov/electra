import 'package:electra_mobile/application/elv5/cctv/cctv01_geometry_contract.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Cctv01ExactVec3Contract v(int x, int y, int z) =>
      Cctv01ExactVec3Contract(
        x: Elv5Rational.integer(x),
        y: Elv5Rational.integer(y),
        z: Elv5Rational.integer(z),
      );

  Cctv01GeometryContract contractV2() => Cctv01GeometryContract(
    cameraId: 'cam-1',
    roomId: 'room-1',
    expectedDefinitionId: 'camera-def',
    expectedDefinitionVersion: 3,
    targetSurfacePatchId: 'target-patch',
    geometryModelEditionId: 'geometry-edition-1',
    geometryModelContentHash: List<String>.filled(64, 'a').join(),
    rectilinearPinholeSupported: true,
    targetIsPlanar: true,
    sensorWidthMm: Elv5Rational.integer(8),
    sensorHeightMm: Elv5Rational.integer(6),
    focalLengthMm: Elv5Rational.integer(4),
    forward: v(1, 0, 0),
    right: v(0, 1, 0),
    up: v(0, 0, 1),
    minimumCoverageRatio: Elv5Rational(BigInt.one, BigInt.from(2)),
    expectedHostSurfacePatchId: 'host-patch',
    hostSurfaceFrame: Cctv01ExactSurfaceFrameContract(
      uAxis: v(0, 1, 0),
      vAxis: v(0, 0, 1),
    ),
    targetSurfaceFrame: Cctv01ExactSurfaceFrameContract(
      uAxis: v(0, 1, 0),
      vAxis: v(0, 0, 1),
    ),
    legacyFrameAxisTolerance: Elv5Rational(
      BigInt.one,
      BigInt.from(1000000000),
    ),
  );

  test('v2 exact surface frames round-trip canonically', () {
    final original = contractV2();
    final decoded = Cctv01GeometryContract.fromMap(
      original.toCanonicalValue(),
    );

    expect(original.effectiveSchema, Cctv01GeometryContract.schema);
    expect(decoded.hasExactSurfaceFrames, isTrue);
    expect(decoded.expectedHostSurfacePatchId, 'host-patch');
    expect(
      const Elv5CanonicalJsonV1().sha256(decoded.toCanonicalValue()),
      const Elv5CanonicalJsonV1().sha256(original.toCanonicalValue()),
    );
  });

  test('legacy v1 edition remains readable but is not exact-frame qualified', () {
    final v2 = contractV2().toCanonicalValue();
    final legacy = Map<String, Object?>.from(v2)
      ..['schema'] = Cctv01GeometryContract.legacySchema
      ..remove('expectedHostSurfacePatchId')
      ..remove('hostSurfaceFrame')
      ..remove('targetSurfaceFrame')
      ..remove('legacyFrameAxisTolerance');

    final decoded = Cctv01GeometryContract.fromMap(legacy);
    expect(decoded.effectiveSchema, Cctv01GeometryContract.legacySchema);
    expect(decoded.hasExactSurfaceFrames, isFalse);
  });

  test('surface frame rejects non-unit or non-orthogonal axes', () {
    expect(
      () => Cctv01ExactSurfaceFrameContract(
        uAxis: Cctv01ExactVec3Contract(
          x: Elv5Rational.integer(2),
          y: Elv5Rational.zero,
          z: Elv5Rational.zero,
        ),
        vAxis: v(0, 1, 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => Cctv01ExactSurfaceFrameContract(
        uAxis: v(1, 0, 0),
        vAxis: v(1, 0, 0),
      ),
      throwsArgumentError,
    );
  });

  test('v2 surface-frame fields are atomic all-or-none', () {
    expect(
      () => Cctv01GeometryContract(
        cameraId: 'cam-1',
        roomId: 'room-1',
        expectedDefinitionId: 'camera-def',
        expectedDefinitionVersion: 1,
        targetSurfacePatchId: 'target-patch',
        geometryModelEditionId: 'edition',
        geometryModelContentHash: List<String>.filled(64, 'b').join(),
        rectilinearPinholeSupported: true,
        targetIsPlanar: true,
        sensorWidthMm: Elv5Rational.integer(8),
        sensorHeightMm: Elv5Rational.integer(6),
        focalLengthMm: Elv5Rational.integer(4),
        forward: v(1, 0, 0),
        right: v(0, 1, 0),
        up: v(0, 0, 1),
        expectedHostSurfacePatchId: 'host-patch',
      ),
      throwsArgumentError,
    );
  });
}
