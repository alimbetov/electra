import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/lan/elv3_realized_link_facts.dart';
import 'package:electra_mobile/application/elv5/lan/elv5_lan_persistence.dart';
import 'package:electra_mobile/application/elv5/lan/lan01_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captures ELV5 composition with exact ELV3 realized lengths', () async {
    final resolver = Lan01PersistedInputResolver(
      lanStore: _LanStore(),
      elv3Facts: _Elv3Facts(),
    );
    final captured = await resolver.capture(_request());
    final result = const Lan01PathLengthKernel().evaluate(captured.value);

    expect(captured.captureRevision, 4);
    expect(captured.dependencies, hasLength(4));
    expect(result.permanent.length.lower.value, Elv5Rational.integer(28));
    expect(result.channel.length.lower.value, Elv5Rational.integer(30));
    expect(result.permanent.passes, isNull);
    expect(result.channel.passes, isNull);
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
  processCode: Elv5ProcessCode.lan01,
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
  }) async => Elv5LanAggregateSnapshot(
    aggregateKind: 'LAN_LINK_COMPOSITION',
    aggregateId: 'ELV5:LAN_LINK_COMPOSITION:link-1',
    subjectId: 'link-1',
    revision: 4,
    payload: <String, Object?>{
      'linkId': 'link-1',
      'orderedSections': <Object?>[
        <String, Object?>{
          'ordinal': 0,
          'realizedSectionId': 't1',
          'classification': 'PERMANENT',
        },
        <String, Object?>{
          'ordinal': 1,
          'realizedSectionId': 't2',
          'classification': 'PATCH',
        },
      ],
      'policyBindingId': 'policy-1',
    },
  );

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
  }) async {
    final meters = realizedSectionId == 't1' ? 28 : 2;
    return Elv3RealizedSectionLengthFact(
      realizedSectionId: realizedSectionId,
      routeSegmentId: 'segment-$realizedSectionId',
      cableRunId: 'run-1',
      cableRunRevision: 3,
      installedLength: Lan01LengthInterval.exact(
        Length(Elv5Rational.integer(meters)),
      ),
      includesRunReserve: true,
      includesTerminationAllowance: true,
      sourceFingerprint:
          List.filled(64, realizedSectionId == 't1' ? 'a' : 'b').join(),
    );
  }
}
