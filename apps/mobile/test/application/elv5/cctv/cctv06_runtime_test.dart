import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv06_link_contract.dart';
import 'package:electra_mobile/application/elv5/cctv/cctv06_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/elv3_realized_link_facts.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_persistence.dart';
import 'package:electra_mobile/application/elv5/power/elv4_current_evidence_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'CCTV06 uses exact ELV3 section lengths and passes inclusive 30 m boundary',
    () async {
      final payload = <String, Object?>{
        'linkId': 'link-1',
        'orderedSections': <Object?>[
          <String, Object?>{
            'ordinal': 0,
            'realizedSectionId': 's1',
            'classification': 'PERMANENT',
          },
          <String, Object?>{
            'ordinal': 1,
            'realizedSectionId': 's2',
            'classification': 'PATCH',
          },
        ],
        'policyBindingId': 'policy-1',
      };
      final fingerprint = const Elv5CanonicalJsonV1().sha256(payload);
      final resolver = Cctv06PersistedInputResolver(
        lanStore: _Lan(payload),
        elv3Facts: const _Lengths(),
        contractSource: _Contract(_contract(fingerprint)),
        powerEvidence: const _Power(),
      );
      final candidate = await buildCctv06Executor().execute(
        await resolver.capture(_request()),
      );
      expect(candidate.assessment, Elv5Assessment.pass);
      final length = Map<String, Object?>.from(
        candidate.output['realizedLengthM']! as Map,
      );
      expect(length['lower'], _r(30));
      expect(length['upper'], _r(30));
      expect(candidate.output['lengthMarginM'], _r(0));
      expect(candidate.output['powerStatus'], 'notApplicable');
    },
  );
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.cctv06,
  subject: Elv5SubjectRef(kind: 'LINK', id: 'link-1'),
  expectedPointerGeneration: 0,
);
Cctv06LinkContract _contract(String fingerprint) => Cctv06LinkContract(
  linkId: 'link-1',
  expectedCompositionFingerprint: fingerprint,
  allowedMediaCodes: const ['COPPER'],
  allowedInterfaceKinds: const ['ETHERNET'],
  allowedCategoryTokens: const ['CAT6'],
  shieldingRequired: true,
  maximumLengthM: Elv5Rational.integer(30),
  sections: <Cctv06SectionEvidenceContract>[
    Cctv06SectionEvidenceContract(
      sectionId: 's1',
      mediumCode: 'COPPER',
      interfaceKind: 'ETHERNET',
      categoryToken: 'CAT6',
      shieldContinuityKnown: true,
      shieldContinuity: true,
      evidenceRef: 'def:s1',
      evidenceContentHash: _h('a'),
    ),
    Cctv06SectionEvidenceContract(
      sectionId: 's2',
      mediumCode: 'COPPER',
      interfaceKind: 'ETHERNET',
      categoryToken: 'CAT6',
      shieldContinuityKnown: true,
      shieldContinuity: true,
      evidenceRef: 'def:s2',
      evidenceContentHash: _h('b'),
    ),
  ],
  powered: false,
);

final class _Lan implements Elv5LanFactStore {
  const _Lan(this.payload);
  final Map<String, Object?> payload;
  @override
  Future<Elv5LanAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async => Elv5LanAggregateSnapshot(
    aggregateKind: 'LAN_LINK_COMPOSITION',
    aggregateId: 'link-bind',
    subjectId: 'link-1',
    revision: 4,
    payload: payload,
  );
}

final class _Lengths implements Elv3RealizedLinkFactSource {
  const _Lengths();
  @override
  Future<Elv3RealizedSectionLengthFact> requireSectionLength({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
  }) async {
    final meters = realizedSectionId == 's1' ? 10 : 20;
    final length = Length(Elv5Rational.integer(meters));
    return Elv3RealizedSectionLengthFact(
      realizedSectionId: realizedSectionId,
      routeSegmentId: 'route-$realizedSectionId',
      cableRunId: 'run-1',
      cableRunRevision: 2,
      installedLength: Lan01LengthInterval(lower: length, upper: length),
      includesRunReserve: true,
      includesTerminationAllowance: true,
      sourceFingerprint: _h(realizedSectionId == 's1' ? 'c' : 'd'),
    );
  }
}

final class _Contract implements Cctv06LinkContractSource {
  const _Contract(this.value);
  final Cctv06LinkContract value;
  @override
  Future<Cctv06LinkContractSnapshot?> loadActiveForLink({
    required String projectId,
    required String designRevisionId,
    required String linkId,
  }) async => Cctv06LinkContractSnapshot(
    bindingId: 'c6',
    bindingRevision: 1,
    evidenceRef: 'CCTV06:link-1:${_h('e')}',
    contentHash: _h('e'),
    contract: value,
  );
}

final class _Power implements Elv4CurrentEvidenceSource {
  const _Power();
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
  }) async => const <Elv4CurrentEvaluationSnapshot>[];
}

Map<String, Object?> _r(int n) => <String, Object?>{
  'numerator': '$n',
  'denominator': '1',
};
String _h(String c) => List<String>.filled(64, c).join();
