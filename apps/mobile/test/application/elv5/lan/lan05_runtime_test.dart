import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/elv3_realized_link_facts.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_persistence.dart';
import 'package:electra_mobile/application/elv5/lan/lan05_optical_section_evidence.dart';
import 'package:electra_mobile/application/elv5/lan/lan05_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'uses persisted optical facts, exact ELV3 length, and attenuation evidence',
    () async {
      final captured = await Lan05PersistedInputResolver(
        lanStore: _LanStore(),
        elv3Facts: _Elv3Facts(),
        opticalEvidence: _OpticalEvidence(),
      ).capture(_request());
      final result = const Lan05OpticalBudgetKernel().evaluate(captured.value);

      expect(
        result.aToB.physicalLoss.lower.value,
        Elv5Rational.parseDecimal('2.5'),
      );
      expect(
        result.aToB.sensitivity.margin!.value,
        Elv5Rational.parseDecimal('9.5'),
      );
      expect(
        result.aToB.overload.margin!.value,
        Elv5Rational.parseDecimal('3.5'),
      );
      expect(result.passes, isTrue);
    },
  );

  test('missing section attenuation is durable blocked evidence', () async {
    final resolver = Lan05PersistedInputResolver(
      lanStore: _LanStore(),
      elv3Facts: _Elv3Facts(),
      opticalEvidence: _OpticalEvidence(missing: true),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (value) => value.reasonCode,
          'reasonCode',
          'LAN05_SECTION_ATTENUATION_EVIDENCE_MISSING',
        ),
      ),
    );
  });
}

Elv5CalculationRequest _request() => Elv5CalculationRequest(
  projectId: 'p',
  designRevisionId: 'd',
  scope: Elv5ScopeRef(
    kind: Elv5ScopeKind.design,
    scopeId: 'd',
    scenarioKey: 'NONE',
  ),
  processCode: Elv5ProcessCode.lan05,
  subject: Elv5SubjectRef(kind: 'LINK', id: 'link-1'),
  expectedPointerGeneration: 0,
);

final class _LanStore implements Elv5LanMutationStore {
  @override
  Future<Elv5LanAggregateSnapshot?> load({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
  }) async {
    if (operation == 'REPLACE_LINK_COMPOSITION') {
      return Elv5LanAggregateSnapshot(
        aggregateKind: 'LAN_LINK_COMPOSITION',
        aggregateId: 'composition-1',
        subjectId: 'link-1',
        revision: 2,
        payload: <String, Object?>{
          'linkId': 'link-1',
          'orderedSections': <Object?>[
            <String, Object?>{
              'ordinal': 0,
              'realizedSectionId': 'section-1',
              'classification': 'PERMANENT',
            },
          ],
          'policyBindingId': 'policy-1',
        },
      );
    }
    if (operation == 'REPLACE_OPTICAL_LINK_ASSIGNMENTS') {
      return Elv5LanAggregateSnapshot(
        aggregateKind: 'LAN_OPTICAL_LINK',
        aggregateId: 'optical-1',
        subjectId: 'link-1',
        revision: 3,
        payload: <String, Object?>{
          'linkId': 'link-1',
          'forwardOptics': _optics(),
          'reverseOptics': _optics(),
          'connectorEvents': <Object?>[],
          'spliceEvents': <Object?>[],
        },
      );
    }
    return null;
  }

  Map<String, Object?> _optics() => <String, Object?>{
    'txPortId': 'tx',
    'rxPortId': 'rx',
    'wavelengthNm': '1310',
    'txMinDbm': '-3',
    'txMaxDbm': '-2',
    'receiverSensitivityDbm': '-15',
    'receiverOverloadDbm': '-1',
    'requiredSensitivityMarginDb': '0',
  };

  @override
  Future<void> replace({
    required String projectId,
    required String designRevisionId,
    required String operation,
    required String subjectId,
    required String bindingId,
    required int? expectedRootRevision,
    required Map<String, Object?> payload,
    required DateTime updatedAtUtc,
  }) => throw UnimplementedError();
}

final class _Elv3Facts implements Elv3RealizedLinkFactSource {
  @override
  Future<Elv3RealizedSectionLengthFact> requireSectionLength({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
  }) async => Elv3RealizedSectionLengthFact(
    realizedSectionId: realizedSectionId,
    routeSegmentId: 'route-1',
    cableRunId: 'run-1',
    cableRunRevision: 1,
    installedLength: Lan01LengthInterval.exact(
      Length(Elv5Rational.integer(1000)),
    ),
    includesRunReserve: true,
    includesTerminationAllowance: true,
    sourceFingerprint: List.filled(64, 'a').join(),
  );
}

final class _OpticalEvidence implements Lan05OpticalSectionEvidenceSource {
  _OpticalEvidence({this.missing = false});
  final bool missing;

  @override
  Future<Lan05OpticalSectionEvidence?> findAttenuation({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
    required Elv5Rational wavelengthNm,
  }) async =>
      missing
          ? null
          : Lan05OpticalSectionEvidence(
            realizedSectionId: realizedSectionId,
            wavelengthNm: wavelengthNm,
            attenuationDbPerKm: Lan05LossInterval.exact(
              LossDb(Elv5Rational.parseDecimal('2.5')),
            ),
            evidenceFingerprint: List.filled(64, 'b').join(),
            evidenceRef: 'catalog:fiber-fixture:v1',
          );
}
