import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/acs/acs06_topology_contract.dart';
import '../../../application/elv5/acs/acs06_topology_contract_write.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';

final class DriftAcs06TopologyContractStore
    implements Acs06TopologyContractSource, Acs06TopologyContractWriter {
  const DriftAcs06TopologyContractStore(
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
  Future<Acs06TopologyContractSnapshot?> loadActiveForDoor({
    required String projectId,
    required String designRevisionId,
    required String doorId,
  }) async {
    final rows = await database
        .customSelect(
          'SELECT id, revision, definition_ref_json FROM discipline_policy_bindings '
          'WHERE project_id = ? AND design_revision_id = ? AND subject_kind = ? '
          'AND subject_id = ? AND deleted_at IS NULL ORDER BY id',
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
      final raw = jsonDecode(row.read<String>('definition_ref_json'));
      if (raw is Map && raw['policyCode'] == 'ACS06_TOPOLOGY_CONTRACT') {
        matching.add(row);
      }
    }
    if (matching.isEmpty) return null;
    if (matching.length != 1) {
      throw StateError('ACS06_ACTIVE_CONTRACT_BINDING_AMBIGUOUS:$doorId');
    }

    final binding = matching.single;
    final definitionRaw = jsonDecode(
      binding.read<String>('definition_ref_json'),
    );
    if (definitionRaw is! Map) {
      throw StateError('ACS06_DEFINITION_REF_INVALID:$doorId');
    }
    final definition = Map<String, Object?>.from(definitionRaw);
    final evidenceRef = _text(definition, 'editionId');
    final contentHash = _text(definition, 'contentHash');

    final evidence = await database
        .customSelect(
          'SELECT canonical_payload_json, payload_sha256 '
          'FROM elv_revision_aggregate_evidence_records '
          'WHERE evidence_ref = ? AND project_id = ? AND design_revision_id = ? '
          'AND aggregate_kind = ? AND aggregate_id = ?',
          variables: <Variable>[
            Variable.withString(evidenceRef),
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString('ACS06_TOPOLOGY_CONTRACT'),
            Variable.withString(doorId),
          ],
        )
        .getSingleOrNull();
    if (evidence == null) {
      throw StateError('ACS06_CONTRACT_EVIDENCE_MISSING:$evidenceRef');
    }
    final decoded = jsonDecode(evidence.read<String>('canonical_payload_json'));
    if (decoded is! Map) {
      throw StateError('ACS06_CONTRACT_PAYLOAD_INVALID:$evidenceRef');
    }
    final payload = Map<String, Object?>.from(decoded);
    if (_encoder.sha256(payload) != contentHash ||
        evidence.read<String>('payload_sha256') != contentHash) {
      throw StateError('ACS06_CONTRACT_HASH_MISMATCH:$evidenceRef');
    }
    final contract = Acs06TopologyContract.fromMap(payload);
    if (contract.doorId != doorId) {
      throw StateError(
        'ACS06_CONTRACT_DOOR_MISMATCH:$doorId:${contract.doorId}',
      );
    }
    return Acs06TopologyContractSnapshot(
      bindingId: binding.read<String>('id'),
      bindingRevision: binding.read<int>('revision'),
      evidenceRef: evidenceRef,
      contentHash: contentHash,
      contract: contract,
    );
  }

  @override
  Future<void> replace(
    ReplaceAcs06TopologyContractCommand command,
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
      throw StateError('ACS06_DESIGN_REVISION_NOT_FOUND');
    }
    if (revision.read<String>('state') != 'WORKING') {
      throw StateError('ACS06_DESIGN_REVISION_READ_ONLY');
    }
    if (revision.read<int>('revision') != command.expectedDesignRevision) {
      throw StateError('ACS06_DESIGN_REVISION_CONFLICT');
    }

    final payload = command.contract.toCanonicalValue();
    final hash = _encoder.sha256(payload);
    final evidenceRef = 'ACS06:${command.contract.doorId}:$hash';
    final existing = await database
        .customSelect(
          'SELECT payload_sha256 FROM elv_revision_aggregate_evidence_records '
          'WHERE evidence_ref = ?',
          variables: <Variable>[Variable.withString(evidenceRef)],
        )
        .getSingleOrNull();
    if (existing == null) {
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
          Variable.withString('ACS06_TOPOLOGY_CONTRACT'),
          Variable.withString(command.contract.doorId),
          Variable.withString(_canonical(payload)),
          Variable.withString(hash),
          Variable<DateTime>(now),
          Variable.withString(originDeviceId),
        ],
      );
    } else if (existing.read<String>('payload_sha256') != hash) {
      throw StateError('ACS06_EVIDENCE_REF_COLLISION:$evidenceRef');
    }

    final definition = <String, Object?>{
      'policyCode': 'ACS06_TOPOLOGY_CONTRACT',
      'editionId': evidenceRef,
      'contentHash': hash,
    };
    final applicability = <String, Object?>{
      'scopeKinds': <String>['DESIGN'],
    };

    if (command.expectedBindingRevision == null) {
      final rows = await database
          .customSelect(
            'SELECT id, definition_ref_json FROM discipline_policy_bindings '
            'WHERE project_id = ? AND design_revision_id = ? AND subject_kind = ? '
            'AND subject_id = ? AND deleted_at IS NULL',
            variables: <Variable>[
              Variable.withString(command.projectId),
              Variable.withString(command.designRevisionId),
              Variable.withString('DOOR'),
              Variable.withString(command.contract.doorId),
            ],
          )
          .get();
      for (final row in rows) {
        final decoded = jsonDecode(row.read<String>('definition_ref_json'));
        if (decoded is Map &&
            decoded['policyCode'] == 'ACS06_TOPOLOGY_CONTRACT') {
          throw StateError(
            'ACS06_ACTIVE_CONTRACT_ALREADY_EXISTS:${row.read<String>('id')}',
          );
        }
      }
      await runRawStatement(
        database,
        'INSERT INTO discipline_policy_bindings '
        '(project_id, design_revision_id, id, revision, created_at, updated_at, deleted_at, '
        'origin_device_id, subject_kind, subject_id, process_codes_json, definition_ref_json, '
        'definition_sha256, applicability_json, applicability_sha256) '
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
          Variable.withString(_canonical(<String>['ACS-06'])),
          Variable.withString(_canonical(definition)),
          Variable.withString(hash),
          Variable.withString(_canonical(applicability)),
          Variable.withString(_encoder.sha256(applicability)),
        ],
      );
    } else {
      final changed = await database.customUpdate(
        'UPDATE discipline_policy_bindings SET revision = revision + 1, updated_at = ?, '
        'origin_device_id = ?, definition_ref_json = ?, definition_sha256 = ?, '
        'applicability_json = ?, applicability_sha256 = ? '
        'WHERE project_id = ? AND design_revision_id = ? AND id = ? '
        'AND subject_kind = ? AND subject_id = ? AND revision = ? AND deleted_at IS NULL',
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
          Variable.withString('DOOR'),
          Variable.withString(command.contract.doorId),
          Variable<int>(command.expectedBindingRevision!),
        ],
      );
      if (changed != 1) {
        throw StateError('ACS06_CONTRACT_BINDING_CAS_FAILED');
      }
    }

    final changedDesign = await database.customUpdate(
      'UPDATE project_design_revisions SET revision = revision + 1, updated_at = ?, '
      'origin_device_id = ? WHERE project_id = ? AND id = ? AND revision = ? '
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
      throw StateError('ACS06_DESIGN_REVISION_CAS_FAILED');
    }
  });

  String _canonical(Object? value) => utf8.decode(_encoder.encode(value));
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be non-empty text.');
  }
  return value.trim();
}
