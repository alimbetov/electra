import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/lan/lan05_optical_section_evidence.dart';
import '../../database/app_database.dart';

final class DriftLan05OpticalSectionEvidenceSource
    implements Lan05OpticalSectionEvidenceSource {
  const DriftLan05OpticalSectionEvidenceSource(this.database);

  final AppDatabase database;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Future<Lan05OpticalSectionEvidence?> findAttenuation({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
    required Elv5Rational wavelengthNm,
  }) async {
    final rows = await database.customSelect(
      'SELECT evidence_json FROM link_section_assignments '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND realized_section_id = ? ORDER BY binding_id, ordinal',
      variables: <Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString(realizedSectionId),
      ],
    ).get();
    if (rows.isEmpty) return null;

    Lan05OpticalSectionEvidence? resolved;
    for (final row in rows) {
      final encoded = row.read<String>('evidence_json');
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || decoded.isEmpty) continue;
      final map = decoded.cast<String, Object?>();
      if (map['schema'] != 'electra.elv5-optical-fiber-evidence.v1') continue;
      final profilesRaw = map['attenuationProfiles'];
      if (profilesRaw is! List) {
        throw StateError('LAN05_ATTENUATION_PROFILES_INVALID:$realizedSectionId');
      }
      for (final raw in profilesRaw) {
        if (raw is! Map) {
          throw StateError('LAN05_ATTENUATION_PROFILE_INVALID:$realizedSectionId');
        }
        final profile = Map<String, Object?>.from(raw);
        final wave = _decimal(profile, 'wavelengthNm');
        if (wave != wavelengthNm) continue;
        final minimum = _decimal(profile, 'minDbPerKm');
        final maximum = _decimal(profile, 'maxDbPerKm');
        if (minimum < Elv5Rational.zero || maximum < minimum) {
          throw StateError('LAN05_ATTENUATION_INTERVAL_INVALID:$realizedSectionId');
        }
        final evidenceRef = profile['evidenceRef'];
        if (evidenceRef is! String || evidenceRef.trim().isEmpty) {
          throw StateError('LAN05_ATTENUATION_EVIDENCE_REF_MISSING:$realizedSectionId');
        }
        final candidate = Lan05OpticalSectionEvidence(
          realizedSectionId: realizedSectionId,
          wavelengthNm: wave,
          attenuationDbPerKm: Lan05LossInterval(
            lower: LossDb(minimum),
            upper: LossDb(maximum),
          ),
          evidenceFingerprint: _encoder.sha256(<String, Object?>{
            'schema': map['schema'],
            'realizedSectionId': realizedSectionId,
            'profile': profile,
          }),
          evidenceRef: evidenceRef.trim(),
        );
        if (resolved != null &&
            (resolved.attenuationDbPerKm.lower.value != minimum ||
                resolved.attenuationDbPerKm.upper.value != maximum ||
                resolved.evidenceRef != candidate.evidenceRef)) {
          throw StateError('LAN05_ATTENUATION_EVIDENCE_CONFLICT:$realizedSectionId');
        }
        resolved = candidate;
      }
    }
    return resolved;
  }
}

Elv5Rational _decimal(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is! String) {
    throw FormatException('$key must be an exact decimal string.');
  }
  return Elv5Rational.parseDecimal(raw);
}
