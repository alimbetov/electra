part of 'app_database.dart';

@DataClassName('ElvRevisionAggregateEvidenceRow')
class ElvRevisionAggregateEvidenceRecords extends Table {
  TextColumn get evidenceRef => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get aggregateKind => text()();
  TextColumn get aggregateId => text()();
  TextColumn get canonicalPayloadJson => text()();
  TextColumn get payloadSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {evidenceRef};
}

@DataClassName('ElvRevisionCommandHistoryOperationRow')
class ElvRevisionCommandHistoryOperations extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  IntColumn get sequence => integer()();
  TextColumn get originalCommandId => text()();
  TextColumn get state => text()();
  TextColumn get forwardCommandType => text()();
  TextColumn get forwardCommandSchema => text()();
  TextColumn get forwardCanonicalPayloadJson => text()();
  TextColumn get forwardPayloadSha256 => text()();
  TextColumn get inverseCommandType => text()();
  TextColumn get inverseCommandSchema => text()();
  TextColumn get inverseCanonicalPayloadJson => text()();
  TextColumn get inversePayloadSha256 => text()();
  @ReferenceName('historyOperationsByBeforeEvidence')
  TextColumn get beforeAggregateEvidenceRef =>
      text().references(ElvRevisionAggregateEvidenceRecords, #evidenceRef)();
  TextColumn get beforeAggregateHash => text()();
  @ReferenceName('historyOperationsByAfterEvidence')
  TextColumn get afterAggregateEvidenceRef =>
      text().references(ElvRevisionAggregateEvidenceRecords, #evidenceRef)();
  TextColumn get afterAggregateHash => text()();
  IntColumn get cursorGeneration => integer()();
  TextColumn get affectedIdsJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, designRevisionId, sequence};
}

@DataClassName('ElvRevisionCommandHistoryCursorRow')
class ElvRevisionCommandHistoryCursors extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  IntColumn get generation => integer()();
  IntColumn get headSequence => integer()();
  TextColumn get branchId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, designRevisionId};
}

@DataClassName('ElvRevisionCommandHistoryExecutionRow')
class ElvRevisionCommandHistoryExecutions extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  IntColumn get historySequence => integer()();
  TextColumn get executionCommandId => text()();
  TextColumn get executionKind => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, executionCommandId};
}
