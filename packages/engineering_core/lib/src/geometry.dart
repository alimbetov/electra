import 'dart:math' as math;

/// Integer-millimetre point used for persisted planar geometry.
final class Point2Mm {
  const Point2Mm(this.xMm, this.yMm);

  final int xMm;
  final int yMm;

  Point2Mm operator +(Vector2Mm vector) =>
      Point2Mm(xMm + vector.dxMm, yMm + vector.dyMm);

  Vector2Mm operator -(Point2Mm other) =>
      Vector2Mm(xMm - other.xMm, yMm - other.yMm);

  @override
  bool operator ==(Object other) =>
      other is Point2Mm && other.xMm == xMm && other.yMm == yMm;

  @override
  int get hashCode => Object.hash(xMm, yMm);
}

/// Integer-millimetre point used for persisted world geometry.
final class Point3Mm {
  const Point3Mm(this.xMm, this.yMm, this.zMm);

  final int xMm;
  final int yMm;
  final int zMm;

  @override
  bool operator ==(Object other) =>
      other is Point3Mm &&
      other.xMm == xMm &&
      other.yMm == yMm &&
      other.zMm == zMm;

  @override
  int get hashCode => Object.hash(xMm, yMm, zMm);
}

final class Point2D {
  const Point2D(this.x, this.y);

  final double x;
  final double y;
}

