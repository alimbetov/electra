import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('source commit accepts full Git SHA1 while authority requires SHA256',
      () {
    final value = Elv5QualificationIdentity(
        processVersion: 'v1',
        rulesetVersion: 'r1',
        sourceSha: '724d93919bc404bea9b133cf5b8ead7065b3d8df',
        authorityFingerprint: _hash('b'));
    expect(value.sourceSha, '724d93919bc404bea9b133cf5b8ead7065b3d8df');
    expect(
        Elv5QualificationIdentity.fromMap(value.toCanonicalValue())
            .canonicalSha256(),
        value.canonicalSha256());
    for (final invalid in ['724d939', 'a' * 39, 'a' * 41, 'g' * 40]) {
      expect(
          () => Elv5QualificationIdentity(
              processVersion: 'v1',
              rulesetVersion: 'r1',
              sourceSha: invalid,
              authorityFingerprint: _hash('b')),
          throwsArgumentError);
    }
    expect(
        () => Elv5QualificationIdentity(
            processVersion: 'v1',
            rulesetVersion: 'r1',
            sourceSha: value.sourceSha,
            authorityFingerprint: 'b' * 40),
        throwsArgumentError);
  });

  test('qualification identity has deterministic canonical identity', () {
    final value = Elv5QualificationIdentity(
      processVersion: 'cctv05.v1',
      rulesetVersion: 'foundation-rules.v1',
      sourceSha: _hash('a'),
      authorityFingerprint: _hash('b'),
    );
    final same = Elv5QualificationIdentity(
      processVersion: 'cctv05.v1',
      rulesetVersion: 'foundation-rules.v1',
      sourceSha: _hash('a'),
      authorityFingerprint: _hash('b'),
    );

    expect(value.canonicalSha256(), same.canonicalSha256());
    expect(value.toCanonicalValue()['sourceSha'], _hash('a'));
  });

  test(
      'qualification identity refuses missing or synthetic-looking invalid sha',
      () {
    expect(
      () => Elv5QualificationIdentity(
        processVersion: 'v1',
        rulesetVersion: 'r1',
        sourceSha: 'HEAD',
        authorityFingerprint: _hash('b'),
      ),
      throwsArgumentError,
    );
    expect(
      () => Elv5QualificationIdentity(
        processVersion: '',
        rulesetVersion: 'r1',
        sourceSha: _hash('a'),
        authorityFingerprint: _hash('b'),
      ),
      throwsArgumentError,
    );
  });
}

String _hash(String char) => List<String>.filled(64, char).join();
