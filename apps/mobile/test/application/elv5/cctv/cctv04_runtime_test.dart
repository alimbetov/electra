import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv04_pse_contract.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv04_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/lan03_poe_contract.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CCTV04 preserves global PWR06 totals and projects CCTV contribution', () async {
    final members = _members();
    final closure = cctv04Pwr06ClosureFingerprint(pseId: 'pse-1', members: members);
    final resolver = Cctv04PersistedInputResolver(
      contractSource: _Contracts(_contract(closure)),
      powerEvidence: _Power(<Elv4CurrentEvaluationSnapshot>[
        _pwr06('lan-delivery', _hash('a'), members, marginW: 5),
        _pwr06('cctv-delivery', _hash('b'), members, marginW: 5),
      ]),
    );

    final result = await buildCctv04Executor().execute(
      await resolver.capture(_request()),
    );

    expect(result.assessment, Elv5Assessment.pass);
    expect(result.output['globalDemandW'], _r(30));
    expect(result.output['availableCapabilityW'], _r(35));
    expect(result.output['globalMarginW'], _r(5));
    expect(result.output['cctvContributionW'], _r(12));
  });

  test('LAN03 and CCTV04 hash the same physical PWR06 closure identically', () {
    final members = _members();
    expect(
      cctv04Pwr06ClosureFingerprint(pseId: 'pse-1', members: members),
      lan03Pwr06ClosureFingerprint(pseId: 'pse-1', members: members),
    );
  });

  test('CCTV04 rejects a discipline-filtered PWR06 delivery set', () async {
    final members = _members();
    final closure = cctv04Pwr06ClosureFingerprint(pseId: 'pse-1', members: members);
    final resolver = Cctv04PersistedInputResolver(
      contractSource: _Contracts(_contract(closure)),
      powerEvidence: _Power(<Elv4CurrentEvaluationSnapshot>[
        _pwr06('cctv-delivery', _hash('b'), members, marginW: 5),
      ]),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'CCTV04_PWR06_DELIVERY_SET_MISMATCH',
        ),
      ),
    );
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
      projectId: 'project',
      designRevisionId: 'revision',
      scope: Elv5ScopeRef(
        kind: Elv5ScopeKind.design,
        scopeId: 'revision',
        scenarioKey: 'NONE',
      ),
      processCode: Elv5ProcessCode.cctv04,
      subject: Elv5SubjectRef(kind: 'PSE', id: 'pse-1'),
      expectedPointerGeneration: 0,
    );

Cctv04PseProjectionContract _contract(String closure) =>
    Cctv04PseProjectionContract(
      pseId: 'pse-1',
      scenarioId: 'scenario-1',
      segmentId: 'segment-1',
      expectedClosureFingerprint: closure,
      expectedInputFingerprintByDeliveryId: <String, String>{
        'lan-delivery': _hash('a'),
        'cctv-delivery': _hash('b'),
      },
      cctvLoadIds: const <String>['cctv-load'],
    );

List<Map<String, Object?>> _members() => <Map<String, Object?>>[
      <String, Object?>{
        'originId': 'lan-load',
        'portId': 'port-1',
        'reservedW': _r(18),
      },
      <String, Object?>{
        'originId': 'cctv-load',
        'portId': 'port-2',
        'reservedW': _r(12),
      },
    ];

Elv4CurrentEvaluationSnapshot _pwr06(
  String deliveryId,
  String inputFingerprint,
  List<Map<String, Object?>> members, {
  required int marginW,
}) =>
    Elv4CurrentEvaluationSnapshot(
      nodeKey: PowerNodeKeyV2(
        revisionId: 'revision',
        scenarioId: 'scenario-1',
        scopeKind: PowerEvaluationScopeKind.segment,
        scopeId: 'segment-1',
        processCode: PowerProcessCode.pwr06,
        subjectKind: 'POE_DELIVERY',
        subjectId: deliveryId,
      ),
      evaluationId: 'eval-$deliveryId',
      inputFingerprint: inputFingerprint,
      evidenceSha256: _hash(deliveryId == 'lan-delivery' ? 'c' : 'd'),
      pointerGeneration: 3,
      evidence: <String, Object?>{
        'output': <String, Object?>{
          'deliveryId': deliveryId,
          'groupId': 'pse-1',
          'groupReservedW': _r(30),
          'groupMarginW': _r(marginW),
        },
        'consumedFacts': <Object?>[
          <String, Object?>{
            'key': '["elv4-dep-v1","project","revision","GROUP_MEMBERSHIP","pse-1","POE_MEMBERSHIP"]',
            'valueSchema': 'electra.elv4.poe-membership.v1',
            'canonicalValueJson': canonicalEngineeringJsonV1(members),
            'presence': 'PRESENT',
          },
        ],
      },
    );

final class _Power implements Elv4CurrentEvidenceSource {
  const _Power(this.values);
  final List<Elv4CurrentEvaluationSnapshot> values;

  @override
  Future<List<Elv4CurrentEvaluationSnapshot>> loadCurrent({
    required String projectId,
    required String designRevisionId,
    required PowerProcessCode processCode,
    String? scenarioId,
    PowerEvaluationScopeKind? scopeKind,
    String? scopeId,
    String? subjectKind,
    String? subjectId,
  }) async =>
      values;
}

final class _Contracts implements Cctv04PseProjectionContractSource {
  const _Contracts(this.contract);
  final Cctv04PseProjectionContract contract;

  @override
  Future<Cctv04PseProjectionContractSnapshot?> loadActiveForPse({
    required String projectId,
    required String designRevisionId,
    required String pseId,
  }) async =>
      Cctv04PseProjectionContractSnapshot(
        bindingId: 'cctv04-binding',
        bindingRevision: 1,
        evidenceRef: 'CCTV04:pse-1:${_hash('e')}',
        contentHash: _hash('e'),
        contract: contract,
      );
}

Map<String, Object?> _r(int value) => <String, Object?>{
      'numerator': value.toString(),
      'denominator': '1',
    };

String _hash(String char) => List<String>.filled(64, char).join();
