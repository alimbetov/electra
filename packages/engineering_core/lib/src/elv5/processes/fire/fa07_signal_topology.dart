enum Fa07AssessmentStatus { pass, fail, blocked }

enum Fa07TopologyCase { normal, openFault, shortFault, returnLoss }

final class Fa07SignalEdge {
  Fa07SignalEdge({
    required this.edgeId,
    required this.fromNodeId,
    required this.toNodeId,
  }) {
    if (edgeId.isEmpty || fromNodeId.isEmpty || toNodeId.isEmpty) {
      throw ArgumentError('FA07 edge identities must not be empty.');
    }
  }

  final String edgeId;
  final String fromNodeId;
  final String toNodeId;
}

final class Fa07FaultScenario {
  Fa07FaultScenario({
    required this.caseType,
    required this.removedEdgeIds,
    required this.expectedReachableDeviceIds,
  }) {
    if (caseType == Fa07TopologyCase.normal) {
      throw ArgumentError('FA07 normal case is not a fault scenario.');
    }
  }

  final Fa07TopologyCase caseType;
  final Set<String> removedEdgeIds;
  final Set<String> expectedReachableDeviceIds;
}

final class Fa07Input {
  Fa07Input({
    required this.loopId,
    required this.sourceNodeId,
    required this.returnNodeId,
    required this.deviceNodeIds,
    required this.addressMemberIds,
    required this.edges,
    required this.permittedBranchNodeIds,
    required this.maxBranchNodes,
    required this.requiredFaultCases,
    required this.faultScenarios,
  }) {
    if (loopId.isEmpty || sourceNodeId.isEmpty || returnNodeId.isEmpty) {
      throw ArgumentError('FA07 loop/source/return identities must not be empty.');
    }
    if (maxBranchNodes < 0) {
      throw ArgumentError('FA07 maxBranchNodes must be nonnegative.');
    }
    final edgeIds = <String>{};
    for (final edge in edges) {
      if (!edgeIds.add(edge.edgeId)) {
        throw ArgumentError('FA07 duplicate edgeId: ${edge.edgeId}');
      }
    }
    final faultTypes = <Fa07TopologyCase>{};
    for (final scenario in faultScenarios) {
      if (!faultTypes.add(scenario.caseType)) {
        throw ArgumentError('FA07 duplicate fault scenario: ${scenario.caseType}');
      }
      if (!edgeIds.containsAll(scenario.removedEdgeIds)) {
        throw ArgumentError('FA07 fault scenario references unknown edge.');
      }
    }
  }

  final String loopId;
  final String sourceNodeId;
  final String returnNodeId;
  final Set<String> deviceNodeIds;
  final Set<String> addressMemberIds;
  final List<Fa07SignalEdge> edges;
  final Set<String> permittedBranchNodeIds;
  final int maxBranchNodes;
  final Set<Fa07TopologyCase> requiredFaultCases;
  final List<Fa07FaultScenario> faultScenarios;
}

final class Fa07CaseResult {
  const Fa07CaseResult({
    required this.caseType,
    required this.status,
    required this.reachableDeviceIds,
    this.reason,
  });

  final Fa07TopologyCase caseType;
  final Fa07AssessmentStatus status;
  final Set<String> reachableDeviceIds;
  final String? reason;
}

final class Fa07Result {
  const Fa07Result({
    required this.status,
    required this.cases,
    this.governingCase,
    this.reason,
  });

  final Fa07AssessmentStatus status;
  final Map<Fa07TopologyCase, Fa07CaseResult> cases;
  final Fa07TopologyCase? governingCase;
  final String? reason;
}

final class Fa07SignalTopologyKernel {
  const Fa07SignalTopologyKernel();

