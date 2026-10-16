import 'dart:convert';

import 'package:engineering_core/engineering_core_elv5.dart';

import '../persistence/elv5_runtime_persistence.dart';
import '../wire/elv5_wire_command.dart';

final class Elv5CalculationRequest {
  const Elv5CalculationRequest({
    required this.projectId,
    required this.designRevisionId,
    required this.scope,
    required this.processCode,
    required this.subject,
    required this.expectedPointerGeneration,
  });

  final String projectId;
  final String designRevisionId;
  final Elv5ScopeRef scope;
  final Elv5ProcessCode processCode;
  final Elv5SubjectRef subject;
  final int expectedPointerGeneration;

  Elv5EngineeringNodeKeyV3 get nodeKey => Elv5EngineeringNodeKeyV3(
    designRevisionId: designRevisionId,
    scope: scope,
    processCode: processCode,
    subject: subject,
  );
}

final class Elv5CapturedInput<I> {
  Elv5CapturedInput({
    required this.request,
    required this.value,
    required this.inputFingerprint,
    required this.policyFingerprint,
    required Iterable<Elv5DependencyMarker> dependencies,
    required Map<String, int> upstreamPointerGenerations,
    required this.captureRevision,
  }) : dependencies = List.unmodifiable(dependencies),
       upstreamPointerGenerations = Map.unmodifiable(upstreamPointerGenerations);

  final Elv5CalculationRequest request;
  final I value;
  final String inputFingerprint;
  final String policyFingerprint;
  final List<Elv5DependencyMarker> dependencies;
  final Map<String, int> upstreamPointerGenerations;
  final int captureRevision;
}

final class Elv5ProcessEvaluationCandidate {
  Elv5ProcessEvaluationCandidate({
    required this.nodeKey,
    required this.algorithmVersion,
    required this.inputSchemaVersion,
    required this.outputSchemaVersion,
    required this.numericBackendVersion,
    required this.canonicalEncoderVersion,
    required this.inputFingerprint,
    required this.policyFingerprint,
    required this.execution,
    required this.completion,
    required this.assessment,
    required Map<String, Object?> output,
    required Map<String, Object?> evidence,
    required Iterable<Elv5DependencyMarker> dependencies,
    required this.completedAtUtc,
  }) : output = Map.unmodifiable(output),
       evidence = Map.unmodifiable(evidence),
       dependencies = List.unmodifiable(dependencies) {
    final descriptor = Elv5ProcessCatalog.require(nodeKey.processCode);
    if (descriptor.versions.algorithmVersion != algorithmVersion ||
        descriptor.versions.inputSchemaVersion != inputSchemaVersion ||
        descriptor.versions.outputSchemaVersion != outputSchemaVersion ||
        descriptor.versions.numericBackendVersion != numericBackendVersion) {
      throw StateError('ELV5_PROCESS_VERSION_MISMATCH');
    }
  }

  final Elv5EngineeringNodeKeyV3 nodeKey;
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String numericBackendVersion;
  final String canonicalEncoderVersion;
  final String inputFingerprint;
  final String policyFingerprint;
  final Elv5Execution execution;
  final Elv5Completion completion;
  final Elv5Assessment assessment;
  final Map<String, Object?> output;
  final Map<String, Object?> evidence;
  final List<Elv5DependencyMarker> dependencies;
  final DateTime completedAtUtc;

  String get nodeKeyJson => _canonicalJson(nodeKey.toCanonicalValue());
  String get nodeKeySha256 => _encoder.sha256(nodeKey.toCanonicalValue());
  String get outputJson => _canonicalJson(output);
  String get outputSha256 => _encoder.sha256(output);
  String get evidenceJson => _canonicalJson(evidence);
  String get evidenceSha256 => _encoder.sha256(evidence);

  /// Evaluation identity is content-addressed. Re-running the exact same input
  /// and algorithm produces the same immutable evaluation identity.
  String get evaluationId => _encoder.sha256({
    'schema': 'electra.elv5-evaluation-identity.v1',
    'nodeKey': nodeKey.toCanonicalValue(),
    'algorithmVersion': algorithmVersion,
    'inputSchemaVersion': inputSchemaVersion,
    'outputSchemaVersion': outputSchemaVersion,
    'numericBackendVersion': numericBackendVersion,
    'canonicalEncoderVersion': canonicalEncoderVersion,
    'inputFingerprint': inputFingerprint,
    'policyFingerprint': policyFingerprint,
    'outputSha256': outputSha256,
    'evidenceSha256': evidenceSha256,
  });

