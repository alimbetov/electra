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
        sourceSha = _sha256(sourceSha, 'sourceSha'),
        authorityFingerprint =
            _sha256(authorityFingerprint, 'authorityFingerprint');

  static const schema = 'electra.elv5-foundation-qualification-identity.v1';

  final String processVersion;
  final String rulesetVersion;
  final String sourceSha;
  final String authorityFingerprint;

  @override
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'processVersion': processVersion,
    'rulesetVersion': rulesetVersion,
    'sourceSha': sourceSha,
    'authorityFingerprint': authorityFingerprint,
  };

  String canonicalSha256({Elv5CanonicalEncoder encoder = const Elv5CanonicalJsonV1()}) =>
      encoder.sha256(toCanonicalValue());
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
