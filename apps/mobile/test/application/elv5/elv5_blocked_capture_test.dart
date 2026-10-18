import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_capture_guard.dart';
import 'package:electra_mobile/application/elv5/persistence/elv5_runtime_persistence.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'design revision guard turns engineering block into durable candidate',
    () async {
      final request = _request();
      final dependency = Elv5DependencyMarker(
        projectId: 'p',
        designRevisionId: 'd',
        dependencyKey: '{"domain":"fixture"}',
        dependencyKeySha256: List.filled(64, 'a').join(),
        logicalNodeKeySha256: List.filled(64, 'b').join(),
        relationKind: 'FACT',
        updatedAtUtc: DateTime.utc(2026, 10, 16),
      );
      final inner = _BlockedResolver(request: request, dependency: dependency);
      final guarded = Elv5RevisionGuardedInputResolver<String>(
        inner: inner,
        revisions: _RevisionSource(41),
      );
      final adapter = Elv5BlockedAwareTypedProcessCalculationAdapter<String>(
        resolver: guarded,
        executor: _NeverExecutor(),
        nowUtc: () => DateTime.utc(2026, 10, 16),
      );

      final captured = await adapter.capture(request);
      final candidate = await adapter.execute(captured);

      expect(captured.captureRevision, 41);
      expect(candidate.execution, Elv5Execution.blocked);
      expect(candidate.completion, Elv5Completion.incomplete);
      expect(candidate.assessment, Elv5Assessment.unresolved);
      expect(candidate.output['reasonCode'], 'FIXTURE_EVIDENCE_MISSING');
      expect(
        candidate.dependencies.single.dependencyKeySha256,
        dependency.dependencyKeySha256,
      );
    },
  );
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.lan05,
  subject: Elv5SubjectRef(kind: 'LINK', id: 'link-1'),
  expectedPointerGeneration: 0,
);

final class _BlockedResolver implements Elv5ProcessInputResolver<String> {
  _BlockedResolver({required this.request, required this.dependency});

  final Elv5CalculationRequest request;
  final Elv5DependencyMarker dependency;

  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan05;

  @override
  Future<Elv5CapturedInput<String>> capture(
    Elv5CalculationRequest request,
  ) async {
    throw Elv5CaptureBlockedException(
      request: this.request,
      reasonCode: 'FIXTURE_EVIDENCE_MISSING',
      inputFingerprint: List.filled(64, 'c').join(),
      policyFingerprint: List.filled(64, 'd').join(),
      dependencies: <Elv5DependencyMarker>[dependency],
      evidence: const <String, Object?>{'fixture': true},
    );
  }
}

final class _RevisionSource implements Elv5CaptureRevisionSource {
  _RevisionSource(this.value);
  final int value;

  @override
  Future<int> requireWorkingRevision({
    required String projectId,
    required String designRevisionId,
  }) async => value;
}

final class _NeverExecutor implements Elv5PureProcessExecutor<String> {
  @override
  Elv5ProcessCode get processCode => Elv5ProcessCode.lan05;

  @override
  Future<Elv5ProcessEvaluationCandidate> execute(
    Elv5CapturedInput<String> input,
  ) => throw StateError('Executor must not run for blocked capture.');
}
