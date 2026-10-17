import 'package:engineering_core/engineering_core.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../elv_cable_run_repository.dart';
import 'environment_scope_resolver.dart';

final class Elv5AmpacitySectionEvidence {
  const Elv5AmpacitySectionEvidence({
    required this.referenceRow,
    required this.temperatureCorrection,
    required this.groupingCorrection,
    required this.additionalCorrections,
  });

  final Elv5AmpacityReferenceRow referenceRow;
  final Elv5AmpacityTemperatureCorrection temperatureCorrection;
  final Elv5AmpacityGroupingCorrection groupingCorrection;
  final List<Elv5AmpacityAdditionalCorrection> additionalCorrections;
}

/// Resolves exact cable/material/installation/loaded-conductor and correction
/// evidence for one physical route section. Implementations must fail closed;
/// they may not synthesize Cu, 30 C, k=1 or loaded-conductor defaults.
abstract interface class Elv5AmpacitySectionEvidenceSource {
  Future<Elv5AmpacitySectionEvidence?> loadForSection({
    required String projectId,
    required String designRevisionId,
    required CanonicalCableRun cableRun,
    required CableRunTraversal traversal,
    required Elv5ResolvedEnvironment environment,
  });
}

final class Elv5AmpacityRouteResolutionException implements Exception {
  const Elv5AmpacityRouteResolutionException(this.code, this.details);

  final String code;
  final Map<String, Object?> details;

  @override
  String toString() => '$code:$details';
}

final class Elv5AmpacityRouteResolver {
  const Elv5AmpacityRouteResolver({
    required this.cableRuns,
    required this.environments,
    required this.sectionEvidence,
  });

  final ElvCableRunRepository cableRuns;
  final Elv5EnvironmentScopeResolver environments;
  final Elv5AmpacitySectionEvidenceSource sectionEvidence;

  Future<Elv5RouteAmpacityInput> resolve({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  }) async {
    final run = await cableRuns.findRun(projectId, designRevisionId, cableRunId);
    if (run == null || run.state != CanonicalCableRunState.active) {
      throw Elv5AmpacityRouteResolutionException(
        'ELV5_AMPACITY_ACTIVE_CABLE_RUN_REQUIRED',
        <String, Object?>{'cableRunId': cableRunId},
      );
    }

    final traversals = await cableRuns.loadTraversals(cableRunId);
    if (traversals.isEmpty) {
      throw Elv5AmpacityRouteResolutionException(
        'ELV5_AMPACITY_ROUTE_TRAVERSALS_REQUIRED',
        <String, Object?>{'cableRunId': cableRunId},
      );
    }
    final ordered = [...traversals]..sort((a, b) => a.sequence.compareTo(b.sequence));

    final sections = <Elv5RouteAmpacitySectionInput>[];
    for (final traversal in ordered) {
      final environment = await environments.resolveForRouteSection(
        projectId: projectId,
        designRevisionId: designRevisionId,
        routeSectionId: traversal.routeSegmentId,
      );
      if (environment == null) {
        throw Elv5AmpacityRouteResolutionException(
          'ELV5_AMPACITY_ENVIRONMENT_PROFILE_REQUIRED',
          <String, Object?>{
            'cableRunId': cableRunId,
            'routeSectionId': traversal.routeSegmentId,
          },
        );
      }

      final evidence = await sectionEvidence.loadForSection(
        projectId: projectId,
        designRevisionId: designRevisionId,
        cableRun: run,
        traversal: traversal,
        environment: environment,
      );
      if (evidence == null) {
        throw Elv5AmpacityRouteResolutionException(
          'ELV5_AMPACITY_SECTION_EVIDENCE_REQUIRED',
          <String, Object?>{
            'cableRunId': cableRunId,
            'routeSectionId': traversal.routeSegmentId,
          },
        );
      }

      if (evidence.temperatureCorrection.actualAmbientTemperatureC !=
          environment.binding.profile.temperatureC.maximum) {
        throw Elv5AmpacityRouteResolutionException(
          'ELV5_AMPACITY_TEMPERATURE_EVIDENCE_SCOPE_MISMATCH',
          <String, Object?>{
            'routeSectionId': traversal.routeSegmentId,
            'profileMaximumC':
                environment.binding.profile.temperatureC.maximum.toMap(),
            'correctionTemperatureC':
                evidence.temperatureCorrection.actualAmbientTemperatureC.toMap(),
          },
        );
      }

      sections.add(
        Elv5RouteAmpacitySectionInput(
          sectionId: traversal.routeSegmentId,
          environmentBinding: environment.toCoreBinding(),
          ampacityInput: Elv5AmpacityInput(
            cableOrSectionId: traversal.routeSegmentId,
            referenceRow: evidence.referenceRow,
            temperatureCorrection: evidence.temperatureCorrection,
            groupingCorrection: evidence.groupingCorrection,
            additionalCorrections: evidence.additionalCorrections,
          ),
        ),
      );
    }

    return Elv5RouteAmpacityInput(
      cableRunId: cableRunId,
      orderedSections: sections,
    );
  }
}
