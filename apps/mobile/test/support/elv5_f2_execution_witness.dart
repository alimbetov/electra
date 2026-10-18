import 'dart:convert';
import 'package:drift/drift.dart' show Variable;
import 'package:electra_mobile/application/elv5/calculation/elv5_qualification_identity_source.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

/// Read the committed frozen row anew; never synthesize a source identity from
/// fixture input/output. Ordinary unaddressed developer runs emit no witness.
Future<void> emitF2PersistedWitness(AppDatabase db, String processCode) async {
  const source = String.fromEnvironment('ELECTRA_SOURCE_SHA');
  if (source.isEmpty) return;
  const encoder = Elv5CanonicalJsonV1();
  final code = Elv5ProcessCode.parse(processCode);
  final expected = Elv5BuildQualificationIdentitySource.fromEnvironment()
      .forProcess(code);
  final row =
      await db
          .customSelect(
            'SELECT r.*, p.generation AS observed_generation, p.freshness AS observed_freshness, d.state AS observed_revision_state '
            'FROM discipline_evaluation_pointers p JOIN discipline_evaluation_records r ON r.project_id=p.project_id AND r.design_revision_id=p.design_revision_id AND r.evaluation_id=p.evaluation_id '
            'JOIN project_design_revisions d ON d.project_id=p.project_id AND d.id=p.design_revision_id '
            'WHERE p.project_id = ? AND p.design_revision_id = ? AND r.process_code = ?',
            variables: [
              Variable.withString('p'),
              Variable.withString('d'),
              Variable.withString(processCode),
            ],
          )
          .getSingle();
  final evidence = Map<String, Object?>.from(
    jsonDecode(row.read<String>('evidence_json')) as Map,
  );
  final identity = Elv5QualificationIdentity.fromMap(
    Map<String, Object?>.from(
      evidence['foundationQualificationIdentity'] as Map,
    ),
  );
  expect(identity.toCanonicalValue(), expected.toCanonicalValue());
  expect(
    evidence['foundationQualificationIdentitySha256'],
    identity.canonicalSha256(),
  );
  expect(encoder.sha256(evidence), row.read<String>('evidence_sha256'));
  expect(
    encoder.sha256(jsonDecode(row.read<String>('output_json'))),
    row.read<String>('output_sha256'),
  );
  expect(row.read<String>('observed_freshness'), 'CURRENT');
  expect(row.read<String>('observed_revision_state'), 'FROZEN');
  expect(row.read<String>('execution'), 'SUCCEEDED');
  expect(row.read<String>('completion'), 'COMPLETE');
  print(
    'ELV5_F2_WITNESS:${jsonEncode({'schema': 'electra.elv5-f2-lifecycle-event.v1', 'processCode': processCode, 'sourceSha': source, 'stage': 'PERSISTED_IDENTITY', 'qualificationIdentity': identity.toCanonicalValue(), 'authorityManifest': Elv5FoundationAuthorityManifest.instance.toCanonicalValue(), 'evaluationId': row.read<String>('evaluation_id'), 'nodeKeySha256': row.read<String>('logical_node_key_sha256'), 'inputFingerprint': row.read<String>('input_fingerprint'), 'outputSha256': row.read<String>('output_sha256'), 'evidenceSha256': row.read<String>('evidence_sha256'), 'pointerGeneration': row.read<int>('observed_generation'), 'freshness': row.read<String>('observed_freshness'), 'revisionState': row.read<String>('observed_revision_state'), 'execution': row.read<String>('execution'), 'completion': row.read<String>('completion'), 'assessment': row.read<String>('assessment')})}',
  );
}
