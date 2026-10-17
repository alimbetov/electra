import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_kernel_executor.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Elv5CalculationRequest request(Elv5ProcessCode code) =>
      Elv5CalculationRequest(
        projectId: 'project-1',
        designRevisionId: 'revision-1',
        scope: Elv5ScopeRef(
          kind: Elv5ScopeKind.design,
          scopeId: 'design-1',
          scenarioKey: 'NONE',
        ),
        processCode: code,
        subject: Elv5SubjectRef(kind: 'FIXTURE', id: 'subject-1'),
        expectedPointerGeneration: 3,
      );

  Elv5CapturedInput<int> captured(Elv5ProcessCode code) =>
      Elv5CapturedInput<int>(
        request: request(code),
        value: 21,
        inputFingerprint: 'input-sha',
        policyFingerprint: 'policy-sha',
        dependencies: const [],
        upstreamPointerGenerations: const {},
        captureRevision: 7,
      );

  Elv5PureKernelExecutor<int, int> executor() =>
      Elv5PureKernelExecutor<int, int>(
        processCode: Elv5ProcessCode.cctv01,
        calculate: (input) => input * 2,
        encodeOutput: (output) => {'value': output},
        encodeEvidence:
            (captured, output) => {
              'captureRevision': captured.captureRevision,
              'outputEcho': output,
            },
        assessmentOf: (_) => Elv5Assessment.pass,
        executionOf: (_) => Elv5Execution.succeeded,
        completionOf: (_) => Elv5Completion.complete,
        nowUtc: () => DateTime.utc(2026, 10, 16, 18, 30),
      );

  test(
    'bridges pure kernel output into immutable evaluation candidate',
    () async {
      final result = await executor().execute(captured(Elv5ProcessCode.cctv01));
      final descriptor = Elv5ProcessCatalog.require(Elv5ProcessCode.cctv01);

      expect(result.nodeKey.processCode, Elv5ProcessCode.cctv01);
      expect(result.algorithmVersion, descriptor.versions.algorithmVersion);
      expect(result.inputSchemaVersion, descriptor.versions.inputSchemaVersion);
      expect(
        result.outputSchemaVersion,
        descriptor.versions.outputSchemaVersion,
      );
      expect(
        result.numericBackendVersion,
        descriptor.versions.numericBackendVersion,
      );
      expect(
        result.canonicalEncoderVersion,
        const Elv5CanonicalJsonV1().version,
      );
      expect(result.inputFingerprint, 'input-sha');
      expect(result.policyFingerprint, 'policy-sha');
      expect(result.execution, Elv5Execution.succeeded);
      expect(result.completion, Elv5Completion.complete);
      expect(result.assessment, Elv5Assessment.pass);
      expect(result.output, {'value': 42});
      expect(result.evidence, {'captureRevision': 7, 'outputEcho': 42});
      expect(result.completedAtUtc, DateTime.utc(2026, 10, 16, 18, 30));
    },
  );

  test('rejects captured input for another process code', () async {
    expect(
      () => executor().execute(captured(Elv5ProcessCode.cctv02)),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ELV5_KERNEL_PROCESS_CODE_MISMATCH'),
        ),
      ),
    );
  });
}
