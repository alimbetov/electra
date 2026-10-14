import 'dart:convert';
import 'dart:io';

import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

EngineeringReferenceCatalog _fixture() => EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );

void main() {
  test('publication rejects profile codes that collide after normalization', () {
    final source = _fixture();
    final camera = source.profile('CAMERA');
    final alias = ComponentEngineeringProfile.fromMap({
      ...camera.toMap(),
      'code': ' camera ',
    });
    final catalog = EngineeringReferenceCatalog(
      id: 'round2-collision',
      code: 'ELV2',
      version: '2',
      source: 'round2-test',
      profiles: [camera, alias],
      vocabulary: source.vocabulary,
    );

    expect(
      catalog.validateForPublication(),
      contains(
        'Profile codes must be canonical and unique after normalization.',
      ),
    );
  });

  test('profile lookup uses the same canonical code identity', () {
    final catalog = _fixture();

    expect(catalog.profile(' camera ').code, 'CAMERA');
    expect(catalog.profile('Camera').code, 'CAMERA');
  });
}
