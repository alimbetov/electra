import 'package:electra_mobile/application/elv5/fire/fa01_address_capacity_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa07_topology_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips FA-01 profile resource semantics', () {
    final contract = Fa01AddressCapacityContract(
      loopId: 'loop-1',
      deviceLimit: 10,
      addressLimit: 20,
      requiredDeviceSpare: 2,
      requiredAddressSpare: 3,
      profileAddressConsumption: const <String, int>{'p1': 2},
      profileDeviceCountContribution: const <String, int>{'p1': 1},
    );
    final restored = Fa01AddressCapacityContract.fromMap(
      contract.toCanonicalValue(),
    );
    expect(restored.profileAddressConsumption['p1'], 2);
    expect(restored.profileDeviceCountContribution['p1'], 1);
    expect(restored.requiredAddressSpare, 3);
  });

  test(
    'FA-07 topology contract rejects graph that omits a mapped device node',
    () {
      expect(
        () => Fa07TopologyContract(
          loopId: 'loop-1',
          topologyProfile: Fa07TopologyProfileIdentity(
            profileCode: 'CLASS-A',
            editionId: 'v1',
            contentHash: _hash('a'),
          ),
          expectedFa01MembershipFingerprint: _hash('b'),
          sourceNodeId: 'source',
          returnNodeId: 'return',
          deviceNodeIdByDeviceId: const <String, String>{'d1': 'n1'},
          edges: <Fa07EdgeContract>[
            Fa07EdgeContract(
              edgeId: 'e1',
              fromNodeId: 'source',
              toNodeId: 'return',
            ),
          ],
          permittedBranchNodeIds: const <String>[],
          maxBranchNodes: 0,
          requiredFaultCases: const <String>[],
          faultScenarios: const <Fa07FaultScenarioContract>[],
        ),
        throwsArgumentError,
      );
    },
  );

  test('round-trips FA-07 exact topology and fault model', () {
    final contract = Fa07TopologyContract(
      loopId: 'loop-1',
      topologyProfile: Fa07TopologyProfileIdentity(
        profileCode: 'CLASS-A',
        editionId: 'v1',
        contentHash: _hash('a'),
      ),
      expectedFa01MembershipFingerprint: _hash('b'),
      sourceNodeId: 'source',
      returnNodeId: 'return',
      deviceNodeIdByDeviceId: const <String, String>{'d1': 'n1'},
      edges: <Fa07EdgeContract>[
        Fa07EdgeContract(edgeId: 'e1', fromNodeId: 'source', toNodeId: 'n1'),
        Fa07EdgeContract(edgeId: 'e2', fromNodeId: 'n1', toNodeId: 'return'),
      ],
      permittedBranchNodeIds: const <String>[],
      maxBranchNodes: 0,
      requiredFaultCases: const <String>['OPEN_FAULT'],
      faultScenarios: <Fa07FaultScenarioContract>[
        Fa07FaultScenarioContract(
          caseCode: 'OPEN_FAULT',
          removedEdgeIds: const <String>['e1'],
          expectedReachableDeviceIds: const <String>[],
        ),
      ],
    );
    final restored = Fa07TopologyContract.fromMap(contract.toCanonicalValue());
    expect(restored.requiredFaultCases, contains('OPEN_FAULT'));
    expect(restored.faultScenarios.single.removedEdgeIds, contains('e1'));
  });
}

String _hash(String c) => List<String>.filled(64, c).join();
