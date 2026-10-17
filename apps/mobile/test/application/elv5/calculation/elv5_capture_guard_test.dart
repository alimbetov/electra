import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_capture_guard.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries once when design revision changes during capture', () async {
    final revisions = _RevisionSource(<int>[1, 2, 2, 2]);
    final inner = _Resolver();
    final guarded = Elv5RevisionGuardedInputResolver<String>(
      inner: inner,
      revisions: revisions,
    );

    final captured = await guarded.capture(_request());
    expect(inner.captureCount, 2);
    expect(captured.captureRevision, 2);
    expect(captured.value, 'capture-2');
  });

  test('rejects capture when revision keeps changing across both attempts', () async {
    final guarded = Elv5RevisionGuardedInputResolver<String>(
      inner: _Resolver(),
      revisions: _RevisionSource(<int>[1, 2, 2, 3]),
    );

    await expectLater(
      guarded.capture(_request()),
      throwsA(isA<StateError>().having(
        (value) => value.message,
        'message',
        contains('ELV5_CAPTURE_CHANGED_DURING_READ'),
      )),
    );
  });

  test('retries blocked capture and stamps only stable revision', () async {
    final inner = _BlockedResolver();
    final guarded = Elv5RevisionGuardedInputResolver<String>(
      inner: inner,
      revisions: _RevisionSource(<int>[4, 5, 5, 5]),
    );

    await expectLater(
      guarded.capture(_request()),
      throwsA(isA<Elv5CaptureBlockedException>()
          .having((value) => value.captureRevision, 'captureRevision', 5)
          .having((value) => value.reasonCode, 'reasonCode', 'TEST_BLOCKED')),
    );
    expect(inner.captureCount, 2);
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
      projectId: 'p',
      designRevisionId: 'd',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'd',
        scenarioKey: 'NONE',
      ),
      processCode: Elv5ProcessCode.fa01,
      subject: Elv5SubjectRef(kind: 'FIRE_LOOP', id: 'loop-1'),
      expectedPointerGeneration: 0,
    );

final class _RevisionSource implements Elv5CaptureRevisionSource {
  _RevisionSource(this.values);
  final List<int> values;
  var index = 0;

  @override
  Future<int> requireWorkingRevision({
    required String projectId,
    required String designRevisionId,
  }) async => values[index++];
}

final class _Resolver implements Elv5ProcessInputResolver<String> {
  var captureCount = 0;

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa01;

  @override
  Future<Elv5CapturedInput<String>> capture(
    Elv5CalculationRequest request,
  ) async {
    captureCount++;
    return Elv5CapturedInput<String>(
      request: request,
      value: 'capture-$captureCount',
      inputFingerprint: _hash('a'),
      policyFingerprint: _hash('b'),
      dependencies: const <dynamic>[],
      upstreamPointerGenerations: const <String, int>{},
      captureRevision: 999,
    );
  }
}

final class _BlockedResolver implements Elv5ProcessInputResolver<String> {
  var captureCount = 0;

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.fa01;

  @override
  Future<Elv5CapturedInput<String>> capture(
    Elv5CalculationRequest request,
  ) async {
    captureCount++;
    throw Elv5CaptureBlockedException(
      request: request,
      reasonCode: 'TEST_BLOCKED',
      inputFingerprint: _hash('c'),
      policyFingerprint: _hash('d'),
      dependencies: const <dynamic>[],
      evidence: const <String, Object?>{'test': true},
    );
  }
}

String _hash(String char) => List<String>.filled(64, char).join();
