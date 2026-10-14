enum ElvVerticalDiscipline { cctv, lan, acs, fire, fiber }

final class ElvVerticalFixturePlan {
  const ElvVerticalFixturePlan({
    required this.discipline,
    required this.connectionCount,
    required this.cableCount,
    required this.allocationCount,
    required this.minimumTraversalCount,
    required this.requiresCarrierAssignment,
    this.normativeComplianceExpected = false,
  });

  final ElvVerticalDiscipline discipline;
  final int connectionCount;
  final int cableCount;
  final int allocationCount;
  final int minimumTraversalCount;
  final bool requiresCarrierAssignment;
  final bool normativeComplianceExpected;
}

abstract final class ElvVerticalFixturePlans {
  static const cctv = ElvVerticalFixturePlan(
    discipline: ElvVerticalDiscipline.cctv,
    connectionCount: 1,
    cableCount: 1,
    allocationCount: 1,
    minimumTraversalCount: 3,
    requiresCarrierAssignment: true,
  );

  static const lan = ElvVerticalFixturePlan(
    discipline: ElvVerticalDiscipline.lan,
    connectionCount: 1,
    cableCount: 1,
    allocationCount: 1,
    minimumTraversalCount: 1,
    requiresCarrierAssignment: true,
  );

  static const acs = ElvVerticalFixturePlan(
    discipline: ElvVerticalDiscipline.acs,
    connectionCount: 4,
    cableCount: 1,
    allocationCount: 4,
    minimumTraversalCount: 1,
    requiresCarrierAssignment: true,
  );

  static const fire = ElvVerticalFixturePlan(
    discipline: ElvVerticalDiscipline.fire,
    connectionCount: 2,
    cableCount: 2,
    allocationCount: 2,
    minimumTraversalCount: 1,
    requiresCarrierAssignment: true,
  );

  static const fiber = ElvVerticalFixturePlan(
    discipline: ElvVerticalDiscipline.fiber,
    connectionCount: 2,
    cableCount: 1,
    allocationCount: 2,
    minimumTraversalCount: 1,
    requiresCarrierAssignment: true,
  );

  static const all = [cctv, lan, acs, fire, fiber];
}
