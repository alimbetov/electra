import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart'
    show CanonicalCableRun, CableRunTraversal;
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/environment/ampacity_route_resolver.dart';
import '../../../application/elv5/environment/ampacity_section_contract.dart';
import '../../../application/elv5/environment/environment_scope_resolver.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';

final class DriftElv5AmpacitySectionContractStore
    implements
        Elv5AmpacitySectionContractSource,
        Elv5AmpacitySectionContractWriter,
        Elv5AmpacitySectionEvidenceSource {
  const DriftElv5AmpacitySectionContractStore(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : _nowUtc = nowUtc ?? _defaultNow;

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _nowUtc;
  static const _encoder = Elv5CanonicalJsonV1();
  static DateTime _defaultNow() => DateTime.now().toUtc();

  @override
  Future<Elv5AmpacitySectionContractSnapshot?> loadActiveForSection({
    required String projectId,
    required String designRevisionId,
    required String routeSectionId,
  }) async {
    final rows = await database.customSelect(
      'SELECT id, revision, definition_ref_json '
      'FROM discipline_policy_bindings '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND subject_kind = ? AND subject_id = ? '
      'AND deleted_at IS NULL ORDER BY id',
      variables: <Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString('ROUTE_SECTION'),
        Variable.withString(routeSectionId),
      ],
    ).get();

    final matching = <QueryRow>[];
    for (final row in rows) {
      final raw = jsonDecode(row.read<String>('definition_ref_json'));
      if (raw is Map && raw['policyCode'] == 'ELV5_AMPACITY_SECTION_CONTRACT') {
        matching.add(row);
      }
    }
    if (matching.isEmpty) return null;
    if (matching.length != 1) {
      throw StateError(
        'ELV5_AMPACITY_SECTION_BINDING_AMBIGUOUS:$routeSectionId',
      );
    }

    final binding = matching.single;
    final definitionRaw = jsonDecode(
      binding.read<String>('definition_ref_json'),
    );
    if (definitionRaw is! Map) {
      throw StateError(
        'ELV5_AMPACITY_SECTION_DEFINITION_INVALID:$routeSectionId',
      );
    }
    final definition = Map<String, Object?>.from(definitionRaw);
    final evidenceRef = _text(definition, 'editionId');
    final contentHash = _text(definition, 'contentHash');

    final evidence = await database.customSelect(
      'SELECT canonical_payload_json, payload_sha256 '
      'FROM elv_revision_aggregate_evidence_records '
      'WHERE evidence_ref = ? AND project_id = ? AND design_revision_id = ? '
      'AND aggregate_kind = ? AND aggregate_id = ?',
      variables: <Variable>[
        Variable.withString(evidenceRef),
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString('ELV5_AMPACITY_SECTION_CONTRACT'),
        Variable.withString(routeSectionId),
      ],
    ).getSingleOrNull();
    if (evidence == null) {
      throw StateError('ELV5_AMPACITY_SECTION_EVIDENCE_MISSING:$evidenceRef');
    }

    final payloadRaw = jsonDecode(
      evidence.read<String>('canonical_payload_json'),
    );
    if (payloadRaw is! Map) {
      throw StateError('ELV5_AMPACITY_SECTION_PAYLOAD_INVALID:$evidenceRef');
    }
    final payload = Map<String, Object?>.from(payloadRaw);
    if (_encoder.sha256(payload) != contentHash ||
        evidence.read<String>('payload_sha256') != contentHash) {
      throw StateError('ELV5_AMPACITY_SECTION_HASH_MISMATCH:$evidenceRef');
    }

    final contract = Elv5AmpacitySectionContract.fromMap(payload);
    if (contract.routeSectionId != routeSectionId) {
      throw StateError(
        'ELV5_AMPACITY_SECTION_IDENTITY_MISMATCH:$routeSectionId',
      );
    }
    return Elv5AmpacitySectionContractSnapshot(
      bindingId: binding.read<String>('id'),
      bindingRevision: binding.read<int>('revision'),
      evidenceRef: evidenceRef,
      contentHash: contentHash,
      contract: contract,
    );
  }

  @override
  Future<Elv5AmpacitySectionEvidence?> loadForSection({
    required String projectId,
    required String designRevisionId,
    required CanonicalCableRun cableRun,
    required CableRunTraversal traversal,
    required Elv5ResolvedEnvironment environment,
  }) async {
    final snapshot = await loadActiveForSection(
      projectId: projectId,
      designRevisionId: designRevisionId,
      routeSectionId: traversal.routeSegmentId,
    );
    if (snapshot == null) return null;

    final contract = snapshot.contract;
    if (contract.routeSectionId != traversal.routeSegmentId ||
        contract.cableRunId != cableRun.id ||
        contract.cableId != cableRun.cableId) {
      throw Elv5AmpacityRouteResolutionException(
        'ELV5_AMPACITY_SECTION_PHYSICAL_IDENTITY_MISMATCH',
        <String, Object?>{
          'routeSectionId': traversal.routeSegmentId,
          'contractRouteSectionId': contract.routeSectionId,
          'expectedCableRunId': cableRun.id,
          'contractCableRunId': contract.cableRunId,
          'expectedCableId': cableRun.cableId,
          'contractCableId': contract.cableId,
        },
      );
    }

    final profile = environment.binding.profile;
    if (contract.expectedEnvironmentProfileId != profile.profileId ||
        contract.expectedEnvironmentEditionId != profile.editionId ||
        contract.expectedEnvironmentContentHash != environment.binding.contentHash) {
      throw Elv5AmpacityRouteResolutionException(
        'ELV5_AMPACITY_SECTION_ENVIRONMENT_IDENTITY_MISMATCH',
        <String, Object?>{
          'routeSectionId': contract.routeSectionId,
          'expectedProfileId': contract.expectedEnvironmentProfileId,
          'actualProfileId': profile.profileId,
          'expectedEditionId': contract.expectedEnvironmentEditionId,
          'actualEditionId': profile.editionId,
          'expectedContentHash': contract.expectedEnvironmentContentHash,
          'actualContentHash': environment.binding.contentHash,
        },
      );
    }
    if (contract.temperatureCorrection.actualAmbientTemperatureC !=
        profile.temperatureC.maximum) {
      throw Elv5AmpacityRouteResolutionException(
        'ELV5_AMPACITY_SECTION_TEMPERATURE_SCOPE_MISMATCH',
        <String, Object?>{
          'routeSectionId': contract.routeSectionId,
          'profileMaximumC': profile.temperatureC.maximum.toMap(),
          'correctionTemperatureC':
              contract.temperatureCorrection.actualAmbientTemperatureC.toMap(),
        },
      );
    }

    return Elv5AmpacitySectionEvidence(
      referenceRow: contract.referenceRow,
      temperatureCorrection: contract.temperatureCorrection,
      groupingCorrection: contract.groupingCorrection,
      additionalCorrections: contract.additionalCorrections,
    );
  }

  @override
  Future<void> replace(ReplaceElv5AmpacitySectionContractCommand command) =>
      database.transaction(() async {
        final now = _nowUtc().toUtc();
        await _requireWorkingRevision(command);

        final payload = command.contract.toCanonicalValue();
        final hash = _encoder.sha256(payload);
        final evidenceRef = 'AMPACITY:${command.contract.routeSectionId}:$hash';
        await _ensureEvidence(
          command: command,
          evidenceRef: evidenceRef,
          hash: hash,
          payload: payload,
          now: now,
        );
        await _replaceBinding(
          command: command,
          evidenceRef: evidenceRef,
          hash: hash,
          now: now,
        );

        final changedDesign = await database.customUpdate(
          'UPDATE project_design_revisions '
          'SET revision = revision + 1, updated_at = ?, origin_device_id = ? '
          'WHERE project_id = ? AND id = ? AND revision = ? '
          'AND state = ? AND deleted_at IS NULL',
          variables: <Variable>[
            Variable<DateTime>(now),
            Variable.withString(originDeviceId),
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable<int>(command.expectedDesignRevision),
            Variable.withString('WORKING'),
          ],
        );
        if (changedDesign != 1) {
          throw StateError('ELV5_AMPACITY_DESIGN_REVISION_CAS_FAILED');
        }
      });

  Future<void> _requireWorkingRevision(
    ReplaceElv5AmpacitySectionContractCommand command,
  ) async {
    final revision = await database.customSelect(
      'SELECT state, revision FROM project_design_revisions '
      'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
      variables: <Variable>[
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
      ],
    ).getSingleOrNull();
    if (revision == null) {
      throw StateError('ELV5_AMPACITY_DESIGN_REVISION_NOT_FOUND');
    }
    if (revision.read<String>('state') != 'WORKING') {
      throw StateError('ELV5_AMPACITY_DESIGN_REVISION_READ_ONLY');
    }
    if (revision.read<int>('revision') != command.expectedDesignRevision) {
      throw StateError('ELV5_AMPACITY_DESIGN_REVISION_CONFLICT');
    }
  }

  Future<void> _ensureEvidence({
    required ReplaceElv5AmpacitySectionContractCommand command,
    required String evidenceRef,
    required String hash,
    required Map<String, Object?> payload,
    required DateTime now,
  }) async {
    final existing = await database.customSelect(
      'SELECT payload_sha256 FROM elv_revision_aggregate_evidence_records '
      'WHERE evidence_ref = ?',
      variables: <Variable>[Variable.withString(evidenceRef)],
    ).getSingleOrNull();
    if (existing != null) {
      if (existing.read<String>('payload_sha256') != hash) {
        throw StateError('ELV5_AMPACITY_EVIDENCE_REF_COLLISION:$evidenceRef');
      }
      return;
    }
    await runRawStatement(
      database,
      'INSERT INTO elv_revision_aggregate_evidence_records '
      '(evidence_ref, project_id, design_revision_id, aggregate_kind, aggregate_id, '
      'canonical_payload_json, payload_sha256, created_at, origin_device_id) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      <Variable>[
        Variable.withString(evidenceRef),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString('ELV5_AMPACITY_SECTION_CONTRACT'),
        Variable.withString(command.contract.routeSectionId),
        Variable.withString(_canonical(payload)),
        Variable.withString(hash),
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
      ],
    );
  }

  Future<void> _replaceBinding({
    required ReplaceElv5AmpacitySectionContractCommand command,
    required String evidenceRef,
    required String hash,
    required DateTime now,
  }) async {
    final definition = <String, Object?>{
      'policyCode': 'ELV5_AMPACITY_SECTION_CONTRACT',
      'editionId': evidenceRef,
      'contentHash': hash,
    };
    final applicability = <String, Object?>{
      'scopeKind': 'ROUTE_SECTION',
      'scopeId': command.contract.routeSectionId,
    };

    if (command.expectedBindingRevision == null) {
      final rows = await database.customSelect(
        'SELECT id, definition_ref_json FROM discipline_policy_bindings '
        'WHERE project_id = ? AND design_revision_id = ? '
        'AND subject_kind = ? AND subject_id = ? AND deleted_at IS NULL',
        variables: <Variable>[
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString('ROUTE_SECTION'),
          Variable.withString(command.contract.routeSectionId),
        ],
      ).get();
      for (final row in rows) {
        final decoded = jsonDecode(row.read<String>('definition_ref_json'));
        if (decoded is Map &&
            decoded['policyCode'] == 'ELV5_AMPACITY_SECTION_CONTRACT') {
          throw StateError(
            'ELV5_AMPACITY_ACTIVE_BINDING_ALREADY_EXISTS:'
            '${row.read<String>('id')}',
          );
        }
      }
      await runRawStatement(
        database,
        'INSERT INTO discipline_policy_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, subject_kind, subject_id, process_codes_json, '
        'definition_ref_json, definition_sha256, applicability_json, applicability_sha256) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Variable>[
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(command.bindingId),
          Variable<DateTime>(now),
          Variable<DateTime>(now),
          Variable.withString(originDeviceId),
          Variable.withString('ROUTE_SECTION'),
          Variable.withString(command.contract.routeSectionId),
          Variable.withString(_canonical(<String>['FA-08'])),
          Variable.withString(_canonical(definition)),
          Variable.withString(hash),
          Variable.withString(_canonical(applicability)),
          Variable.withString(_encoder.sha256(applicability)),
        ],
      );
      return;
    }

    final changed = await database.customUpdate(
      'UPDATE discipline_policy_bindings '
      'SET revision = revision + 1, updated_at = ?, origin_device_id = ?, '
      'definition_ref_json = ?, definition_sha256 = ?, applicability_json = ?, '
      'applicability_sha256 = ? '
      'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
      'AND subject_kind = ? AND subject_id = ? AND revision = ? '
      'AND deleted_at IS NULL',
      variables: <Variable>[
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
        Variable.withString(_canonical(definition)),
        Variable.withString(hash),
        Variable.withString(_canonical(applicability)),
        Variable.withString(_encoder.sha256(applicability)),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable.withString(command.bindingId),
        Variable.withString('ROUTE_SECTION'),
        Variable.withString(command.contract.routeSectionId),
        Variable<int>(command.expectedBindingRevision!),
      ],
    );
    if (changed != 1) {
      throw StateError('ELV5_AMPACITY_BINDING_CAS_FAILED');
    }
  }

  String _canonical(Object? value) => utf8.decode(_encoder.encode(value));
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return value.trim();
}
