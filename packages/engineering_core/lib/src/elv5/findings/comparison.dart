enum Elv5Assessment { pass, fail, unresolved, notAssessed }

enum Elv5Execution { succeeded, blocked, failed }

enum Elv5Completion { complete, incomplete }

enum Elv5Freshness { current, stale }

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
