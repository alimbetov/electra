import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../lib/application/elv5/environment/ampacity_route_resolver.dart';
import '../../../../lib/application/elv5/environment/environment_profile_persistence.dart';
import '../../../../lib/application/elv5/environment/environment_scope_resolver.dart';
import '../../../../lib/application/elv_cable_run_repository.dart';

void main() {
  String hash(String ch) => List<String>.filled(64, ch).join();

  Elv5EnvironmentProfile environment(String id, String maxC) =>
      Elv5EnvironmentProfile(
        profileId: id,
        editionId: 'v1',
        profileCode: id,
        temperatureC: Elv5RationalRange(
          minimum: Elv5Rational.parseDecimal('-20'),
          maximum: Elv5Rational.parseDecimal(maxC),
        ),
        relativeHumidityPercent: Elv5RationalRange(
          minimum: Elv5Rational.parseDecimal('20'),
          maximum: Elv5Rational.parseDecimal('80'),
        ),
        condensationRisk: Elv5CondensationRisk.none,
        exposure: Elv5EnvironmentExposure.indoor,
        evidenceRef: 'ENV:$id:v1',
        evidenceContentHash: hash('a'),
      );

  Elv5ResolvedEnvironment resolved(
    String sectionId,
    Elv5EnvironmentProfile profile,
  ) => Elv5ResolvedEnvironment(
    routeSectionId: sectionId,
    roomId: 'room-1',
    binding: Elv5EnvironmentProfileSnapshot(
      bindingId: 'binding-$sectionId',
      bindingRevision: 1,
      scopeKind: 'ROUTE_SECTION',
      scopeId: sectionId,
      evidenceRef: profile.evidenceRef,
      contentHash: hash('e'),
      profile: profile,
    ),
    usedSectionOverride: true,
  );

  Elv5AmpacitySectionEvidence evidence(
    String sectionId,
    Elv5ResolvedEnvironment env,
  ) => Elv5AmpacitySectionEvidence(
    referenceRow: Elv5AmpacityReferenceRow(
      conductorCrossSectionMm2: Elv5Rational.parseDecimal('2.5'),
      conductorMaterialCode: 'CU',
      insulationSystemCode: 'PVC70',
      referenceAmbientTemperatureC: Elv5Rational.parseDecimal('30'),
      installationMethodCode: 'B2',
      loadedConductors: 3,
      baseAllowableCurrentA: Elv5Rational.parseDecimal('30'),
      evidenceRef: 'ROW:$sectionId',
      evidenceContentHash: hash('b'),
    ),
    temperatureCorrection: Elv5AmpacityTemperatureCorrection(
      actualAmbientTemperatureC: env.binding.profile.temperatureC.maximum,
      factor: sectionId == 'section-2'
          ? Elv5Rational.parseDecimal('0.8')
          : Elv5Rational.one,
      evidenceRef: 'TEMP:$sectionId',
      evidenceContentHash: hash('c'),
    ),
    groupingCorrection: Elv5AmpacityGroupingCorrection(
      groupedCableOrCircuitCount: 1,
      arrangementCode: 'SINGLE',
      factor: Elv5Rational.one,
      evidenceRef: 'GROUP:$sectionId',
      evidenceContentHash: hash('d'),
    ),
    additionalCorrections: const <Elv5AmpacityAdditionalCorrection>[],
  );

  test('resolves every traversal and preserves route order', () async {
    final run = CanonicalCableRun(
      id: 'run-1',
      projectId: 'project-1',
      cableId: 'cable-1',
      designRevisionId: 'revision-1',
      state: CanonicalCableRunState.active,
      reservePercent: 0,
      terminationAllowanceMm: 0,
      revision: 1,
    );
    final repo = _FakeCableRuns(run, const <CableRunTraversal>[
      CableRunTraversal(
        id: 't2',
        cableRunId: 'run-1',
        sequence: 2,
        routeSegmentId: 'section-2',
        direction: CableTraversalDirection.forward,
      ),
      CableRunTraversal(
        id: 't1',
        cableRunId: 'run-1',
        sequence: 1,
        routeSegmentId: 'section-1',
        direction: CableTraversalDirection.forward,
      ),
    ]);
    final env1 = resolved('section-1', environment('OFFICE', '30'));
    final env2 = resolved('section-2', environment('SHAFT', '45'));
    final resolver = Elv5AmpacityRouteResolver(
      cableRuns: repo,
      environments: _FakeEnvironmentResolver(<String, Elv5ResolvedEnvironment>{
        'section-1': env1,
        'section-2': env2,
      }),
      sectionEvidence: _FakeSectionEvidence(
        <String, Elv5AmpacitySectionEvidence>{
          'section-1': evidence('section-1', env1),
          'section-2': evidence('section-2', env2),
        },
      ),
    );

    final input = await resolver.resolve(
      projectId: 'project-1',
      designRevisionId: 'revision-1',
      cableRunId: 'run-1',
    );
    final result = const Elv5RouteAmpacityKernel().evaluate(input);

    expect(input.orderedSections.map((e) => e.sectionId), <String>[
      'section-1',
      'section-2',
    ]);
    expect(result.governingSectionId, 'section-2');
    expect(result.allowableCurrentIzA, Elv5Rational.parseDecimal('24'));
  });

  test('missing explicit environment profile fails closed', () async {
    final resolver = Elv5AmpacityRouteResolver(
      cableRuns: _FakeCableRuns(
        CanonicalCableRun(
          id: 'run-1',
          projectId: 'project-1',
          cableId: 'cable-1',
          designRevisionId: 'revision-1',
          state: CanonicalCableRunState.active,
          reservePercent: 0,
          terminationAllowanceMm: 0,
          revision: 1,
        ),
        const <CableRunTraversal>[
          CableRunTraversal(
            id: 't1',
            cableRunId: 'run-1',
            sequence: 1,
            routeSegmentId: 'section-1',
            direction: CableTraversalDirection.forward,
          ),
        ],
      ),
      environments: _FakeEnvironmentResolver(
        const <String, Elv5ResolvedEnvironment>{},
      ),
      sectionEvidence: _FakeSectionEvidence(
        const <String, Elv5AmpacitySectionEvidence>{},
      ),
    );

    await expectLater(
      resolver.resolve(
        projectId: 'project-1',
        designRevisionId: 'revision-1',
        cableRunId: 'run-1',
      ),
      throwsA(
        isA<Elv5AmpacityRouteResolutionException>().having(
          (e) => e.code,
          'code',
          'ELV5_AMPACITY_ENVIRONMENT_PROFILE_REQUIRED',
        ),
      ),
    );
  });
}

