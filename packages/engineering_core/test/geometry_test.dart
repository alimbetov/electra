import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('geometry primitives', () {
    test('segment length is deterministic in millimetres', () {
      final segment = Segment3Mm(
        const Point3Mm(0, 0, 0),
        const Point3Mm(3000, 4000, 0),
      );

      expect(segment.lengthMm, 5000);
    });

    test('polygon rejects degenerate geometry', () {
      expect(
        () => Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(1000, 0),
          Point2Mm(2000, 0),
        ]),
        throwsArgumentError,
      );
    });

    test('polygon area uses exact integer persisted coordinates', () {
      final polygon = Polygon2Mm(const [
        Point2Mm(0, 0),
        Point2Mm(4000, 0),
        Point2Mm(4000, 3000),
        Point2Mm(0, 3000),
      ]);

      expect(polygon.areaMm2, 12000000);
      expect(polygon.edges, hasLength(4));
    });

    test('local coordinate frame round trips within tolerance', () {
      final frame = LocalCoordinateFrame(
        origin: const Point3Mm(1000, 2000, 3000),
        uAxis: const Vector3D(1, 0, 0),
        vAxis: const Vector3D(0, 0, 1),
      );

      final world = frame.localToWorld(const Point2Mm(1500, 700));
      final local = frame.worldToLocal(world);

      expect(world.x, 2500);
      expect(world.y, 2000);
      expect(world.z, 3700);
      expect(local.x, closeTo(1500, 1e-9));
      expect(local.y, closeTo(700, 1e-9));
    });

    test('local coordinate frame rejects non-orthogonal axes', () {
      expect(
        () => LocalCoordinateFrame(
          origin: const Point3Mm(0, 0, 0),
          uAxis: const Vector3D(1, 0, 0),
          vAxis: const Vector3D(1, 1, 0),
        ),
        throwsArgumentError,
      );
    });

    test('geometry tolerance compares continuous world points', () {
      const tolerance = GeometryTolerance(linearMm: 0.5);
      expect(
        tolerance.pointsEqual(
          const Point3D(1, 2, 3),
          const Point3D(1.2, 2.1, 3.1),
        ),
        isTrue,
      );
      expect(
        tolerance.pointsEqual(
          const Point3D(1, 2, 3),
          const Point3D(2, 2, 3),
        ),
        isFalse,
      );
    });
  });
}
