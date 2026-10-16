import 'package:engineering_core/engineering_core_elv5.dart';

final class Lan05AttenuationProfileDraft {
  Lan05AttenuationProfileDraft({
    required this.wavelengthNm,
    required this.minimumDbPerKm,
    required this.maximumDbPerKm,
    required String evidenceRef,
  }) : evidenceRef = evidenceRef.trim() {
    if (wavelengthNm <= Elv5Rational.zero) {
      throw ArgumentError('LAN05 wavelength must be positive.');
    }
    if (minimumDbPerKm < Elv5Rational.zero ||
        maximumDbPerKm < minimumDbPerKm) {
      throw ArgumentError('LAN05 attenuation interval is invalid.');
    }
    if (this.evidenceRef.isEmpty) {
      throw ArgumentError('LAN05 attenuation evidenceRef is required.');
    }
  }

  final Elv5Rational wavelengthNm;
  final Elv5Rational minimumDbPerKm;
  final Elv5Rational maximumDbPerKm;
  final String evidenceRef;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'wavelengthNm': wavelengthNm.toMap(),
        'minDbPerKm': minimumDbPerKm.toMap(),
        'maxDbPerKm': maximumDbPerKm.toMap(),
        'evidenceRef': evidenceRef,
      };
}

final class ReplaceLan05SectionEvidenceCommand {
  ReplaceLan05SectionEvidenceCommand({
    required String projectId,
    required String designRevisionId,
    required String linkId,
    required String realizedSectionId,
    required this.expectedLinkRevision,
    required this.expectedDesignRevision,
    required Iterable<Lan05AttenuationProfileDraft> profiles,
  })  : projectId = _text(projectId, 'projectId'),
        designRevisionId = _text(designRevisionId, 'designRevisionId'),
        linkId = _text(linkId, 'linkId'),
        realizedSectionId = _text(realizedSectionId, 'realizedSectionId'),
        profiles = List.unmodifiable(_normalize(profiles)) {
    if (expectedLinkRevision < 1 || expectedDesignRevision < 1) {
      throw ArgumentError('LAN05 expected revisions must be positive.');
    }
    if (this.profiles.isEmpty) {
      throw ArgumentError('LAN05 attenuation evidence requires profiles.');
    }
  }

  final String projectId;
  final String designRevisionId;
  final String linkId;
  final String realizedSectionId;
  final int expectedLinkRevision;
  final int expectedDesignRevision;
  final List<Lan05AttenuationProfileDraft> profiles;

  Map<String, Object?> get evidencePayload => <String, Object?>{
        'schema': 'electra.elv5-optical-fiber-evidence.v1',
        'attenuationProfiles': [
          for (final profile in profiles) profile.toCanonicalValue(),
        ],
      };

  static List<Lan05AttenuationProfileDraft> _normalize(
    Iterable<Lan05AttenuationProfileDraft> values,
  ) {
    final result = values.toList()
      ..sort((a, b) => a.wavelengthNm.compareTo(b.wavelengthNm));
    for (var i = 1; i < result.length; i++) {
      if (result[i - 1].wavelengthNm == result[i].wavelengthNm) {
        throw ArgumentError('LAN05 duplicate attenuation wavelength.');
      }
    }
    return result;
  }
}

abstract interface class Lan05OpticalSectionEvidenceWriter {
  Future<void> replace(ReplaceLan05SectionEvidenceCommand command);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
