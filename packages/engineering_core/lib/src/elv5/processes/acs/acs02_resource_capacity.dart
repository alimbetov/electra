import '../../numeric/rational.dart';

enum Acs02AssessmentStatus { pass, fail }

enum Acs02ResourceKind { reader, relay, supervisedInput, other }

final class Acs02Resource {
  Acs02Resource({required this.resourceId, required this.kind}) {
    if (resourceId.isEmpty)
      throw ArgumentError('ACS02 resourceId must not be empty.');
  }
  final String resourceId;
  final Acs02ResourceKind kind;
}

final class Acs02Assignment {
  Acs02Assignment({required this.assignmentId, required this.resourceId}) {
    if (assignmentId.isEmpty || resourceId.isEmpty) {
      throw ArgumentError('ACS02 assignment identities must not be empty.');
    }
  }
  final String assignmentId;
  final String resourceId;
}

final class Acs02SpareRule {
  Acs02SpareRule({required this.absoluteMinimum, required this.ratio}) {
    if (absoluteMinimum < 0 || ratio < Elv5Rational.zero) {
      throw ArgumentError('ACS02 spare rule must be nonnegative.');
    }
  }
  final int absoluteMinimum;
  final Elv5Rational ratio;
}

final class Acs02Input {
  Acs02Input({
    required this.controllerId,
    required this.resources,
    required this.assignments,
    required this.unavailableResourceIds,
    required this.spareRules,
  }) {
    if (controllerId.isEmpty)
      throw ArgumentError('ACS02 controllerId must not be empty.');
    _unique(resources.map((e) => e.resourceId), 'resource');
    _unique(assignments.map((e) => e.assignmentId), 'assignment');
  }
  final String controllerId;
  final List<Acs02Resource> resources;
  final List<Acs02Assignment> assignments;
  final Set<String> unavailableResourceIds;
  final Map<Acs02ResourceKind, Acs02SpareRule> spareRules;

  static void _unique(Iterable<String> values, String label) {
    final seen = <String>{};
    for (final value in values) {
      if (!seen.add(value))
        throw ArgumentError('ACS02 duplicate $label identity: $value');
    }
  }
}

final class Acs02PoolResult {
  const Acs02PoolResult({
    required this.kind,
    required this.available,
    required this.occupied,
    required this.requiredSpare,
    required this.headroom,
    required this.status,
  });
  final Acs02ResourceKind kind;
  final int available;
  final int occupied;
  final int requiredSpare;
  final int headroom;
  final Acs02AssessmentStatus status;
}

final class Acs02Result {
  const Acs02Result({
    required this.status,
    required this.pools,
    required this.conflictingAssignmentIds,
  });
  final Acs02AssessmentStatus status;
  final Map<Acs02ResourceKind, Acs02PoolResult> pools;
  final List<String> conflictingAssignmentIds;
}

final class Acs02ResourceCapacityKernel {
  const Acs02ResourceCapacityKernel();

  Acs02Result evaluate(Acs02Input input) {
    final resources = <String, Acs02Resource>{
      for (final r in input.resources) r.resourceId: r
    };
    final occupiedByKind = <Acs02ResourceKind, Set<String>>{};
    final conflicts = <String>[];
    for (final assignment in input.assignments) {
      final resource = resources[assignment.resourceId];
      if (resource == null ||
          input.unavailableResourceIds.contains(assignment.resourceId)) {
        conflicts.add(assignment.assignmentId);
        continue;
      }
      final occupied =
          occupiedByKind.putIfAbsent(resource.kind, () => <String>{});
      if (!occupied.add(resource.resourceId))
        conflicts.add(assignment.assignmentId);
    }
    conflicts.sort();

    final pools = <Acs02ResourceKind, Acs02PoolResult>{};
    for (final kind in Acs02ResourceKind.values) {
      final available = input.resources
          .where((r) =>
              r.kind == kind &&
              !input.unavailableResourceIds.contains(r.resourceId))
          .length;
      final occupied = occupiedByKind[kind]?.length ?? 0;
      final rule = input.spareRules[kind] ??
          Acs02SpareRule(absoluteMinimum: 0, ratio: Elv5Rational.zero);
      final ratioSpare =
          (Elv5Rational.integer(occupied) * rule.ratio).ceil().toInt();
      final spare =
          ratioSpare > rule.absoluteMinimum ? ratioSpare : rule.absoluteMinimum;
      final headroom = available - occupied - spare;
      pools[kind] = Acs02PoolResult(
        kind: kind,
        available: available,
        occupied: occupied,
        requiredSpare: spare,
        headroom: headroom,
        status: headroom >= 0
            ? Acs02AssessmentStatus.pass
            : Acs02AssessmentStatus.fail,
      );
    }
    final status = conflicts.isEmpty &&
            pools.values.every((p) => p.status == Acs02AssessmentStatus.pass)
        ? Acs02AssessmentStatus.pass
        : Acs02AssessmentStatus.fail;
    return Acs02Result(
      status: status,
      pools: Map.unmodifiable(pools),
      conflictingAssignmentIds: List.unmodifiable(conflicts),
    );
  }
}
