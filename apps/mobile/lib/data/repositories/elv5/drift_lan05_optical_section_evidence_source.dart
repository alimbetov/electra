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
    final rows = await database
        .customSelect(
          'SELECT evidence_json FROM link_section_assignments '
          'WHERE project_id = ? AND design_revision_id = ? '
          'AND realized_section_id = ? ORDER BY binding_id, ordinal',
          variables: <Variable>[
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(realizedSectionId),
          ],
        )
        .get();
    if (rows.isEmpty) return null;

    Lan05OpticalSectionEvidence? resolved;
    for (final row in rows) {
      final encoded = row.read<String>('evidence_json');
      final decoded = jsonDecode(encoded);
      if (decoded is! Map || decoded.isEmpty) continue;
      final map = decoded.cast<String, Object?>();
      if (map['schema'] != Lan05OpticalFiberEvidenceDocument.schema) continue;
      final documentSection = map['realizedSectionId'];
      if (documentSection != null && documentSection != realizedSectionId) {
        throw StateError(
          'LAN05_ATTENUATION_SECTION_IDENTITY_MISMATCH:$realizedSectionId',
        );
      }
      final profilesRaw = map['attenuationProfiles'];
      if (profilesRaw is! List) {
        throw StateError(
          'LAN05_ATTENUATION_PROFILES_INVALID:$realizedSectionId',
        );
      }
      for (final raw in profilesRaw) {
        if (raw is! Map) {
          throw StateError(
            'LAN05_ATTENUATION_PROFILE_INVALID:$realizedSectionId',
          );
        }
        final profile = Map<String, Object?>.from(raw);
        final wave = _exact(profile, 'wavelengthNm');
        if (wave != wavelengthNm) continue;
        final minimum = _exact(profile, 'minDbPerKm');
        final maximum = _exact(profile, 'maxDbPerKm');
        if (minimum < Elv5Rational.zero || maximum < minimum) {
          throw StateError(
            'LAN05_ATTENUATION_INTERVAL_INVALID:$realizedSectionId',
          );
        }
        final evidenceRef = profile['evidenceRef'];
        if (evidenceRef is! String || evidenceRef.trim().isEmpty) {
          throw StateError(
            'LAN05_ATTENUATION_EVIDENCE_REF_MISSING:$realizedSectionId',
          );
        }
        final candidate = Lan05OpticalSectionEvidence(
          realizedSectionId: realizedSectionId,
          wavelengthNm: wave,
          attenuationDbPerKm: Lan05LossInterval(
            lower: LossDb(minimum),
            upper: LossDb(maximum),
          ),
          evidenceFingerprint: _profileFingerprint(
            realizedSectionId,
            map['schema'],
            profile,
          ),
          evidenceRef: evidenceRef.trim(),
        );
        if (resolved != null &&
            (resolved.attenuationDbPerKm.lower.value != minimum ||
                resolved.attenuationDbPerKm.upper.value != maximum ||
                resolved.evidenceRef != candidate.evidenceRef)) {
          throw StateError(
            'LAN05_ATTENUATION_EVIDENCE_CONFLICT:$realizedSectionId',
          );
        }
        resolved = candidate;
      }
    }
    return resolved;
  }
}

