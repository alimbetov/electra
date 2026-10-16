import 'engineering_hash.dart';
import 'power_evaluation.dart';
import 'power_numeric.dart';

const powerIntervalCapabilityAlgorithmVersion = 'elv4-pwr02-interval-v1';

final class PowerIntervalCapabilityInput {
  PowerIntervalCapabilityInput({
    required this.demandW,
    required this.nameplateW,
    PowerRational? reserveMultiplier,
    PowerRational? deratingFactor,
  })  : reserveMultiplier = reserveMultiplier ?? PowerRational.one,
        deratingFactor = deratingFactor ?? PowerRational.one {
    if (demandW.lower.isNegative || nameplateW.isNegative) {
      throw ArgumentError('Power capability quantities cannot be negative.');
    }
    if (this.reserveMultiplier <= PowerRational.zero) {
      throw ArgumentError('Reserve multiplier must be positive.');
    }
    if (this.deratingFactor <= PowerRational.zero ||
        this.deratingFactor > PowerRational.one) {
      throw ArgumentError('Derating factor must be in (0, 1].');
    }
  }

  final PowerInterval demandW;
  final PowerRational nameplateW;
  final PowerRational reserveMultiplier;
  final PowerRational deratingFactor;
}

final class PowerIntervalCapabilityAssessment {
  const PowerIntervalCapabilityAssessment({
    required this.status,
    required this.physicalDemandW,
    required this.requiredW,
    required this.availableW,
    required this.marginW,
  });

  final PowerEvaluationStatus status;
  final PowerInterval physicalDemandW;
  final PowerInterval requiredW;
  final PowerInterval availableW;
  final PowerInterval marginW;
}

PowerIntervalCapabilityAssessment evaluateIntervalPowerCapability(
  PowerIntervalCapabilityInput input,
) {
  final reserve = PowerInterval.exact(input.reserveMultiplier);
  final required = input.demandW * reserve;
  final available =
      PowerInterval.exact(input.nameplateW * input.deratingFactor);
  final numeric = required.assessAtMost(available);
  final status = switch (numeric) {
    PowerNumericAssessment.pass => PowerEvaluationStatus.pass,
    PowerNumericAssessment.fail => PowerEvaluationStatus.fail,
    PowerNumericAssessment.unresolved => PowerEvaluationStatus.unresolved,
  };
  return PowerIntervalCapabilityAssessment(
    status: status,
    physicalDemandW: input.demandW,
    requiredW: required,
    availableW: available,
    marginW: available - required,
  );
}

PowerEvaluationEvidence buildPowerIntervalCapabilityEvidence({
  required String evaluationId,
  required String revisionId,
  required String scenarioId,
  required String segmentId,
  required String subjectKind,
  required String subjectId,
  required PowerIntervalCapabilityInput input,
  required PowerIntervalCapabilityAssessment assessment,
  Iterable<PowerNodeKeyV2> dependencies = const [],
}) {
  if (input.demandW.lower != assessment.physicalDemandW.lower ||
      input.demandW.upper != assessment.physicalDemandW.upper) {
    throw ArgumentError('Interval capability evidence input/result mismatch.');
  }
  final inputs = <String, Object?>{
    'schema': 'electra.elv4-pwr02-interval-input.v1',
    'demandW': input.demandW.toMap(),
    'nameplateW': input.nameplateW.toMap(),
    'reserveMultiplier': input.reserveMultiplier.toMap(),
    'deratingFactor': input.deratingFactor.toMap(),
  };
  return PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: revisionId,
      scenarioId: scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: segmentId,
      processCode: PowerProcessCode.pwr02,
      subjectKind: subjectKind,
      subjectId: subjectId,
    ),
    algorithmVersion: powerIntervalCapabilityAlgorithmVersion,
    inputSchemaVersion: 'electra.elv4-pwr02-interval-input.v1',
    outputSchemaVersion: 'electra.elv4-pwr02-interval-output.v1',
    inputFingerprint: sha256HexUtf8(canonicalEngineeringJsonV1(inputs)),
    status: assessment.status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: inputs,
    output: {
      'physicalDemandW': assessment.physicalDemandW.toMap(),
      'requiredW': assessment.requiredW.toMap(),
      'availableW': assessment.availableW.toMap(),
      'marginW': assessment.marginW.toMap(),
    },
    dependencies: dependencies,
    quantities: [
      {
        'code': 'PHYSICAL_DEMAND_W_INTERVAL',
        'value': assessment.physicalDemandW.toMap(),
      },
      {'code': 'REQUIRED_W_INTERVAL', 'value': assessment.requiredW.toMap()},
      {'code': 'AVAILABLE_W_INTERVAL', 'value': assessment.availableW.toMap()},
      {'code': 'MARGIN_W_INTERVAL', 'value': assessment.marginW.toMap()},
    ],
    findings: [
      if (assessment.status == PowerEvaluationStatus.fail)
        PowerEvaluationFinding(
          code: 'ELV4_POWER_CAPABILITY_EXCEEDED',
          severity: 'FAIL',
          message: 'Conservative required power exceeds available capability.',
        ),
      if (assessment.status == PowerEvaluationStatus.unresolved)
        PowerEvaluationFinding(
          code: 'ELV4_NUMERIC_BOUNDARY_UNCERTAIN',
          severity: 'UNRESOLVED',
          message:
              'Demand and available capability intervals overlap at the decision boundary.',
        ),
    ],
    assumptions: const ['INTERVAL_DECISION_USES_CONSERVATIVE_BOUNDS'],
  );
}
