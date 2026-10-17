import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_persistence.dart';
import 'package:electra_mobile/application/elv5/lan/lan04_compatibility_contract.dart';
import 'package:electra_mobile/application/elv5/lan/lan04_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN04 passes when every realized section satisfies exact required mode', () async {
    final payload = _payload();
    final resolver = Lan04PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload)),
    );
    final result = await buildLan04Executor().execute(await resolver.capture(_request()));
    expect(result.assessment, Elv5Assessment.pass);
    expect(result.output['status'], 'pass');
    expect(result.output['limitingSectionId'], isNull);
  });

  test('LAN04 reports first path section with incompatible speed capability', () async {
    final payload = _payload();
    final resolver = Lan04PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload, section2Speeds: const ['100BASE-TX'])),
    );
    final result = await buildLan04Executor().execute(await resolver.capture(_request()));
    expect(result.assessment, Elv5Assessment.fail);
    expect(result.output['limitingSectionId'], 'section-2');
    expect(result.output['limitingProperty'], 'speedMode');
  });

  test('LAN04 unknown shield continuity stays unresolved', () async {
    final payload = _payload();
    final resolver = Lan04PersistedInputResolver(
      lanStore: _Store(payload),
      contractSource: _Contracts(_contract(payload, section1ShieldKnown: false)),
    );
    final result = await buildLan04Executor().execute(await resolver.capture(_request()));
    expect(result.assessment, Elv5Assessment.unresolved);
    expect(result.output['status'], 'unresolved');
    expect(result.output['limitingSectionId'], 'section-1');
    expect(result.output['limitingProperty'], 'shielding');
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'project',
  designRevisionId: 'revision',
  scope: Elv5ScopeRef(kind: Elv5ScopeKind.design, scopeId: 'revision', scenarioKey: 'NONE'),
  processCode: Elv5ProcessCode.lan04,
  subject: Elv5SubjectRef(kind: 'LINK', id: 'link-1'),
  expectedPointerGeneration: 0,
);

Map<String,Object?> _payload()=> <String,Object?>{
  'linkId':'link-1',
  'orderedSections':<Object?>[
    <String,Object?>{'ordinal':0,'realizedSectionId':'section-1','classification':'PERMANENT'},
    <String,Object?>{'ordinal':1,'realizedSectionId':'section-2','classification':'PERMANENT'},
  ],
  'policyBindingId':'policy-link-1',
};

Lan04CompatibilityContract _contract(
  Map<String,Object?> payload, {
  List<String> section2Speeds = const ['1000BASE-T'],
  bool section1ShieldKnown = true,
}) => Lan04CompatibilityContract(
  linkId:'link-1',
  expectedCompositionFingerprint:const Elv5CanonicalJsonV1().sha256(payload),
  requiredMediumCode:'COPPER',
  requiredInterfaceKind:'ETHERNET',
  requiredSpeedMode:'1000BASE-T',
  requiredConnectorKind:'RJ45',
  shieldingRequired:true,
  sections:<Lan04SectionCapabilityContract>[
    _section('section-1',speeds:const ['1000BASE-T'],shieldKnown:section1ShieldKnown),
    _section('section-2',speeds:section2Speeds),
  ],
);

Lan04SectionCapabilityContract _section(
  String id, {
  required List<String> speeds,
  bool shieldKnown = true,
}) => Lan04SectionCapabilityContract(
  sectionId:id,
  mediumCode:'COPPER',
  supportedInterfaceKinds:const ['ETHERNET'],
  supportedSpeedModes:speeds,
  supportedConnectorKinds:const ['RJ45'],
  shieldContinuityKnown:shieldKnown,
  shieldContinuity:shieldKnown,
  evidenceRef:'CATALOG:$id',
  evidenceContentHash:_hash(id=='section-1'?'a':'b'),
);

final class _Store implements Elv5LanFactStore {
  const _Store(this.payload);
  final Map<String,Object?> payload;
  @override
  Future<Elv5LanAggregateSnapshot?> load({required String projectId,required String designRevisionId,required String operation,required String subjectId}) async =>
    Elv5LanAggregateSnapshot(aggregateKind:'LAN_LINK_COMPOSITION',aggregateId:'ELV5:LAN_LINK_COMPOSITION:link-1',subjectId:'link-1',revision:3,payload:payload);
}

final class _Contracts implements Lan04CompatibilityContractSource {
  const _Contracts(this.contract);
  final Lan04CompatibilityContract contract;
  @override
  Future<Lan04CompatibilityContractSnapshot?> loadActiveForLink({required String projectId,required String designRevisionId,required String linkId}) async =>
    Lan04CompatibilityContractSnapshot(bindingId:'lan04-binding',bindingRevision:1,evidenceRef:'LAN04:link-1:${_hash('c')}',contentHash:_hash('c'),contract:contract);
}

String _hash(String char)=>List<String>.filled(64,char).join();
