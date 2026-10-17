import 'package:engineering_core/engineering_core_elv5.dart';

/// Supplies exact build/authority identity for evaluations that are eligible to
/// participate in Foundation qualification. Returning null is intentional: a
/// normal developer build may calculate, but it is not qualification-addressed.
abstract interface class Elv5QualificationIdentitySource {
  Elv5QualificationIdentity? forProcess(Elv5ProcessCode processCode);
}

final class Elv5BuildQualificationIdentitySource
    implements Elv5QualificationIdentitySource {
  Elv5BuildQualificationIdentitySource({
    required String sourceSha,
    Elv5FoundationAuthorityManifest authority =
        Elv5FoundationAuthorityManifest.instance,
  }) : _sourceSha = _sha(sourceSha),
       _authorityFingerprint = authority.fingerprint();

  /// Build pipelines should pass:
  /// `--dart-define=ELECTRA_SOURCE_SHA=<exact 64-hex git commit sha>`.
  ///
  /// Absence does not invent identity; it produces an unqualified runtime.
  factory Elv5BuildQualificationIdentitySource.fromEnvironment() {
    const sourceSha = String.fromEnvironment('ELECTRA_SOURCE_SHA');
    return Elv5BuildQualificationIdentitySource(sourceSha: sourceSha);
  }

  static Elv5BuildQualificationIdentitySource? tryFromEnvironment() {
    const sourceSha = String.fromEnvironment('ELECTRA_SOURCE_SHA');
    if (sourceSha.trim().isEmpty) return null;
    return Elv5BuildQualificationIdentitySource(sourceSha: sourceSha);
  }

  final String _sourceSha;
  final String _authorityFingerprint;

  @override
  Elv5QualificationIdentity forProcess(Elv5ProcessCode processCode) {
    final descriptor = Elv5ProcessCatalog.require(processCode);
    return Elv5QualificationIdentity(
      processVersion: descriptor.versions.processVersion,
      rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
      sourceSha: _sourceSha,
      authorityFingerprint: _authorityFingerprint,
    );
  }
}

String _sha(String value) {
  final normalized = value.trim().toLowerCase();
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    throw ArgumentError.value(
      value,
      'sourceSha',
      'Qualification builds require exact lowercase 64-hex git source SHA.',
    );
  }
  return normalized;
}
