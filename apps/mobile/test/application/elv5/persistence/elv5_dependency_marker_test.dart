import 'package:electra_mobile/application/elv5/persistence/elv5_runtime_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonicalizes legacy upstream evaluation relation to EVAL', () {
    final marker = Elv5DependencyMarker(
      projectId: 'p',
      designRevisionId: 'd',
      dependencyKey: '{"k":"v"}',
      dependencyKeySha256: _hash('a'),
      logicalNodeKeySha256: _hash('b'),
      relationKind: 'UPSTREAM_EVALUATION',
      updatedAtUtc: DateTime.utc(2026, 10, 17),
    );

    expect(marker.relationKind, 'EVAL');
  });

  test('keeps canonical dependency relations unchanged', () {
    for (final kind in const <String>[
      'FACT',
      'SET',
      'POLICY',
      'EVAL',
      'POINTER',
      'MISSING',
    ]) {
      final marker = Elv5DependencyMarker(
        projectId: 'p',
        designRevisionId: 'd',
        dependencyKey: '{"kind":"$kind"}',
        dependencyKeySha256: _hash('c'),
        logicalNodeKeySha256: _hash('d'),
        relationKind: kind,
        updatedAtUtc: DateTime.utc(2026, 10, 17),
      );
      expect(marker.relationKind, kind);
    }
  });
}

String _hash(String char) => List<String>.filled(64, char).join();