final class Point3D {
  const Point3D(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double distanceTo(Point3D other) {
    final dx = x - other.x;
    final dy = y - other.y;
    final dz = z - other.z;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

final class Vector2Mm {
  const Vector2Mm(this.dxMm, this.dyMm);

  final int dxMm;
  final int dyMm;

  double get lengthMm => math.sqrt(dxMm * dxMm + dyMm * dyMm);
}

final class Vector3D {
  const Vector3D(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double get length => math.sqrt(x * x + y * y + z * z);

  Vector3D normalized() {
    final magnitude = length;
    if (magnitude == 0) {
      throw ArgumentError.value(this, 'vector', 'Vector must be non-zero.');
    }
    return Vector3D(x / magnitude, y / magnitude, z / magnitude);
  }

  double dot(Vector3D other) => x * other.x + y * other.y + z * other.z;

  Vector3D cross(Vector3D other) => Vector3D(
    y * other.z - z * other.y,
    z * other.x - x * other.z,
    x * other.y - y * other.x,
  );

  Vector3D operator *(double scale) =>
      Vector3D(x * scale, y * scale, z * scale);
}

final class Segment2Mm {
  Segment2Mm(this.start, this.end) {
    if (start == end) {
      throw ArgumentError('Segment endpoints must be distinct.');
    }
  }

  final Point2Mm start;
  final Point2Mm end;

  double get lengthMm => (end - start).lengthMm;
}

final class Segment3Mm {
  Segment3Mm(this.start, this.end) {
    if (start == end) {
      throw ArgumentError('Segment endpoints must be distinct.');
    }
  }

  final Point3Mm start;
  final Point3Mm end;

  double get lengthMm {
    final dx = end.xMm - start.xMm;
    final dy = end.yMm - start.yMm;
    final dz = end.zMm - start.zMm;
    return math.sqrt(dx * dx + dy * dy + dz * dz);
  }
}

/// Closed simple polygon represented without repeating the first vertex at the end.
final class Polygon2Mm {
  Polygon2Mm(Iterable<Point2Mm> vertices)
    : vertices = List.unmodifiable(vertices) {
    if (this.vertices.length < 3) {
      throw ArgumentError('Polygon requires at least three vertices.');
    }
    for (var i = 0; i < this.vertices.length; i++) {
      final next = (i + 1) % this.vertices.length;
      if (this.vertices[i] == this.vertices[next]) {
        throw ArgumentError('Polygon cannot contain zero-length edges.');
      }
    }
    if (signedDoubleAreaMm2 == 0) {
      throw ArgumentError('Polygon area must be non-zero.');
    }
    if (_hasSelfIntersection()) {
      throw ArgumentError('Polygon must be simple and cannot self-intersect.');
    }
  }

  final List<Point2Mm> vertices;

  int get signedDoubleAreaMm2 {
    var sum = 0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      sum += a.xMm * b.yMm - b.xMm * a.yMm;
    }
    return sum;
  }

  double get areaMm2 => signedDoubleAreaMm2.abs() / 2.0;

  List<Segment2Mm> get edges => List.unmodifiable([
    for (var i = 0; i < vertices.length; i++)
      Segment2Mm(vertices[i], vertices[(i + 1) % vertices.length]),
  ]);

  bool containsPointInclusive(Point2Mm point) {
    final polygonEdges = edges;
    for (final edge in polygonEdges) {
      if (_pointOnSegment(point, edge.start, edge.end)) {
        return true;
      }
    }

    var inside = false;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final a = vertices[i];
      final b = vertices[j];
      final crossesRay = (a.yMm > point.yMm) != (b.yMm > point.yMm);
      if (!crossesRay) {
        continue;
      }
      final crossingX =
          (b.xMm - a.xMm) * (point.yMm - a.yMm) /
              (b.yMm - a.yMm) +
          a.xMm;
      if (point.xMm < crossingX) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// True when all of [other] lies inside or on this polygon boundary.
  bool containsPolygon(Polygon2Mm other) {
    if (!other.vertices.every(containsPointInclusive)) {
      return false;
    }
    for (final childEdge in other.edges) {
      for (final hostEdge in edges) {
        if (_segmentsProperlyIntersect(
          childEdge.start,
          childEdge.end,
          hostEdge.start,
          hostEdge.end,
        )) {
          return false;
        }
      }
    }
    return true;
  }

  bool _hasSelfIntersection() {
    final polygonEdges = edges;
    for (var i = 0; i < polygonEdges.length; i++) {
      for (var j = i + 1; j < polygonEdges.length; j++) {
        final adjacent =
            j == i + 1 || (i == 0 && j == polygonEdges.length - 1);
        if (adjacent) {
          continue;
        }
        final a = polygonEdges[i];
        final b = polygonEdges[j];
        if (_segmentsIntersect(a.start, a.end, b.start, b.end)) {
          return true;
        }
      }
    }
    return false;
  }

  static int _cross(Point2Mm a, Point2Mm b, Point2Mm c) =>
      (b.xMm - a.xMm) * (c.yMm - a.yMm) -
      (b.yMm - a.yMm) * (c.xMm - a.xMm);

  static bool _pointOnSegment(Point2Mm p, Point2Mm a, Point2Mm b) {
    if (_cross(a, b, p) != 0) {
      return false;
    }
    return p.xMm >= math.min(a.xMm, b.xMm) &&
        p.xMm <= math.max(a.xMm, b.xMm) &&
        p.yMm >= math.min(a.yMm, b.yMm) &&
        p.yMm <= math.max(a.yMm, b.yMm);
  }

  static bool _segmentsIntersect(
    Point2Mm a,
    Point2Mm b,
    Point2Mm c,
    Point2Mm d,
  ) {
    final o1 = _cross(a, b, c);
    final o2 = _cross(a, b, d);
    final o3 = _cross(c, d, a);
    final o4 = _cross(c, d, b);

    if (_oppositeSigns(o1, o2) && _oppositeSigns(o3, o4)) {
      return true;
    }
    return (o1 == 0 && _pointOnSegment(c, a, b)) ||
        (o2 == 0 && _pointOnSegment(d, a, b)) ||
        (o3 == 0 && _pointOnSegment(a, c, d)) ||
        (o4 == 0 && _pointOnSegment(b, c, d));
  }

  static bool _segmentsProperlyIntersect(
    Point2Mm a,
    Point2Mm b,
    Point2Mm c,
    Point2Mm d,
  ) {
    final o1 = _cross(a, b, c);
    final o2 = _cross(a, b, d);
    final o3 = _cross(c, d, a);
    final o4 = _cross(c, d, b);
    return _oppositeSigns(o1, o2) && _oppositeSigns(o3, o4);
  }

  static bool _oppositeSigns(int a, int b) => (a < 0 && b > 0) || (a > 0 && b < 0);
}

final class GeometryTolerance {
  const GeometryTolerance({
    this.linearMm = 0.5,
    this.angularRadians = 1e-6,
  }) : assert(linearMm >= 0),
       assert(angularRadians >= 0);

  final double linearMm;
  final double angularRadians;

  bool nearlyEqual(double a, double b) => (a - b).abs() <= linearMm;

  bool pointsEqual(Point3D a, Point3D b) => a.distanceTo(b) <= linearMm;

  bool vectorsParallel(Vector3D a, Vector3D b) {
    final an = a.normalized();
    final bn = b.normalized();
    final dot = an.dot(bn).abs().clamp(-1.0, 1.0);
    final angle = math.acos(dot);
    return angle <= angularRadians;
  }
}

final class Plane {
  Plane({required this.origin, required Vector3D normal})
    : normal = normal.normalized();

  final Point3Mm origin;
  final Vector3D normal;

  double signedDistanceMm(Point3D point) {
    final delta = Vector3D(
      point.x - origin.xMm,
      point.y - origin.yMm,
      point.z - origin.zMm,
    );
    return delta.dot(normal);
  }
}

/// Reversible local 2D frame embedded in 3D world space.
final class LocalCoordinateFrame {
  LocalCoordinateFrame({
    required this.origin,
    required Vector3D uAxis,
    required Vector3D vAxis,
    this.tolerance = const GeometryTolerance(),
  }) : uAxis = uAxis.normalized(),
       vAxis = vAxis.normalized() {
    final dot = this.uAxis.dot(this.vAxis).abs();
    if (dot > tolerance.angularRadians) {
      throw ArgumentError('uAxis and vAxis must be orthogonal.');
    }
  }

  final Point3Mm origin;
  final Vector3D uAxis;
  final Vector3D vAxis;
  final GeometryTolerance tolerance;

  Vector3D get normal => uAxis.cross(vAxis).normalized();

  Point3D localToWorld(Point2Mm local) => Point3D(
    origin.xMm + uAxis.x * local.xMm + vAxis.x * local.yMm,
    origin.yMm + uAxis.y * local.xMm + vAxis.y * local.yMm,
    origin.zMm + uAxis.z * local.xMm + vAxis.z * local.yMm,
  );

  Point2D worldToLocal(Point3D world) {
    final delta = Vector3D(
      world.x - origin.xMm,
      world.y - origin.yMm,
      world.z - origin.zMm,
    );
    final offPlane = delta.dot(normal).abs();
    if (offPlane > tolerance.linearMm) {
      throw ArgumentError.value(
        world,
        'world',
        'Point is not on the local frame plane within tolerance.',
      );
    }
    return Point2D(delta.dot(uAxis), delta.dot(vAxis));
  }
}
