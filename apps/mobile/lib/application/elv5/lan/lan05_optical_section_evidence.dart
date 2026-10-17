import 'package:engineering_core/engineering_core_elv5.dart';

final class Lan05OpticalSectionEvidence {
  const Lan05OpticalSectionEvidence({
    required this.realizedSectionId,
    required this.wavelengthNm,
    required this.attenuationDbPerKm,
    required this.evidenceFingerprint,
    required this.evidenceRef,
  });

  final String realizedSectionId;
  final Elv5Rational wavelengthNm;
  final Lan05LossInterval attenuationDbPerKm;
  final String evidenceFingerprint;
  final String evidenceRef;
}

final class Lan05OpticalAttenuationProfile {
  Lan05OpticalAttenuationProfile({
    required this.wavelengthNm,
    required this.attenuationDbPerKm,
    required String evidenceRef,
  }) : evidenceRef = _requiredText(evidenceRef, 'evidenceRef') {
    if (wavelengthNm <= Elv5Rational.zero) {
      throw ArgumentError('LAN05 wavelength must be positive.');
    }
    if (attenuationDbPerKm.lower.value < Elv5Rational.zero ||
        attenuationDbPerKm.upper.value < attenuationDbPerKm.lower.value) {
      throw ArgumentError('LAN05 attenuation interval is invalid.');
    }
  }

  final Elv5Rational wavelengthNm;
  final Lan05LossInterval attenuationDbPerKm;
  final String evidenceRef;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'wavelengthNm': wavelengthNm.toMap(),
    'minDbPerKm': attenuationDbPerKm.lower.value.toMap(),
    'maxDbPerKm': attenuationDbPerKm.upper.value.toMap(),
    'evidenceRef': evidenceRef,
  };
}

final class Lan05OpticalFiberEvidenceDocument {
  Lan05OpticalFiberEvidenceDocument({
    required String realizedSectionId,
    required Iterable<Lan05OpticalAttenuationProfile> attenuationProfiles,
  }) : realizedSectionId = _requiredText(
         realizedSectionId,
         'realizedSectionId',
       ),
       attenuationProfiles = List.unmodifiable(
         _normalizeProfiles(attenuationProfiles),
       );

  static const schema = 'electra.elv5-optical-fiber-evidence.v1';

  final String realizedSectionId;
  final List<Lan05OpticalAttenuationProfile> attenuationProfiles;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'realizedSectionId': realizedSectionId,
    'attenuationProfiles': <Object?>[
      for (final profile in attenuationProfiles) profile.toCanonicalValue(),
    ],
  };

  static List<Lan05OpticalAttenuationProfile> _normalizeProfiles(
    Iterable<Lan05OpticalAttenuationProfile> values,
  ) {
    final profiles = values.toList(growable: false)
      ..sort((a, b) => a.wavelengthNm.compareTo(b.wavelengthNm));
    if (profiles.isEmpty) {
      throw ArgumentError('LAN05 optical evidence requires profiles.');
    }
    final wavelengths = <String>{};
    for (final profile in profiles) {
      final key = profile.wavelengthNm.toString();
      if (!wavelengths.add(key)) {
        throw ArgumentError('LAN05 duplicate attenuation wavelength: $key.');
      }
    }
    return profiles;
  }
}

final class ReplaceLan05OpticalSectionEvidenceCommand {
  ReplaceLan05OpticalSectionEvidenceCommand({
    required String projectId,
    required String designRevisionId,
    required String bindingId,
    required this.expectedBindingRevision,
    required this.expectedDesignRevision,
    required this.evidence,
  }) : projectId = _requiredText(projectId, 'projectId'),
       designRevisionId = _requiredText(designRevisionId, 'designRevisionId'),
       bindingId = _requiredText(bindingId, 'bindingId') {
    if (expectedBindingRevision <= 0 || expectedDesignRevision <= 0) {
      throw ArgumentError('LAN05 expected revisions must be positive.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final String bindingId;
  final int expectedBindingRevision;
  final int expectedDesignRevision;
  final Lan05OpticalFiberEvidenceDocument evidence;
}

/// Reads immutable-by-reference per-section fiber attenuation evidence persisted
/// against the active LAN link-composition section assignment.
abstract interface class Lan05OpticalSectionEvidenceSource {
  Future<Lan05OpticalSectionEvidence?> findAttenuation({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
    required Elv5Rational wavelengthNm,
  });
}

/// Production write contract for attaching exact optical authority evidence to a
/// realized link section. Implementations must guard both the link-composition
/// aggregate revision and the design-revision token in one transaction.
abstract interface class Lan05OpticalSectionEvidenceWriter {
  Future<void> replace(ReplaceLan05OpticalSectionEvidenceCommand command);
}

String _requiredText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError('$field must be non-empty.');
  return normalized;
}
