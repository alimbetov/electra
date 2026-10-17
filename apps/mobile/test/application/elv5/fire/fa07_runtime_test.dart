import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/elv5_fire_persistence.dart';
import 'package:electra_mobile/application/elv5/fire/fa01_membership_fingerprint.dart';
import 'package:electra_mobile/application/elv5/fire/fa07_runtime.dart';
import 'package:electra_mobile/application/elv5/fire/fa07_topology_contract.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('projects exact FA-01 membership through directed signal topology', () async {
    final fixture = _fixture();
    final resolver = Fa07PersistedInputResolver(
      fireStore: _FireStore(fixture.payload),
      contractSource: _ContractSource(_contract(fixture.membership)),
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );
    final captured = await resolver.capture(_request());
    final candidate = await buildFa07Executor().execute(captured);
    expect(candidate.assessment, Elv5Assessment.pass);
    expect(candidate.output['status'], 'pass');
  });

  test('blocks topology edition bound to stale FA-01 membership', () async {
    final fixture = _fixture();
    final resolver = Fa07PersistedInputResolver(
      fireStore: _FireStore(fixture.payload),
      contractSource: _ContractSource(_contract(_hash('f'))),
    );
    await expectLater(
      resolver.capture(_request()),
      throwsA(isA<Elv5CaptureBlockedException>().having(
        (value) => value.reasonCode,
        'reasonCode',
        'FA07_FA01_MEMBERSHIP_FINGERPRINT_MISMATCH',
      )),
    );
  });

  test('required fault case without explicit model remains BLOCKED', () async {
    final fixture = _fixture();
    final base = _contract(fixture.membership);
    final contract = Fa07TopologyContract(
      loopId: base.loopId,
      topologyProfile: base.topologyProfile,
      expectedFa01MembershipFingerprint: base.expectedFa01MembershipFingerprint,
      sourceNodeId: base.sourceNodeId,
      returnNodeId: base.returnNodeId,
      deviceNodeIdByDeviceId: base.deviceNodeIdByDeviceId,
      edges: base.edges,
      permittedBranchNodeIds: base.permittedBranchNodeIds,
      maxBranchNodes: base.maxBranchNodes,
      requiredFaultCases: const <String>['OPEN_FAULT'],
      faultScenarios: const <Fa07FaultScenarioContract>[],
    );
    final resolver = Fa07PersistedInputResolver(
      fireStore: _FireStore(fixture.payload),
      contractSource: _ContractSource(contract),
    );
    final captured = await resolver.capture(_request());
    final candidate = await buildFa07Executor().execute(captured);
    expect(candidate.execution, Elv5Execution.blocked);
    expect(candidate.assessment, Elv5Assessment.unresolved);
    expect(candidate.output['reason'], 'FA07_REQUIRED_FAULT_MODEL_MISSING');
  });
}

({Map<String,Object?> payload,String membership}) _fixture() {
  final payload = <String,Object?>{
    'loopId':'loop-1',
    'topologyProfileRef':<String,Object?>{
      'profileCode':'CLASS-A','editionId':'v1','contentHash':_hash('a'),
    },
    'addressDomain':<String,Object?>{
      'panelId':'panel-1','loopId':'loop-1','minAddress':1,'maxAddress':20,
      'reservedAddresses':<int>[],
    },
    'deviceAssignments':<Object?>[
      <String,Object?>{'deviceId':'d1','profileRef':'single','expandedAddresses':<int>[1]},
      <String,Object?>{'deviceId':'d2','profileRef':'single','expandedAddresses':<int>[2]},
      <String,Object?>{'deviceId':'d3','profileRef':'single','expandedAddresses':<int>[3]},
    ],
  };
  final membership = fa01MembershipFingerprint(
    loopId: 'loop-1',
    addressDomain: Map<String,Object?>.from(payload['addressDomain']! as Map),
    deviceAssignments: [
      for (final row in payload['deviceAssignments']! as List)
        Map<String,Object?>.from(row as Map),
    ],
  );
  return (payload:payload,membership:membership);
}

Fa07TopologyContract _contract(String membership) => Fa07TopologyContract(
  loopId:'loop-1',
  topologyProfile:Fa07TopologyProfileIdentity(
    profileCode:'CLASS-A',editionId:'v1',contentHash:_hash('a')),
  expectedFa01MembershipFingerprint:membership,
  sourceNodeId:'source',returnNodeId:'return',
  deviceNodeIdByDeviceId:const <String,String>{'d1':'n1','d2':'n2','d3':'n3'},
  edges:<Fa07EdgeContract>[
    Fa07EdgeContract(edgeId:'e1',fromNodeId:'source',toNodeId:'n1'),
    Fa07EdgeContract(edgeId:'e2',fromNodeId:'n1',toNodeId:'n2'),
    Fa07EdgeContract(edgeId:'e3',fromNodeId:'n2',toNodeId:'n3'),
    Fa07EdgeContract(edgeId:'e4',fromNodeId:'n3',toNodeId:'return'),
  ],
  permittedBranchNodeIds:const <String>[],maxBranchNodes:0,
  requiredFaultCases:const <String>[],faultScenarios:const <Fa07FaultScenarioContract>[],
);

Elv5CalculationRequest _request()=>Elv5CalculationRequest(
  projectId:'p',designRevisionId:'d',scope:Elv5ScopeRef(kind:Elv5ScopeKind.design,scopeId:'d',scenarioKey:'NONE'),
  processCode:Elv5ProcessCode.fa07,subject:Elv5SubjectRef(kind:'FIRE_LOOP',id:'loop-1'),expectedPointerGeneration:0);

final class _FireStore implements Elv5FireFactStore {
  const _FireStore(this.payload);final Map<String,Object?> payload;
  @override Future<Elv5FireAggregateSnapshot?> load({required String projectId,required String designRevisionId,required String operation,required String subjectId}) async=>Elv5FireAggregateSnapshot(aggregateKind:'FIRE_LOOP',aggregateId:'ELV5:FIRE_LOOP:loop-1',subjectId:'loop-1',revision:4,payload:payload);
}
final class _ContractSource implements Fa07TopologyContractSource {
  const _ContractSource(this.contract);final Fa07TopologyContract contract;
  @override Future<Fa07TopologyContractSnapshot?> loadActiveForLoop({required String projectId,required String designRevisionId,required String loopId}) async=>Fa07TopologyContractSnapshot(bindingId:'fa07-binding',bindingRevision:2,evidenceRef:'FA07:loop-1:${_hash('b')}',contentHash:_hash('b'),contract:contract);
}
String _hash(String char)=>List<String>.filled(64,char).join();
