import 'package:engineering_core/engineering_core_elv5.dart';

final class Cctv01ExactVec3Contract {
  const Cctv01ExactVec3Contract({
    required this.x,
    required this.y,
    required this.z,
  });

  final Elv5Rational x;
  final Elv5Rational y;
  final Elv5Rational z;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'x': x.toMap(),
    'y': y.toMap(),
    'z': z.toMap(),
  };

  factory Cctv01ExactVec3Contract.fromMap(Map<String, Object?> map) {
    _exact(map, const {'x', 'y', 'z'}, 'CCTV01 vector');
    return Cctv01ExactVec3Contract(
      x: Elv5Rational.fromMap(_map(map['x'], 'x')),
      y: Elv5Rational.fromMap(_map(map['y'], 'y')),
      z: Elv5Rational.fromMap(_map(map['z'], 'z')),
    );
  }
}

final class Cctv01ExactSurfaceFrameContract {
  Cctv01ExactSurfaceFrameContract({required this.uAxis, required this.vAxis}) {
    if (_norm2(uAxis) != Elv5Rational.one ||
        _norm2(vAxis) != Elv5Rational.one ||
        !_dot(uAxis, vAxis).isZero) {
      throw ArgumentError(
        'CCTV01 surface frame axes must be exact orthonormal unit vectors.',
      );
    }
  }

  final Cctv01ExactVec3Contract uAxis;
  final Cctv01ExactVec3Contract vAxis;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'uAxis': uAxis.toCanonicalValue(),
    'vAxis': vAxis.toCanonicalValue(),
  };

  factory Cctv01ExactSurfaceFrameContract.fromMap(Map<String, Object?> map) {
    _exact(map, const {'uAxis', 'vAxis'}, 'CCTV01 surface frame');
    return Cctv01ExactSurfaceFrameContract(
      uAxis: Cctv01ExactVec3Contract.fromMap(_map(map['uAxis'], 'uAxis')),
      vAxis: Cctv01ExactVec3Contract.fromMap(_map(map['vAxis'], 'vAxis')),
    );
  }
}

final class Cctv01GeometryContract {
  Cctv01GeometryContract({
    required String cameraId,
    required String roomId,
    required String expectedDefinitionId,
    required this.expectedDefinitionVersion,
    required String targetSurfacePatchId,
    required String geometryModelEditionId,
    required String geometryModelContentHash,
    required this.rectilinearPinholeSupported,
    required this.targetIsPlanar,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    required this.focalLengthMm,
    required this.forward,
    required this.right,
    required this.up,
    this.minimumCoverageRatio,
    String? expectedHostSurfacePatchId,
    this.hostSurfaceFrame,
    this.targetSurfaceFrame,
    this.legacyFrameAxisTolerance,
  }) : cameraId = _text(cameraId, 'cameraId'),
       roomId = _text(roomId, 'roomId'),
       expectedDefinitionId = _text(
         expectedDefinitionId,
         'expectedDefinitionId',
       ),
       targetSurfacePatchId = _text(
         targetSurfacePatchId,
         'targetSurfacePatchId',
       ),
       geometryModelEditionId = _text(
         geometryModelEditionId,
         'geometryModelEditionId',
       ),
       geometryModelContentHash = _sha(
         geometryModelContentHash,
         'geometryModelContentHash',
       ),
       expectedHostSurfacePatchId =
           expectedHostSurfacePatchId == null
               ? null
               : _text(
                 expectedHostSurfacePatchId,
                 'expectedHostSurfacePatchId',
               ) {
    if (expectedDefinitionVersion < 1) {
      throw ArgumentError.value(
        expectedDefinitionVersion,
        'expectedDefinitionVersion',
        'Must be >= 1.',
      );
    }
    for (final entry in <MapEntry<String, Elv5Rational>>[
      MapEntry('sensorWidthMm', sensorWidthMm),
      MapEntry('sensorHeightMm', sensorHeightMm),
      MapEntry('focalLengthMm', focalLengthMm),
    ]) {
      if (entry.value <= Elv5Rational.zero) {
        throw ArgumentError.value(entry.value, entry.key, 'Must be > 0.');
      }
    }
    if (minimumCoverageRatio != null &&
        (minimumCoverageRatio! < Elv5Rational.zero ||
            minimumCoverageRatio! > Elv5Rational.one)) {
      throw ArgumentError.value(
        minimumCoverageRatio,
        'minimumCoverageRatio',
        'Must be in [0,1].',
      );
    }
    if (_norm2(forward) != Elv5Rational.one ||
        _norm2(right) != Elv5Rational.one ||
        _norm2(up) != Elv5Rational.one) {
      throw ArgumentError(
        'CCTV01 orientation vectors must be exact unit vectors.',
      );
    }
    if (!_dot(forward, right).isZero ||
        !_dot(forward, up).isZero ||
        !_dot(right, up).isZero) {
      throw ArgumentError(
        'CCTV01 orientation vectors must be exactly orthogonal.',
      );
    }

    final exactFrameFields = <Object?>[
      this.expectedHostSurfacePatchId,
      hostSurfaceFrame,
      targetSurfaceFrame,
      legacyFrameAxisTolerance,
    ];
    final exactCount = exactFrameFields.where((value) => value != null).length;
    if (exactCount != 0 && exactCount != exactFrameFields.length) {
      throw ArgumentError(
        'CCTV01 exact surface-frame v2 fields must be supplied together.',
      );
    }
    if (legacyFrameAxisTolerance != null &&
        legacyFrameAxisTolerance! < Elv5Rational.zero) {
      throw ArgumentError.value(
        legacyFrameAxisTolerance,
        'legacyFrameAxisTolerance',
        'Must be >= 0.',
      );
    }
  }

