import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core_elv5.dart';

import '../../../application/elv5/calculation/elv5_current_evaluation_source.dart';
import '../../database/app_database.dart';

final class DriftElv5CurrentEvaluationSource
    implements Elv5CurrentEvaluationSource {
  const DriftElv5CurrentEvaluationSource(this.database);

  final AppDatabase database;

  @override
  Future<List<Elv5CurrentEvaluationSnapshot>> loadCurrent({
    required String projectId,
    required String designRevisionId,
    required Elv5ProcessCode processCode,
    String? scopeKind,
    String? scopeId,
    String? scenarioKey,
    String? subjectKind,
    String? subjectId,
  }) async {
    final rows = await database.customSelect(
      'SELECT p.logical_node_key_sha256 AS pointer_node_sha, p.generation AS pointer_generation, '
      'r.process_code, r.scope_kind, r.scope_id, r.scenario_key, r.subject_kind, r.subject_id, '
      'r.evaluation_id, r.input_fingerprint, r.output_sha256, r.evidence_sha256, '
      'r.execution, r.completion, r.assessment, r.output_json, r.evidence_json '
      'FROM discipline_evaluation_pointers p '
      'JOIN discipline_evaluation_records r ON r.project_id = p.project_id '
      'AND r.design_revision_id = p.design_revision_id AND r.evaluation_id = p.evaluation_id '
      'WHERE p.project_id = ? AND p.design_revision_id = ? AND p.freshness = ? '
      'AND r.process_code = ? ORDER BY p.logical_node_key_sha256',
      variables:<Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
        Variable.withString('CURRENT'),
        Variable.withString(processCode.wireCode),
      ],
    ).get();

    final result = <Elv5CurrentEvaluationSnapshot>[];
    for (final row in rows) {
      final rowScopeKind = row.read<String>('scope_kind');
      final rowScopeId = row.read<String>('scope_id');
      final rowScenario = row.read<String>('scenario_key');
      final rowSubjectKind = row.read<String>('subject_kind');
      final rowSubjectId = row.read<String>('subject_id');
      if (scopeKind != null && rowScopeKind != scopeKind) continue;
      if (scopeId != null && rowScopeId != scopeId) continue;
      if (scenarioKey != null && rowScenario != scenarioKey) continue;
      if (subjectKind != null && rowSubjectKind != subjectKind) continue;
      if (subjectId != null && rowSubjectId != subjectId) continue;
      result.add(Elv5CurrentEvaluationSnapshot(
        logicalNodeKeySha256:row.read<String>('pointer_node_sha'),
        processCode:Elv5ProcessCode.parse(row.read<String>('process_code')),
        scopeKind:rowScopeKind,
        scopeId:rowScopeId,
        scenarioKey:rowScenario,
        subjectKind:rowSubjectKind,
        subjectId:rowSubjectId,
        evaluationId:row.read<String>('evaluation_id'),
        inputFingerprint:row.read<String>('input_fingerprint'),
        outputSha256:row.read<String>('output_sha256'),
        evidenceSha256:row.read<String>('evidence_sha256'),
        pointerGeneration:row.read<int>('pointer_generation'),
        execution:row.read<String>('execution'),
        completion:row.read<String>('completion'),
        assessment:row.read<String>('assessment'),
        output:_object(row.read<String>('output_json'),'output_json'),
        evidence:_object(row.read<String>('evidence_json'),'evidence_json'),
      ));
    }
    return List.unmodifiable(result);
  }

  Map<String,Object?> _object(String json,String field){
    final decoded=jsonDecode(json);
    if(decoded is! Map)throw StateError('ELV5_CURRENT_$field must decode to object.');
    return Map<String,Object?>.from(decoded);
  }
}
