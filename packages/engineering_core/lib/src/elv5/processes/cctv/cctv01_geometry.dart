import '../../numeric/quantity.dart';
import '../../numeric/rational.dart';

enum Cctv01AssessmentStatus {
  pass,
  fail,
  unresolved,
  blocked,
  unsupported,
  notAssessed,
}

enum Cctv01GoverningDimension {
  modelApplicability,
  frameTransform,
  rayIntersection,
  zoneCoverage,
}

/// Exact project-frame vector used only by the CCTV-01 calculation boundary.
/// Components are rational direction/scalar coordinates; persisted geometry
/// remains owned by the ELV3 geometry model.
final class Cctv01Vec3 {
  const Cctv01Vec3(this.x, this.y, this.z);

  final Elv5Rational x;
  final Elv5Rational y;
  final Elv5Rational z;

  Cctv01Vec3 operator +(Cctv01Vec3 other) =>
      Cctv01Vec3(x + other.x, y + other.y, z + other.z);
  Cctv01Vec3 operator -(Cctv01Vec3 other) =>
      Cctv01Vec3(x - other.x, y - other.y, z - other.z);
  Cctv01Vec3 scale(Elv5Rational factor) =>
      Cctv01Vec3(x * factor, y * factor, z * factor);
  Elv5Rational dot(Cctv01Vec3 other) => x * other.x + y * other.y + z * other.z;
  Cctv01Vec3 cross(Cctv01Vec3 other) => Cctv01Vec3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  Elv5Rational get squaredNorm => dot(this);
}

final class Cctv01Point3 {
  const Cctv01Point3(this.x, this.y, this.z);

  final Elv5Rational x;
  final Elv5Rational y;
  final Elv5Rational z;

  Cctv01Point3 translate(Cctv01Vec3 vector) => Cctv01Point3(
        x + vector.x,
        y + vector.y,
        z + vector.z,
      );

  Cctv01Vec3 operator -(Cctv01Point3 other) =>
      Cctv01Vec3(x - other.x, y - other.y, z - other.z);
}

final class Cctv01Point2 {
  const Cctv01Point2(this.x, this.y);

  final Elv5Rational x;
  final Elv5Rational y;

  @override
  bool operator ==(Object other) =>
      other is Cctv01Point2 && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Exact already-resolved camera orientation in the project frame.
/// The application boundary may derive this from the captured Rotation3.
final class Cctv01ResolvedOrientation {
  Cctv01ResolvedOrientation({
    required this.forward,
    required this.right,
    required this.up,
  }) {
    if (forward.squaredNorm.isZero ||
        right.squaredNorm.isZero ||
        up.squaredNorm.isZero) {
      throw ArgumentError('CCTV01 orientation basis vectors must be non-zero.');
    }
  }

  final Cctv01Vec3 forward;
  final Cctv01Vec3 right;
  final Cctv01Vec3 up;
}

final class Cctv01Plane {
  Cctv01Plane({
    required this.origin,
    required this.uAxis,
    required this.vAxis,
  }) {
    if (uAxis.cross(vAxis).squaredNorm.isZero) {
      throw ArgumentError('CCTV01 target-plane axes must be independent.');
    }
  }

  final Cctv01Point3 origin;
  final Cctv01Vec3 uAxis;
  final Cctv01Vec3 vAxis;
}

final class Cctv01PinholeIntrinsics {
  Cctv01PinholeIntrinsics({
    required this.sensorWidth,
    required this.sensorHeight,
    required this.focalLength,
  }) {
    if (sensorWidth.value <= Elv5Rational.zero ||
        sensorHeight.value <= Elv5Rational.zero ||
        focalLength.value <= Elv5Rational.zero) {
      throw ArgumentError(
          'CCTV01 sensor dimensions/focal length must be positive.');
    }
  }

