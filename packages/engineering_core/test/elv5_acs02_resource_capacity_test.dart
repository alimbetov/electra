import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('ACS-02 keeps resource pools independent', () {
    final result = const Acs02ResourceCapacityKernel().evaluate(
      Acs02Input(
        controllerId: 'ctrl-1',
        resources: [
          Acs02Resource(resourceId: 'r1', kind: Acs02ResourceKind.reader),
          Acs02Resource(resourceId: 'r2', kind: Acs02ResourceKind.reader),
          Acs02Resource(resourceId: 'r3', kind: Acs02ResourceKind.reader),
          Acs02Resource(resourceId: 'r4', kind: Acs02ResourceKind.reader),
          Acs02Resource(resourceId: 'rel1', kind: Acs02ResourceKind.relay),
          Acs02Resource(resourceId: 'rel2', kind: Acs02ResourceKind.relay),
        ],
        assignments: [
          Acs02Assignment(assignmentId: 'a1', resourceId: 'r1'),
          Acs02Assignment(assignmentId: 'a2', resourceId: 'r2'),
          Acs02Assignment(assignmentId: 'a3', resourceId: 'r3'),
          Acs02Assignment(assignmentId: 'a4', resourceId: 'rel1'),
          Acs02Assignment(assignmentId: 'a5', resourceId: 'rel2'),
        ],
        unavailableResourceIds: {},
        spareRules: {
          Acs02ResourceKind.reader: Acs02SpareRule(
            absoluteMinimum: 0,
            ratio: Elv5Rational.zero,
          ),
          Acs02ResourceKind.relay: Acs02SpareRule(
            absoluteMinimum: 0,
            ratio: Elv5Rational.zero,
          ),
        },
      ),
    );

    expect(result.status, Acs02AssessmentStatus.pass);
    expect(result.pools[Acs02ResourceKind.reader]!.headroom, 1);
    expect(result.pools[Acs02ResourceKind.relay]!.headroom, 0);
  });

  test('same physical relay cannot be consumed twice through aliases', () {
    final result = const Acs02ResourceCapacityKernel().evaluate(
      Acs02Input(
        controllerId: 'ctrl-1',
        resources: [
          Acs02Resource(resourceId: 'rel1', kind: Acs02ResourceKind.relay),
          Acs02Resource(resourceId: 'rel2', kind: Acs02ResourceKind.relay),
        ],
        assignments: [
          Acs02Assignment(assignmentId: 'door-a', resourceId: 'rel1'),
          Acs02Assignment(assignmentId: 'door-b', resourceId: 'rel1'),
        ],
        unavailableResourceIds: {},
        spareRules: {},
      ),
    );

    expect(result.status, Acs02AssessmentStatus.fail);
    expect(result.conflictingAssignmentIds, ['door-b']);
  });

  test('spare requirement can consume exact remaining capacity', () {
    final result = const Acs02ResourceCapacityKernel().evaluate(
      Acs02Input(
        controllerId: 'ctrl-1',
        resources: [
          Acs02Resource(
              resourceId: 'i1', kind: Acs02ResourceKind.supervisedInput),
          Acs02Resource(
              resourceId: 'i2', kind: Acs02ResourceKind.supervisedInput),
        ],
        assignments: [
          Acs02Assignment(assignmentId: 'input-a', resourceId: 'i1'),
        ],
        unavailableResourceIds: {},
        spareRules: {
          Acs02ResourceKind.supervisedInput: Acs02SpareRule(
            absoluteMinimum: 1,
            ratio: Elv5Rational.zero,
          ),
        },
      ),
    );

    expect(result.pools[Acs02ResourceKind.supervisedInput]!.headroom, 0);
    expect(result.status, Acs02AssessmentStatus.pass);
  });
}