  static const legacySchema = 'electra.elv5-cctv01-geometry-contract.v1';
  static const schema = 'electra.elv5-cctv01-geometry-contract.v2';

  final String cameraId;
  final String roomId;
  final String expectedDefinitionId;
  final int expectedDefinitionVersion;
  final String targetSurfacePatchId;
  final String geometryModelEditionId;
  final String geometryModelContentHash;
  final bool rectilinearPinholeSupported;
  final bool targetIsPlanar;
  final Elv5Rational sensorWidthMm;
  final Elv5Rational sensorHeightMm;
  final Elv5Rational focalLengthMm;
  final Cctv01ExactVec3Contract forward;
  final Cctv01ExactVec3Contract right;
  final Cctv01ExactVec3Contract up;
  final Elv5Rational? minimumCoverageRatio;

  /// V2 exact surface-frame authority. Legacy ELV3 floating axes are retained
  /// only as a compatibility witness and are never used for engineering math.
  final String? expectedHostSurfacePatchId;
  final Cctv01ExactSurfaceFrameContract? hostSurfaceFrame;
  final Cctv01ExactSurfaceFrameContract? targetSurfaceFrame;
  final Elv5Rational? legacyFrameAxisTolerance;

  bool get hasExactSurfaceFrames =>
      expectedHostSurfacePatchId != null &&
      hostSurfaceFrame != null &&
      targetSurfaceFrame != null &&
      legacyFrameAxisTolerance != null;

  String get effectiveSchema => hasExactSurfaceFrames ? schema : legacySchema;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': effectiveSchema,
    'cameraId': cameraId,
    'roomId': roomId,
    'expectedDefinitionId': expectedDefinitionId,
    'expectedDefinitionVersion': expectedDefinitionVersion,
    'targetSurfacePatchId': targetSurfacePatchId,
    'geometryModelEditionId': geometryModelEditionId,
    'geometryModelContentHash': geometryModelContentHash,
    'rectilinearPinholeSupported': rectilinearPinholeSupported,
    'targetIsPlanar': targetIsPlanar,
    'sensorWidthMm': sensorWidthMm.toMap(),
    'sensorHeightMm': sensorHeightMm.toMap(),
    'focalLengthMm': focalLengthMm.toMap(),
    'forward': forward.toCanonicalValue(),
    'right': right.toCanonicalValue(),
    'up': up.toCanonicalValue(),
    'minimumCoverageRatio': minimumCoverageRatio?.toMap(),
    if (hasExactSurfaceFrames) ...<String, Object?>{
      'expectedHostSurfacePatchId': expectedHostSurfacePatchId,
      'hostSurfaceFrame': hostSurfaceFrame!.toCanonicalValue(),
      'targetSurfaceFrame': targetSurfaceFrame!.toCanonicalValue(),
      'legacyFrameAxisTolerance': legacyFrameAxisTolerance!.toMap(),
    },
  };

  factory Cctv01GeometryContract.fromMap(Map<String, Object?> map) {
    final schemaValue = map['schema'];
    if (schemaValue == legacySchema) {
      _exact(map, _legacyFields, 'CCTV01 v1 contract');
      return _fromCommonMap(map);
    }
    if (schemaValue == schema) {
      _exact(map, _v2Fields, 'CCTV01 v2 contract');
      return _fromCommonMap(
        map,
        expectedHostSurfacePatchId: _mapText(map, 'expectedHostSurfacePatchId'),
        hostSurfaceFrame: Cctv01ExactSurfaceFrameContract.fromMap(
          _map(map['hostSurfaceFrame'], 'hostSurfaceFrame'),
        ),
        targetSurfaceFrame: Cctv01ExactSurfaceFrameContract.fromMap(
          _map(map['targetSurfaceFrame'], 'targetSurfaceFrame'),
        ),
        legacyFrameAxisTolerance: Elv5Rational.fromMap(
          _map(map['legacyFrameAxisTolerance'], 'legacyFrameAxisTolerance'),
        ),
      );
    }
    throw const FormatException('Unsupported CCTV01 contract schema.');
  }

  static Cctv01GeometryContract _fromCommonMap(
    Map<String, Object?> map, {
    String? expectedHostSurfacePatchId,
    Cctv01ExactSurfaceFrameContract? hostSurfaceFrame,
    Cctv01ExactSurfaceFrameContract? targetSurfaceFrame,
    Elv5Rational? legacyFrameAxisTolerance,
  }) {
    final version = map['expectedDefinitionVersion'];
    if (version is! int) {
      throw const FormatException('expectedDefinitionVersion must be integer.');
    }
    final pinhole = map['rectilinearPinholeSupported'];
    final planar = map['targetIsPlanar'];
    if (pinhole is! bool || planar is! bool) {
      throw const FormatException(
        'CCTV01 applicability flags must be boolean.',
      );
    }
    return Cctv01GeometryContract(
      cameraId: _mapText(map, 'cameraId'),
      roomId: _mapText(map, 'roomId'),
      expectedDefinitionId: _mapText(map, 'expectedDefinitionId'),
      expectedDefinitionVersion: version,
      targetSurfacePatchId: _mapText(map, 'targetSurfacePatchId'),
      geometryModelEditionId: _mapText(map, 'geometryModelEditionId'),
      geometryModelContentHash: _mapText(map, 'geometryModelContentHash'),
      rectilinearPinholeSupported: pinhole,
      targetIsPlanar: planar,
      sensorWidthMm: Elv5Rational.fromMap(
        _map(map['sensorWidthMm'], 'sensorWidthMm'),
      ),
      sensorHeightMm: Elv5Rational.fromMap(
        _map(map['sensorHeightMm'], 'sensorHeightMm'),
      ),
      focalLengthMm: Elv5Rational.fromMap(
        _map(map['focalLengthMm'], 'focalLengthMm'),
      ),
      forward: Cctv01ExactVec3Contract.fromMap(_map(map['forward'], 'forward')),
      right: Cctv01ExactVec3Contract.fromMap(_map(map['right'], 'right')),
      up: Cctv01ExactVec3Contract.fromMap(_map(map['up'], 'up')),
      minimumCoverageRatio:
          map['minimumCoverageRatio'] == null
              ? null
              : Elv5Rational.fromMap(
                _map(map['minimumCoverageRatio'], 'minimumCoverageRatio'),
              ),
      expectedHostSurfacePatchId: expectedHostSurfacePatchId,
      hostSurfaceFrame: hostSurfaceFrame,
      targetSurfaceFrame: targetSurfaceFrame,
      legacyFrameAxisTolerance: legacyFrameAxisTolerance,
    );
  }

  static const Set<String> _legacyFields = <String>{
    'schema',
    'cameraId',
    'roomId',
    'expectedDefinitionId',
    'expectedDefinitionVersion',
    'targetSurfacePatchId',
    'geometryModelEditionId',
    'geometryModelContentHash',
    'rectilinearPinholeSupported',
    'targetIsPlanar',
    'sensorWidthMm',
    'sensorHeightMm',
    'focalLengthMm',
    'forward',
    'right',
    'up',
    'minimumCoverageRatio',
  };

  static const Set<String> _v2Fields = <String>{
    ..._legacyFields,
    'expectedHostSurfacePatchId',
    'hostSurfaceFrame',
    'targetSurfaceFrame',
    'legacyFrameAxisTolerance',
  };
}

