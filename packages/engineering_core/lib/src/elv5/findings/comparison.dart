enum Elv5Assessment { pass, fail, unresolved, notAssessed }

/// Persisted ELV5 execution vocabulary. Retained for replay compatibility.
enum Elv5Execution { succeeded, blocked, failed }

/// Persisted ELV5 completion vocabulary. Retained for replay compatibility.
enum Elv5Completion { complete, incomplete }

enum Elv5Freshness { current, stale }

/// Foundation execution axis. Engineering/capture BLOCKED is not a software
/// execution failure: the runtime succeeded in producing a durable blocked
/// engineering result.
enum Elv5FoundationExecution { succeeded, failed }

/// Foundation completion axis. This deliberately separates a durable blocked
/// engineering result from a partially completed calculation.
enum Elv5FoundationCompletion { complete, partial, blocked }

/// Backward-compatible projection from the persisted ELV5 status vocabulary to
/// the Foundation status axes. It does not rewrite historical records.
final class Elv5FoundationStatusProjection {
  const Elv5FoundationStatusProjection({
    required this.execution,
    required this.completion,
    required this.assessment,
    required this.freshness,
  });

  final Elv5FoundationExecution execution;
  final Elv5FoundationCompletion completion;
  final Elv5Assessment assessment;
  final Elv5Freshness freshness;
}

Elv5FoundationStatusProjection projectElv5FoundationStatus({
  required Elv5Execution execution,
  required Elv5Completion completion,
  required Elv5Assessment assessment,
  required Elv5Freshness freshness,
}) {
  final foundationExecution = execution == Elv5Execution.failed
      ? Elv5FoundationExecution.failed
      : Elv5FoundationExecution.succeeded;

  final foundationCompletion = switch (execution) {
    Elv5Execution.blocked => Elv5FoundationCompletion.blocked,
    Elv5Execution.succeeded ||
    Elv5Execution.failed =>
      completion == Elv5Completion.complete
          ? Elv5FoundationCompletion.complete
          : Elv5FoundationCompletion.partial,
  };

  return Elv5FoundationStatusProjection(
    execution: foundationExecution,
    completion: foundationCompletion,
    assessment: assessment,
    freshness: freshness,
  );
}

/// Common threshold comparison. Positive [signedMargin] always means acceptable
/// headroom; callers must orient operands before constructing this object.
final class Elv5EngineeringComparison<Q> {
  const Elv5EngineeringComparison({
    required this.assessment,
    required this.signedMargin,
    required this.inclusiveThreshold,
  });

  final Elv5Assessment assessment;
  final Q? signedMargin;
  final bool inclusiveThreshold;
}

final class Elv5LimitingFactor {
  const Elv5LimitingFactor({
    required this.code,
    required this.subjectId,
    required this.caseId,
  });

  final String code;
  final String subjectId;
  final String caseId;
}
