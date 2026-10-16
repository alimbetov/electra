part of 'app_database.dart';

/// Shared revision ownership for mutable ELV5 aggregate roots.
mixin DisciplineRevisionAuditColumns on Table {
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

@DataClassName('DisciplinePolicyBindingRow')
class DisciplinePolicyBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get subjectKind => text()();
  TextColumn get subjectId => text()();
  TextColumn get processCodesJson => text()();
  TextColumn get definitionRefJson => text()();
  TextColumn get definitionSha256 => text()();
  TextColumn get applicabilityJson => text()();
  TextColumn get applicabilitySha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

/// Aggregate root for the complete REPLACE_CAMERA_STREAMS set.
@DataClassName('CameraStreamSetBindingRow')
class CameraStreamSetBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get cameraId => text().references(ComponentInstances, #id)();
  TextColumn get transportOverheadModelRefJson => text().nullable()();
  TextColumn get transportOverheadModelSha256 => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('CameraStreamBindingRow')
class CameraStreamBindings extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get cameraId => text().references(ComponentInstances, #id)();
  TextColumn get encodedStreamId => text()();
  TextColumn get streamProfileJson => text()();
  TextColumn get streamProfileSha256 => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    encodedStreamId,
  };
}

@DataClassName('CameraStreamSubscriptionRow')
class CameraStreamSubscriptions extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get cameraId => text().references(ComponentInstances, #id)();
  TextColumn get subscriptionId => text()();
  TextColumn get encodedStreamId => text()();
  TextColumn get receiverId => text()();
  TextColumn get deliveryMode => text()();
  TextColumn get orderedNetworkEdgeIdsJson => text()();
  TextColumn get multicastGroupId => text().nullable()();
  TextColumn get multicastTreeJson => text().nullable()();
  TextColumn get multicastTreeSha256 => text().nullable()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    subscriptionId,
  };
}

@DataClassName('RecordingPoolBindingRow')
class RecordingPoolBindings extends Table with DisciplineRevisionAuditColumns {
  TextColumn get poolId => text()();
  TextColumn get horizonJson => text()();
  TextColumn get temporalPolicyJson => text()();
  TextColumn get sizingBasis => text()();
  TextColumn get reserveMultiplierJson => text()();
  TextColumn get redundancyModelJson => text().nullable()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('RecordingAssignmentRow')
class RecordingAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get encodedStreamId => text()();
  TextColumn get copyRole => text()();
  TextColumn get scheduleProfileId => text()();
  TextColumn get bitrateValueJson => text()();
  TextColumn get bitrateEvidenceJson => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    encodedStreamId,
    copyRole,
  };
}

@DataClassName('RecordingScheduleSegmentRow')
class RecordingScheduleSegments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get scheduleProfileId => text()();
  TextColumn get segmentId => text()();
  IntColumn get ordinal => integer()();
  TextColumn get scheduleJson => text()();
  TextColumn get scheduleSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    scheduleProfileId,
    segmentId,
  };
}

@DataClassName('RecorderCapacityBindingRow')
class RecorderCapacityBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get recorderId => text().references(ComponentInstances, #id)();
  TextColumn get accountingBasis => text()();
  TextColumn get recorderDefinitionRefJson => text()();
  TextColumn get recorderDefinitionSha256 => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('RecorderAssignmentRow')
class RecorderAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get assignmentId => text()();
  TextColumn get cameraId => text().references(ComponentInstances, #id)();
  TextColumn get encodedStreamId => text()();
  TextColumn get licenseChannelId => text()();
  TextColumn get storagePoolId => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    assignmentId,
  };
}

@DataClassName('LinkCompositionBindingRow')
class LinkCompositionBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get linkId => text()();
  TextColumn get policyBindingId => text()();
  TextColumn get compositionKind =>
      text().withDefault(const Constant('ORDERED'))();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('LinkSectionAssignmentRow')
class LinkSectionAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  IntColumn get ordinal => integer()();
  TextColumn get realizedSectionId => text()();
  TextColumn get sectionRole => text()();
  TextColumn get evidenceJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, bindingId, ordinal};
}

@DataClassName('PortCapacityBindingRow')
class PortCapacityBindings extends Table with DisciplineRevisionAuditColumns {
  TextColumn get switchId => text().references(ComponentInstances, #id)();
  TextColumn get sparePolicyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PortCapacityAssignmentRow')
class PortCapacityAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get endpointId => text()();
  TextColumn get portId => text().references(EngineeringPortInstances, #id)();
  TextColumn get selectedMode => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, bindingId, portId};
}

@DataClassName('OpticalLinkBindingRow')
class OpticalLinkBindings extends Table with DisciplineRevisionAuditColumns {
  TextColumn get linkId => text()();
  TextColumn get forwardOpticsJson => text()();
  TextColumn get reverseOpticsJson => text()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('OpticalLossEventRow')
class OpticalLossEvents extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get directionCode => text()();
  TextColumn get eventId => text()();
  TextColumn get eventKind => text()();
  IntColumn get ordinal => integer()();
  TextColumn get lossIntervalJson => text()();
  TextColumn get evidenceJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    directionCode,
    eventId,
  };
}

