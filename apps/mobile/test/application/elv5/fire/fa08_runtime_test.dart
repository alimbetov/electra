import 'package:electra_mobile/application/elv5/calculation/elv5_blocked_capture.dart';
import 'package:electra_mobile/application/elv5/calculation/elv5_calculation_runtime.dart';
import 'package:electra_mobile/application/elv5/environment/ampacity_route_resolver.dart';
import 'package:electra_mobile/application/elv5/environment/environment_profile_persistence.dart';
import 'package:electra_mobile/application/elv5/environment/environment_scope_resolver.dart';
import 'package:electra_mobile/application/elv5/fire/fa08_policy_contract.dart';
import 'package:electra_mobile/application/elv5/fire/fa08_route_facts.dart';
import 'package:electra_mobile/application/elv5/fire/fa08_runtime.dart';
import 'package:electra_mobile/application/elv_cable_run_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FA-08 passes exact Iz/environment policy but leaves compliance not assessed', () async {
    final env = _resolvedEnvironment();
    final resolver = Fa08PersistedInputResolver(
      policySource: _PolicySource(),
      ampacityResolver: Elv5AmpacityRouteResolver(
        cableRuns: _Runs(),
        environments: _Environments(env),
        sectionEvidence: _AmpacityEvidence(env),
      ),
      routeCableFacts: _CableFacts(),
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );

    final captured = await resolver.capture(_request());
    final candidate = await buildFa08Executor().execute(captured);

    expect(candidate.assessment, Elv5Assessment.pass);
    expect(candidate.output['technicalPolicyMatch'], 'pass');
    expect(candidate.output['verifiedCompliance'], 'notAssessed');
    final results = <Map<String, Object?>>[
      for (final row in candidate.output['policyResults']! as List)
        Map<String, Object?>.from(row as Map),
    ];
    expect(results, hasLength(3));
    expect(results.every((row) => row['status'] == 'pass'), isTrue);

    final byCode = <String, Map<String, Object?>>{
      for (final row in results) row['requirementCode']! as String: row,
    };
    expect(
      Map<String, Object?>.from(byCode['MIN_IZ']!['numericMargin']! as Map),
      <String, Object?>{'numerator': '4', 'denominator': '1'},
    );
    expect(
      Map<String, Object?>.from(byCode['MAX_TEMP']!['numericMargin']! as Map),
      <String, Object?>{'numerator': '5', 'denominator': '1'},
    );
    expect(
      Map<String, Object?>.from(byCode['MAX_RH']!['numericMargin']! as Map),
      <String, Object?>{'numerator': '10', 'denominator': '1'},
    );
  });

  test('FA-08 missing explicit environment remains durable capture BLOCKED', () async {
    final resolver = Fa08PersistedInputResolver(
      policySource: _PolicySource(),
      ampacityResolver: Elv5AmpacityRouteResolver(
        cableRuns: _Runs(),
        environments: const _Environments(null),
        sectionEvidence: const _NoAmpacityEvidence(),
      ),
      routeCableFacts: _CableFacts(),
    );

    await expectLater(
      resolver.capture(_request()),
      throwsA(
        isA<Elv5CaptureBlockedException>().having(
          (e) => e.reasonCode,
          'reasonCode',
          'ELV5_AMPACITY_ENVIRONMENT_PROFILE_REQUIRED',
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
      processCode: Elv5ProcessCode.fa08,
      subject: Elv5SubjectRef(kind: 'CABLE_RUN', id: 'run-1'),
      expectedPointerGeneration: 0,
    );

Elv5ResolvedEnvironment _resolvedEnvironment() {
  final profile = Elv5EnvironmentProfile(
    profileId: 'HOT_ROOM',
    editionId: 'env-v1',
    profileCode: 'HOT_ROOM',
    temperatureC: Elv5RationalRange(
      minimum: Elv5Rational.parseDecimal('10'),
      maximum: Elv5Rational.parseDecimal('45'),
    ),
    relativeHumidityPercent: Elv5RationalRange(
      minimum: Elv5Rational.parseDecimal('20'),
      maximum: Elv5Rational.parseDecimal('80'),
    ),
    condensationRisk: Elv5CondensationRisk.none,
    exposure: Elv5EnvironmentExposure.indoor,
    evidenceRef: 'ENV:HOT_ROOM:env-v1',
    evidenceContentHash: _hash('a'),
  );
  return Elv5ResolvedEnvironment(
    routeSectionId: 'section-1',
    roomId: 'room-1',
    binding: Elv5EnvironmentProfileSnapshot(
      bindingId: 'env-binding',
      bindingRevision: 1,
      scopeKind: 'ROOM',
      scopeId: 'room-1',
      evidenceRef: profile.evidenceRef,
      contentHash: _hash('e'),
      profile: profile,
    ),
    usedSectionOverride: false,
  );
}

final class _PolicySource implements Fa08CablePolicyContractSource {
  @override
  Future<Fa08CablePolicyContractSnapshot?> loadActiveForCableRun({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  }) async => Fa08CablePolicyContractSnapshot(
        bindingId: 'fa08-policy',
        bindingRevision: 1,
        evidenceRef: 'FA08:run-1:${_hash('f')}',
        contentHash: _hash('f'),
        contract: Fa08CablePolicyContract(
          cableRunId: 'run-1',
          policyId: 'policy-1',
          requirements: <Fa08Requirement>[
            Fa08Requirement.numeric(
              code: 'MIN_IZ',
              kind: Fa08RequirementKind.numericMinimum,
              propertyCode: Fa08RouteSection.ampacityIzPropertyCode,
              unitCode: 'A',
              threshold: Elv5Rational.parseDecimal('20'),
            ),
            Fa08Requirement.numeric(
              code: 'MAX_TEMP',
              kind: Fa08RequirementKind.numericMaximum,
              propertyCode: Fa08PersistedInputResolver.environmentTempMaxCode,
              unitCode: 'C',
              threshold: Elv5Rational.parseDecimal('50'),
            ),
            Fa08Requirement.numeric(
              code: 'MAX_RH',
              kind: Fa08RequirementKind.numericMaximum,
              propertyCode: Fa08PersistedInputResolver.environmentRhMaxCode,
              unitCode: 'PCT',
              threshold: Elv5Rational.parseDecimal('90'),
            ),
          ],
        ),
      );
}

final class _CableFacts implements Fa08RouteCableFactSource {
  @override
  Future<List<Fa08RouteCableFact>> loadForCableRun({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  }) async => const <Fa08RouteCableFact>[
        Fa08RouteCableFact(
          sectionId: 'section-1',
          cableId: 'cable-1',
          cableEditionId: 'catalog:v1:CABLE-A:hash',
          cableClass: 'TEST_CLASS_A',
          numericFacts: <Fa08NumericFact>[],
        ),
      ];
}

final class _Runs implements ElvCableRunRepository {
  @override
  Future<CanonicalCableRun?> findRun(
    String projectId,
    String designRevisionId,
    String cableRunId,
  ) async => CanonicalCableRun(
        id: 'run-1',
        projectId: 'p',
        cableId: 'cable-1',
        designRevisionId: 'd',
        state: CanonicalCableRunState.active,
        reservePercent: 0,
        terminationAllowanceMm: 0,
        revision: 1,
      );

  @override
  Future<List<CableRunTraversal>> loadTraversals(String cableRunId) async =>
      const <CableRunTraversal>[
        CableRunTraversal(
          id: 't1',
          cableRunId: 'run-1',
          sequence: 1,
          routeSegmentId: 'section-1',
          direction: CableTraversalDirection.forward,
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Environments implements Elv5EnvironmentScopeResolver {
  const _Environments(this.value);
  final Elv5ResolvedEnvironment? value;
  @override
  Future<Elv5ResolvedEnvironment?> resolveForRouteSection({
    required String projectId,
    required String designRevisionId,
    required String routeSectionId,
  }) async => value;
}

final class _AmpacityEvidence implements Elv5AmpacitySectionEvidenceSource {
  const _AmpacityEvidence(this.environment);
  final Elv5ResolvedEnvironment environment;
  @override
  Future<Elv5AmpacitySectionEvidence?> loadForSection({
    required String projectId,
    required String designRevisionId,
    required CanonicalCableRun cableRun,
    required CableRunTraversal traversal,
    required Elv5ResolvedEnvironment environment,
  }) async => Elv5AmpacitySectionEvidence(
        referenceRow: Elv5AmpacityReferenceRow(
          conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
          conductorMaterialCode: 'CU',
          insulationSystemCode: 'PVC70',
          referenceAmbientTemperatureC: Elv5Rational.parseDecimal('30'),
          installationMethodCode: 'B2',
          loadedConductors: 3,
          baseAllowableCurrentA: Elv5Rational.parseDecimal('30'),
          evidenceRef: 'AMPACITY:ROW',
          evidenceContentHash: _hash('b'),
        ),
        temperatureCorrection: Elv5AmpacityTemperatureCorrection(
          actualAmbientTemperatureC:
              this.environment.binding.profile.temperatureC.maximum,
          factor: Elv5Rational.parseDecimal('0.8'),
          evidenceRef: 'TEMP:45',
          evidenceContentHash: _hash('c'),
        ),
        groupingCorrection: Elv5AmpacityGroupingCorrection(
          groupedCableOrCircuitCount: 1,
          arrangementCode: 'SINGLE',
          factor: Elv5Rational.one,
          evidenceRef: 'GROUP:1',
          evidenceContentHash: _hash('d'),
        ),
        additionalCorrections: const <Elv5AmpacityAdditionalCorrection>[],
      );
}

final class _NoAmpacityEvidence implements Elv5AmpacitySectionEvidenceSource {
  const _NoAmpacityEvidence();
  @override
  Future<Elv5AmpacitySectionEvidence?> loadForSection({
    required String projectId,
    required String designRevisionId,
    required CanonicalCableRun cableRun,
    required CableRunTraversal traversal,
    required Elv5ResolvedEnvironment environment,
  }) async => null;
}

String _hash(String char) => List<String>.filled(64, char).join();
