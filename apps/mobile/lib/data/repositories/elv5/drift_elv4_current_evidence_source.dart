import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../../application/elv5/power/elv4_current_evidence_source.dart';
import '../../database/app_database.dart';

/// Runtime-grade ELV4 evidence reader for ELV5 resolvers.
///
/// This intentionally repeats the identity/hash checks used by ELV4
/// qualification rather than trusting a row merely because it exists.
final class DriftElv4CurrentEvidenceSource
    implements Elv4CurrentEvidenceSource {
  const DriftElv4CurrentEvidenceSource(this.database);

  final AppDatabase database;

  @override
  Future<List<Elv4CurrentEvaluationSnapshot>> loadCurrent({
    required String projectId,
    required String designRevisionId,
    required PowerProcessCode processCode,
    String? scenarioId,
    PowerEvaluationScopeKind? scopeKind,
    String? scopeId,
    String? subjectKind,
    String? subjectId,
  }) async {
    final rows =
        await database
            .customSelect(
              'SELECT e.logical_node_key_json, e.logical_node_key_sha256, '
              'e.evaluation_id, e.input_fingerprint, e.evidence_json, '
              'e.evidence_sha256, p.generation, p.state AS pointer_state, '
              'p.evaluation_id AS pointer_evaluation_id, '
              'p.evidence_sha256 AS pointer_evidence_sha256 '
              'FROM power_evaluation_records e '
              'JOIN power_evaluation_pointers p '
              'ON p.project_id = e.project_id '
              'AND p.design_revision_id = e.design_revision_id '
              'AND p.logical_node_key_sha256 = e.logical_node_key_sha256 '
              'WHERE e.project_id = ? AND e.design_revision_id = ? '
              'AND e.process_code = ? AND p.state = ?',
              variables: <Variable>[
                Variable.withString(projectId),
                Variable.withString(designRevisionId),
                Variable.withString(_wire(processCode)),
                Variable.withString('CURRENT'),
              ],
            )
            .get();

    final result = <Elv4CurrentEvaluationSnapshot>[];
    for (final row in rows) {
      final nodeJson = row.read<String>('logical_node_key_json');
      final node = PowerNodeKeyV2.decode(nodeJson);
      if (node.revisionId != designRevisionId ||
          (scenarioId != null && node.scenarioId != scenarioId) ||
          (scopeKind != null && node.scopeKind != scopeKind) ||
          (scopeId != null && node.scopeId != scopeId) ||
          (subjectKind != null && node.subjectKind != subjectKind) ||
          (subjectId != null && node.subjectId != subjectId)) {
        continue;
      }
      if (node.sha256 != row.read<String>('logical_node_key_sha256')) {
        throw StateError('ELV4_CURRENT_NODE_HASH_MISMATCH:${node.encode()}');
      }

      final evaluationId = row.read<String>('evaluation_id');
      final evidenceSha = row.read<String>('evidence_sha256');
      if (row.readNullable<String>('pointer_evaluation_id') != evaluationId ||
          row.readNullable<String>('pointer_evidence_sha256') != evidenceSha) {
        throw StateError(
          'ELV4_CURRENT_POINTER_IDENTITY_MISMATCH:$evaluationId',
        );
      }

      final evidenceJson = row.read<String>('evidence_json');
      if (sha256HexUtf8(evidenceJson) != evidenceSha) {
        throw StateError('ELV4_CURRENT_EVIDENCE_HASH_MISMATCH:$evaluationId');
      }
      final decoded = jsonDecode(evidenceJson);
      if (decoded is! Map) {
        throw StateError('ELV4_CURRENT_EVIDENCE_NOT_OBJECT:$evaluationId');
      }
      final evidence = decoded.cast<String, Object?>();
      final embeddedNode = evidence['logicalNodeKey'];
      final inputFingerprint = row.read<String>('input_fingerprint');
      if (embeddedNode is! List ||
          canonicalEngineeringJsonV1(embeddedNode) != nodeJson ||
          evidence['evaluationId'] != evaluationId ||
          evidence['inputFingerprint'] != inputFingerprint) {
        throw StateError(
          'ELV4_CURRENT_EMBEDDED_IDENTITY_MISMATCH:$evaluationId',
        );
      }
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(inputFingerprint)) {
        throw StateError(
          'ELV4_CURRENT_INPUT_FINGERPRINT_INVALID:$evaluationId',
        );
      }

      result.add(
        Elv4CurrentEvaluationSnapshot(
          nodeKey: node,
          evaluationId: evaluationId,
          inputFingerprint: inputFingerprint,
          evidenceSha256: evidenceSha,
          pointerGeneration: row.read<int>('generation'),
          evidence: evidence,
        ),
      );
    }
    result.sort((a, b) => a.nodeKey.compareTo(b.nodeKey));
    return List.unmodifiable(result);
  }
}

String _wire(PowerProcessCode value) => switch (value) {
  PowerProcessCode.pwr01 => 'ELV-PWR-01',
  PowerProcessCode.pwr02 => 'ELV-PWR-02',
  PowerProcessCode.pwr03 => 'ELV-PWR-03',
  PowerProcessCode.pwr04 => 'ELV-PWR-04',
  PowerProcessCode.pwr05 => 'ELV-PWR-05',
  PowerProcessCode.pwr06 => 'ELV-PWR-06',
};
