import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv4_qualification_matrix.dart';
import '../database/app_database.dart';

final class Elv4QualificationCaseScope {
  const Elv4QualificationCaseScope({
    required this.caseId,
    required this.projectId,
    required this.designRevisionId,
  });

  final String caseId;
  final String projectId;
  final String designRevisionId;
}

final class Elv4PersistedQualificationEvidence {
  const Elv4PersistedQualificationEvidence({
    required this.row,
    required this.logicalNodeKey,
    required this.evidenceSha256,
    required this.inputFingerprint,
    required this.pointerGeneration,
  });

  final Elv4QualificationEvidenceRow row;
  final String logicalNodeKey;
  final String evidenceSha256;
  final String inputFingerprint;
  final int pointerGeneration;

  Map<String, Object?> toReportMap() => {
    'context': row.context,
    'processCode': row.processCode,
    'dimension': row.dimension,
    'completion': row.completion,
    'assessment': row.assessment,
    'execution': row.execution,
    'evaluationId': row.evaluationId,
    'logicalNodeKey': logicalNodeKey,
    'evidenceSha256': evidenceSha256,
    'inputFingerprint': inputFingerprint,
    'pointerGeneration': pointerGeneration,
  };
}

/// Converts only immutable, CURRENT, PASS runtime evaluation evidence into the
/// exact process/context/dimension qualification matrix.
///
/// The manifest defines obligations, never outcomes. A required process/context
/// must resolve to exactly one persisted aggregate evaluation. The reader
/// verifies the evidence digest, embedded logical node identity, pointer
/// identity and input fingerprint before dimensions are expanded from that
/// evaluation. Missing, stale or ambiguous runtime evidence fails closed.
final class DriftElv4QualificationEvidenceReader {
  const DriftElv4QualificationEvidenceReader(this.database);

  final AppDatabase database;

  static Map<String, Elv4QualificationCaseScope> caseScopesFromManifest(
    Map<String, Object?> manifest,
  ) {
    final cases = manifest['positiveCases'];
    if (cases is! List) {
      throw const FormatException('positiveCases must be an array.');
    }
    final result = <String, Elv4QualificationCaseScope>{};
    for (final raw in cases) {
      if (raw is! Map) {
        throw const FormatException('positiveCases entries must be objects.');
      }
      final value = raw.cast<String, Object?>();
      final caseId = _text(value['id'], 'positiveCases.id');
      final factsRaw = value['facts'];
      if (factsRaw is! Map) {
        throw FormatException('$caseId.facts must be an object.');
      }
      final facts = factsRaw.cast<String, Object?>();
      final scope = Elv4QualificationCaseScope(
        caseId: caseId,
        projectId: _text(facts['projectId'], '$caseId.facts.projectId'),
        designRevisionId: _text(
          facts['designRevisionId'],
          '$caseId.facts.designRevisionId',
        ),
      );
      if (result.containsKey(caseId)) {
        throw FormatException('Duplicate qualification case scope: $caseId.');
      }
      result[caseId] = scope;
    }
    return Map.unmodifiable(result);
  }

  Future<List<Elv4PersistedQualificationEvidence>> collect({
    required Elv4QualificationMatrixContract contract,
    required Map<String, Elv4QualificationCaseScope> caseScopes,
  }) async {
    final required = contract.requiredCaseIds.toSet();
    if (caseScopes.keys.toSet().difference(required).isNotEmpty ||
        required.difference(caseScopes.keys.toSet()).isNotEmpty) {
      throw StateError(
        'Qualification case scopes must exactly match required case ids.',
      );
    }

    final output = <Elv4PersistedQualificationEvidence>[];
    for (final caseId in contract.requiredCaseIds) {
      final scope = caseScopes[caseId]!;
      final persisted = await _loadCurrentPassEvaluations(scope);
      final obligations = contract.expectedRows
          .where((row) => row.caseId == caseId)
          .toList(growable: false);
      final grouped = <String, List<Elv4QualificationExpectedRow>>{};
      for (final obligation in obligations) {
        grouped
            .putIfAbsent(
              '${obligation.processCode}|${obligation.context}',
              () => <Elv4QualificationExpectedRow>[],
            )
            .add(obligation);
      }

      for (final entry in grouped.entries) {
        final parts = entry.key.split('|');
        final processCode = parts[0];
        final context = parts[1];
        final matches = persisted
            .where(
              (candidate) =>
                  candidate.processCode == processCode &&
                  candidate.context == context,
            )
            .toList(growable: false);
        if (matches.length != 1) {
          throw StateError(
            'Qualification $caseId/$processCode/$context requires exactly one '
            'CURRENT aggregate evaluation; found ${matches.length}.',
          );
        }
        final evidence = matches.single;
        for (final obligation in entry.value) {
          output.add(
            Elv4PersistedQualificationEvidence(
              row: Elv4QualificationEvidenceRow(
                caseId: caseId,
                processCode: obligation.processCode,
                context: obligation.context,
                dimension: obligation.dimension,
                completion: obligation.completion,
                assessment: obligation.assessment,
                execution: obligation.execution,
                evaluationId: evidence.evaluationId,
              ),
              logicalNodeKey: evidence.logicalNodeKey,
              evidenceSha256: evidence.evidenceSha256,
              inputFingerprint: evidence.inputFingerprint,
              pointerGeneration: evidence.pointerGeneration,
            ),
          );
        }
      }
    }

    contract.validateEvidence(output.map((value) => value.row));
    output.sort((a, b) => a.row.key.compareTo(b.row.key));
    return List.unmodifiable(output);
  }

