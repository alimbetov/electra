enum Acs01AssessmentStatus { pass, fail, unresolved }

enum Acs01RoleCode {
  entryReader,
  exitReader,
  exitButton,
  lock,
  doorContact,
  emergencyRelease,
  other,
}

enum Acs01RequirementKind { atLeast, exactly, allOf, anyOf, exactlyOneOf }

final class Acs01RoleAssignment {
  Acs01RoleAssignment({
    required this.assignmentId,
    required this.componentId,
    required this.role,
  }) {
    if (assignmentId.isEmpty || componentId.isEmpty) {
      throw ArgumentError('ACS01 assignment identities must not be empty.');
    }
  }

  final String assignmentId;
  final String componentId;
  final Acs01RoleCode role;
}

final class Acs01ComponentCapabilities {
  Acs01ComponentCapabilities({
    required this.componentId,
    required this.allowedRoles,
    this.allowRoleSharing = false,
  }) {
    if (componentId.isEmpty) {
      throw ArgumentError('ACS01 componentId must not be empty.');
    }
  }

  final String componentId;
  final Set<Acs01RoleCode> allowedRoles;
  final bool allowRoleSharing;
}

final class Acs01RequirementNode {
  Acs01RequirementNode.roleCount({
    required this.nodeId,
    required this.kind,
    required this.role,
    required this.count,
  }) : children = const [] {
    if (kind != Acs01RequirementKind.atLeast &&
        kind != Acs01RequirementKind.exactly) {
      throw ArgumentError(
          'ACS01 role-count node kind must be atLeast or exactly.');
    }
    _validateId(nodeId);
    if (count == null || count! < 0) {
      throw ArgumentError('ACS01 role-count requirement must be nonnegative.');
    }
  }

  Acs01RequirementNode.group({
    required this.nodeId,
    required this.kind,
    required this.children,
  })  : role = null,
        count = null {
    if (kind != Acs01RequirementKind.allOf &&
        kind != Acs01RequirementKind.anyOf &&
        kind != Acs01RequirementKind.exactlyOneOf) {
      throw ArgumentError('ACS01 group node has invalid kind.');
    }
    _validateId(nodeId);
    if (children.isEmpty) {
      throw ArgumentError('ACS01 group node must have children.');
    }
  }

  final String nodeId;
  final Acs01RequirementKind kind;
  final Acs01RoleCode? role;
  final int? count;
  final List<Acs01RequirementNode> children;

  static void _validateId(String value) {
    if (value.isEmpty) throw ArgumentError('ACS01 nodeId must not be empty.');
  }
}

final class Acs01Input {
  Acs01Input({
    required this.doorId,
    required this.profileId,
    required this.rootRequirement,
    required this.assignments,
    required this.capabilities,
    required this.assignmentClosureComplete,
  }) {
    if (doorId.isEmpty || profileId.isEmpty) {
      throw ArgumentError('ACS01 door/profile identities must not be empty.');
    }
    _requireUnique(assignments.map((e) => e.assignmentId), 'assignment');
    _requireUnique(
        capabilities.map((e) => e.componentId), 'component capability');
    _validateRequirementTree(rootRequirement);
  }

  final String doorId;
  final String profileId;
  final Acs01RequirementNode rootRequirement;
  final List<Acs01RoleAssignment> assignments;
  final List<Acs01ComponentCapabilities> capabilities;
  final bool assignmentClosureComplete;

