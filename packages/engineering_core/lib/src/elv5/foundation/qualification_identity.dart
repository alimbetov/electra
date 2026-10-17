import '../canonical/canonical_json_v1.dart';

/// Exact authority/build identity required before a process evaluation may be
/// promoted from runtime-integrated to Foundation QUALIFIED/ACCEPTED.
///
/// This object deliberately has no defaults. In particular sourceSha and
/// authorityFingerprint must come from a real build/authority provider; callers
/// may not synthesize them from runtime input/output content.
final class Elv5QualificationIdentity implements Elv5CanonicalValue {
  Elv5QualificationIdentity({
    required String processVersion,
    required String rulesetVersion,
    required String sourceSha,
    required String authorityFingerprint,
  })  : processVersion = _text(processVersion, 'processVersion'),
        rulesetVersion = _text(rulesetVersion, 'rulesetVersion'),
        sourceSha = _gitSha(sourceSha),
        authorityFingerprint =
            _sha256(authorityFingerprint, 'authorityFingerprint');

  static const schema = 'electra.elv5-foundation-qualification-identity.v1';

  final String processVersion;
  final String rulesetVersion;
  final String sourceSha;
  final String authorityFingerprint;

  factory Elv5QualificationIdentity.fromMap(Map<String, Object?> value) {
    _exactKeys(
      value,
      const {
        'schema',
        'processVersion',
        'rulesetVersion',
        'sourceSha',
        'authorityFingerprint',
      },
    );
    if (value['schema'] != schema) {
      throw const FormatException(
        'Unsupported ELV5 Foundation qualification identity schema.',
      );
    }
    return Elv5QualificationIdentity(
      processVersion: _mapText(value, 'processVersion'),
      rulesetVersion: _mapText(value, 'rulesetVersion'),
      sourceSha: _mapText(value, 'sourceSha'),
      authorityFingerprint: _mapText(value, 'authorityFingerprint'),
    );
  }

  @override
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'processVersion': processVersion,
        'rulesetVersion': rulesetVersion,
        'sourceSha': sourceSha,
        'authorityFingerprint': authorityFingerprint,
      };

  String canonicalSha256({
    Elv5CanonicalEncoder encoder = const Elv5CanonicalJsonV1(),
  }) =>
      encoder.sha256(toCanonicalValue());
}

String _mapText(Map<String, Object?> value, String field) {
  final raw = value[field];
  if (raw is! String) {
    throw FormatException('$field must be text.');
  }
  return raw;
}

void _exactKeys(Map<String, Object?> value, Set<String> expected) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw const FormatException(
      'Qualification identity has missing or unknown fields.',
    );
  }
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _sha256(String value, String field) {
  final normalized = _text(value, field).toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Expected lowercase SHA-256.');
  }
  return normalized;
}

String _gitSha(String value) {
  final normalized = _text(value, 'sourceSha').toLowerCase();
  if (!RegExp(r'^(?:[0-9a-f]{40}|[0-9a-f]{64})$').hasMatch(normalized)) {
    throw ArgumentError.value(
        value, 'sourceSha', 'Expected full Git SHA-1 or SHA-256 object id.');
  }
  return normalized;
}
