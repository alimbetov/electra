enum Acs06AssessmentStatus { pass, fail, blocked }

enum Acs06EdgeKind { data, control, powerFeed, monitor, release }

enum Acs06ReleaseCause {
  normalAccess,
  requestToExit,
  fireRelease,
  emergencyBreakGlass,
  powerFailure,
}

enum Acs06LockSafetyMode { failSafe, failSecure, projectDefined }

enum Acs06LockOutcome { secured, released }

final class Acs06GraphEdge {
  Acs06GraphEdge({
    required this.edgeId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.kind,
  }) {
    if (edgeId.isEmpty || fromNodeId.isEmpty || toNodeId.isEmpty) {
      throw ArgumentError('ACS06 graph identities must not be empty.');
    }
  }

  final String edgeId;
  final String fromNodeId;
  final String toNodeId;
  final Acs06EdgeKind kind;
}

final class Acs06PathRequirement {
  Acs06PathRequirement({
    required this.requirementId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.allowedKinds,
  }) {
    if (requirementId.isEmpty || fromNodeId.isEmpty || toNodeId.isEmpty) {
      throw ArgumentError('ACS06 path requirement identities must not be empty.');
    }
    if (allowedKinds.isEmpty) {
      throw ArgumentError('ACS06 path requirement must allow at least one edge kind.');
    }
  }

  final String requirementId;
  final String fromNodeId;
  final String toNodeId;
  final Set<Acs06EdgeKind> allowedKinds;
}

final class Acs06CauseProfile {
  Acs06CauseProfile({
    required this.cause,
    required this.requiredPaths,
    required this.outcomeWhenSatisfied,
    this.requiresConductiveFeed = false,
    this.requiresSupervision = false,
  });

  final Acs06ReleaseCause cause;
  final List<Acs06PathRequirement> requiredPaths;
  final Acs06LockOutcome outcomeWhenSatisfied;
  final bool requiresConductiveFeed;
  final bool requiresSupervision;
}

final class Acs06TruthRow {
  const Acs06TruthRow({required this.cause, required this.expectedOutcome});

  final Acs06ReleaseCause cause;
  final Acs06LockOutcome expectedOutcome;
}

final class Acs06Input {
  Acs06Input({
    required this.doorId,
    required this.lockNodeId,
    required this.edges,
    required this.causeProfiles,
    required this.truthTable,
    required this.safetyMode,
    this.projectDefinedPowerFailureOutcome,
  }) {
    if (doorId.isEmpty || lockNodeId.isEmpty) {
      throw ArgumentError('ACS06 door/lock identity must not be empty.');
    }
    final edgeIds = <String>{};
    for (final edge in edges) {
      if (!edgeIds.add(edge.edgeId)) {
        throw ArgumentError('ACS06 duplicate edgeId: ${edge.edgeId}');
      }
    }
    _requireCompleteCauses(causeProfiles.map((e) => e.cause), 'cause profile');
    _requireCompleteCauses(truthTable.map((e) => e.cause), 'truth row');
    if (safetyMode == Acs06LockSafetyMode.projectDefined &&
        projectDefinedPowerFailureOutcome == null) {
      throw ArgumentError('ACS06 project-defined safety mode requires power-failure outcome.');
    }
  }

  final String doorId;
  final String lockNodeId;
  final List<Acs06GraphEdge> edges;
  final List<Acs06CauseProfile> causeProfiles;
  final List<Acs06TruthRow> truthTable;
  final Acs06LockSafetyMode safetyMode;
  final Acs06LockOutcome? projectDefinedPowerFailureOutcome;

  static void _requireCompleteCauses(
    Iterable<Acs06ReleaseCause> values,
    String label,
  ) {
    final seen = <Acs06ReleaseCause>{};
    for (final value in values) {
      if (!seen.add(value)) {
        throw ArgumentError('ACS06 duplicate $label: $value');
      }
    }
    if (seen.length != Acs06ReleaseCause.values.length ||
        !seen.containsAll(Acs06ReleaseCause.values)) {
      throw ArgumentError('ACS06 requires exactly five canonical $label values.');
    }
  }
}

final class Acs06CauseResult {
  const Acs06CauseResult({
    required this.cause,
    required this.status,
    required this.expectedOutcome,
    this.modeledOutcome,
    this.failedRequirementId,
    this.reason,
  });

  final Acs06ReleaseCause cause;
  final Acs06AssessmentStatus status;
  final Acs06LockOutcome expectedOutcome;
  final Acs06LockOutcome? modeledOutcome;
  final String? failedRequirementId;
  final String? reason;
}

final class Acs06Result {
  const Acs06Result({
    required this.status,
    required this.causes,
    this.governingCause,
  });

  final Acs06AssessmentStatus status;
  final Map<Acs06ReleaseCause, Acs06CauseResult> causes;
  final Acs06ReleaseCause? governingCause;
}

final class Acs06DoorTopologyKernel {
  const Acs06DoorTopologyKernel();

