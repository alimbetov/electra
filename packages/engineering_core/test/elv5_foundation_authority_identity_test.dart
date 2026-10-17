import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('authority manifest deterministically covers all 27 process contracts', () {
    const manifest = Elv5FoundationAuthorityManifest.instance;
    final canonical = manifest.toCanonicalValue();
    final processes = canonical['processes']! as List<Object?>;

    expect(processes, hasLength(27));
    expect(manifest.fingerprint(), matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(manifest.fingerprint(), manifest.fingerprint());

    final processVersions = <String>{};
    for (final code in Elv5ProcessCode.values) {
      final descriptor = Elv5ProcessCatalog.require(code);
      expect(descriptor.versions.processVersion, isNotEmpty);
      expect(processVersions.add(descriptor.versions.processVersion), isTrue);
    }
    expect(processVersions, hasLength(27));
  });

  test('qualification identity requires exact source and authority SHA-256', () {
    final descriptor = Elv5ProcessCatalog.require(Elv5ProcessCode.cctv01);
    final authority = Elv5FoundationAuthorityManifest.instance.fingerprint();
    final sourceSha = 'a' * 64;

    final identity = Elv5QualificationIdentity(
      processVersion: descriptor.versions.processVersion,
      rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
      sourceSha: sourceSha,
      authorityFingerprint: authority,
    );

    expect(identity.sourceSha, sourceSha);
    expect(identity.authorityFingerprint, authority);
    expect(identity.canonicalSha256(), matches(RegExp(r'^[0-9a-f]{64}$')));

    expect(
      () => Elv5QualificationIdentity(
        processVersion: descriptor.versions.processVersion,
        rulesetVersion: Elv5FoundationAuthorityManifest.rulesetVersion,
        sourceSha: 'HEAD',
        authorityFingerprint: authority,
      ),
      throwsArgumentError,
    );
  });
}
