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

/// Reads immutable per-section fiber attenuation evidence already persisted in
/// `link_section_assignments.evidence_json`.
abstract interface class Lan05OpticalSectionEvidenceSource {
  Future<Lan05OpticalSectionEvidence?> findAttenuation({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
    required Elv5Rational wavelengthNm,
  });
}