final class Cctv01GeometryContractSnapshot {
  const Cctv01GeometryContractSnapshot({
    required this.bindingId,
    required this.bindingRevision,
    required this.evidenceRef,
    required this.contentHash,
    required this.contract,
  });
  final String bindingId;
  final int bindingRevision;
  final String evidenceRef;
  final String contentHash;
  final Cctv01GeometryContract contract;
}

abstract interface class Cctv01GeometryContractSource {
  Future<Cctv01GeometryContractSnapshot?> loadActiveForCamera({
    required String projectId,
    required String designRevisionId,
    required String cameraId,
  });
}

final class ReplaceCctv01GeometryContractCommand {
  ReplaceCctv01GeometryContractCommand({
    required this.projectId,
    required this.designRevisionId,
    required this.expectedDesignRevision,
    required this.bindingId,
    required this.expectedBindingRevision,
    required this.contract,
  }) {
    _text(projectId, 'projectId');
    _text(designRevisionId, 'designRevisionId');
    _text(bindingId, 'bindingId');
    if (expectedDesignRevision < 1 ||
        (expectedBindingRevision != null && expectedBindingRevision! < 1)) {
      throw ArgumentError('CCTV01 expected revisions must be positive.');
    }
  }
  final String projectId;
  final String designRevisionId;
  final int expectedDesignRevision;
  final String bindingId;
  final int? expectedBindingRevision;
  final Cctv01GeometryContract contract;
}

abstract interface class Cctv01GeometryContractWriter {
  Future<void> replace(ReplaceCctv01GeometryContractCommand command);
}

Elv5Rational _dot(Cctv01ExactVec3Contract a, Cctv01ExactVec3Contract b) =>
    a.x * b.x + a.y * b.y + a.z * b.z;
Elv5Rational _norm2(Cctv01ExactVec3Contract a) => _dot(a, a);
Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty)
    throw ArgumentError.value(value, field, 'Must not be empty.');
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized))
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  return normalized;
}

void _exact(Map<String, Object?> map, Set<String> expected, String field) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty)
    throw FormatException('$field has missing or unknown fields.');
}
