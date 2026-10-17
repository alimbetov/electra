import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/fire/fa05_autonomy_contract.dart';
import '../../../application/elv5/fire/fa05_autonomy_contract_write.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';

final class DriftFa05AutonomyContractStore
    implements Fa05AutonomyContractSource, Fa05AutonomyContractWriter {
  const DriftFa05AutonomyContractStore(
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
  Future<Fa05AutonomyContractSnapshot?> loadActiveForBank({
    required String projectId,
    required String designRevisionId,
    required String bankId,
  }) async {
    final rows =
        await database
            .customSelect(
              'SELECT id, revision, process_codes_json, definition_ref_json '
              'FROM discipline_policy_bindings WHERE project_id = ? '
              'AND design_revision_id = ? AND subject_kind = ? AND subject_id = ? '
              'AND deleted_at IS NULL ORDER BY id',
              variables: <Variable>[
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                Variable.withString('POWER_BANK'),
                Variable.withString(bankId),
              ],
            )
            .get();
    final matching = <QueryRow>[];
    for (final row in rows) {
      final rawCodes = jsonDecode(row.read<String>('process_codes_json'));
      if (rawCodes is! List) {
        throw StateError(
          'FA05_POLICY_PROCESS_CODES_INVALID:${row.read<String>('id')}',
        );
      }
      if (rawCodes.contains('FA-05')) matching.add(row);
    }
    if (matching.isEmpty) return null;
    if (matching.length != 1) {
      throw StateError('FA05_ACTIVE_CONTRACT_BINDING_AMBIGUOUS:$bankId');
    }

    final binding = matching.single;
    final rawDefinition = jsonDecode(
      binding.read<String>('definition_ref_json'),
    );
    if (rawDefinition is! Map) {
      throw StateError('FA05_DEFINITION_REF_INVALID:$bankId');
    }
    final definition = Map<String, Object?>.from(rawDefinition);
    if (definition['policyCode'] != 'FA05_AUTONOMY_CONTRACT') {
      throw StateError('FA05_DEFINITION_POLICY_CODE_INVALID:$bankId');
    }
    final evidenceRef = _requiredText(definition, 'editionId');
    final contentHash = _requiredText(definition, 'contentHash');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash)) {
      throw StateError('FA05_DEFINITION_HASH_INVALID:$bankId');
    }

    final evidence =
        await database
            .customSelect(
              'SELECT canonical_payload_json, payload_sha256 FROM '
              'elv_revision_aggregate_evidence_records WHERE evidence_ref = ? '
              'AND project_id = ? AND design_revision_id = ? AND aggregate_kind = ? '
              'AND aggregate_id = ?',
              variables: <Variable>[
                Variable.withString(evidenceRef),
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                Variable.withString('FA05_AUTONOMY_CONTRACT'),
                Variable.withString(bankId),
              ],
            )
            .getSingleOrNull();
    if (evidence == null) {
      throw StateError('FA05_CONTRACT_EVIDENCE_MISSING:$evidenceRef');
    }
    final canonical = evidence.read<String>('canonical_payload_json');
    final decoded = jsonDecode(canonical);
    if (decoded is! Map) {
      throw StateError('FA05_CONTRACT_PAYLOAD_INVALID:$evidenceRef');
    }
    final payload = Map<String, Object?>.from(decoded);
    final computedHash = _encoder.sha256(payload);
    if (computedHash != contentHash ||
        evidence.read<String>('payload_sha256') != contentHash) {
      throw StateError('FA05_CONTRACT_HASH_MISMATCH:$evidenceRef');
    }
    final contract = Fa05AutonomyContract.fromMap(payload);
    if (contract.bankId != bankId) {
      throw StateError(
        'FA05_CONTRACT_BANK_MISMATCH:$bankId:${contract.bankId}',
      );
    }
    return Fa05AutonomyContractSnapshot(
      bindingId: binding.read<String>('id'),
      bindingRevision: binding.read<int>('revision'),
      evidenceRef: evidenceRef,
      contentHash: contentHash,
      contract: contract,
    );
  }

  @override
  Future<void> replace(
    ReplaceFa05AutonomyContractCommand command,
  ) => database.transaction(() async {
    final now = _nowUtc().toUtc();
    final revision =
        await database
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
      throw StateError(
        'FA05_DESIGN_REVISION_NOT_FOUND:${command.designRevisionId}',
      );
    }
    if (revision.read<String>('state') != 'WORKING') {
      throw StateError('FA05_DESIGN_REVISION_READ_ONLY');
    }
    if (revision.read<int>('revision') != command.expectedDesignRevision) {
      throw StateError('FA05_DESIGN_REVISION_CONFLICT');
    }

    final bank =
        await database
            .customSelect(
              'SELECT id FROM component_instances WHERE id = ? AND deleted_at IS NULL',
              variables: <Variable>[
                Variable.withString(command.contract.bankId),
              ],
            )
            .getSingleOrNull();
    if (bank == null) {
      throw StateError(
        'FA05_BATTERY_BANK_COMPONENT_NOT_FOUND:${command.contract.bankId}',
      );
    }

    final payload = command.contract.toCanonicalValue();
    final contentHash = _encoder.sha256(payload);
    final evidenceRef = 'FA05:${command.contract.bankId}:$contentHash';
    final canonicalPayload = _canonical(payload);
    final existingEvidence =
        await database
            .customSelect(
              'SELECT payload_sha256 FROM elv_revision_aggregate_evidence_records '
              'WHERE evidence_ref = ?',
              variables: <Variable>[Variable.withString(evidenceRef)],
            )
            .getSingleOrNull();
    if (existingEvidence == null) {
      await runRawStatement(
        database,
        'INSERT INTO elv_revision_aggregate_evidence_records '
        '(evidence_ref, project_id, design_revision_id, aggregate_kind, '
        'aggregate_id, canonical_payload_json, payload_sha256, created_at, '
        'origin_device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Variable>[
          Variable.withString(evidenceRef),
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString('FA05_AUTONOMY_CONTRACT'),
          Variable.withString(command.contract.bankId),
          Variable.withString(canonicalPayload),
          Variable.withString(contentHash),
          Variable<DateTime>(now),
          Variable.withString(originDeviceId),
        ],
      );
    } else if (existingEvidence.read<String>('payload_sha256') != contentHash) {
      throw StateError('FA05_EVIDENCE_REF_COLLISION:$evidenceRef');
    }

    final definitionRef = <String, Object?>{
      'policyCode': 'FA05_AUTONOMY_CONTRACT',
      'editionId': evidenceRef,
      'contentHash': contentHash,
    };
    final applicability = <String, Object?>{
      'scopeKinds': <String>['DESIGN', 'SCENARIO'],
      'scenarioIds': <String>[command.contract.scenarioId],
    };
    final processCodes = <String>['FA-05'];

    if (command.expectedBindingRevision == null) {
      final currentRows =
          await database
              .customSelect(
                'SELECT id, process_codes_json FROM discipline_policy_bindings '
                'WHERE project_id = ? AND design_revision_id = ? '
                'AND subject_kind = ? AND subject_id = ? AND deleted_at IS NULL',
                variables: <Variable>[
                  Variable.withString(command.projectId),
                  Variable.withString(command.designRevisionId),
                  Variable.withString('POWER_BANK'),
                  Variable.withString(command.contract.bankId),
                ],
              )
              .get();
      for (final row in currentRows) {
        final codes = jsonDecode(row.read<String>('process_codes_json'));
        if (codes is List && codes.contains('FA-05')) {
          throw StateError(
            'FA05_ACTIVE_CONTRACT_ALREADY_EXISTS:${row.read<String>('id')}',
          );
        }
      }
      await runRawStatement(
        database,
        'INSERT INTO discipline_policy_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, '
        'deleted_at, origin_device_id, subject_kind, subject_id, '
        'process_codes_json, definition_ref_json, definition_sha256, '
        'applicability_json, applicability_sha256) '
        'VALUES (?, ?, ?, 1, ?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, ?)',
        <Variable>[
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(command.bindingId),
          Variable<DateTime>(now),
          Variable<DateTime>(now),
          Variable.withString(originDeviceId),
          Variable.withString('POWER_BANK'),
          Variable.withString(command.contract.bankId),
          Variable.withString(_canonical(processCodes)),
          Variable.withString(_canonical(definitionRef)),
          Variable.withString(contentHash),
          Variable.withString(_canonical(applicability)),
          Variable.withString(_encoder.sha256(applicability)),
        ],
      );
    } else {
      final changed = await database.customUpdate(
        'UPDATE discipline_policy_bindings SET revision = revision + 1, '
        'updated_at = ?, origin_device_id = ?, process_codes_json = ?, '
        'definition_ref_json = ?, definition_sha256 = ?, applicability_json = ?, '
        'applicability_sha256 = ? WHERE project_id = ? AND design_revision_id = ? '
        'AND id = ? AND subject_kind = ? AND subject_id = ? AND revision = ? '
        'AND deleted_at IS NULL',
        variables: <Variable>[
          Variable<DateTime>(now),
          Variable.withString(originDeviceId),
          Variable.withString(_canonical(processCodes)),
          Variable.withString(_canonical(definitionRef)),
          Variable.withString(contentHash),
          Variable.withString(_canonical(applicability)),
          Variable.withString(_encoder.sha256(applicability)),
          Variable.withString(command.projectId),
          Variable.withString(command.designRevisionId),
          Variable.withString(command.bindingId),
          Variable.withString('POWER_BANK'),
          Variable.withString(command.contract.bankId),
          Variable<int>(command.expectedBindingRevision!),
        ],
      );
      if (changed != 1) throw StateError('FA05_CONTRACT_BINDING_CAS_FAILED');
    }

    final changedDesign = await database.customUpdate(
      'UPDATE project_design_revisions SET revision = revision + 1, '
      'updated_at = ?, origin_device_id = ? WHERE project_id = ? AND id = ? '
      'AND revision = ? AND state = ? AND deleted_at IS NULL',
      variables: <Variable>[
        Variable<DateTime>(now),
        Variable.withString(originDeviceId),
        Variable.withString(command.projectId),
        Variable.withString(command.designRevisionId),
        Variable<int>(command.expectedDesignRevision),
        Variable.withString('WORKING'),
      ],
    );
    if (changedDesign != 1) throw StateError('FA05_DESIGN_REVISION_CAS_FAILED');
  });

  String _canonical(Object? value) => utf8.decode(_encoder.encode(value));
}

String _requiredText(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return value.trim();
}
