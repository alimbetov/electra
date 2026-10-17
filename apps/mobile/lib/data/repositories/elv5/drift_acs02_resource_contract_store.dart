import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/acs/acs02_resource_contract.dart';
import '../../database/app_database.dart';
import '../../database/drift_raw_statement.dart';

final class DriftAcs02ResourceContractStore
    implements Acs02ResourceContractSource, Acs02ResourceContractWriter {
  const DriftAcs02ResourceContractStore(
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
  Future<Acs02ResourceContractSnapshot?> loadActiveForController({
    required String projectId,
    required String designRevisionId,
    required String controllerId,
  }) async {
    final rows = await database.customSelect(
      'SELECT id, revision, definition_ref_json FROM discipline_policy_bindings '
      'WHERE project_id = ? AND design_revision_id = ? AND subject_kind = ? '
      'AND subject_id = ? AND deleted_at IS NULL ORDER BY id',
      variables: <Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString('CONTROLLER'),
        Variable.withString(controllerId),
      ],
    ).get();
    final matching = <QueryRow>[];
    for (final row in rows) {
      final raw = jsonDecode(row.read<String>('definition_ref_json'));
      if (raw is Map && raw['policyCode'] == 'ACS02_RESOURCE_CONTRACT') {
        matching.add(row);
      }
    }
    if (matching.isEmpty) return null;
    if (matching.length != 1) {
      throw StateError('ACS02_ACTIVE_CONTRACT_BINDING_AMBIGUOUS:$controllerId');
    }
    final binding = matching.single;
    final raw = jsonDecode(binding.read<String>('definition_ref_json'));
    if (raw is! Map) {
      throw StateError('ACS02_DEFINITION_REF_INVALID:$controllerId');
    }
    final definition = Map<String, Object?>.from(raw);
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
        Variable.withString('ACS02_RESOURCE_CONTRACT'),
        Variable.withString(controllerId),
      ],
    ).getSingleOrNull();
    if (evidence == null) {
      throw StateError('ACS02_CONTRACT_EVIDENCE_MISSING:$evidenceRef');
    }
    final decoded = jsonDecode(evidence.read<String>('canonical_payload_json'));
    if (decoded is! Map) {
      throw StateError('ACS02_CONTRACT_PAYLOAD_INVALID:$evidenceRef');
    }
    final payload = Map<String, Object?>.from(decoded);
    if (_encoder.sha256(payload) != contentHash ||
        evidence.read<String>('payload_sha256') != contentHash) {
      throw StateError('ACS02_CONTRACT_HASH_MISMATCH:$evidenceRef');
    }
    final contract = Acs02ResourceContract.fromMap(payload);
    if (contract.controllerId != controllerId) {
      throw StateError('ACS02_CONTRACT_CONTROLLER_MISMATCH:$controllerId');
    }
    return Acs02ResourceContractSnapshot(
      bindingId: binding.read<String>('id'),
      bindingRevision: binding.read<int>('revision'),
      evidenceRef: evidenceRef,
      contentHash: contentHash,
      contract: contract,
    );
  }

  @override
  Future<void> replace(ReplaceAcs02ResourceContractCommand command) =>
      database.transaction(() async {
        final now = _nowUtc().toUtc();
        final revision = await database.customSelect(
          'SELECT state, revision FROM project_design_revisions '
          'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
          variables: <Variable>[
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
          ],
        ).getSingleOrNull();
        if (revision == null) throw StateError('ACS02_DESIGN_REVISION_NOT_FOUND');
        if (revision.read<String>('state') != 'WORKING') {
          throw StateError('ACS02_DESIGN_REVISION_READ_ONLY');
        }
        if (revision.read<int>('revision') != command.expectedDesignRevision) {
          throw StateError('ACS02_DESIGN_REVISION_CONFLICT');
        }

        final payload = command.contract.toCanonicalValue();
        final hash = _encoder.sha256(payload);
        final ref = 'ACS02:${command.contract.controllerId}:$hash';
        final existing = await database.customSelect(
          'SELECT payload_sha256 FROM elv_revision_aggregate_evidence_records '
          'WHERE evidence_ref = ?',
          variables: <Variable>[Variable.withString(ref)],
        ).getSingleOrNull();
        if (existing == null) {
          await runRawStatement(
            database,
            'INSERT INTO elv_revision_aggregate_evidence_records '
            '(evidence_ref,project_id,design_revision_id,aggregate_kind,aggregate_id,'
            'canonical_payload_json,payload_sha256,created_at,origin_device_id) '
            'VALUES (?,?,?,?,?,?,?,?,?)',
            <Variable>[
              Variable.withString(ref),
              Variable.withString(command.projectId),
              Variable.withString(command.designRevisionId),
              Variable.withString('ACS02_RESOURCE_CONTRACT'),
              Variable.withString(command.contract.controllerId),
              Variable.withString(_canonical(payload)),
              Variable.withString(hash),
              Variable<DateTime>(now),
              Variable.withString(originDeviceId),
            ],
          );
        } else if (existing.read<String>('payload_sha256') != hash) {
          throw StateError('ACS02_EVIDENCE_REF_COLLISION:$ref');
        }

        final definition = <String, Object?>{
          'policyCode': 'ACS02_RESOURCE_CONTRACT',
          'editionId': ref,
          'contentHash': hash,
        };
        final applicability = <String, Object?>{
          'scopeKinds': <String>['DESIGN'],
        };
        if (command.expectedBindingRevision == null) {
          final rows = await database.customSelect(
            'SELECT id, definition_ref_json FROM discipline_policy_bindings '
            'WHERE project_id = ? AND design_revision_id = ? AND subject_kind = ? '
            'AND subject_id = ? AND deleted_at IS NULL',
            variables: <Variable>[
              Variable.withString(command.projectId),
              Variable.withString(command.designRevisionId),
              Variable.withString('CONTROLLER'),
              Variable.withString(command.contract.controllerId),
            ],
          ).get();
          for (final row in rows) {
            final value = jsonDecode(row.read<String>('definition_ref_json'));
            if (value is Map && value['policyCode'] == 'ACS02_RESOURCE_CONTRACT') {
              throw StateError(
                'ACS02_ACTIVE_CONTRACT_ALREADY_EXISTS:${row.read<String>('id')}',
              );
            }
          }
          await runRawStatement(
            database,
            'INSERT INTO discipline_policy_bindings '
            '(project_id,design_revision_id,id,revision,created_at,updated_at,deleted_at,'
            'origin_device_id,subject_kind,subject_id,process_codes_json,definition_ref_json,'
            'definition_sha256,applicability_json,applicability_sha256) '
            'VALUES (?,?,?,1,?,?,NULL,?,?,?,?,?,?,?,?)',
            <Variable>[
              Variable.withString(command.projectId),
              Variable.withString(command.designRevisionId),
              Variable.withString(command.bindingId),
              Variable<DateTime>(now),
              Variable<DateTime>(now),
              Variable.withString(originDeviceId),
              Variable.withString('CONTROLLER'),
              Variable.withString(command.contract.controllerId),
              Variable.withString(_canonical(<String>['ACS-02'])),
              Variable.withString(_canonical(definition)),
              Variable.withString(hash),
              Variable.withString(_canonical(applicability)),
              Variable.withString(_encoder.sha256(applicability)),
            ],
          );
        } else {
          final changed = await database.customUpdate(
            'UPDATE discipline_policy_bindings SET revision = revision + 1, '
            'updated_at = ?, origin_device_id = ?, definition_ref_json = ?, '
            'definition_sha256 = ?, applicability_json = ?, applicability_sha256 = ? '
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
              Variable.withString('CONTROLLER'),
              Variable.withString(command.contract.controllerId),
              Variable<int>(command.expectedBindingRevision!),
            ],
          );
          if (changed != 1) {
            throw StateError('ACS02_CONTRACT_BINDING_CAS_FAILED');
          }
        }

        final changedDesign = await database.customUpdate(
          'UPDATE project_design_revisions SET revision = revision + 1, '
          'updated_at = ?, origin_device_id = ? '
          'WHERE project_id = ? AND id = ? AND revision = ? AND state = ? '
          'AND deleted_at IS NULL',
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
          throw StateError('ACS02_DESIGN_REVISION_CAS_FAILED');
        }
      });

  String _canonical(Object? value) => utf8.decode(_encoder.encode(value));
}

String _text(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be text.');
  }
  return value.trim();
}