final class _FakeCableRuns implements ElvCableRunRepository {
  _FakeCableRuns(this.run, this.traversals);
  final CanonicalCableRun run;
  final List<CableRunTraversal> traversals;

  @override
  Future<CanonicalCableRun?> findRun(
    String projectId,
    String designRevisionId,
    String cableRunId,
  ) async => cableRunId == run.id ? run : null;

  @override
  Future<List<CableRunTraversal>> loadTraversals(String cableRunId) async =>
      traversals;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeEnvironmentResolver implements Elv5EnvironmentScopeResolver {
  const _FakeEnvironmentResolver(this.values);
  final Map<String, Elv5ResolvedEnvironment> values;

  @override
  Future<Elv5ResolvedEnvironment?> resolveForRouteSection({
    required String projectId,
    required String designRevisionId,
    required String routeSectionId,
  }) async => values[routeSectionId];
}

final class _FakeSectionEvidence implements Elv5AmpacitySectionEvidenceSource {
  const _FakeSectionEvidence(this.values);
  final Map<String, Elv5AmpacitySectionEvidence> values;

  @override
  Future<Elv5AmpacitySectionEvidence?> loadForSection({
    required String projectId,
    required String designRevisionId,
    required CanonicalCableRun cableRun,
    required CableRunTraversal traversal,
    required Elv5ResolvedEnvironment environment,
  }) async => values[traversal.routeSegmentId];
}
