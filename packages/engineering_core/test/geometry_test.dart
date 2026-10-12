import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  group('concave segment containment', () {
    final host = Polygon2Mm(const [
      Point2Mm(0, 0),
      Point2Mm(6, 0),
      Point2Mm(6, 6),
      Point2Mm(4, 6),
      Point2Mm(4, 2),
      Point2Mm(2, 2),
      Point2Mm(2, 6),
      Point2Mm(0, 6),
    ]);

    test('rejects crossing a notch with both endpoints inside', () {
      expect(
        host.containsSegment(
          Segment2Mm(const Point2Mm(1, 4), const Point2Mm(5, 4)),
        ),
        isFalse,
      );
    });

    test('rejects exit through vertices in either direction', () {
      for (final points in [
        const [Point2Mm(2, 6), Point2Mm(4, 6)],
        const [Point2Mm(4, 6), Point2Mm(2, 6)],
      ]) {
        expect(host.containsSegment(Segment2Mm(points[0], points[1])), isFalse);
      }
    });

    test(
      'detects a one-mm exterior interval without rounding its midpoint',
      () {
        final narrow = Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(5, 0),
          Point2Mm(5, 5),
          Point2Mm(3, 5),
          Point2Mm(3, 2),
          Point2Mm(2, 2),
          Point2Mm(2, 5),
          Point2Mm(0, 5),
        ]);
        expect(
          narrow.containsSegment(
            Segment2Mm(const Point2Mm(2, 5), const Point2Mm(3, 5)),
          ),
          isFalse,
        );
      },
    );

    test('accepts boundary overlap and a tangent vertex contact', () {
      expect(
        host.containsSegment(
          Segment2Mm(const Point2Mm(0, 2), const Point2Mm(6, 2)),
        ),
        isTrue,
      );
      expect(
        host.containsSegment(
          Segment2Mm(const Point2Mm(0, 4), const Point2Mm(4, 0)),
        ),
        isTrue,
      );
    });

    test('polygon containment rejects a bridge across notch vertices', () {
      expect(
        host.containsPolygon(
          Polygon2Mm(const [
            Point2Mm(0, 0),
            Point2Mm(6, 0),
            Point2Mm(4, 6),
            Point2Mm(2, 6),
          ]),
        ),
        isFalse,
      );
    });
  });

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

    test('polygon rejects self-intersection', () {
      expect(
        () => Polygon2Mm(const [
          Point2Mm(0, 0),
          Point2Mm(2000, 2000),
          Point2Mm(0, 2000),
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

    test('polygon containment includes host boundary', () {
      final host = Polygon2Mm(const [
        Point2Mm(0, 0),
        Point2Mm(4000, 0),
        Point2Mm(4000, 3000),
        Point2Mm(0, 3000),
      ]);
      final door = Polygon2Mm(const [
        Point2Mm(500, 0),
        Point2Mm(1400, 0),
        Point2Mm(1400, 2100),
        Point2Mm(500, 2100),
      ]);

      expect(host.containsPolygon(door), isTrue);
      expect(host.containsPointInclusive(const Point2Mm(0, 1500)), isTrue);
    });

    test('polygon containment rejects geometry leaving a concave host', () {
      final host = Polygon2Mm(const [
        Point2Mm(0, 0),
        Point2Mm(4000, 0),
        Point2Mm(4000, 1000),
        Point2Mm(1000, 1000),
        Point2Mm(1000, 4000),
        Point2Mm(0, 4000),
      ]);
      final crossing = Polygon2Mm(const [
        Point2Mm(500, 500),
        Point2Mm(3500, 500),
        Point2Mm(500, 3500),
      ]);

      expect(host.containsPolygon(crossing), isFalse);
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
        tolerance.pointsEqual(const Point3D(1, 2, 3), const Point3D(2, 2, 3)),
        isFalse,
      );
    });
  });
}
