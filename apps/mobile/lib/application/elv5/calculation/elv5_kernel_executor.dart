import 'package:engineering_core/engineering_core_elv5.dart';

import 'elv5_calculation_runtime.dart';

typedef Elv5KernelCalculate<I, O> = O Function(I input);
typedef Elv5KernelEncodeOutput<O> = Map<String, Object?> Function(O output);
typedef Elv5KernelEncodeEvidence<I, O> = Map<String, Object?> Function(
  Elv5CapturedInput<I> captured,
  O output,
);
typedef Elv5KernelAssessment<O> = Elv5Assessment Function(O output);
typedef Elv5KernelExecution<O> = Elv5Execution Function(O output);
typedef Elv5KernelCompletion<O> = Elv5Completion Function(O output);

/// Generic bridge from a pure engineering kernel into the ELV5 immutable
/// evaluation/publication runtime.
///
/// Process-specific code owns only:
///  * typed input capture;
///  * pure [calculate];
///  * canonical output/evidence encoding;
///  * explicit execution/completion/assessment mapping.
///
/// Version metadata, fingerprints, dependencies and node identity are always
/// taken from the captured runtime contract and code-owned process catalog.
final class Elv5PureKernelExecutor<I, O> implements Elv5PureProcessExecutor<I> {
  Elv5PureKernelExecutor({
    required this.processCode,
    required this.calculate,
    required this.encodeOutput,
    required this.encodeEvidence,
    required this.assessmentOf,
    required this.executionOf,
    required this.completionOf,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  @override
  final Elv5ProcessCode processCode;

  final Elv5KernelCalculate<I, O> calculate;
  final Elv5KernelEncodeOutput<O> encodeOutput;
  final Elv5KernelEncodeEvidence<I, O> encodeEvidence;
  final Elv5KernelAssessment<O> assessmentOf;
  final Elv5KernelExecution<O> executionOf;
  final Elv5KernelCompletion<O> completionOf;
  final DateTime Function() _nowUtc;

  @override
  Future<Elv5ProcessEvaluationCandidate> execute(
    Elv5CapturedInput<I> input,
  ) async {
    if (input.request.processCode != processCode) {
      throw StateError(
        'ELV5_KERNEL_PROCESS_CODE_MISMATCH:'
        '${input.request.processCode.wireCode}:expected:${processCode.wireCode}',
      );
    }

    final descriptor = Elv5ProcessCatalog.require(processCode);
    final output = calculate(input.value);
    final encodedOutput = encodeOutput(output);
    final encodedEvidence = encodeEvidence(input, output);

    return Elv5ProcessEvaluationCandidate(
      nodeKey: input.request.nodeKey,
      algorithmVersion: descriptor.versions.algorithmVersion,
      inputSchemaVersion: descriptor.versions.inputSchemaVersion,
      outputSchemaVersion: descriptor.versions.outputSchemaVersion,
      numericBackendVersion: descriptor.versions.numericBackendVersion,
      canonicalEncoderVersion: Elv5CanonicalJsonV1.version,
      inputFingerprint: input.inputFingerprint,
      policyFingerprint: input.policyFingerprint,
      execution: executionOf(output),
      completion: completionOf(output),
      assessment: assessmentOf(output),
      output: encodedOutput,
      evidence: encodedEvidence,
      dependencies: input.dependencies,
      completedAtUtc: _nowUtc().toUtc(),
    );
  }
}
