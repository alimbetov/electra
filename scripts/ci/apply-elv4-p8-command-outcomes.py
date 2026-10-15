from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {count}')
    path.write_text(text.replace(old, new, 1))


support = Path('apps/mobile/lib/data/repositories/drift_elv_runtime_support.dart')
repo = Path('apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart')

replace_once(
    support,
    """  if (row.outcomeKind != 'SUCCESS') {\n    return ElvCommandFailureResult(\n      ElvFailure(\n        code: 'ELV_REPLAYED_REJECTION',\n        category: ElvFailureCategory.validation,\n        details: {'logicalResultJson': row.logicalResultJson},\n      ),\n    );\n  }\n""",
    """  if (row.outcomeKind == 'REJECTED') {\n    return ElvCommandFailureResult(\n      _failureFromMap(\n        jsonDecode(row.logicalResultJson) as Map<String, dynamic>,\n      ),\n    );\n  }\n  if (row.outcomeKind != 'SUCCESS') {\n    return const ElvCommandFailureResult(\n      ElvFailure(\n        code: 'ELV_COMMAND_LEDGER_INVALID_OUTCOME',\n        category: ElvFailureCategory.storage,\n      ),\n    );\n  }\n""",
)

anchor = """ElvCommandFailureResult<T> elvRuntimeFailure<T>(\n"""
insert = """Future<ElvCommandFailureResult<T>> recordElvRuntimeRejection<T>({\n  required AppDatabase database,\n  required String projectId,\n  required String commandId,\n  required String commandType,\n  required String schema,\n  required Map<String, Object?> payload,\n  required ElvFailure failure,\n  required String originDeviceId,\n  DateTime? now,\n}) async {\n  final instant = (now ?? DateTime.now()).toUtc();\n  await database\n      .into(database.commandExecutionRecords)\n      .insert(\n        CommandExecutionRecordsCompanion.insert(\n          projectId: projectId,\n          commandId: commandId,\n          commandType: commandType,\n          payloadSchemaVersion: 1,\n          normalizedPayloadSha256: elvRuntimeFingerprint(schema, payload),\n          outcomeKind: 'REJECTED',\n          logicalResultJson: canonicalEngineeringJsonV1(_failureToMap(failure)),\n          createdAt: instant,\n          committedAt: instant,\n          originDeviceId: originDeviceId,\n        ),\n      );\n  return ElvCommandFailureResult(failure);\n}\n\nMap<String, Object?> _failureToMap(ElvFailure failure) => {\n  'code': failure.code,\n  'category': failure.category.name,\n  'entityType': failure.entityType,\n  'entityId': failure.entityId,\n  'field': failure.field,\n  'expectedRevision': failure.expectedRevision,\n  'actualRevision': failure.actualRevision,\n  'details': failure.details,\n};\n\nElvFailure _failureFromMap(Map<String, dynamic> map) => ElvFailure(\n  code: map['code']! as String,\n  category: ElvFailureCategory.values.byName(map['category']! as String),\n  entityType: map['entityType'] as String?,\n  entityId: map['entityId'] as String?,\n  field: map['field'] as String?,\n  expectedRevision: (map['expectedRevision'] as num?)?.toInt(),\n  actualRevision: (map['actualRevision'] as num?)?.toInt(),\n  details: Map<String, Object?>.from(\n    map['details'] as Map? ?? const <String, Object?>{},\n  ),\n);\n\nElvCommandFailureResult<T> elvRuntimeFailure<T>(\n"""
replace_once(support, anchor, insert)

replace_once(
    support,
    """  String? entityId,\n  int? expectedRevision,\n""",
    """  String? entityId,\n  String? field,\n  int? expectedRevision,\n""",
)
replace_once(
    support,
    """    entityId: entityId,\n    expectedRevision: expectedRevision,\n""",
    """    entityId: entityId,\n    field: field,\n    expectedRevision: expectedRevision,\n""",
)

replace_once(
    repo,
    """    if (row == null) {\n      return elvRuntimeFailure(\n        'ELV_DESIGN_REVISION_NOT_FOUND',\n        ElvFailureCategory.notFound,\n      );\n    }\n    if (row.state != 'WORKING') {\n      return elvRuntimeFailure(\n        'ELV_DESIGN_REVISION_NOT_WORKING',\n        ElvFailureCategory.lifecycle,\n      );\n    }\n    if (row.revision != command.expectedRevision) {\n      return elvRuntimeFailure(\n        'ELV_DESIGN_REVISION_REVISION_CONFLICT',\n        ElvFailureCategory.revisionConflict,\n        expectedRevision: command.expectedRevision,\n        actualRevision: row.revision,\n      );\n    }\n""",
    """    if (row == null) {\n      return recordElvRuntimeRejection<ProjectDesignRevision>(\n        database: database,\n        projectId: command.projectId,\n        commandId: command.commandId,\n        commandType: type,\n        schema: schema,\n        payload: payload,\n        failure: const ElvFailure(\n          code: 'ELV_DESIGN_REVISION_NOT_FOUND',\n          category: ElvFailureCategory.notFound,\n        ),\n        originDeviceId: originDeviceId,\n        now: _now(),\n      );\n    }\n    if (row.state != 'WORKING') {\n      return recordElvRuntimeRejection<ProjectDesignRevision>(\n        database: database,\n        projectId: command.projectId,\n        commandId: command.commandId,\n        commandType: type,\n        schema: schema,\n        payload: payload,\n        failure: const ElvFailure(\n          code: 'ELV_DESIGN_REVISION_NOT_WORKING',\n          category: ElvFailureCategory.lifecycle,\n        ),\n        originDeviceId: originDeviceId,\n        now: _now(),\n      );\n    }\n    if (row.revision != command.expectedRevision) {\n      return recordElvRuntimeRejection<ProjectDesignRevision>(\n        database: database,\n        projectId: command.projectId,\n        commandId: command.commandId,\n        commandType: type,\n        schema: schema,\n        payload: payload,\n        failure: ElvFailure(\n          code: 'ELV_DESIGN_REVISION_REVISION_CONFLICT',\n          category: ElvFailureCategory.revisionConflict,\n          expectedRevision: command.expectedRevision,\n          actualRevision: row.revision,\n        ),\n        originDeviceId: originDeviceId,\n        now: _now(),\n      );\n    }\n""",
)

print('Applied P8 command outcome durability patch.')
