import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../database/app_database.dart';

String elvRuntimeFingerprint(String schema, Map<String, Object?> payload) =>
    sha256HexUtf8(
      canonicalEngineeringJsonV1({'schema': schema, 'payload': payload}),
    );

Future<ElvCommandResult<T>?> replayElvRuntimeCommand<T>({
  required AppDatabase database,
  required String projectId,
  required String commandId,
  required String commandType,
  required String schema,
  required Map<String, Object?> payload,
  required T Function(Map<String, dynamic>) decode,
}) async {
  final row =
      await (database.select(database.commandExecutionRecords)..where(
            (candidate) =>
                candidate.projectId.equals(projectId) &
                candidate.commandId.equals(commandId),
          ))
          .getSingleOrNull();
  if (row == null) return null;
  final expected = elvRuntimeFingerprint(schema, payload);
  if (row.commandType != commandType ||
      row.normalizedPayloadSha256 != expected) {
    return const ElvCommandFailureResult(
      ElvFailure(
        code: 'ELV_IDEMPOTENCY_CONFLICT',
        category: ElvFailureCategory.commandEnvelope,
      ),
    );
  }
  if (row.outcomeKind == 'REJECTED') {
    return ElvCommandFailureResult(
      _failureFromMap(
        jsonDecode(row.logicalResultJson) as Map<String, dynamic>,
      ),
    );
  }
  if (row.outcomeKind != 'SUCCESS') {
    return const ElvCommandFailureResult(
      ElvFailure(
        code: 'ELV_COMMAND_LEDGER_INVALID_OUTCOME',
        category: ElvFailureCategory.storage,
      ),
    );
  }
  return ElvCommandSuccess(
    decode(jsonDecode(row.logicalResultJson) as Map<String, dynamic>),
  );
}

Future<void> recordElvRuntimeSuccess({
  required AppDatabase database,
  required String projectId,
  required String commandId,
  required String commandType,
  required String schema,
  required Map<String, Object?> payload,
  required Map<String, Object?> result,
  required String originDeviceId,
  DateTime? now,
}) async {
  final instant = (now ?? DateTime.now()).toUtc();
  await database
      .into(database.commandExecutionRecords)
      .insert(
        CommandExecutionRecordsCompanion.insert(
          projectId: projectId,
          commandId: commandId,
          commandType: commandType,
          payloadSchemaVersion: 1,
          normalizedPayloadSha256: elvRuntimeFingerprint(schema, payload),
          outcomeKind: 'SUCCESS',
          logicalResultJson: canonicalEngineeringJsonV1(result),
          createdAt: instant,
          committedAt: instant,
          originDeviceId: originDeviceId,
        ),
      );
}

Future<ElvCommandFailureResult<T>> recordElvRuntimeRejection<T>({
  required AppDatabase database,
  required String projectId,
  required String commandId,
  required String commandType,
  required String schema,
  required Map<String, Object?> payload,
  required ElvFailure failure,
  required String originDeviceId,
  DateTime? now,
}) async {
  final instant = (now ?? DateTime.now()).toUtc();
  await database
      .into(database.commandExecutionRecords)
      .insert(
        CommandExecutionRecordsCompanion.insert(
          projectId: projectId,
          commandId: commandId,
          commandType: commandType,
          payloadSchemaVersion: 1,
          normalizedPayloadSha256: elvRuntimeFingerprint(schema, payload),
          outcomeKind: 'REJECTED',
          logicalResultJson: canonicalEngineeringJsonV1(_failureToMap(failure)),
          createdAt: instant,
          committedAt: instant,
          originDeviceId: originDeviceId,
        ),
      );
  return ElvCommandFailureResult(failure);
}

Map<String, Object?> _failureToMap(ElvFailure failure) => {
  'code': failure.code,
  'category': failure.category.name,
  'entityType': failure.entityType,
  'entityId': failure.entityId,
  'field': failure.field,
  'expectedRevision': failure.expectedRevision,
  'actualRevision': failure.actualRevision,
  'details': failure.details,
};

ElvFailure _failureFromMap(Map<String, dynamic> map) => ElvFailure(
  code: map['code']! as String,
  category: ElvFailureCategory.values.byName(map['category']! as String),
  entityType: map['entityType'] as String?,
  entityId: map['entityId'] as String?,
  field: map['field'] as String?,
  expectedRevision: (map['expectedRevision'] as num?)?.toInt(),
  actualRevision: (map['actualRevision'] as num?)?.toInt(),
  details: Map<String, Object?>.from(
    map['details'] as Map? ?? const <String, Object?>{},
  ),
);

ElvCommandFailureResult<T> elvRuntimeFailure<T>(
  String code,
  ElvFailureCategory category, {
  String? entityType,
  String? entityId,
  String? field,
  int? expectedRevision,
  int? actualRevision,
  Map<String, Object?> details = const {},
}) => ElvCommandFailureResult(
  ElvFailure(
    code: code,
    category: category,
    entityType: entityType,
    entityId: entityId,
    field: field,
    expectedRevision: expectedRevision,
    actualRevision: actualRevision,
    details: details,
  ),
);
