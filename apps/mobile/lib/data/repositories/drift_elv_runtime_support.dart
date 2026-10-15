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
  if (row.outcomeKind != 'SUCCESS') {
    return ElvCommandFailureResult(
      ElvFailure(
        code: 'ELV_REPLAYED_REJECTION',
        category: ElvFailureCategory.validation,
        details: {'logicalResultJson': row.logicalResultJson},
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

ElvCommandFailureResult<T> elvRuntimeFailure<T>(
  String code,
  ElvFailureCategory category, {
  String? entityType,
  String? entityId,
  int? expectedRevision,
  int? actualRevision,
  Map<String, Object?> details = const {},
}) => ElvCommandFailureResult(
  ElvFailure(
    code: code,
    category: category,
    entityType: entityType,
    entityId: entityId,
    expectedRevision: expectedRevision,
    actualRevision: actualRevision,
    details: details,
  ),
);
