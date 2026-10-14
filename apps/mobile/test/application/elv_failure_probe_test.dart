import 'package:electra_mobile/application/elv_failure_probe.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv_failure_injector.dart';

void main() {
  test('probe throws only on the configured stable failure point', () async {
    final probe = ArmedElvFailureProbe(
      ElvFailurePoints.p2ReserveAfterFirstClaim,
    );
    await probe.hit(ElvFailurePoints.p1CreateCableAfterInsert);
    expect(probe.hits, 0);

    await expectLater(
      probe.hit(ElvFailurePoints.p2ReserveAfterFirstClaim),
      throwsA(isA<ElvInjectedFailure>()),
    );
    expect(probe.hits, 1);
  });
}
