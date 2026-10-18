import 'package:engineering_core/engineering_core_elv5.dart'
    show
        Fa07AssessmentStatus,
        Fa07FaultScenario,
        Fa07Input,
        Fa07SignalEdge,
        Fa07SignalTopologyKernel,
        Fa07TopologyCase;
import 'package:test/test.dart';

void main() {
  List<Fa07SignalEdge> loopEdges() => [
        Fa07SignalEdge(edgeId: 'e1', fromNodeId: 'source', toNodeId: 'd1'),
        Fa07SignalEdge(edgeId: 'e2', fromNodeId: 'd1', toNodeId: 'd2'),
        Fa07SignalEdge(edgeId: 'e3', fromNodeId: 'd2', toNodeId: 'return'),
      ];

  test('passes normal directed source-to-return closure', () {
    final result = const Fa07SignalTopologyKernel().evaluate(
      Fa07Input(
        loopId: 'loop-1',
        sourceNodeId: 'source',
        returnNodeId: 'return',
        deviceNodeIds: {'d1', 'd2'},
        addressMemberIds: {'d1', 'd2'},
        edges: loopEdges(),
        permittedBranchNodeIds: const {},
        maxBranchNodes: 0,
        requiredFaultCases: const {},
        faultScenarios: const [],
      ),
    );

    expect(result.status, Fa07AssessmentStatus.pass);
  });

  test('missing return edge fails normal closure', () {
    final edges = loopEdges()..removeWhere((edge) => edge.edgeId == 'e3');
    final result = const Fa07SignalTopologyKernel().evaluate(
      Fa07Input(
        loopId: 'loop-1',
        sourceNodeId: 'source',
        returnNodeId: 'return',
        deviceNodeIds: {'d1', 'd2'},
        addressMemberIds: {'d1', 'd2'},
        edges: edges,
        permittedBranchNodeIds: const {},
        maxBranchNodes: 0,
        requiredFaultCases: const {},
        faultScenarios: const [],
      ),
    );

    expect(result.status, Fa07AssessmentStatus.fail);
    expect(result.reason, 'FA07_RETURN_CLOSURE_INCOMPLETE');
  });

  test('required fault case without supported model is blocked', () {
    final result = const Fa07SignalTopologyKernel().evaluate(
      Fa07Input(
        loopId: 'loop-1',
        sourceNodeId: 'source',
        returnNodeId: 'return',
        deviceNodeIds: {'d1', 'd2'},
        addressMemberIds: {'d1', 'd2'},
        edges: loopEdges(),
        permittedBranchNodeIds: const {},
        maxBranchNodes: 0,
        requiredFaultCases: {Fa07TopologyCase.shortFault},
        faultScenarios: const [],
      ),
    );

    expect(result.status, Fa07AssessmentStatus.blocked);
    expect(result.governingCase, Fa07TopologyCase.shortFault);
  });

  test('supported open-fault transform compares exact reachable set', () {
    final result = const Fa07SignalTopologyKernel().evaluate(
      Fa07Input(
        loopId: 'loop-1',
        sourceNodeId: 'source',
        returnNodeId: 'return',
        deviceNodeIds: {'d1', 'd2'},
        addressMemberIds: {'d1', 'd2'},
        edges: loopEdges(),
        permittedBranchNodeIds: const {},
        maxBranchNodes: 0,
        requiredFaultCases: {Fa07TopologyCase.openFault},
        faultScenarios: [
          Fa07FaultScenario(
            caseType: Fa07TopologyCase.openFault,
            removedEdgeIds: {'e2'},
            expectedReachableDeviceIds: {'d1'},
          ),
        ],
      ),
    );

    expect(result.status, Fa07AssessmentStatus.pass);
  });

  test('address membership mismatch fails before graph qualification', () {
    final result = const Fa07SignalTopologyKernel().evaluate(
      Fa07Input(
        loopId: 'loop-1',
        sourceNodeId: 'source',
        returnNodeId: 'return',
        deviceNodeIds: {'d1', 'd2'},
        addressMemberIds: {'d1'},
        edges: loopEdges(),
        permittedBranchNodeIds: const {},
        maxBranchNodes: 0,
        requiredFaultCases: const {},
        faultScenarios: const [],
      ),
    );

    expect(result.status, Fa07AssessmentStatus.fail);
    expect(result.reason, 'FA07_ADDRESS_MEMBERSHIP_MISMATCH');
  });
}