  Acs06Result evaluate(Acs06Input input) {
    final profiles = <Acs06ReleaseCause, Acs06CauseProfile>{
      for (final profile in input.causeProfiles) profile.cause: profile,
    };
    final expected = <Acs06ReleaseCause, Acs06LockOutcome>{
      for (final row in input.truthTable) row.cause: row.expectedOutcome,
    };
    final adjacency = <String, List<Acs06GraphEdge>>{};
    for (final edge in input.edges) {
      adjacency.putIfAbsent(edge.fromNodeId, () => <Acs06GraphEdge>[]).add(edge);
    }
    for (final list in adjacency.values) {
      list.sort((a, b) => a.edgeId.compareTo(b.edgeId));
    }

    final results = <Acs06ReleaseCause, Acs06CauseResult>{};
    Acs06ReleaseCause? governing;
    var overall = Acs06AssessmentStatus.pass;

    for (final cause in Acs06ReleaseCause.values) {
      final profile = profiles[cause]!;
      final expectedOutcome = expected[cause]!;
      final result = _evaluateCause(input, profile, expectedOutcome, adjacency);
      results[cause] = result;
      if (governing == null && result.status != Acs06AssessmentStatus.pass) {
        governing = cause;
      }
      if (result.status == Acs06AssessmentStatus.fail) {
        overall = Acs06AssessmentStatus.fail;
      } else if (result.status == Acs06AssessmentStatus.blocked &&
          overall == Acs06AssessmentStatus.pass) {
        overall = Acs06AssessmentStatus.blocked;
      }
    }

    return Acs06Result(
      status: overall,
      causes: Map.unmodifiable(results),
      governingCause: governing,
    );
  }

  static Acs06CauseResult _evaluateCause(
    Acs06Input input,
    Acs06CauseProfile profile,
    Acs06LockOutcome expected,
    Map<String, List<Acs06GraphEdge>> adjacency,
  ) {
    if (profile.requiresConductiveFeed && !_hasIncomingFeed(input.lockNodeId, input.edges)) {
      return Acs06CauseResult(
        cause: profile.cause,
        status: Acs06AssessmentStatus.fail,
        expectedOutcome: expected,
        failedRequirementId: 'ACS06_REQUIRED_CONDUCTIVE_FEED',
        reason: 'ACS06_LOCK_HAS_NO_CONDUCTIVE_POWER_FEED',
      );
    }
    if (profile.requiresSupervision && !_hasIncomingMonitor(input.lockNodeId, input.edges)) {
      return Acs06CauseResult(
        cause: profile.cause,
        status: Acs06AssessmentStatus.fail,
        expectedOutcome: expected,
        failedRequirementId: 'ACS06_REQUIRED_SUPERVISION',
        reason: 'ACS06_REQUIRED_SUPERVISION_PATH_MISSING',
      );
    }

    for (final requirement in [...profile.requiredPaths]
      ..sort((a, b) => a.requirementId.compareTo(b.requirementId))) {
      if (!_reachable(
        requirement.fromNodeId,
        requirement.toNodeId,
        requirement.allowedKinds,
        adjacency,
      )) {
        return Acs06CauseResult(
          cause: profile.cause,
          status: Acs06AssessmentStatus.fail,
          expectedOutcome: expected,
          failedRequirementId: requirement.requirementId,
          reason: 'ACS06_REQUIRED_PATH_MISSING',
        );
      }
    }

    final modeled = profile.cause == Acs06ReleaseCause.powerFailure
        ? _powerFailureOutcome(input)
        : profile.outcomeWhenSatisfied;
    final status = modeled == expected
        ? Acs06AssessmentStatus.pass
        : Acs06AssessmentStatus.fail;
    return Acs06CauseResult(
      cause: profile.cause,
      status: status,
      expectedOutcome: expected,
      modeledOutcome: modeled,
      reason: status == Acs06AssessmentStatus.pass
          ? null
          : 'ACS06_MODELED_OUTCOME_MISMATCH',
    );
  }

  static Acs06LockOutcome _powerFailureOutcome(Acs06Input input) => switch (input.safetyMode) {
        Acs06LockSafetyMode.failSafe => Acs06LockOutcome.released,
        Acs06LockSafetyMode.failSecure => Acs06LockOutcome.secured,
        Acs06LockSafetyMode.projectDefined => input.projectDefinedPowerFailureOutcome!,
      };

  static bool _hasIncomingFeed(String lockNodeId, List<Acs06GraphEdge> edges) =>
      edges.any((e) => e.toNodeId == lockNodeId && e.kind == Acs06EdgeKind.powerFeed);

  static bool _hasIncomingMonitor(String lockNodeId, List<Acs06GraphEdge> edges) =>
      edges.any((e) => e.toNodeId == lockNodeId && e.kind == Acs06EdgeKind.monitor);

  static bool _reachable(
    String source,
    String target,
    Set<Acs06EdgeKind> allowedKinds,
    Map<String, List<Acs06GraphEdge>> adjacency,
  ) {
    if (source == target) return true;
    final queue = <String>[source];
    final visited = <String>{source};
    var index = 0;
    while (index < queue.length) {
      final node = queue[index++];
      for (final edge in adjacency[node] ?? const <Acs06GraphEdge>[]) {
        if (!allowedKinds.contains(edge.kind)) continue;
        if (edge.toNodeId == target) return true;
        if (visited.add(edge.toNodeId)) queue.add(edge.toNodeId);
      }
    }
    return false;
  }
}
