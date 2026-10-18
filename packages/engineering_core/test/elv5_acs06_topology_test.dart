import 'package:engineering_core/engineering_core_elv5.dart'
    show
        Acs06AssessmentStatus,
        Acs06CauseProfile,
        Acs06DoorTopologyKernel,
        Acs06EdgeKind,
        Acs06GraphEdge,
        Acs06Input,
        Acs06LockOutcome,
        Acs06LockSafetyMode,
        Acs06PathRequirement,
        Acs06ReleaseCause,
        Acs06TruthRow;
import 'package:test/test.dart';

void main() {
  List<Acs06CauseProfile> profiles({bool requireFeed = true}) => [
        Acs06CauseProfile(
          cause: Acs06ReleaseCause.normalAccess,
          requiredPaths: [
            Acs06PathRequirement(
              requirementId: 'normal-control',
              fromNodeId: 'reader',
              toNodeId: 'lock',
              allowedKinds: {Acs06EdgeKind.data, Acs06EdgeKind.control},
            ),
          ],
          outcomeWhenSatisfied: Acs06LockOutcome.released,
          requiresConductiveFeed: requireFeed,
        ),
        Acs06CauseProfile(
          cause: Acs06ReleaseCause.requestToExit,
          requiredPaths: [
            Acs06PathRequirement(
              requirementId: 'rex-release',
              fromNodeId: 'rex',
              toNodeId: 'lock',
              allowedKinds: {Acs06EdgeKind.release},
            ),
          ],
          outcomeWhenSatisfied: Acs06LockOutcome.released,
          requiresConductiveFeed: requireFeed,
        ),
        Acs06CauseProfile(
          cause: Acs06ReleaseCause.fireRelease,
          requiredPaths: [
            Acs06PathRequirement(
              requirementId: 'fire-release',
              fromNodeId: 'fire',
              toNodeId: 'lock',
              allowedKinds: {Acs06EdgeKind.release},
            ),
          ],
          outcomeWhenSatisfied: Acs06LockOutcome.released,
          requiresConductiveFeed: requireFeed,
        ),
        Acs06CauseProfile(
          cause: Acs06ReleaseCause.emergencyBreakGlass,
          requiredPaths: [
            Acs06PathRequirement(
              requirementId: 'break-glass',
              fromNodeId: 'glass',
              toNodeId: 'lock',
              allowedKinds: {Acs06EdgeKind.release},
            ),
          ],
          outcomeWhenSatisfied: Acs06LockOutcome.released,
          requiresConductiveFeed: requireFeed,
        ),
        Acs06CauseProfile(
          cause: Acs06ReleaseCause.powerFailure,
          requiredPaths: const [],
          outcomeWhenSatisfied: Acs06LockOutcome.released,
        ),
      ];

  List<Acs06TruthRow> truth() => Acs06ReleaseCause.values
      .map((cause) => Acs06TruthRow(
            cause: cause,
            expectedOutcome: Acs06LockOutcome.released,
          ))
      .toList();

  List<Acs06GraphEdge> completeEdges() => [
        Acs06GraphEdge(
          edgeId: 'reader-data',
          fromNodeId: 'reader',
          toNodeId: 'controller',
          kind: Acs06EdgeKind.data,
        ),
        Acs06GraphEdge(
          edgeId: 'controller-control',
          fromNodeId: 'controller',
          toNodeId: 'lock',
          kind: Acs06EdgeKind.control,
        ),
        Acs06GraphEdge(
          edgeId: 'lock-feed',
          fromNodeId: 'psu',
          toNodeId: 'lock',
          kind: Acs06EdgeKind.powerFeed,
        ),
        Acs06GraphEdge(
          edgeId: 'rex-release',
          fromNodeId: 'rex',
          toNodeId: 'lock',
          kind: Acs06EdgeKind.release,
        ),
        Acs06GraphEdge(
          edgeId: 'fire-release',
          fromNodeId: 'fire',
          toNodeId: 'lock',
          kind: Acs06EdgeKind.release,
        ),
        Acs06GraphEdge(
          edgeId: 'glass-release',
          fromNodeId: 'glass',
          toNodeId: 'lock',
          kind: Acs06EdgeKind.release,
        ),
      ];

  test('passes complete five-cause fail-safe topology', () {
    final result = const Acs06DoorTopologyKernel().evaluate(
      Acs06Input(
        doorId: 'door-1',
        lockNodeId: 'lock',
        edges: completeEdges(),
        causeProfiles: profiles(),
        truthTable: truth(),
        safetyMode: Acs06LockSafetyMode.failSafe,
      ),
    );

    expect(result.status, Acs06AssessmentStatus.pass);
    expect(result.causes.length, 5);
  });

  test('dry relay control cannot substitute conductive lock feed', () {
    final edges = completeEdges()
      ..removeWhere((edge) => edge.kind == Acs06EdgeKind.powerFeed);
    final result = const Acs06DoorTopologyKernel().evaluate(
      Acs06Input(
        doorId: 'door-1',
        lockNodeId: 'lock',
        edges: edges,
        causeProfiles: profiles(),
        truthTable: truth(),
        safetyMode: Acs06LockSafetyMode.failSafe,
      ),
    );

    expect(result.status, Acs06AssessmentStatus.fail);
    expect(
      result.causes[Acs06ReleaseCause.normalAccess]!.reason,
      'ACS06_LOCK_HAS_NO_CONDUCTIVE_POWER_FEED',
    );
  });

  test('fail-secure power failure is checked against persisted truth row', () {
    final result = const Acs06DoorTopologyKernel().evaluate(
      Acs06Input(
        doorId: 'door-1',
        lockNodeId: 'lock',
        edges: completeEdges(),
        causeProfiles: profiles(),
        truthTable: truth(),
        safetyMode: Acs06LockSafetyMode.failSecure,
      ),
    );

    expect(result.status, Acs06AssessmentStatus.fail);
    expect(result.governingCause, Acs06ReleaseCause.powerFailure);
  });

  test('missing mandatory fire-release path fails only that cause', () {
    final edges = completeEdges()
      ..removeWhere((edge) => edge.edgeId == 'fire-release');
    final result = const Acs06DoorTopologyKernel().evaluate(
      Acs06Input(
        doorId: 'door-1',
        lockNodeId: 'lock',
        edges: edges,
        causeProfiles: profiles(),
        truthTable: truth(),
        safetyMode: Acs06LockSafetyMode.failSafe,
      ),
    );

    expect(result.status, Acs06AssessmentStatus.fail);
    expect(
      result.causes[Acs06ReleaseCause.fireRelease]!.failedRequirementId,
      'fire-release',
    );
  });
}
