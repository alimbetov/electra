import 'package:electra_mobile/application/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UuidV7IdGenerator creates unique RFC9562 version 7 identifiers', () {
    final generator = UuidV7IdGenerator();
    final first = generator.next();
    final second = generator.next();

    expect(first, isNot(second));
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(first),
      isTrue,
    );
    expect(
      RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(second),
      isTrue,
    );
  });
}