  Elv5EvaluationRecord toRecord({required String projectId}) =>
      Elv5EvaluationRecord(
        projectId: projectId,
        designRevisionId: nodeKey.designRevisionId,
        logicalNodeKeyJson: nodeKeyJson,
        logicalNodeKeySha256: nodeKeySha256,
        evaluationId: evaluationId,
        scopeKind: nodeKey.scope.kind.name.toUpperCase(),
        scopeId: nodeKey.scope.scopeId,
        scenarioKey: nodeKey.scope.scenarioKey,
        processCode: nodeKey.processCode.wireCode,
        subjectKind: nodeKey.subject.kind,
        subjectId: nodeKey.subject.id,
        algorithmVersion: algorithmVersion,
        inputSchemaVersion: inputSchemaVersion,
        outputSchemaVersion: outputSchemaVersion,
        numericBackendVersion: numericBackendVersion,
        canonicalEncoderVersion: canonicalEncoderVersion,
        inputFingerprint: inputFingerprint,
        policyFingerprint: policyFingerprint,
        execution: execution.name.toUpperCase(),
        completion: completion.name.toUpperCase(),
        assessment: assessment.name.toUpperCase(),
        outputJson: outputJson,
        outputSha256: outputSha256,
        evidenceJson: evidenceJson,
        evidenceSha256: evidenceSha256,
        completedAtUtc: completedAtUtc,
      );

  static const _encoder = Elv5CanonicalJsonV1();

  static String _canonicalJson(Object? value) => utf8.decode(
    _encoder.encode(value),
    allowMalformed: false,
  );
}

abstract interface class Elv5ProcessInputResolver<I> {
  Elv5ProcessCode get processCode;

  Future<Elv5CapturedInput<I>> capture(Elv5CalculationRequest request);
}

/// Executor boundary is intentionally independent from repositories/Drift/UI.
/// P7 may run medium/large implementations in a bounded worker pool without
/// changing calculation service semantics.
abstract interface class Elv5PureProcessExecutor<I> {
  Elv5ProcessCode get processCode;

  Future<Elv5ProcessEvaluationCandidate> execute(Elv5CapturedInput<I> input);
}

abstract interface class Elv5ProcessCalculationAdapter {
  Elv5ProcessCode get processCode;
  Elv5WorkloadClass get workloadClass;

  Future<Elv5CapturedProcess> capture(Elv5CalculationRequest request);
  Future<Elv5ProcessEvaluationCandidate> execute(Elv5CapturedProcess input);
}

final class Elv5CapturedProcess {
  const Elv5CapturedProcess({
    required this.request,
    required this.opaqueInput,
    required this.inputFingerprint,
    required this.captureRevision,
  });

  final Elv5CalculationRequest request;
  final Object opaqueInput;
  final String inputFingerprint;
  final int captureRevision;
}

final class Elv5TypedProcessCalculationAdapter<I>
    implements Elv5ProcessCalculationAdapter {
  Elv5TypedProcessCalculationAdapter({
    required this.resolver,
    required this.executor,
  }) {
    if (resolver.processCode != executor.processCode) {
      throw ArgumentError('ELV5 resolver/executor process-code mismatch.');
    }
  }

  final Elv5ProcessInputResolver<I> resolver;
  final Elv5PureProcessExecutor<I> executor;

  @override
  Elv5ProcessCode get processCode => resolver.processCode;

  @override
  Elv5WorkloadClass get workloadClass =>
      Elv5ProcessCatalog.require(processCode).baseWorkloadClass;

  @override
  Future<Elv5CapturedProcess> capture(Elv5CalculationRequest request) async {
    final captured = await resolver.capture(request);
    return Elv5CapturedProcess(
      request: request,
      opaqueInput: captured,
      inputFingerprint: captured.inputFingerprint,
      captureRevision: captured.captureRevision,
    );
  }

  @override
  Future<Elv5ProcessEvaluationCandidate> execute(
    Elv5CapturedProcess input,
  ) => executor.execute(input.opaqueInput as Elv5CapturedInput<I>);
}

final class Elv5ProcessCalculationRegistry {
  Elv5ProcessCalculationRegistry(Iterable<Elv5ProcessCalculationAdapter> values)
    : _byCode = Map.unmodifiable({for (final value in values) value.processCode: value}) {
    if (_byCode.length != values.length) {
      throw ArgumentError('Duplicate ELV5 calculation adapter.');
    }
  }

  final Map<Elv5ProcessCode, Elv5ProcessCalculationAdapter> _byCode;

  Elv5ProcessCalculationAdapter require(Elv5ProcessCode code) =>
      _byCode[code] ?? (throw StateError('ELV5_PROCESS_RUNTIME_NOT_IMPLEMENTED:${code.wireCode}'));

  Set<Elv5ProcessCode> get registeredCodes => Set.unmodifiable(_byCode.keys.toSet());
}

final class Elv5CalculationBatch {
  Elv5CalculationBatch({
    required this.command,
    required Iterable<Elv5ProcessEvaluationCandidate> evaluations,
    required Map<String, int> captureRevisions,
  }) : evaluations = List.unmodifiable(evaluations),
       captureRevisions = Map.unmodifiable(captureRevisions);

  final Elv5WireCommandEnvelope command;
  final List<Elv5ProcessEvaluationCandidate> evaluations;
  final Map<String, int> captureRevisions;
}

const _encoder = Elv5CanonicalJsonV1();

String _canonicalJson(Object? value) => utf8.decode(
  _encoder.encode(value),
  allowMalformed: false,
);