  Fa07Result evaluate(Fa07Input input) {
    if (!_sameSet(input.deviceNodeIds, input.addressMemberIds)) {
      return const Fa07Result(
        status: Fa07AssessmentStatus.fail,
        cases: {},
        governingCase: Fa07TopologyCase.normal,
        reason: 'FA07_ADDRESS_MEMBERSHIP_MISMATCH',
      );
    }

    final normal = _evaluateNormal(input);
    final results = <Fa07TopologyCase, Fa07CaseResult>{
      Fa07TopologyCase.normal: normal,
    };
    if (normal.status != Fa07AssessmentStatus.pass) {
      return Fa07Result(
        status: normal.status,
        cases: Map.unmodifiable(results),
        governingCase: Fa07TopologyCase.normal,
        reason: normal.reason,
      );
    }

    final scenarios = <Fa07TopologyCase, Fa07FaultScenario>{
      for (final scenario in input.faultScenarios) scenario.caseType: scenario,
    };
    for (final caseType in const [
      Fa07TopologyCase.openFault,
      Fa07TopologyCase.shortFault,
      Fa07TopologyCase.returnLoss,
    ]) {
      if (!input.requiredFaultCases.contains(caseType)) continue;
      final scenario = scenarios[caseType];
      if (scenario == null) {
        final blocked = Fa07CaseResult(
          caseType: caseType,
          status: Fa07AssessmentStatus.blocked,
          reachableDeviceIds: const {},
          reason: 'FA07_REQUIRED_FAULT_MODEL_MISSING',
        );
        results[caseType] = blocked;
        return Fa07Result(
          status: Fa07AssessmentStatus.blocked,
          cases: Map.unmodifiable(results),
          governingCase: caseType,
          reason: blocked.reason,
        );
      }
      final fault = _evaluateFault(input, scenario);
      results[caseType] = fault;
      if (fault.status != Fa07AssessmentStatus.pass) {
        return Fa07Result(
          status: fault.status,
          cases: Map.unmodifiable(results),
          governingCase: caseType,
          reason: fault.reason,
        );
      }
    }

    return Fa07Result(
      status: Fa07AssessmentStatus.pass,
      cases: Map.unmodifiable(results),
    );
  }

  static Fa07CaseResult _evaluateNormal(Fa07Input input) {
    final reachable = _reachableFrom(
      input.sourceNodeId,
      input.edges,
      const <String>{},
    );
    final reachableDevices = input.deviceNodeIds.intersection(reachable);
    if (reachableDevices.length != input.deviceNodeIds.length) {
      return Fa07CaseResult(
        caseType: Fa07TopologyCase.normal,
        status: Fa07AssessmentStatus.fail,
        reachableDeviceIds: Set.unmodifiable(reachableDevices),
        reason: 'FA07_SOURCE_REACHABILITY_INCOMPLETE',
      );
    }

    final reverse = input.edges
        .map((e) => Fa07SignalEdge(
              edgeId: e.edgeId,
              fromNodeId: e.toNodeId,
              toNodeId: e.fromNodeId,
            ))
        .toList();
    final canReachReturn = _reachableFrom(input.returnNodeId, reverse, const <String>{});
    if (!canReachReturn.containsAll(input.deviceNodeIds)) {
      return Fa07CaseResult(
        caseType: Fa07TopologyCase.normal,
        status: Fa07AssessmentStatus.fail,
        reachableDeviceIds: Set.unmodifiable(reachableDevices),
        reason: 'FA07_RETURN_CLOSURE_INCOMPLETE',
      );
    }

    final outDegree = <String, int>{};
    for (final edge in input.edges) {
      outDegree.update(edge.fromNodeId, (value) => value + 1, ifAbsent: () => 1);
    }
    final branchNodes = outDegree.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
    if (branchNodes.length > input.maxBranchNodes ||
        !input.permittedBranchNodeIds.containsAll(branchNodes)) {
      return Fa07CaseResult(
        caseType: Fa07TopologyCase.normal,
        status: Fa07AssessmentStatus.fail,
        reachableDeviceIds: Set.unmodifiable(reachableDevices),
        reason: 'FA07_BRANCH_POLICY_VIOLATION',
      );
    }

    return Fa07CaseResult(
      caseType: Fa07TopologyCase.normal,
      status: Fa07AssessmentStatus.pass,
      reachableDeviceIds: Set.unmodifiable(reachableDevices),
    );
  }

  static Fa07CaseResult _evaluateFault(
    Fa07Input input,
    Fa07FaultScenario scenario,
  ) {
    final reachable = _reachableFrom(
      input.sourceNodeId,
      input.edges,
      scenario.removedEdgeIds,
    );
    final reachableDevices = input.deviceNodeIds.intersection(reachable);
    final pass = _sameSet(reachableDevices, scenario.expectedReachableDeviceIds);
    return Fa07CaseResult(
      caseType: scenario.caseType,
      status: pass ? Fa07AssessmentStatus.pass : Fa07AssessmentStatus.fail,
      reachableDeviceIds: Set.unmodifiable(reachableDevices),
      reason: pass ? null : 'FA07_FAULT_REACHABILITY_MISMATCH',
    );
  }

  static Set<String> _reachableFrom(
    String source,
    List<Fa07SignalEdge> edges,
    Set<String> removedEdgeIds,
  ) {
    final adjacency = <String, List<String>>{};
    for (final edge in edges) {
      if (removedEdgeIds.contains(edge.edgeId)) continue;
      adjacency.putIfAbsent(edge.fromNodeId, () => <String>[]).add(edge.toNodeId);
    }
    final visited = <String>{source};
    final queue = <String>[source];
    var index = 0;
    while (index < queue.length) {
      final node = queue[index++];
      for (final next in adjacency[node] ?? const <String>[]) {
        if (visited.add(next)) queue.add(next);
      }
    }
    return visited;
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}
