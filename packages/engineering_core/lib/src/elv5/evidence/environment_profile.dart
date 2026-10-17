import '../numeric/rational.dart';

enum Elv5CondensationRisk { none, possible, expected, unknown }

enum Elv5EnvironmentExposure { indoor, outdoor, mixed, unknown }

final class Elv5RationalRange {
  Elv5RationalRange({required this.minimum, required this.maximum}) {
    if (maximum < minimum) {
      throw ArgumentError('Environment range maximum must be >= minimum.');
    }
  }

  final Elv5Rational minimum;
  final Elv5Rational maximum;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'minimum': minimum.toMap(),
        'maximum': maximum.toMap(),
      };
}

/// Versioned engineering environment evidence.
///
/// Room type/category is deliberately not part of this contract. Room type may
/// suggest a profile in UI, but only an explicitly selected/captured profile is
/// allowed to affect engineering results.
final class Elv5EnvironmentProfile {
  Elv5EnvironmentProfile({
    required String profileId,
    required String editionId,
    required String profileCode,
    required this.temperatureC,
    required this.relativeHumidityPercent,
    required this.condensationRisk,
    required this.exposure,
    String? moistureClassCode,
    String? contaminationClassCode,
    String? climateClassCode,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : profileId = _text(profileId, 'profileId'),
        editionId = _text(editionId, 'editionId'),
        profileCode = _code(profileCode, 'profileCode'),
        moistureClassCode = _nullableCode(moistureClassCode),
        contaminationClassCode = _nullableCode(contaminationClassCode),
        climateClassCode = _nullableCode(climateClassCode),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha256(evidenceContentHash, 'evidenceContentHash') {
    final zero = Elv5Rational.zero;
    final hundred = Elv5Rational.integer(100);
    if (relativeHumidityPercent.minimum < zero ||
        relativeHumidityPercent.maximum > hundred) {
      throw ArgumentError('Relative humidity must be inside 0..100 %.');
    }
  }

  final String profileId;
  final String editionId;
  final String profileCode;
  final Elv5RationalRange temperatureC;
  final Elv5RationalRange relativeHumidityPercent;
  final Elv5CondensationRisk condensationRisk;
  final Elv5EnvironmentExposure exposure;
  final String? moistureClassCode;
  final String? contaminationClassCode;
  final String? climateClassCode;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': 'electra.elv5-environment-profile.v1',
        'profileId': profileId,
        'editionId': editionId,
        'profileCode': profileCode,
        'temperatureC': temperatureC.toCanonicalValue(),
        'relativeHumidityPercent': relativeHumidityPercent.toCanonicalValue(),
        'condensationRisk': condensationRisk.name,
        'exposure': exposure.name,
        'moistureClassCode': moistureClassCode,
        'contaminationClassCode': contaminationClassCode,
        'climateClassCode': climateClassCode,
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
      };
}

/// Binds a versioned environment profile to a spatial scope.
///
/// Precedence is explicit: a traversal/section override may replace a room
/// profile only when that override is itself versioned evidence. Implicit
/// inheritance from room type/category is forbidden.
final class Elv5EnvironmentScopeBinding {
  Elv5EnvironmentScopeBinding({
    required String bindingId,
    required String scopeKind,
    required String scopeId,
    required this.profile,
    required this.priority,
  })  : bindingId = _text(bindingId, 'bindingId'),
        scopeKind = _code(scopeKind, 'scopeKind'),
        scopeId = _text(scopeId, 'scopeId') {
    if (priority < 0) {
      throw ArgumentError.value(priority, 'priority', 'Must be >= 0.');
    }
  }

  final String bindingId;
  final String scopeKind;
  final String scopeId;
  final Elv5EnvironmentProfile profile;
  final int priority;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': 'electra.elv5-environment-scope-binding.v1',
        'bindingId': bindingId,
        'scopeKind': scopeKind,
        'scopeId': scopeId,
        'priority': priority,
        'profile': profile.toCanonicalValue(),
      };
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _code(String value, String field) => _text(value, field).toUpperCase();

String? _nullableCode(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toUpperCase();
  return normalized.isEmpty ? null : normalized;
}

String _sha256(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}