  final Length sensorWidth;
  final Length sensorHeight;
  final Length focalLength;
}

final class Cctv01Polygon2 {
  Cctv01Polygon2(Iterable<Cctv01Point2> input)
      : vertices = List.unmodifiable(_normalizeClosingVertex(input.toList())) {
    if (vertices.length < 3) {
      throw ArgumentError('CCTV01 polygon requires at least three vertices.');
    }
    for (var i = 0; i < vertices.length; i++) {
      if (vertices[i] == vertices[(i + 1) % vertices.length]) {
        throw ArgumentError('CCTV01 polygon cannot contain zero-length edges.');
      }
    }
    if (signedDoubleArea.isZero) {
      throw ArgumentError('CCTV01 polygon area must be non-zero.');
    }
    if (_hasSelfIntersection(vertices)) {
      throw ArgumentError('CCTV01 polygon must be simple.');
    }
  }

  final List<Cctv01Point2> vertices;

  Elv5Rational get signedDoubleArea {
    var sum = Elv5Rational.zero;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      sum = sum + a.x * b.y - b.x * a.y;
    }
    return sum;
  }

  Elv5Rational get area {
    final doubleArea = signedDoubleArea;
    final absolute = doubleArea.isNegative ? -doubleArea : doubleArea;
    return absolute / Elv5Rational.integer(2);
  }

  static List<Cctv01Point2> _normalizeClosingVertex(List<Cctv01Point2> values) {
    if (values.length > 1 && values.first == values.last) {
      return values.sublist(0, values.length - 1);
    }
    return values;
  }

  static Elv5Rational _cross(Cctv01Point2 a, Cctv01Point2 b, Cctv01Point2 c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

  static bool _onSegment(Cctv01Point2 p, Cctv01Point2 a, Cctv01Point2 b) {
    if (!_cross(a, b, p).isZero) return false;
    final minX = a.x <= b.x ? a.x : b.x;
    final maxX = a.x >= b.x ? a.x : b.x;
    final minY = a.y <= b.y ? a.y : b.y;
    final maxY = a.y >= b.y ? a.y : b.y;
    return p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY;
  }

  static int _orientation(Cctv01Point2 a, Cctv01Point2 b, Cctv01Point2 c) =>
      _cross(a, b, c).compareTo(Elv5Rational.zero);

  static bool _segmentsIntersect(
    Cctv01Point2 a,
    Cctv01Point2 b,
    Cctv01Point2 c,
    Cctv01Point2 d,
  ) {
    final o1 = _orientation(a, b, c);
    final o2 = _orientation(a, b, d);
    final o3 = _orientation(c, d, a);
    final o4 = _orientation(c, d, b);
    if (o1 != o2 && o3 != o4) return true;
    if (o1 == 0 && _onSegment(c, a, b)) return true;
    if (o2 == 0 && _onSegment(d, a, b)) return true;
    if (o3 == 0 && _onSegment(a, c, d)) return true;
    if (o4 == 0 && _onSegment(b, c, d)) return true;
    return false;
  }

  static bool _hasSelfIntersection(List<Cctv01Point2> points) {
    final n = points.length;
    for (var i = 0; i < n; i++) {
      final a = points[i];
      final b = points[(i + 1) % n];
      for (var j = i + 1; j < n; j++) {
        final adjacent = j == i + 1 || (i == 0 && j == n - 1);
        if (adjacent) continue;
        final c = points[j];
        final d = points[(j + 1) % n];
        if (_segmentsIntersect(a, b, c, d)) return true;
      }
    }
    return false;
  }
}

final class Cctv01Input {
  Cctv01Input({
    required this.cameraId,
    required this.cameraFrameId,
    required this.targetFrameId,
    required this.frameTransformResolved,
    required this.rectilinearPinholeSupported,
    required this.targetIsPlanar,
    required this.opticalCenter,
    required this.orientation,
    required this.intrinsics,
    required this.targetPlane,
    required this.targetZone,
    this.minimumCoverageRatio,
  }) {
    if (cameraId.isEmpty || cameraFrameId.isEmpty || targetFrameId.isEmpty) {
      throw ArgumentError('CCTV01 camera/frame identities must not be empty.');
    }
    if (minimumCoverageRatio != null &&
        (minimumCoverageRatio! < Elv5Rational.zero ||
            minimumCoverageRatio! > Elv5Rational.one)) {
      throw ArgumentError('CCTV01 minimum coverage ratio must be in [0,1].');
    }
  }

