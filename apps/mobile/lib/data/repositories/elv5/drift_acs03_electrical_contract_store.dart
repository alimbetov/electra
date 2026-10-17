import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/acs/acs03_electrical_contract.dart';
import '../../../application/elv5/acs/acs03_electrical_contract_write.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';

final class DriftAcs03ElectricalContractStore
    implements Acs03ElectricalContractSource, Acs03ElectricalContractWriter {
  const DriftAcs03ElectricalContractStore(
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
  Future<Acs03ElectricalContractSnapshot?> loadActiveForDoor({
    required String projectId,
    required String designRevisionId,
    required String doorId,
  }) async {
    final rows = await database
        .customSelect(
          'SELECT id, revision, process_codes_json, definition_ref_json '
          'FROM discipline_policy_bindings WHERE project_id = ? '
          'AND design_revision_id = ? AND subject_kind = ? AND subject_id = ? '
          'AND deleted_at IS NULL ORDER BY id',
          variables: <Variable>[
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString('DOOR'),
            Variable.withString(doorId),
          ],
        )
        .get();
    final matching = <QueryRow>[];
    for (final row in rows) {
      final rawCodes = jsonDecode(row.read<String>('process_codes_json'));
      if (rawCodes is! List) {
        throw StateError(
          'ACS03_POLICY_PROCESS_CODES_INVALID:${row.read<String>('id')}',
        );
      }
      if (rawCodes.contains('ACS-03')) matching.add(row);
    }
    if (matching.isEmpty) return null;
    if (matching.length != 1) {
      throw StateError('ACS03_ACTIVE_CONTRACT_BINDING_AMBIGUOUS:$doorId');
    }

    final binding = matching.single;
    final definitionRaw = jsonDecode(
      binding.read<String>('definition_ref_json'),
    );
    if (definitionRaw is! Map) {
      throw StateError('ACS03_DEFINITION_REF_INVALID:$doorId');
    }
    final definition = Map<String, Object?>.from(definitionRaw);
    if (definition['policyCode'] != 'ACS03_ELECTRICAL_CONTRACT') {
      throw StateError('ACS03_DEFINITION_POLICY_CODE_INVALID:$doorId');
    }
    final evidenceRef = _requiredText(definition, 'editionId');
    final contentHash = _requiredText(definition, 'contentHash');
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(contentHash)) {
      throw StateError('ACS03_DEFINITION_HASH_INVALID:$doorId');
    }

    final evidence = await database
        .customSelect(
          'SELECT canonical_payload_json, payload_sha256 FROM '
          'elv_revision_aggregate_evidence_records WHERE evidence_ref = ? '
          'AND project_id = ? AND design_revision_id = ? AND aggregate_kind = ? '
          'AND aggregate_id = ?',
          variables: <Variable>[
            Variable.withString(evidenceRef),
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString('ACS03_ELECTRICAL_CONTRACT'),
            Variable.withString(doorId),
          ],
        )
        .getSingleOrNull();
    if (evidence == null) {
      throw StateError('ACS03_CONTRACT_EVIDENCE_MISSING:$evidenceRef');
    }
    final canonical = evidence.read<String>('canonical_payload_json');
    final decoded = jsonDecode(canonical);
    if (decoded is! Map) {
      throw StateError('ACS03_CONTRACT_PAYLOAD_INVALID:$evidenceRef');
    }
    final payload = Map<String, Object?>.from(decoded);
    final computedHash = _encoder.sha256(payload);
    if (computedHash != contentHash ||
        evidence.read<String>('payload_sha256') != contentHash) {
      throw StateError('ACS03_CONTRACT_HASH_MISMATCH:$evidenceRef');
    }
    final contract = Acs03ElectricalContract.fromMap(payload);
    if (contract.doorId != doorId) {
      throw StateError(
        'ACS03_CONTRACT_DOOR_MISMATCH:$doorId:${contract.doorId}',
      );
    }
    return Acs03ElectricalContractSnapshot(
      bindingId: binding.read<String>('id'),
      bindingRevision: binding.read<int>('revision'),
      evidenceRef: evidenceRef,
      contentHash: contentHash,
      contract: contract,
    );
  }

  @override
  Future<void> replace(
    ReplaceAcs03ElectricalContractCommand command,
  ) => database.transaction(() async {
    final now = _nowUtc().toUtc();
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
      throw StateError(
        'ACS03_DESIGN_REVISION_NOT_FOUND:${command.designRevisionId}',
      );
    }
    if (revision.read<String>('state') != 'WORKING') {
      throw StateError('ACS03_DESIGN_REVISION_READ_ONLY');
    }
    if (revision.read<int>('revision') != command.expectedDesignRevision) {
      throw StateError('ACS03_DESIGN_REVISION_CONFLICT');
    }

    final door = await database
        .customSelect(
          'SELECT id FROM door_calculation_bindings WHERE project_id = ? '
          'AND design_revision_id = ? AND door_assembly_id = ? AND deleted_at IS NULL',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(command.contract.doorId),
          ],
        )
        .getSingleOrNull();
    if (door == null) {
      throw StateError(
        'ACS03_DOOR_CALCULATION_NOT_FOUND:${command.contract.doorId}',
      );
    }
    final doorBindingId = door.read<String>('id');
    final lockRows = await database
        .customSelect(
          'SELECT component_id FROM door_role_assignments WHERE project_id = ? '
          'AND design_revision_id = ? AND binding_id = ? AND UPPER(role_code) = ? '
          'ORDER BY component_id',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(doorBindingId),
            Variable.withString('LOCK'),
          ],
        )
        .get();
    if (lockRows.length != 1 ||
        lockRows.single.read<String>('component_id') !=
            command.contract.lockId) {
      throw StateError(
        'ACS03_LOCK_ROLE_CONTRACT_MISMATCH:${command.contract.doorId}',
      );
    }

    final payload = command.contract.toCanonicalValue();
    final contentHash = _encoder.sha256(payload);
    final evidenceRef = 'ACS03:${command.contract.doorId}:$contentHash';
    final canonicalPayload = utf8.decode(
      _encoder.encode(payload),
      allowMalformed: false,
    );
    final existingEvidence = await database
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
          Variable.withString('ACS03_ELECTRICAL_CONTRACT'),
          Variable.withString(command.contract.doorId),
          Variable.withString(canonicalPayload),
          Variable.withString(contentHash),
          Variable<DateTime>(now),
          Variable.withString(originDeviceId),
        ],
      );
    } else if (existingEvidence.read<String>('payload_sha256') != contentHash) {
      throw StateError('ACS03_EVIDENCE_REF_COLLISION:$evidenceRef');
    }

    final definitionRef = <String, Object?>{
      'policyCode': 'ACS03_ELECTRICAL_CONTRACT',
      'editionId': evidenceRef,
      'contentHash': contentHash,
    };
    final applicability = <String, Object?>{
      'scopeKinds': <String>['DESIGN', 'SCENARIO'],
      'scenarioIds': <String>[],
    };
    final processCodes = <String>['ACS-03'];

    if (command.expectedBindingRevision == null) {
      final currentRows = await database
          .customSelect(
            'SELECT id, process_codes_json FROM discipline_policy_bindings '
            'WHERE project_id = ? AND design_revision_id = ? '
            'AND subject_kind = ? AND subject_id = ? AND deleted_at IS NULL',
            variables: <Variable>[
              Variable.withString(command.projectId),
              Variable.withString(command.designRevisionId),
              Variable.withString('DOOR'),
              Variable.withString(command.contract.doorId),
            ],
          )
          .get();
      for (final row in currentRows) {
        final codes = jsonDecode(row.read<String>('process_codes_json'));
        if (codes is List && codes.contains('ACS-03')) {
          throw StateError(
            'ACS03_ACTIVE_CONTRACT_ALREADY_EXISTS:${row.read<String>('id')}',
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
          Variable.withString('DOOR'),
          Variable.withString(command.contract.doorId),
          Variable.withString(_canonical(processCodes)),
          Variable.withString(_canonical(definitionRef)),
          Variable.withString(contentHash),
          Variable.withString(_canonical(applicability)),
          Variable.withString(_encoder.sha256(applicability)),
        ],
      );
    } else {
      final changedBinding = await database.customUpdate(
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
          Variable.withString('DOOR'),
          Variable.withString(command.contract.doorId),
          Variable<int>(command.expectedBindingRevision!),
        ],
      );
      if (changedBinding != 1) {
        throw StateError('ACS03_CONTRACT_BINDING_CAS_FAILED');
      }
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
    if (changedDesign != 1) {
      throw StateError('ACS03_DESIGN_REVISION_CAS_FAILED');
    }
  });

  String _canonical(Object? value) =>
      utf8.decode(_encoder.encode(value), allowMalformed: false);
}

String _requiredText(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return value.trim();
}
