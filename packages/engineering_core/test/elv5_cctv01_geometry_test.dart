import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Elv5Rational q(String value) => Elv5Rational.parseDecimal(value);
  Length m(String value) => Length(q(value));
  Cctv01Point2 p2(String x, String y) => Cctv01Point2(q(x), q(y));
  Cctv01Point3 p3(String x, String y, String z) => Cctv01Point3(q(x), q(y), q(z));
  Cctv01Vec3 v3(String x, String y, String z) => Cctv01Vec3(q(x), q(y), q(z));

  final down = Cctv01ResolvedOrientation(
    forward: v3('0', '0', '-1'),
    right: v3('1', '0', '0'),
    up: v3('0', '1', '0'),
  );
  final floor = Cctv01Plane(
    origin: p3('0', '0', '0'),
    uAxis: v3('1', '0', '0'),
    vAxis: v3('0', '1', '0'),
  );
  final intrinsics = Cctv01PinholeIntrinsics(
    sensorWidth: m('0.006'),
    sensorHeight: m('0.004'),
    focalLength: m('0.006'),
  );

  Cctv01Input input({
    Cctv01Polygon2? zone,
    Elv5Rational? minimum,
    String cameraFrame = 'project',
    String targetFrame = 'project',
    bool transformResolved = true,
    bool supported = true,
    bool planar = true,
    Cctv01ResolvedOrientation? orientation,
    Cctv01PinholeIntrinsics? cameraIntrinsics,
  }) =>
      Cctv01Input(
        cameraId: 'camera-1',
        cameraFrameId: cameraFrame,
        targetFrameId: targetFrame,
        frameTransformResolved: transformResolved,
        rectilinearPinholeSupported: supported,
        targetIsPlanar: planar,
        opticalCenter: p3('0', '0', '3'),
        orientation: orientation ?? down,
        intrinsics: cameraIntrinsics ?? intrinsics,
        targetPlane: floor,
        targetZone: zone ?? Cctv01Polygon2([
          p2('-1.5', '-1'),
          p2('1.5', '-1'),
          p2('1.5', '1'),
          p2('-1.5', '1'),
        ]),
        minimumCoverageRatio: minimum,
      );

  test('reference normal camera projects exact 3x2 m footprint and full coverage', () {
    final result = const Cctv01GeometryKernel().evaluate(input(minimum: q('1')));

    expect(result.status, Cctv01AssessmentStatus.pass);
    expect(result.footprint!.area, q('6'));
    expect(result.coveredArea, q('6'));
    expect(result.targetArea, q('6'));
    expect(result.coverageRatio, q('1'));
    expect(result.coverageMargin, q('0'));
    expect(result.horizontalHalfFovTangent, q('0.5'));
    expect(result.verticalHalfFovTangent, Elv5Rational(BigInt.one, BigInt.from(3)));
  });

  test('coverage policy fails with exact signed ratio margin', () {
    final result = const Cctv01GeometryKernel().evaluate(input(
      zone: Cctv01Polygon2([
        p2('-2', '-1'),
        p2('2', '-1'),
        p2('2', '1'),
        p2('-2', '1'),
      ]),
      minimum: q('0.9'),
    ));

    expect(result.coveredArea, q('6'));
    expect(result.targetArea, q('8'));
    expect(result.coverageRatio, q('0.75'));
    expect(result.coverageMargin, q('-0.15'));
    expect(result.status, Cctv01AssessmentStatus.fail);
    expect(result.governingDimension, Cctv01GoverningDimension.zoneCoverage);
  });

  test('mixed frames without captured transform block before geometry', () {
    final result = const Cctv01GeometryKernel().evaluate(input(
      cameraFrame: 'camera-local',
      targetFrame: 'project',
      transformResolved: false,
    ));

    expect(result.status, Cctv01AssessmentStatus.blocked);
    expect(result.reasonCode, 'CCTV01_FRAME_TRANSFORM_REQUIRED');
  });

  test('plane-parallel rays remain unresolved with no finite sentinel', () {
    final parallel = Cctv01ResolvedOrientation(
      forward: v3('1', '0', '0'),
      right: v3('0', '1', '0'),
      up: v3('1', '1', '0'),
    );
    final result = const Cctv01GeometryKernel().evaluate(input(orientation: parallel));

    expect(result.status, Cctv01AssessmentStatus.unresolved);
    expect(result.governingDimension, Cctv01GoverningDimension.rayIntersection);
    expect(result.reasonCode, 'CCTV01_RAY_PARALLEL_TO_PLANE');
    expect(result.footprint, isNull);
  });

  test('unsupported lens model never falls back to pinhole', () {
    final result = const Cctv01GeometryKernel().evaluate(input(supported: false));
    expect(result.status, Cctv01AssessmentStatus.unsupported);
    expect(result.reasonCode, 'CCTV01_UNSUPPORTED_CAMERA_MODEL');
  });

  test('non-planar target is explicitly unsupported in v1', () {
    final result = const Cctv01GeometryKernel().evaluate(input(planar: false));
    expect(result.status, Cctv01AssessmentStatus.unsupported);
    expect(result.reasonCode, 'CCTV01_NONPLANAR_TARGET_UNSUPPORTED');
  });

  test('simple concave target is triangulated and clipped deterministically', () {
    final concave = Cctv01Polygon2([
      p2('-1', '-1'),
      p2('1', '-1'),
      p2('1', '0'),
      p2('0', '0'),
      p2('0', '1'),
      p2('-1', '1'),
    ]);
    final result = const Cctv01GeometryKernel().evaluate(input(zone: concave));

    expect(result.status, Cctv01AssessmentStatus.pass);
    expect(result.coveredArea, concave.area);
    expect(result.coverageRatio, q('1'));
  });
}
