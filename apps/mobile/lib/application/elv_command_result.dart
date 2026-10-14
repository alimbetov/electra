enum ElvFailureCategory {
  commandEnvelope,
  notFound,
  projectIsolation,
  lifecycle,
  revisionConflict,
  referenceIntegrity,
  validation,
  dependencyImpact,
  storage,
}

final class ElvFailure {
  const ElvFailure({
    required this.code,
    required this.category,
    this.entityType,
    this.entityId,
    this.field,
    this.expectedRevision,
    this.actualRevision,
    this.details = const {},
  });

  final String code;
  final ElvFailureCategory category;
  final String? entityType;
  final String? entityId;
  final String? field;
  final int? expectedRevision;
  final int? actualRevision;
  final Map<String, Object?> details;
}

sealed class ElvCommandResult<T> {
  const ElvCommandResult();
}

final class ElvCommandSuccess<T> extends ElvCommandResult<T> {
  const ElvCommandSuccess(this.value);
  final T value;
}

final class ElvCommandFailureResult<T> extends ElvCommandResult<T> {
  const ElvCommandFailureResult(this.failure);
  final ElvFailure failure;
}