final class DriftLan05OpticalSectionEvidenceWriter
    implements Lan05OpticalSectionEvidenceWriter {
  DriftLan05OpticalSectionEvidenceWriter(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();

  @override
  Future<void> replace(
    ReplaceLan05OpticalSectionEvidenceCommand command,
  ) => database.transaction(() async {
    final revision = await database
        .customSelect(
          'SELECT state, revision FROM project_design_revisions '
          'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
          ],
        )
        .getSingleOrNull();
    if (revision == null) {
      throw StateError('LAN05_DESIGN_REVISION_NOT_FOUND');
    }
    if (revision.read<String>('state') != 'WORKING') {
      throw StateError('LAN05_DESIGN_REVISION_READ_ONLY');
    }
    if (revision.read<int>('revision') != command.expectedDesignRevision) {
      throw StateError('LAN05_DESIGN_REVISION_CAS_CONFLICT');
    }

    final binding = await database
        .customSelect(
          'SELECT revision FROM link_composition_bindings '
          'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
          'AND deleted_at IS NULL',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(command.bindingId),
          ],
        )
        .getSingleOrNull();
    if (binding == null) {
      throw StateError('LAN05_LINK_COMPOSITION_BINDING_NOT_FOUND');
    }
    if (binding.read<int>('revision') != command.expectedBindingRevision) {
      throw StateError('LAN05_LINK_COMPOSITION_BINDING_CAS_CONFLICT');
    }

    final rows = await database
        .customSelect(
          'SELECT ordinal, evidence_json FROM link_section_assignments '
          'WHERE project_id = ? AND design_revision_id = ? '
          'AND binding_id = ? AND realized_section_id = ?',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(command.bindingId),
            Variable.withString(command.evidence.realizedSectionId),
          ],
        )
        .get();
    if (rows.length != 1) {
      throw StateError(
        rows.isEmpty
            ? 'LAN05_REALIZED_SECTION_NOT_ASSIGNED'
            : 'LAN05_REALIZED_SECTION_ASSIGNMENT_AMBIGUOUS',
      );
    }

    final now = _nowUtc().toUtc();
    final oldEvidence = rows.single.read<String>('evidence_json');
    final dependencyHashes = _evidenceDependencyHashes(
      command.evidence.realizedSectionId,
      oldEvidence,
    );
    if (dependencyHashes.isNotEmpty) {
      final placeholders = List.filled(dependencyHashes.length, '?').join(',');
      final dependentRows = await database
          .customSelect(
            'SELECT DISTINCT logical_node_key_sha256 '
            'FROM discipline_dependency_index '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND dependency_key_sha256 IN ($placeholders)',
            variables: <Variable>[
              Variable.withString(command.projectId),
              Variable.withString(command.designRevisionId),
              ...dependencyHashes.map(Variable.withString),
            ],
          )
          .get();
      final nodeHashes = dependentRows
          .map((row) => row.read<String>('logical_node_key_sha256'))
          .toSet();
      if (nodeHashes.isNotEmpty) {
        final nodePlaceholders = List.filled(nodeHashes.length, '?').join(',');
        await database.customUpdate(
          'UPDATE discipline_evaluation_pointers '
          "SET freshness = 'STALE', generation = generation + 1, "
          'updated_at = ?, origin_device_id = ? '
          'WHERE project_id = ? AND design_revision_id = ? '
          'AND logical_node_key_sha256 IN ($nodePlaceholders) '
          "AND freshness <> 'STALE'",
          variables: <Variable>[
            Variable<DateTime>(now),
            Variable.withString(originDeviceId),
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            ...nodeHashes.map(Variable.withString),
          ],
        );
      }
    }

    final encoded = utf8.decode(
      _encoder.encode(command.evidence.toCanonicalValue()),
      allowMalformed: false,
    );
    final evidenceUpdated = await database.customUpdate(
      'UPDATE link_section_assignments SET evidence_json = ? '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND binding_id = ? AND realized_section_id = ?',
      variables: <Variable>[
        Variable.withString(encoded),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.bindingId),
        Variable.withString(command.evidence.realizedSectionId),
      ],
    );
    if (evidenceUpdated != 1) {
      throw StateError('LAN05_OPTICAL_EVIDENCE_WRITE_CONFLICT');
    }

    final bindingUpdated = await database.customUpdate(
      'UPDATE link_composition_bindings '
      'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
      'AND revision = ? AND deleted_at IS NULL',
      variables: <Variable>[
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.bindingId),
        Variable<int>(command.expectedBindingRevision),
      ],
    );
    if (bindingUpdated != 1) {
      throw StateError('LAN05_LINK_COMPOSITION_BINDING_CAS_CONFLICT');
    }

    final designUpdated = await database.customUpdate(
      'UPDATE project_design_revisions '
      'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
      'WHERE project_id = ? AND id = ? AND revision = ? '
      "AND state = 'WORKING' AND deleted_at IS NULL",
      variables: <Variable>[
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable<int>(command.expectedDesignRevision),
      ],
    );
    if (designUpdated != 1) {
      throw StateError('LAN05_DESIGN_REVISION_CAS_CONFLICT');
    }
  });

  Set<String> _evidenceDependencyHashes(
    String realizedSectionId,
    String encodedEvidence,
  ) {
    final result = <String>{_dependencyHash(realizedSectionId, null)};
    final decoded = jsonDecode(encodedEvidence);
    if (decoded is! Map || decoded.isEmpty) return result;
    final map = Map<String, Object?>.from(decoded);
    if (map['schema'] != Lan05OpticalFiberEvidenceDocument.schema) {
      return result;
    }
    final rawProfiles = map['attenuationProfiles'];
    if (rawProfiles is! List) return result;
    for (final raw in rawProfiles) {
      if (raw is! Map) continue;
      final profile = Map<String, Object?>.from(raw);
      final fingerprint = _profileFingerprint(
        realizedSectionId,
        map['schema'],
        profile,
      );
      result.add(_dependencyHash(realizedSectionId, fingerprint));
    }
    return result;
  }

  String _dependencyHash(String realizedSectionId, String? memberId) =>
      _encoder.sha256(<String, Object?>{
        'schema': 'electra.elv5-dependency-key.v1',
        'relationKind': 'FACT',
        'domain': 'LAN_OPTICAL_SECTION_EVIDENCE',
        'subjectId': realizedSectionId,
        if (memberId != null) 'memberId': memberId,
      });
}

String _profileFingerprint(
  String realizedSectionId,
  Object? schema,
  Map<String, Object?> profile,
) => const Elv5CanonicalJsonV1().sha256(<String, Object?>{
  'schema': schema,
  'realizedSectionId': realizedSectionId,
  'profile': profile,
});

Elv5Rational _exact(Map<String, Object?> value, String key) {
  final raw = value[key];
  if (raw is String) return Elv5Rational.parseDecimal(raw);
  if (raw is Map) {
    return Elv5Rational.fromMap(Map<String, Object?>.from(raw));
  }
  throw FormatException(
    '$key must be an exact decimal string or rational map.',
  );
}
