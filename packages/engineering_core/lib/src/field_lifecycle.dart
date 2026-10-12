enum EngineeringLifecycleStage {
  design,
  approval,
  installation,
  asBuilt,
  testing,
  commissioning,
  maintenance,
}

enum TestType {
  continuity,
  insulationResistance,
  earthContinuity,
  polarity,
  loopImpedance,
  rcdTest,
  phaseSequence,
  voltage,
  current,
  functionalTest,
  motorRotation,
  networkTest,
  custom,
}

enum TestResult { pass, fail, warning, notApplicable }

enum FieldIssueSeverity { info, warning, critical }

enum FieldIssueStatus { open, inProgress, resolved, accepted }

class InstallationDeviation {
  const InstallationDeviation({
    required this.id,
    required this.objectId,
    required this.designRevision,
    required this.reason,
    this.notes,
  });

  final String id;
  final String objectId;
  final int designRevision;
  final String reason;
  final String? notes;
}

class WorkPackage {
  const WorkPackage({
    required this.id,
    required this.code,
    required this.projectId,
    this.floorId,
    this.roomId,
    this.panelId,
    this.taskCodes = const [],
  });

  final String id;
  final String code;
  final String projectId;
  final String? floorId;
  final String? roomId;
  final String? panelId;
  final List<String> taskCodes;
}

class CablePull {
  const CablePull({
    required this.id,
    required this.cableRunId,
    required this.plannedLengthMm,
    this.actualLengthMm,
    this.reserveAtStartMm = 0,
    this.reserveAtEndMm = 0,
    this.cableReelId,
  });

  final String id;
  final String cableRunId;
  final int plannedLengthMm;
  final int? actualLengthMm;
  final int reserveAtStartMm;
  final int reserveAtEndMm;
  final String? cableReelId;
}

class CableReel {
  const CableReel({
    required this.id,
    required this.reelNumber,
    required this.cableDefinitionId,
    required this.initialLengthMm,
    required this.remainingLengthMm,
  });

  final String id;
  final String reelNumber;
  final String cableDefinitionId;
  final int initialLengthMm;
  final int remainingLengthMm;
}

class TestRecord {
  const TestRecord({
    required this.id,
    required this.objectId,
    required this.testType,
    required this.result,
    this.measuredValue,
    this.unit,
    this.notes,
  });

  final String id;
  final String objectId;
  final TestType testType;
  final TestResult result;
  final double? measuredValue;
  final String? unit;
  final String? notes;
}

class FieldIssue {
  const FieldIssue({
    required this.id,
    required this.projectId,
    required this.severity,
    required this.description,
    required this.status,
    this.floorId,
    this.roomId,
    this.objectId,
  });

  final String id;
  final String projectId;
  final FieldIssueSeverity severity;
  final String description;
  final FieldIssueStatus status;
  final String? floorId;
  final String? roomId;
  final String? objectId;
}
