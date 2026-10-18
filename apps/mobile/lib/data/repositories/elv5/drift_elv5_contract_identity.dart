import 'package:engineering_core/engineering_core_elv5.dart';
import '../../database/app_database.dart';
import 'drift_elv5_dependency_invalidator.dart';

/// Payload identity includes revision ownership; historical refs stay readable.
String elv5ContractEvidenceRef({
  required String projectId,
  required String designRevisionId,
  required String kind,
  required String subjectId,
  required String payloadSha256,
}) =>
    '$kind:${const Elv5CanonicalJsonV1().sha256({'schema': 'electra.elv5-contract-evidence-identity.v2', 'projectId': projectId, 'designRevisionId': designRevisionId, 'kind': kind, 'subjectId': subjectId, 'payloadSha256': payloadSha256})}';

Future<int> invalidateElv5ContractSelector(
  AppDatabase database, {
  required String projectId,
  required String designRevisionId,
  required String processCode,
  required String subjectId,
  required String originDeviceId,
}) => DriftElv5DependencyInvalidator(
  database,
  originDeviceId: originDeviceId,
).invalidateSubject(
  projectId: projectId,
  designRevisionId: designRevisionId,
  relationKind: 'SET',
  domain: 'PROCESS_INPUT_SELECTOR',
  subjectId: '$processCode:$subjectId',
);
