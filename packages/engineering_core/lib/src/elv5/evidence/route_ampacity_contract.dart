import 'ampacity_contract.dart';
import 'environment_profile.dart';
import '../numeric/rational.dart';

final class Elv5RouteAmpacitySectionInput {
  Elv5RouteAmpacitySectionInput({
    required String sectionId,
    required this.environmentBinding,
    required this.ampacityInput,
  }) : sectionId = _text(sectionId, 'sectionId') {
    if (ampacityInput.cableOrSectionId != this.sectionId) {
      throw ArgumentError(
        'Ampacity input cableOrSectionId must equal route sectionId.',
      );
    }
    if (ampacityInput.temperatureCorrection.actualAmbientTemperatureC !=
        environmentBinding.profile.temperatureC.maximum) {
      throw ArgumentError(
        'Ampacity temperature must use the conservative profile maximum.',
      );
    }
  }

  final String sectionId;
  final Elv5EnvironmentScopeBinding environmentBinding;
  final Elv5AmpacityInput ampacityInput;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'sectionId': sectionId,
        'environmentBinding': environmentBinding.toCanonicalValue(),
        'ampacityInput': ampacityInput.toCanonicalValue(),
      };
}

final class Elv5RouteAmpacityInput {
  Elv5RouteAmpacityInput({
    required String cableRunId,
    required Iterable<Elv5RouteAmpacitySectionInput> orderedSections,
  })  : cableRunId = _text(cableRunId, 'cableRunId'),
        orderedSections = List.unmodifiable(orderedSections) {
    if (this.orderedSections.isEmpty) {
      throw ArgumentError('Ampacity route must contain at least one section.');
    }
    final seen = <String>{};
    for (final section in this.orderedSections) {
      if (!seen.add(section.sectionId)) {
        throw ArgumentError('Duplicate ampacity route section: ${section.sectionId}');
      }
    }
  }

  final String cableRunId;
  final List<Elv5RouteAmpacitySectionInput> orderedSections;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': 'electra.elv5-route-ampacity-input.v1',
        'cableRunId': cableRunId,
        'orderedSections': <Object?>[
          for (final section in orderedSections) section.toCanonicalValue(),
        ],
      };
}

final class Elv5RouteAmpacitySectionResult {
  const Elv5RouteAmpacitySectionResult({
    required this.sectionId,
    required this.profileId,
    required this.profileEditionId,
    required this.maximumAmbientTemperatureC,
    required this.allowableCurrentIzA,
  });

  final String sectionId;
  final String profileId;
  final String profileEditionId;
  final Elv5Rational maximumAmbientTemperatureC;
  final Elv5Rational allowableCurrentIzA;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'sectionId': sectionId,
        'profileId': profileId,
        'profileEditionId': profileEditionId,
        'maximumAmbientTemperatureC': maximumAmbientTemperatureC.toMap(),
        'allowableCurrentIzA': allowableCurrentIzA.toMap(),
      };
}

final class Elv5RouteAmpacityResult {
  const Elv5RouteAmpacityResult({
    required this.sections,
    required this.governingSectionId,
    required this.allowableCurrentIzA,
  });

  final List<Elv5RouteAmpacitySectionResult> sections;
  final String governingSectionId;
  final Elv5Rational allowableCurrentIzA;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': 'electra.elv5-route-ampacity-result.v1',
        'sections': <Object?>[
          for (final section in sections) section.toCanonicalValue(),
        ],
        'governingSectionId': governingSectionId,
        'allowableCurrentIzA': allowableCurrentIzA.toMap(),
      };
}

final class Elv5RouteAmpacityKernel {
  const Elv5RouteAmpacityKernel();

  Elv5RouteAmpacityResult evaluate(Elv5RouteAmpacityInput input) {
    const kernel = Elv5AmpacityKernel();
    final results = <Elv5RouteAmpacitySectionResult>[];

    for (final section in input.orderedSections) {
      final ampacity = kernel.evaluate(section.ampacityInput);
      results.add(
        Elv5RouteAmpacitySectionResult(
          sectionId: section.sectionId,
          profileId: section.environmentBinding.profile.profileId,
          profileEditionId: section.environmentBinding.profile.editionId,
          maximumAmbientTemperatureC:
              section.environmentBinding.profile.temperatureC.maximum,
          allowableCurrentIzA: ampacity.allowableCurrentIzA,
        ),
      );
    }

    results.sort((a, b) {
      final byIz = a.allowableCurrentIzA.compareTo(b.allowableCurrentIzA);
      return byIz != 0 ? byIz : a.sectionId.compareTo(b.sectionId);
    });
    final governing = results.first;

    return Elv5RouteAmpacityResult(
      sections: List.unmodifiable(results),
      governingSectionId: governing.sectionId,
      allowableCurrentIzA: governing.allowableCurrentIzA,
    );
  }
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