  static void _requireUnique(Iterable<String> values, String label) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value))
        throw ArgumentError('ACS01 duplicate $label identity: $value');
    }
  }

  static void _validateRequirementTree(Acs01RequirementNode root) {
    final seen = <String>{};
    void visit(Acs01RequirementNode node) {
      if (!seen.add(node.nodeId)) {
        throw ArgumentError(
            'ACS01 duplicate/cyclic requirement node: ${node.nodeId}');
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(root);
  }
}

final class Acs01NodeResult {
  const Acs01NodeResult({
    required this.nodeId,
    required this.status,
    required this.margin,
    required this.selectedChildNodeIds,
  });

  final String nodeId;
  final Acs01AssessmentStatus status;
  final int? margin;
  final List<String> selectedChildNodeIds;
}

final class Acs01Result {
  const Acs01Result({
    required this.status,
    required this.nodeResults,
    required this.illegalSharingComponentIds,
    required this.governingNodeId,
  });

  final Acs01AssessmentStatus status;
  final List<Acs01NodeResult> nodeResults;
  final List<String> illegalSharingComponentIds;
  final String governingNodeId;
}

final class Acs01RoleCompletenessKernel {
  const Acs01RoleCompletenessKernel();

  Acs01Result evaluate(Acs01Input input) {
    final capabilities = <String, Acs01ComponentCapabilities>{
      for (final value in input.capabilities) value.componentId: value,
    };
    final eligibleByRole = <Acs01RoleCode, Set<String>>{};
    final rolesByComponent = <String, Set<Acs01RoleCode>>{};
    final invalidAssignments = <String>[];

    final sortedAssignments = [...input.assignments]
      ..sort((a, b) => a.assignmentId.compareTo(b.assignmentId));
    for (final assignment in sortedAssignments) {
      final capability = capabilities[assignment.componentId];
      if (capability == null ||
          !capability.allowedRoles.contains(assignment.role)) {
        invalidAssignments.add(assignment.componentId);
        continue;
      }
      eligibleByRole
          .putIfAbsent(assignment.role, () => <String>{})
          .add(assignment.componentId);
      rolesByComponent
          .putIfAbsent(assignment.componentId, () => <Acs01RoleCode>{})
          .add(assignment.role);
    }

    final illegalSharing = <String>{...invalidAssignments};
    for (final entry in rolesByComponent.entries) {
      final capability = capabilities[entry.key]!;
      if (entry.value.length > 1 && !capability.allowRoleSharing) {
        illegalSharing.add(entry.key);
      }
    }
    final illegalSharingSorted = illegalSharing.toList()..sort();

    final results = <Acs01NodeResult>[];
    Acs01NodeResult eval(Acs01RequirementNode node) {
      if (node.kind == Acs01RequirementKind.atLeast ||
          node.kind == Acs01RequirementKind.exactly) {
        final actual = eligibleByRole[node.role]?.length ?? 0;
        final requiredCount = node.count!;
        final margin = node.kind == Acs01RequirementKind.atLeast
            ? actual - requiredCount
            : -((actual - requiredCount).abs());
        final satisfied = node.kind == Acs01RequirementKind.atLeast
            ? actual >= requiredCount
            : actual == requiredCount;
        final status = satisfied
            ? Acs01AssessmentStatus.pass
            : (input.assignmentClosureComplete
                ? Acs01AssessmentStatus.fail
                : Acs01AssessmentStatus.unresolved);
        final result = Acs01NodeResult(
          nodeId: node.nodeId,
          status: status,
          margin: margin,
          selectedChildNodeIds: const [],
        );
        results.add(result);
        return result;
      }

      final children = [...node.children]
        ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
      final childResults = children.map(eval).toList();
      final passChildren = childResults
          .where((e) => e.status == Acs01AssessmentStatus.pass)
          .toList();
      final unresolvedChildren = childResults
          .where((e) => e.status == Acs01AssessmentStatus.unresolved)
          .toList();

      late Acs01AssessmentStatus status;
      List<String> selected = const [];
      if (node.kind == Acs01RequirementKind.allOf) {
        status = childResults.any((e) => e.status == Acs01AssessmentStatus.fail)
            ? Acs01AssessmentStatus.fail
            : (childResults
                    .any((e) => e.status == Acs01AssessmentStatus.unresolved)
                ? Acs01AssessmentStatus.unresolved
                : Acs01AssessmentStatus.pass);
        if (status == Acs01AssessmentStatus.pass) {
          selected = childResults.map((e) => e.nodeId).toList();
        }
      } else if (node.kind == Acs01RequirementKind.anyOf) {
        if (passChildren.isNotEmpty) {
          status = Acs01AssessmentStatus.pass;
          selected = [passChildren.first.nodeId];
        } else if (unresolvedChildren.isNotEmpty) {
          status = Acs01AssessmentStatus.unresolved;
        } else {
          status = Acs01AssessmentStatus.fail;
        }
      } else if (node.kind == Acs01RequirementKind.exactlyOneOf) {
        if (passChildren.length == 1 && unresolvedChildren.isEmpty) {
          status = Acs01AssessmentStatus.pass;
          selected = [passChildren.single.nodeId];
        } else if (passChildren.length > 1) {
          status = Acs01AssessmentStatus.fail;
        } else if (unresolvedChildren.isNotEmpty) {
          status = Acs01AssessmentStatus.unresolved;
        } else {
          status = Acs01AssessmentStatus.fail;
        }
      } else {
        throw StateError('ACS01 unreachable group requirement kind.');
      }

      final result = Acs01NodeResult(
        nodeId: node.nodeId,
        status: status,
        margin: null,
        selectedChildNodeIds: List.unmodifiable(selected),
      );
      results.add(result);
      return result;
    }

    final root = eval(input.rootRequirement);
    final overall = illegalSharingSorted.isNotEmpty
        ? Acs01AssessmentStatus.fail
        : root.status;
    final failures = results
        .where((e) => e.status == Acs01AssessmentStatus.fail)
        .toList()
      ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
    final unresolved = results
        .where((e) => e.status == Acs01AssessmentStatus.unresolved)
        .toList()
      ..sort((a, b) => a.nodeId.compareTo(b.nodeId));
    final governingNodeId = illegalSharingSorted.isNotEmpty
        ? 'ACS01_ILLEGAL_ROLE_SHARING'
        : (failures.isNotEmpty
            ? failures.first.nodeId
            : (unresolved.isNotEmpty ? unresolved.first.nodeId : root.nodeId));

    results.sort((a, b) => a.nodeId.compareTo(b.nodeId));
    return Acs01Result(
      status: overall,
      nodeResults: List.unmodifiable(results),
      illegalSharingComponentIds: List.unmodifiable(illegalSharingSorted),
      governingNodeId: governingNodeId,
    );
  }
}