  final String cameraId;
  final String cameraFrameId;
  final String targetFrameId;
  final bool frameTransformResolved;
  final bool rectilinearPinholeSupported;
  final bool targetIsPlanar;
  final Cctv01Point3 opticalCenter;
  final Cctv01ResolvedOrientation orientation;
  final Cctv01PinholeIntrinsics? intrinsics;
  final Cctv01Plane? targetPlane;
  final Cctv01Polygon2? targetZone;
  final Elv5Rational? minimumCoverageRatio;
}

final class Cctv01Result {
  const Cctv01Result({
    required this.status,
    required this.footprint,
    required this.coveredArea,
    required this.targetArea,
    required this.coverageRatio,
    required this.coverageMargin,
    required this.horizontalHalfFovTangent,
    required this.verticalHalfFovTangent,
    required this.governingDimension,
    required this.limitingCornerIndex,
    required this.reasonCode,
  });

  final Cctv01AssessmentStatus status;
  final Cctv01Polygon2? footprint;
  final Elv5Rational? coveredArea;
  final Elv5Rational? targetArea;
  final Elv5Rational? coverageRatio;
  final Elv5Rational? coverageMargin;
  final Elv5Rational? horizontalHalfFovTangent;
  final Elv5Rational? verticalHalfFovTangent;
  final Cctv01GoverningDimension? governingDimension;
  final int? limitingCornerIndex;
  final String? reasonCode;
}

final class Cctv01GeometryKernel {
  const Cctv01GeometryKernel();

  Cctv01Result evaluate(Cctv01Input input) {
    if (!input.rectilinearPinholeSupported) {
      return _terminal(
        Cctv01AssessmentStatus.unsupported,
        Cctv01GoverningDimension.modelApplicability,
        'CCTV01_UNSUPPORTED_CAMERA_MODEL',
      );
    }
    if (!input.targetIsPlanar) {
      return _terminal(
        Cctv01AssessmentStatus.unsupported,
        Cctv01GoverningDimension.modelApplicability,
        'CCTV01_NONPLANAR_TARGET_UNSUPPORTED',
      );
    }
    if (input.cameraFrameId != input.targetFrameId &&
        !input.frameTransformResolved) {
      return _terminal(
        Cctv01AssessmentStatus.blocked,
        Cctv01GoverningDimension.frameTransform,
        'CCTV01_FRAME_TRANSFORM_REQUIRED',
      );
    }
    final intrinsics = input.intrinsics;
    final plane = input.targetPlane;
    final zone = input.targetZone;
    if (intrinsics == null || plane == null || zone == null) {
      return _terminal(
        Cctv01AssessmentStatus.blocked,
        Cctv01GoverningDimension.modelApplicability,
        'CCTV01_REQUIRED_GEOMETRY_EVIDENCE_MISSING',
      );
    }

    final half = Elv5Rational(BigInt.one, BigInt.from(2));
    final halfWidth = intrinsics.sensorWidth.value * half;
    final halfHeight = intrinsics.sensorHeight.value * half;
    final focal = intrinsics.focalLength.value;
    final signs = <(int, int)>[(-1, -1), (1, -1), (1, 1), (-1, 1)];
    final normal = plane.uAxis.cross(plane.vAxis);
    final numerator = normal.dot(plane.origin - input.opticalCenter);
    final footprint = <Cctv01Point2>[];

    for (var i = 0; i < signs.length; i++) {
      final sx = Elv5Rational.integer(signs[i].$1);
      final sy = Elv5Rational.integer(signs[i].$2);
      final direction = input.orientation.forward.scale(focal) +
          input.orientation.right.scale(halfWidth * sx) +
          input.orientation.up.scale(halfHeight * sy);
      final denominator = normal.dot(direction);
      if (denominator.isZero) {
        return _terminal(
          Cctv01AssessmentStatus.unresolved,
          Cctv01GoverningDimension.rayIntersection,
          'CCTV01_RAY_PARALLEL_TO_PLANE',
          corner: i,
        );
      }
      final t = numerator / denominator;
      if (t <= Elv5Rational.zero) {
        return _terminal(
          Cctv01AssessmentStatus.unresolved,
          Cctv01GoverningDimension.rayIntersection,
          'CCTV01_RAY_INTERSECTION_NOT_FORWARD',
          corner: i,
        );
      }
      final hit = input.opticalCenter.translate(direction.scale(t));
      footprint.add(_projectToPlane(hit, plane));
    }

    final footprintPolygon = Cctv01Polygon2(footprint);
    final targetTriangles = _triangulate(zone);
    var coveredArea = Elv5Rational.zero;
    for (final triangle in targetTriangles) {
      final clipped = _clipConvexPolygon(triangle, footprintPolygon.vertices);
      if (clipped.length >= 3) {
        coveredArea = coveredArea + _absoluteArea(clipped);
      }
    }
    final targetArea = zone.area;
    final ratio = coveredArea / targetArea;
    final ratioClamped = ratio > Elv5Rational.one ? Elv5Rational.one : ratio;
    final hHalfTangent = halfWidth / focal;
    final vHalfTangent = halfHeight / focal;

    final minimum = input.minimumCoverageRatio;
    if (minimum == null) {
      return Cctv01Result(
        status: Cctv01AssessmentStatus.notAssessed,
        footprint: footprintPolygon,
        coveredArea: coveredArea,
        targetArea: targetArea,
        coverageRatio: ratioClamped,
        coverageMargin: null,
        horizontalHalfFovTangent: hHalfTangent,
        verticalHalfFovTangent: vHalfTangent,
        governingDimension: null,
        limitingCornerIndex: null,
        reasonCode: 'CCTV01_NO_EXPLICIT_COVERAGE_REQUIREMENT',
      );
    }

    final margin = ratioClamped - minimum;
    return Cctv01Result(
      status: margin >= Elv5Rational.zero
          ? Cctv01AssessmentStatus.pass
          : Cctv01AssessmentStatus.fail,
      footprint: footprintPolygon,
      coveredArea: coveredArea,
      targetArea: targetArea,
      coverageRatio: ratioClamped,
      coverageMargin: margin,
      horizontalHalfFovTangent: hHalfTangent,
      verticalHalfFovTangent: vHalfTangent,
      governingDimension: Cctv01GoverningDimension.zoneCoverage,
      limitingCornerIndex: null,
      reasonCode: margin >= Elv5Rational.zero
          ? null
          : 'CCTV01_ZONE_COVERAGE_BELOW_MINIMUM',
    );
  }

