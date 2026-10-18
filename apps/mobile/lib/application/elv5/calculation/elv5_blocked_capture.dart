import 'package:engineering_core/engineering_core_elv5.dart';

import '../persistence/elv5_runtime_persistence.dart';
import 'elv5_calculation_runtime.dart';

/// Fail-closed capture result for mandatory persisted evidence that is absent,
/// unsupported, or internally inconsistent.
///
/// The calculation command must still be able to append durable BLOCKED
/// evidence instead of collapsing into an application exception. Domain
/// resolvers throw this only for engineering/capture incompleteness; programmer
/// errors and corrupt persisted identities remain ordinary exceptions.
final class Elv5CaptureBlockedException implements Exception {
  Elv5CaptureBlockedException({
    required this.request,
    required this.reasonCode,
    required this.inputFingerprint,
    required this.policyFingerprint,
    required Iterable<Elv5DependencyMarker> dependencies,
    required Map<String, Object?> evidence,
    this.captureRevision,
  }) : dependencies = List.unmodifiable(dependencies),
       evidence = Map.unmodifiable(evidence) {
    if (reasonCode.trim().isEmpty) {
      throw ArgumentError('Blocked capture reasonCode must be non-empty.');
    }
  }

  final Elv5CalculationRequest request;
  final String reasonCode;
  final String inputFingerprint;
  final String policyFingerprint;
  final List<Elv5DependencyMarker> dependencies;
  final Map<String, Object?> evidence;
  final int? captureRevision;

  Elv5CaptureBlockedException withCaptureRevision(int value) =>
      Elv5CaptureBlockedException(
        request: request,
        reasonCode: reasonCode,
        inputFingerprint: inputFingerprint,
        policyFingerprint: policyFingerprint,
        dependencies: dependencies,
        evidence: evidence,
        captureRevision: value,
      );
}

/// Typed adapter variant that turns [Elv5CaptureBlockedException] into a
/// deterministic immutable evaluation candidate.
final class Elv5BlockedAwareTypedProcessCalculationAdapter<I>
    implements Elv5ProcessCalculationAdapter {
  Elv5BlockedAwareTypedProcessCalculationAdapter({
    required this.resolver,
    required this.executor,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()) {
    if (resolver.processCode != executor.processCode) {
      throw ArgumentError('ELV5 resolver/executor process-code mismatch.');
    }
  }

  final Elv5ProcessInputResolver<I> resolver;
  final Elv5PureProcessExecutor<I> executor;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Elv5ProcessCode get processCode => resolver.processCode;

  @override
  Elv5WorkloadClass get workloadClass =>
      Elv5ProcessCatalog.require(processCode).baseWorkloadClass;

  @override
  Future<Elv5CapturedProcess> capture(Elv5CalculationRequest request) async {
    try {
      final captured = await resolver.capture(request);
      return Elv5CapturedProcess(
        request: request,
        opaqueInput: captured,
        upstreamPointerGenerations: captured.upstreamPointerGenerations,
        inputFingerprint: captured.inputFingerprint,
        captureRevision: captured.captureRevision,
      );
    } on Elv5CaptureBlockedException catch (blocked) {
      final blockedNodeHash = _encoder.sha256(
        blocked.request.nodeKey.toCanonicalValue(),
      );
      final requestedNodeHash = _encoder.sha256(
        request.nodeKey.toCanonicalValue(),
      );
      if (blockedNodeHash != requestedNodeHash) {
        throw StateError('ELV5_BLOCKED_CAPTURE_NODE_IDENTITY_CHANGED');
      }
      final captureRevision = blocked.captureRevision;
      if (captureRevision == null) {
        throw StateError('ELV5_BLOCKED_CAPTURE_REVISION_MISSING');
      }
      return Elv5CapturedProcess(
        request: request,
        opaqueInput: blocked,
        inputFingerprint: blocked.inputFingerprint,
        captureRevision: captureRevision,
      );
    }
  }

  @override
  Future<Elv5ProcessEvaluationCandidate> execute(
    Elv5CapturedProcess input,
  ) async {
    final opaque = input.opaqueInput;
    if (opaque is! Elv5CaptureBlockedException) {
      return executor.execute(opaque as Elv5CapturedInput<I>);
    }
    final descriptor = Elv5ProcessCatalog.require(processCode);
    return Elv5ProcessEvaluationCandidate(
      nodeKey: input.request.nodeKey,
      algorithmVersion: descriptor.versions.algorithmVersion,
      inputSchemaVersion: descriptor.versions.inputSchemaVersion,
      outputSchemaVersion: descriptor.versions.outputSchemaVersion,
      numericBackendVersion: descriptor.versions.numericBackendVersion,
      canonicalEncoderVersion: Elv5RuntimeContract.canonicalEncoderVersion,
      inputFingerprint: opaque.inputFingerprint,
      policyFingerprint: opaque.policyFingerprint,
      execution: Elv5Execution.blocked,
      completion: Elv5Completion.incomplete,
      assessment: Elv5Assessment.unresolved,
      output: <String, Object?>{
        'schema': 'electra.elv5-blocked-process-output.v1',
        'processCode': processCode.wireCode,
        'reasonCode': opaque.reasonCode,
      },
      evidence: <String, Object?>{
        'schema': 'electra.elv5-blocked-capture-evidence.v1',
        'reasonCode': opaque.reasonCode,
        ...opaque.evidence,
      },
      dependencies: opaque.dependencies,
      completedAtUtc: _nowUtc().toUtc(),
    );
  }
}