@DataClassName('RackCapacityBindingRow')
class RackCapacityBindings extends Table with DisciplineRevisionAuditColumns {
  TextColumn get rackId => text().references(ComponentInstances, #id)();
  TextColumn get capacityBasis => text()();
  TextColumn get capacityJson => text()();
  TextColumn get excludedCapacityJson => text()();
  TextColumn get exclusionProvenanceJson => text()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('RackEquipmentMembershipRow')
class RackEquipmentMemberships extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get equipmentId => text().references(ComponentInstances, #id)();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    equipmentId,
  };
}

@DataClassName('PatchPanelBindingRow')
class PatchPanelBindings extends Table with DisciplineRevisionAuditColumns {
  TextColumn get panelId => text().references(ComponentInstances, #id)();
  TextColumn get sparePolicyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('PatchPanelAssignmentRow')
class PatchPanelAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get panelPortId =>
      text().references(EngineeringPortInstances, #id)();
  TextColumn get endpointId => text()();
  TextColumn get destinationRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    panelPortId,
  };
}

@DataClassName('DoorCalculationBindingRow')
class DoorCalculationBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get doorAssemblyId => text()();
  TextColumn get topologyProfileRefJson => text()();
  TextColumn get safetyMode => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('DoorRoleAssignmentRow')
class DoorRoleAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get componentId => text().references(ComponentInstances, #id)();
  TextColumn get roleCode => text()();
  IntColumn get slot => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    roleCode,
    slot,
  };
}

@DataClassName('DoorReleaseTruthRow')
class DoorReleaseTruthRows extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get causeCode => text()();
  TextColumn get expectedOutcomeCode => text()();
  TextColumn get requiredEvidenceRolesJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    causeCode,
  };
}

@DataClassName('ControllerResourceBindingRow')
class ControllerResourceBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get controllerId => text().references(ComponentInstances, #id)();
  TextColumn get reservePolicyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('ControllerResourceAssignmentRow')
class ControllerResourceAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get resourceId => text()();
  TextColumn get resourceKind => text()();
  TextColumn get subjectId => text()();
  TextColumn get roleCode => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    resourceId,
    roleCode,
  };
}

@DataClassName('FireLoopBindingRow')
class FireLoopBindings extends Table with DisciplineRevisionAuditColumns {
  TextColumn get loopId => text()();
  TextColumn get addressDomainJson => text()();
  TextColumn get addressDomain => text()();
  TextColumn get topologyProfileRefJson => text()();
  TextColumn get policyRefJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('FireLoopDeviceAssignmentRow')
class FireLoopDeviceAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get deviceId => text().references(ComponentInstances, #id)();
  TextColumn get expansionProfileRefJson => text()();
  IntColumn get ordinal => integer()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, bindingId, deviceId};
}

@DataClassName('FireAddressClaimRow')
class FireAddressClaims extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get deviceId => text().references(ComponentInstances, #id)();
  TextColumn get addressDomain => text()();
  IntColumn get address => integer()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    addressDomain,
    address,
  };

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {designRevisionId, addressDomain, address},
  ];
}

@DataClassName('NotificationCircuitBindingRow')
class NotificationCircuitBindings extends Table
    with DisciplineRevisionAuditColumns {
  TextColumn get circuitId => text()();
  TextColumn get outputRefJson => text()();
  TextColumn get policyRefJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId, id};
}

@DataClassName('NotificationCircuitAssignmentRow')
class NotificationCircuitAssignments extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get bindingId => text()();
  TextColumn get deviceId => text().references(ComponentInstances, #id)();
  TextColumn get outputId => text()();
  TextColumn get stateLoadJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    bindingId,
    deviceId,
    outputId,
  };
}

@DataClassName('DisciplineEvaluationRecordRow')
class DisciplineEvaluationRecords extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get logicalNodeKeyJson => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get evaluationId => text()();
  TextColumn get scopeKind => text()();
  TextColumn get scopeId => text()();
  TextColumn get scenarioKey => text()();
  TextColumn get processCode => text()();
  TextColumn get subjectKind => text()();
  TextColumn get subjectId => text()();
  TextColumn get algorithmVersion => text()();
  TextColumn get inputSchemaVersion => text()();
  TextColumn get outputSchemaVersion => text()();
  TextColumn get numericBackendVersion => text()();
  TextColumn get canonicalEncoderVersion => text()();
  TextColumn get inputFingerprint => text()();
  TextColumn get policyFingerprint => text()();
  TextColumn get execution => text()();
  TextColumn get completion => text()();
  TextColumn get assessment => text()();
  TextColumn get outputJson => text()();
  TextColumn get outputSha256 => text()();
  TextColumn get evidenceJson => text()();
  TextColumn get evidenceSha256 => text()();
  DateTimeColumn get completedAtUtc => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    logicalNodeKeySha256,
    evaluationId,
  };

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {evaluationId},
  ];
}

@DataClassName('DisciplineEvaluationPointerRow')
class DisciplineEvaluationPointers extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get logicalNodeKeyJson => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get freshness => text()();
  IntColumn get generation => integer().withDefault(const Constant(0))();
  TextColumn get evaluationId => text().nullable()();
  TextColumn get inputFingerprint => text().nullable()();
  TextColumn get outputSha256 => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    logicalNodeKeySha256,
  };
}

@DataClassName('DisciplineDependencyIndexRow')
class DisciplineDependencyIndex extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get dependencyKey => text()();
  TextColumn get dependencyKeySha256 => text()();
  TextColumn get logicalNodeKeySha256 => text()();
  TextColumn get relationKind => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {
    designRevisionId,
    dependencyKeySha256,
    logicalNodeKeySha256,
  };
}

@DataClassName('DesignRevisionDisciplineSnapshotRow')
class DesignRevisionDisciplineSnapshots extends Table {
  TextColumn get designRevisionId =>
      text().references(ProjectDesignRevisions, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get sectionSchema => text()();
  TextColumn get captureKind => text()();
  TextColumn get payloadJson => text()();
  TextColumn get disciplineSha256 => text()();
  TextColumn get physicalSha256 => text()();
  TextColumn get powerSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId};
}