  static Cctv01Point2 _projectToPlane(Cctv01Point3 point, Cctv01Plane plane) {
    final w = point - plane.origin;
    final uu = plane.uAxis.dot(plane.uAxis);
    final uv = plane.uAxis.dot(plane.vAxis);
    final vv = plane.vAxis.dot(plane.vAxis);
    final wu = w.dot(plane.uAxis);
    final wv = w.dot(plane.vAxis);
    final determinant = uu * vv - uv * uv;
    if (determinant.isZero) {
      throw StateError('CCTV01 target-plane basis became singular.');
    }
    return Cctv01Point2(
      (wu * vv - wv * uv) / determinant,
      (wv * uu - wu * uv) / determinant,
    );
  }

  static List<List<Cctv01Point2>> _triangulate(Cctv01Polygon2 polygon) {
    final vertices = polygon.signedDoubleArea.isNegative
        ? polygon.vertices.reversed.toList()
        : [...polygon.vertices];
    final indices = List<int>.generate(vertices.length, (i) => i);
    final triangles = <List<Cctv01Point2>>[];
    var guard = 0;
    while (indices.length > 3) {
      if (++guard > vertices.length * vertices.length) {
        throw StateError('CCTV01 simple polygon triangulation failed.');
      }
      var clipped = false;
      for (var cursor = 0; cursor < indices.length; cursor++) {
        final prev = indices[(cursor - 1 + indices.length) % indices.length];
        final curr = indices[cursor];
        final next = indices[(cursor + 1) % indices.length];
        final a = vertices[prev];
        final b = vertices[curr];
        final c = vertices[next];
        if (_cross2(a, b, c) <= Elv5Rational.zero) continue;
        var containsOther = false;
        for (final candidate in indices) {
          if (candidate == prev || candidate == curr || candidate == next)
            continue;
          if (_pointInTriangleInclusive(vertices[candidate], a, b, c)) {
            containsOther = true;
            break;
          }
        }
        if (containsOther) continue;
        triangles.add([a, b, c]);
        indices.removeAt(cursor);
        clipped = true;
        break;
      }
      if (!clipped) {
        throw StateError('CCTV01 could not find a deterministic polygon ear.');
      }
    }
    triangles.add([
      vertices[indices[0]],
      vertices[indices[1]],
      vertices[indices[2]],
    ]);
    return triangles;
  }