  Future<List<_PersistedEvaluation>> _loadCurrentPassEvaluations(
    Elv4QualificationCaseScope scope,
  ) async {
    final rows =
        await database
            .customSelect(
              'SELECT e.logical_node_key_json, e.evaluation_id, e.process_code, '
              'e.input_fingerprint, e.status, e.applicability, e.evidence_json, '
              'e.evidence_sha256, p.generation, p.state AS pointer_state, '
              'p.evaluation_id AS pointer_evaluation_id, '
              'p.evidence_sha256 AS pointer_evidence_sha256 '
              'FROM power_evaluation_records e '
              'JOIN power_evaluation_pointers p '
              'ON p.project_id = e.project_id '
              'AND p.design_revision_id = e.design_revision_id '
              'AND p.logical_node_key_sha256 = e.logical_node_key_sha256 '
              'WHERE e.project_id = ? AND e.design_revision_id = ?',
              variables: [
                Variable.withString(scope.projectId),
                Variable.withString(scope.designRevisionId),
              ],
            )
            .get();

    final result = <_PersistedEvaluation>[];
    for (final row in rows) {
      if (row.read<String>('status') != 'PASS' ||
          row.read<String>('applicability') != 'APPLICABLE' ||
          row.read<String>('pointer_state') != 'CURRENT') {
        continue;
      }
      final evaluationId = row.read<String>('evaluation_id');
      final evidenceSha256 = row.read<String>('evidence_sha256');
      if (row.readNullable<String>('pointer_evaluation_id') != evaluationId ||
          row.readNullable<String>('pointer_evidence_sha256') !=
              evidenceSha256) {
        throw StateError(
          'Qualification ${scope.caseId} pointer identity mismatch for '
          '$evaluationId.',
        );
      }
      final evidenceJson = row.read<String>('evidence_json');
      if (sha256HexUtf8(evidenceJson) != evidenceSha256) {
        throw StateError(
          'Qualification ${scope.caseId} evidence hash mismatch for '
          '$evaluationId.',
        );
      }
      final decoded = jsonDecode(evidenceJson);
      if (decoded is! Map) {
        throw StateError('Qualification evidence must decode as an object.');
      }
      final evidence = decoded.cast<String, Object?>();
      final logicalNodeKey = row.read<String>('logical_node_key_json');
      final node = PowerNodeKeyV2.decode(logicalNodeKey);
      final embeddedNode = evidence['logicalNodeKey'];
      if (embeddedNode is! List ||
          canonicalEngineeringJsonV1(embeddedNode) != logicalNodeKey ||
          evidence['evaluationId'] != evaluationId ||
          evidence['status'] != 'PASS' ||
          evidence['applicability'] != 'APPLICABLE') {
        throw StateError(
          'Qualification ${scope.caseId} immutable evidence identity mismatch '
          'for $evaluationId.',
        );
      }
      final inputFingerprint = row.read<String>('input_fingerprint');
      if (evidence['inputFingerprint'] != inputFingerprint ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(inputFingerprint)) {
        throw StateError(
          'Qualification ${scope.caseId} input fingerprint mismatch for '
          '$evaluationId.',
        );
      }
      result.add(
        _PersistedEvaluation(
          evaluationId: evaluationId,
          logicalNodeKey: logicalNodeKey,
          processCode: row.read<String>('process_code'),
          context: _context(node),
          evidenceSha256: evidenceSha256,
          inputFingerprint: inputFingerprint,
          pointerGeneration: row.read<int>('generation'),
        ),
      );
    }
    return result;
  }
}

final class _PersistedEvaluation {
  const _PersistedEvaluation({
    required this.evaluationId,
    required this.logicalNodeKey,
    required this.processCode,
    required this.context,
    required this.evidenceSha256,
    required this.inputFingerprint,
    required this.pointerGeneration,
  });

  final String evaluationId;
  final String logicalNodeKey;
  final String processCode;
  final String context;
  final String evidenceSha256;
  final String inputFingerprint;
  final int pointerGeneration;
}

String _context(PowerNodeKeyV2 node) =>
    node.scopeKind == PowerEvaluationScopeKind.sequence
        ? '${node.scenarioId}/SEQUENCE'
        : '${node.scenarioId}/${node.scopeId}';

String _text(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string.');
  }
  return value.trim();
}
