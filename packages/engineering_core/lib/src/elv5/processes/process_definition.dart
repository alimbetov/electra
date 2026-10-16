import '../canonical/canonical_json_v1.dart';
import '../findings/comparison.dart';
import 'process_code.dart';
import 'process_versions.dart';

enum Elv5ScopeKind { design, segment, sequence }

enum Elv5WorkloadClass { tiny, small, medium, large }

final class Elv5SubjectRef implements Elv5CanonicalValue {
  Elv5SubjectRef({required this.kind, required this.id}) {
    if (kind.trim().isEmpty || id.trim().isEmpty) {
      throw ArgumentError('Subject kind/id must be non-empty.');
    }
  }

  final String kind;
  final String id;

  @override
  Object? toCanonicalValue() => <String, Object?>{'kind': kind, 'id': id};
}

final class Elv5ScopeRef implements Elv5CanonicalValue {
  Elv5ScopeRef({
    required this.kind,
    required this.scopeId,
    required this.scenarioKey,
  }) {
    if (scopeId.trim().isEmpty || scenarioKey.trim().isEmpty) {
      throw ArgumentError('Scope/scenario identity must be non-empty.');
    }
    if (kind == Elv5ScopeKind.design && scenarioKey != 'NONE') {
      throw ArgumentError('DESIGN scope requires scenarioKey NONE.');
    }
  }

  final Elv5ScopeKind kind;
  final String scopeId;
  final String scenarioKey;

  @override
  Object? toCanonicalValue() => <String, Object?>{
    'kind': kind.name.toUpperCase(),
    'scopeId': scopeId,
    'scenarioKey': scenarioKey,
  };
}

final class Elv5EngineeringNodeKeyV3 implements Elv5CanonicalValue {
  Elv5EngineeringNodeKeyV3({
    required this.designRevisionId,
    required this.scope,
    required this.processCode,
    required this.subject,
  }) {
    if (designRevisionId.trim().isEmpty) {
      throw ArgumentError('designRevisionId must be non-empty.');
    }
  }

  final String designRevisionId;
  final Elv5ScopeRef scope;
  final Elv5ProcessCode processCode;
  final Elv5SubjectRef subject;

  @override
  Object? toCanonicalValue() => <Object?>[
    'engineering-node-v3',
    'ELV5',
    designRevisionId,
    scope.scenarioKey,
    scope.kind.name.toUpperCase(),
    scope.scopeId,
    processCode.wireCode,
    subject.kind,
    subject.id,
  ];
}

abstract interface class Elv5TypedProcessDefinition<I, O> {
  Elv5ProcessCode get code;
  Elv5Discipline get discipline;
  Elv5ProcessVersions get versions;
  Set<Elv5ScopeKind> get legalScopes;
  Set<String> get requiredDimensionCodes;
  Elv5WorkloadClass get baseWorkloadClass;
  String get complexityCode;

  O calculate(I input);

  Elv5EvaluationDraft evaluate(I input, O output);
}

final class Elv5EvaluationDraft {
  const Elv5EvaluationDraft({
    required this.nodeKey,
    required this.inputFingerprint,
    required this.policyFingerprint,
    required this.execution,
    required this.completion,
    required this.assessment,
    required this.deterministicOutputHash,
  });

  final Elv5EngineeringNodeKeyV3 nodeKey;
  final String inputFingerprint;
  final String policyFingerprint;
  final Elv5Execution execution;
  final Elv5Completion completion;
  final Elv5Assessment assessment;
  final String deterministicOutputHash;
}
