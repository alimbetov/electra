import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_persistence.dart';
import 'package:electra_mobile/application/elv5/lan/lan02_port_contract.dart';
import 'package:electra_mobile/application/elv5/lan/lan02_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN02 validates media/speed and exact spare headroom', () async {
    final payload = _payload();
    final resolver = Lan02PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload)),
    );
    final result = await buildLan02Executor().execute(await resolver.capture(_request()));
    expect(result.assessment, Elv5Assessment.pass);
    expect(result.output['occupied'], 2);
    expect(result.output['requiredSpare'], 1);
    expect(result.output['available'], 3);
    expect(result.output['headroomPorts'], 0);
  });

  test('LAN02 incompatible port speed fails without changing port count semantics', () async {
    final payload = _payload(requiredSpeedBps: '2500000000');
    final resolver = Lan02PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload)),
    );
    final result = await buildLan02Executor().execute(await resolver.capture(_request()));
    expect(result.assessment, Elv5Assessment.fail);
    expect(result.output['incompatibleEndpointIds'], contains('endpoint-2'));
  });

  test('LAN02 non-integral Mbps wire rate is capture BLOCKED', () async {
    final payload = _payload(requiredSpeedBps: '1000000001');
    final resolver = Lan02PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload)),
    );
    await expectLater(
      resolver.capture(_request()),
      throwsA(isA<Elv5CaptureBlockedException>().having(
        (e) => e.reasonCode,
        'reasonCode',
        'LAN02_SPEED_BPS_NOT_WHOLE_MBPS',
      )),
    );
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'project',
  designRevisionId: 'revision',
  scope: Elv5ScopeRef(kind: Elv5ScopeKind.design, scopeId: 'revision', scenarioKey: 'NONE'),
  processCode: Elv5ProcessCode.lan02,
  subject: Elv5SubjectRef(kind: 'SWITCH', id: 'switch-1'),
  expectedPointerGeneration: 0,
);

Map<String,Object?> _payload({String requiredSpeedBps='1000000000'}) => <String,Object?>{
  'switchId':'switch-1',
  'assignments':<Object?>[
    <String,Object?>{'portId':'p1','endpointId':'endpoint-1','media':'COPPER','speedBps':'1000000000'},
    <String,Object?>{'portId':'p2','endpointId':'endpoint-2','media':'COPPER','speedBps':requiredSpeedBps},
  ],
  'sparePolicyRef':<String,Object?>{'policyCode':'LAN-PORT-SPARE','editionId':'spare-v1','contentHash':_hash('b')},
};

Lan02PortContract _contract(Map<String,Object?> payload)=>Lan02PortContract(
  switchId:'switch-1',
  expectedAggregateFingerprint:const Elv5CanonicalJsonV1().sha256(payload),
  sparePolicy:Lan02PolicyIdentity(policyCode:'LAN-PORT-SPARE',editionId:'spare-v1',contentHash:_hash('b')),
  ports:<Lan02PortContractItem>[
    Lan02PortContractItem(portId:'p1',media:'COPPER',maxSpeedMbps:1000),
    Lan02PortContractItem(portId:'p2',media:'COPPER',maxSpeedMbps:1000),
    Lan02PortContractItem(portId:'p3',media:'COPPER',maxSpeedMbps:1000),
  ],
  absoluteMinimum:1,
  ratio:Elv5Rational.zero,
  combinerCode:'MAX',
);

final class _Store implements Elv5LanFactStore {
  const _Store(this.payload);
  final Map<String,Object?> payload;
  @override
  Future<Elv5LanAggregateSnapshot?> load({required String projectId,required String designRevisionId,required String operation,required String subjectId}) async =>
    Elv5LanAggregateSnapshot(aggregateKind:'LAN_PORT_CAPACITY',aggregateId:'ELV5:LAN_PORT_CAPACITY:switch-1',subjectId:'switch-1',revision:4,payload:payload);
}

final class _Contracts implements Lan02PortContractSource {
  const _Contracts(this.contract);
  final Lan02PortContract contract;
  @override
  Future<Lan02PortContractSnapshot?> loadActiveForSwitch({required String projectId,required String designRevisionId,required String switchId}) async =>
    Lan02PortContractSnapshot(bindingId:'lan02-binding',bindingRevision:1,evidenceRef:'LAN02:switch-1:${_hash('c')}',contentHash:_hash('c'),contract:contract);
}

String _hash(String char)=>List<String>.filled(64,char).join();
