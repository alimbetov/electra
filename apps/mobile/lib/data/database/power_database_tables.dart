part of 'app_database.dart';

mixin PowerRevisionAuditColumns on Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get id => text()();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get originDeviceId => text()();
}

@DataClassName('PowerPortBindingRow')
class PowerPortBindings extends Table with PowerRevisionAuditColumns {
  TextColumn get portId => text().references(EngineeringPortInstances, #id)();
  TextColumn get resolvedProfileJson => text()();
  TextColumn get profileSchema => text()();
  TextColumn get profileSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PowerComponentBindingRow')
class PowerComponentBindings extends Table with PowerRevisionAuditColumns {
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get capabilitiesJson => text()();
  TextColumn get definitionRefJson => text()();
  TextColumn get definitionSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PowerTransferBindingRow')
class PowerTransferBindings extends Table with PowerRevisionAuditColumns {
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get inputPortId =>
      text().references(EngineeringPortInstances, #id)();
  TextColumn get transferKind => text()();
  TextColumn get modelRefJson => text()();
  TextColumn get payloadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PowerTransferOutputRow')
class PowerTransferOutputs extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get transferId => text()();
  TextColumn get outputPortId =>
      text().references(EngineeringPortInstances, #id)();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    transferId,
    outputPortId,
  };
}

@DataClassName('PowerLoadBindingRow')
class PowerLoadBindings extends Table with PowerRevisionAuditColumns {
  TextColumn get inputPortId =>
      text().references(EngineeringPortInstances, #id)();
  TextColumn get stateCode => text()();
  TextColumn get accountingKind => text()();
  TextColumn get originId => text()();
  TextColumn get typedDemandJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PowerCapacityGroupRow')
class PowerCapacityGroups extends Table with PowerRevisionAuditColumns {
  TextColumn get ownerComponentId =>
      text().references(ComponentInstances, #id)();
  TextColumn get limitsJson => text()();
  TextColumn get applicabilityJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PowerCapacityGroupMemberRow')
class PowerCapacityGroupMembers extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get groupId => text()();
  TextColumn get outputPortId =>
      text().references(EngineeringPortInstances, #id)();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    groupId,
    outputPortId,
  };
}

@DataClassName('PowerSupplyRequirementRow')
class PowerSupplyRequirements extends Table with PowerRevisionAuditColumns {
  TextColumn get consumerComponentId =>
      text().references(ComponentInstances, #id)();
  TextColumn get selectionMode => text()();
  TextColumn get payloadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PowerSupplyRequirementInputRow')
class PowerSupplyRequirementInputs extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get requirementId => text()();
  TextColumn get inputPortId =>
      text().references(EngineeringPortInstances, #id)();
  TextColumn get allowedSourcesJson => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    requirementId,
    inputPortId,
  };
}

@DataClassName('PowerOperatingScenarioRow')
class PowerOperatingScenarios extends Table with PowerRevisionAuditColumns {
  TextColumn get role => text()();
  TextColumn get policyRefsJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PowerScenarioSegmentRow')
class PowerScenarioSegments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get scenarioId => text()();
  TextColumn get segmentId => text()();
  IntColumn get ordinal => integer()();
  TextColumn get durationJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    scenarioId,
    segmentId,
  };
}

@DataClassName('PowerScenarioStateRow')
class PowerScenarioStates extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get scenarioId => text()();
  TextColumn get segmentId => text()();
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get stateCode => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    scenarioId,
    segmentId,
    componentId,
  };
}

@DataClassName('PowerScenarioSourceSelectionRow')
class PowerScenarioSourceSelections extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get scenarioId => text()();
  TextColumn get segmentId => text()();
  TextColumn get requirementId => text()();
  TextColumn get selectedSourceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    scenarioId,
    segmentId,
    requirementId,
  };
}

@DataClassName('PowerScenarioUnavailableSourceRow')
class PowerScenarioUnavailableSources extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get scenarioId => text()();
  TextColumn get segmentId => text()();
  TextColumn get sourceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    scenarioId,
    segmentId,
    sourceId,
  };
}

@DataClassName('PoeDeliveryBindingRow')
class PoeDeliveryBindings extends Table with PowerRevisionAuditColumns {
  TextColumn get psePortId =>
      text().references(EngineeringPortInstances, #id)();
  TextColumn get pdPortId => text().references(EngineeringPortInstances, #id)();
  TextColumn get accountingMode => text()();
  TextColumn get definitionRefJson => text()();
  TextColumn get payloadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PoeDeliveryPathMemberRow')
class PoeDeliveryPathMembers extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get deliveryId => text()();
  IntColumn get ordinal => integer()();
  TextColumn get connectionId =>
      text().nullable().references(EngineeringPortConnections, #id)();
  TextColumn get allocationId =>
      text().nullable().references(CableAllocations, #id)();
  TextColumn get evidenceJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, deliveryId, ordinal};
}

@DataClassName('BackupAssemblyRow')
class BackupAssemblies extends Table with PowerRevisionAuditColumns {
  TextColumn get upsComponentId =>
      text().nullable().references(ComponentInstances, #id)();
  TextColumn get chargerComponentId =>
      text().nullable().references(ComponentInstances, #id)();
  TextColumn get bankComponentId =>
      text().nullable().references(ComponentInstances, #id)();
  TextColumn get policyJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('BackupProtectedOutputRow')
class BackupProtectedOutputs extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get assemblyId => text()();
  TextColumn get outputPortId =>
      text().references(EngineeringPortInstances, #id)();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    assemblyId,
    outputPortId,
  };
}

@DataClassName('BatteryBankBindingRow')
class BatteryBankBindings extends Table with PowerRevisionAuditColumns {
  TextColumn get bankComponentId =>
      text().references(ComponentInstances, #id)();
  TextColumn get unitRefJson => text()();
  IntColumn get seriesCount => integer()();
  IntColumn get parallelCount => integer()();
  TextColumn get usableModelJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('DesignRevisionPowerSnapshotRow')
class DesignRevisionPowerSnapshots extends Table {
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get sectionSchema => text()();
  TextColumn get captureKind => text()();
  TextColumn get payloadJson => text()();
  TextColumn get powerSha256 => text()();
  TextColumn get physicalSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId};
}

@DataClassName('DesignRevisionSnapshotManifestRow')
class DesignRevisionSnapshotManifests extends Table {
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get manifestSchema => text()();
  TextColumn get manifestSha256 => text()();
  TextColumn get physicalSha256 => text()();
  TextColumn get powerSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId};
}

@DataClassName('PowerEvaluationRecordRow')
class PowerEvaluationRecords extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get logicalNodeKeyJson => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get evaluationId => text()();
  TextColumn get scopeKind => text()();
  TextColumn get scopeId => text()();
  TextColumn get processCode => text()();
  TextColumn get subjectKind => text()();
  TextColumn get subjectId => text()();
  TextColumn get inputFingerprint => text()();
  TextColumn get status => text()();
  TextColumn get applicability => text()();
  TextColumn get evidenceJson => text()();
  TextColumn get evidenceSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    logicalNodeKeySha256,
    evaluationId,
  };
}

@DataClassName('PowerEvaluationPointerRow')
class PowerEvaluationPointers extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get logicalNodeKeyJson => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get state => text()();
  IntColumn get generation => integer()();
  TextColumn get evaluationId => text().nullable()();
  TextColumn get evidenceSha256 => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    logicalNodeKeySha256,
  };
}

@DataClassName('PowerOperationRecordRow')
class PowerOperationRecords extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get operationId => text()();
  TextColumn get commandType => text()();
  TextColumn get payloadSchema => text()();
  TextColumn get commandFingerprint => text()();
  TextColumn get status => text()();
  TextColumn get resultJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get committedAt => dateTime().nullable()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    projectId,
    designRevisionId,
    operationId,
  };
}