  static List<Cctv01Point2> _clipConvexPolygon(
    List<Cctv01Point2> subject,
    List<Cctv01Point2> rawClip,
  ) {
    var clip = [...rawClip];
    if (_signedDoubleArea(clip).isNegative) clip = clip.reversed.toList();
    var output = [...subject];
    for (var edgeIndex = 0; edgeIndex < clip.length; edgeIndex++) {
      final edgeA = clip[edgeIndex];
      final edgeB = clip[(edgeIndex + 1) % clip.length];
      if (output.isEmpty) break;
      final input = output;
      output = <Cctv01Point2>[];
      var previous = input.last;
      var previousInside = _cross2(edgeA, edgeB, previous) >= Elv5Rational.zero;
      for (final current in input) {
        final currentInside =
            _cross2(edgeA, edgeB, current) >= Elv5Rational.zero;
        if (currentInside != previousInside) {
          output.add(_lineIntersection(previous, current, edgeA, edgeB));
        }
        if (currentInside) output.add(current);
        previous = current;
        previousInside = currentInside;
      }
    }
    return output;
  }

  static Cctv01Point2 _lineIntersection(
    Cctv01Point2 p,
    Cctv01Point2 q,
    Cctv01Point2 a,
    Cctv01Point2 b,
  ) {
    final rx = q.x - p.x;
    final ry = q.y - p.y;
    final sx = b.x - a.x;
    final sy = b.y - a.y;
    final denominator = rx * sy - ry * sx;
    if (denominator.isZero) return q;
    final apx = a.x - p.x;
    final apy = a.y - p.y;
    final t = (apx * sy - apy * sx) / denominator;
    return Cctv01Point2(p.x + rx * t, p.y + ry * t);
  }

  static bool _pointInTriangleInclusive(
    Cctv01Point2 p,
    Cctv01Point2 a,
    Cctv01Point2 b,
    Cctv01Point2 c,
  ) {
    final c1 = _cross2(a, b, p);
    final c2 = _cross2(b, c, p);
    final c3 = _cross2(c, a, p);
    final hasNegative = c1 < Elv5Rational.zero ||
        c2 < Elv5Rational.zero ||
        c3 < Elv5Rational.zero;
    final hasPositive = c1 > Elv5Rational.zero ||
        c2 > Elv5Rational.zero ||
        c3 > Elv5Rational.zero;
    return !(hasNegative && hasPositive);
  }

  static Elv5Rational _cross2(Cctv01Point2 a, Cctv01Point2 b, Cctv01Point2 c) =>
      (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);

  static Elv5Rational _signedDoubleArea(List<Cctv01Point2> points) {
    var sum = Elv5Rational.zero;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum = sum + a.x * b.y - b.x * a.y;
    }
    return sum;
  }

  static Elv5Rational _absoluteArea(List<Cctv01Point2> points) {
    final twice = _signedDoubleArea(points);
    final absolute = twice.isNegative ? -twice : twice;
    return absolute / Elv5Rational.integer(2);
  }

  static Cctv01Result _terminal(
    Cctv01AssessmentStatus status,
    Cctv01GoverningDimension dimension,
    String reason, {
    int? corner,
  }) =>
      Cctv01Result(
        status: status,
        footprint: null,
        coveredArea: null,
        targetArea: null,
        coverageRatio: null,
        coverageMargin: null,
        horizontalHalfFovTangent: null,
        verticalHalfFovTangent: null,
        governingDimension: dimension,
        limitingCornerIndex: corner,
        reasonCode: reason,
      );
}
