import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
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

  test('qualification identity refuses missing or synthetic-looking invalid sha', () {
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
