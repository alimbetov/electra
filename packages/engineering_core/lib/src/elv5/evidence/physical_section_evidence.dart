/// Minimal discipline-neutral physical evidence shared by technical link checks.
///
/// Interface/category/speed/connector semantics deliberately remain with the
/// consuming discipline because LAN capability sets and CCTV realized-interface
/// selections are not the same engineering claim.
final class Elv5PhysicalSectionEvidence {
  Elv5PhysicalSectionEvidence({
    required String sectionId,
    required String mediumCode,
    required this.shieldContinuityKnown,
    required this.shieldContinuity,
    required String evidenceRef,
    required String evidenceContentHash,
  })  : sectionId = _text(sectionId, 'sectionId'),
        mediumCode = _medium(mediumCode),
        evidenceRef = _text(evidenceRef, 'evidenceRef'),
        evidenceContentHash = _sha(evidenceContentHash, 'evidenceContentHash') {
    if (!shieldContinuityKnown && shieldContinuity) {
      throw ArgumentError(
        'Unknown physical shield continuity cannot assert true.',
      );
    }
  }

  static const schema = 'electra.elv5-physical-section-evidence.v1';

  final String sectionId;
  final String mediumCode;
  final bool shieldContinuityKnown;
  final bool shieldContinuity;
  final String evidenceRef;
  final String evidenceContentHash;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'sectionId': sectionId,
        'mediumCode': mediumCode,
        'shieldContinuityKnown': shieldContinuityKnown,
        'shieldContinuity': shieldContinuity,
        'evidenceRef': evidenceRef,
        'evidenceContentHash': evidenceContentHash,
      };

  factory Elv5PhysicalSectionEvidence.fromMap(Map<String, Object?> map) {
    _exact(
      map,
      const <String>{
        'schema',
        'sectionId',
        'mediumCode',
        'shieldContinuityKnown',
        'shieldContinuity',
        'evidenceRef',
        'evidenceContentHash',
      },
    );
    if (map['schema'] != schema) {
      throw const FormatException(
          'Unsupported physical section evidence schema.');
    }
    final known = map['shieldContinuityKnown'];
    final continuity = map['shieldContinuity'];
    if (known is! bool || continuity is! bool) {
      throw const FormatException(
          'Physical section shield fields must be boolean.');
    }
    return Elv5PhysicalSectionEvidence(
      sectionId: _mapText(map, 'sectionId'),
      mediumCode: _mapText(map, 'mediumCode'),
      shieldContinuityKnown: known,
      shieldContinuity: continuity,
      evidenceRef: _mapText(map, 'evidenceRef'),
      evidenceContentHash: _mapText(map, 'evidenceContentHash'),
    );
  }
}

String _medium(String value) {
  final normalized = _text(value, 'mediumCode').toUpperCase();
  if (!const <String>{'COPPER', 'FIBER', 'OTHER'}.contains(normalized)) {
    throw ArgumentError.value(value, 'mediumCode', 'Unsupported medium.');
  }
  return normalized;
}

String _mapText(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String) throw FormatException('$key must be text.');
  return _text(value, key);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

void _exact(Map<String, Object?> map, Set<String> expected) {
  final actual = map.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw const FormatException(
      'Physical section evidence has missing or unknown fields.',
    );
  }
}
