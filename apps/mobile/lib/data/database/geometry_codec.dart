import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';

abstract final class GeometryCodec {
  static String encodePolygon(Polygon2Mm polygon) => jsonEncode([
        for (final point in polygon.vertices) [point.xMm, point.yMm],
      ]);

  static Polygon2Mm decodePolygon(String encoded) {
    final raw = jsonDecode(encoded) as List<dynamic>;
    return Polygon2Mm(
      raw.map((entry) {
        final pair = entry as List<dynamic>;
        if (pair.length != 2) {
          throw const FormatException('Expected [xMm, yMm] polygon vertex.');
        }
        return Point2Mm(pair[0] as int, pair[1] as int);
      }),
    );
  }
}
