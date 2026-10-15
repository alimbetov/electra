import 'battery_backup_evaluation.dart';
import 'engineering_hash.dart';
import 'power_assets.dart';
import 'power_catalog.dart';
import 'power_dc_backup.dart';
import 'power_dependency.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';
import 'power_numeric.dart';

const batterySequenceEvidenceAlgorithmVersion = 'elv4-pwr04-battery-v1';
const batterySequenceInputSchemaVersion = 'electra.elv4-pwr04-input.v1';
const batterySequenceOutputSchemaVersion = 'electra.elv4-pwr04-output.v1';
const chargerBoundaryEvidenceAlgorithmVersion = 'elv4-p6-charger-boundary-v1';
const chargerBoundaryInputSchemaVersion = 'electra.elv4-p6-charger-input.v1';
const chargerBoundaryOutputSchemaVersion = 'electra.elv4-p6-charger-output.v1';

final class BackupEvidenceContext {
  BackupEvidenceContext({
    required String projectId,
    required String revisionId,
    required String scenarioId,
    required String sequenceId,
    required String bankId,
  })  : projectId = _text(projectId, 'projectId'),
        revisionId = _text(revisionId, 'revisionId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        sequenceId = _text(sequenceId, 'sequenceId'),
        bankId = _text(bankId, 'bankId');

  final String projectId;
  final String revisionId;
  final String scenarioId;
  final String sequenceId;
  final String bankId;
}

final class ChargerEvidenceContext {
  ChargerEvidenceContext({
    required String projectId,
    required String revisionId,
    required String scenarioId,
    required String segmentId,
    required String chargerId,
    required String bankId,
  })  : projectId = _text(projectId, 'projectId'),
        revisionId = _text(revisionId, 'revisionId'),
        scenarioId = _text(scenarioId, 'scenarioId'),
        segmentId = _text(segmentId, 'segmentId'),
        chargerId = _text(chargerId, 'chargerId'),
        bankId = _text(bankId, 'bankId');

  final String projectId;
  final String revisionId;
  final String scenarioId;
  final String segmentId;
  final String chargerId;
  final String bankId;
}

final class BatterySequenceEvaluationRecord {
  BatterySequenceEvaluationRecord({
    required this.evaluation,
    required this.consumedInput,
  }) {
    if (evaluation.nodeKey.processCode != PowerProcessCode.pwr04 ||
        evaluation.nodeKey.scopeKind != PowerEvaluationScopeKind.sequence) {
      throw ArgumentError('Battery sequence evidence requires sequence PWR-04.');
    }
    if (evaluation.inputFingerprint != consumedInput.inputFingerprint) {
      throw ArgumentError('PWR-04 fingerprint/consumed-input mismatch.');
    }
  }

  final PowerEvaluationEvidence evaluation;
  final PowerConsumedInput consumedInput;

  Map<String, Object?> toMap() => {
        ...evaluation.toMap(),
        'dependencyKeys': consumedInput.dependencyKeys,
        'consumedFacts':
            consumedInput.facts.map((value) => value.toMap()).toList(),
        'consumedEvaluations':
            consumedInput.evaluations.map((value) => value.toMap()).toList(),
      };

  String get canonicalJson => canonicalEngineeringJsonV1(toMap());
  String get evidenceSha256 => sha256HexUtf8(canonicalJson);

  PowerConsumedInputDiff diff(BatterySequenceEvaluationRecord previous) =>
      consumedInput.diff(previous.consumedInput);
}

final class ChargerBoundaryEvaluationRecord {
  ChargerBoundaryEvaluationRecord({
    required this.evaluation,
    required this.consumedInput,
  }) {
    if (evaluation.nodeKey.processCode != PowerProcessCode.pwr01 ||
        evaluation.nodeKey.scopeKind != PowerEvaluationScopeKind.segment) {
      throw ArgumentError('Charger boundary evidence requires segment PWR-01.');
    }
    if (evaluation.inputFingerprint != consumedInput.inputFingerprint) {
      throw ArgumentError('Charger boundary fingerprint/consumed-input mismatch.');
    }
  }

  final PowerEvaluationEvidence evaluation;
  final PowerConsumedInput consumedInput;

  Map<String, Object?> toMap() => {
        ...evaluation.toMap(),
        'dependencyKeys': consumedInput.dependencyKeys,
        'consumedFacts':
            consumedInput.facts.map((value) => value.toMap()).toList(),
        'consumedEvaluations':
            consumedInput.evaluations.map((value) => value.toMap()).toList(),
      };

  String get canonicalJson => canonicalEngineeringJsonV1(toMap());
  String get evidenceSha256 => sha256HexUtf8(canonicalJson);

  PowerConsumedInputDiff diff(ChargerBoundaryEvaluationRecord previous) =>
      consumedInput.diff(previous.consumedInput);
}

BatterySequenceEvaluationRecord buildBatterySequenceEvaluationRecord({
  required String evaluationId,
  required BackupEvidenceContext context,
  required BatteryBankBinding bank,
  required BatteryWhAvailabilityModel availability,
  required Iterable<BackupEnergySegment> segments,
  required PowerExtensionPolicy extensionPolicy,
  required BatteryBankSequenceEvaluation result,
  required Iterable<PowerEvaluationEvidence> segmentDemandEvaluations,
}) {
  if (bank.componentId != context.bankId) {
    throw ArgumentError('Battery evidence context/bank identity mismatch.');
  }
  final sequence = segments.toList();
  final dependencies = _validateSequenceDependencies(
    context: context,
    segments: sequence,
    evaluations: segmentDemandEvaluations,
  );

  final consumedInput = PowerConsumedInput(
    algorithmVersion: batterySequenceEvidenceAlgorithmVersion,
    inputSchemaVersion: batterySequenceInputSchemaVersion,
    numericPolicyVersion: powerNumericPolicyVersion,
    facts: [
      PowerConsumedFact.present(
        key: _backupKey(
          context,
          kind: PowerDependencyKind.definition,
          entityId: bank.unitDefinition.definitionRef.definitionCode,
          purpose: 'BATTERY_DEFINITION',
        ),
        valueSchema: 'electra.elv4.battery-definition.v1',
        value: bank.unitDefinition.toMap(),
      ),
      PowerConsumedFact.present(
        key: _backupKey(
          context,
          kind: PowerDependencyKind.batteryBank,
          entityId: context.bankId,
          purpose: 'BATTERY_BANK',
        ),
        valueSchema: 'electra.elv4.battery-bank.v1',
        value: bank.toMap(),
      ),
      PowerConsumedFact.present(
        key: _backupKey(
          context,
          kind: PowerDependencyKind.policy,
          entityId: context.bankId,
          purpose: 'BATTERY_AVAILABILITY_MODEL',
        ),
        valueSchema: 'electra.elv4.battery-availability.v1',
        value: _availabilityMap(availability),
      ),
      PowerConsumedFact.present(
        key: _backupKey(
          context,
          kind: PowerDependencyKind.backupSequence,
          entityId: context.sequenceId,
          purpose: 'PROTECTED_SEQUENCE',
        ),
        valueSchema: 'electra.elv4.backup-sequence.v1',
        value: {
          'segments': sequence.map(_segmentMap).toList(growable: false),
          'extensionPolicy': extensionPolicy.name.toUpperCase(),
        },
      ),
      PowerConsumedFact.present(
        key: _backupKey(
          context,
          kind: PowerDependencyKind.scenario,
          entityId: context.scenarioId,
          purpose: 'BACKUP_SEQUENCE_SCENARIO',
          scenarioScoped: true,
        ),
        valueSchema: 'electra.elv4.backup-scenario.v1',
        value: {
          'scenarioId': context.scenarioId,
          'sequenceId': context.sequenceId,
        },
      ),
    ],
    evaluations: dependencies,
  );

  final raw = result.sequence;
  final evaluation = PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: context.revisionId,
      scenarioId: context.scenarioId,
      scopeKind: PowerEvaluationScopeKind.sequence,
      scopeId: context.scenarioId,
      processCode: PowerProcessCode.pwr04,
      subjectKind: 'BATTERY_BANK',
      subjectId: context.bankId,
    ),
    algorithmVersion: batterySequenceEvidenceAlgorithmVersion,
    inputSchemaVersion: batterySequenceInputSchemaVersion,
    outputSchemaVersion: batterySequenceOutputSchemaVersion,
    inputFingerprint: consumedInput.inputFingerprint,
    status: result.status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: {
      'sequenceId': context.sequenceId,
      'bankId': context.bankId,
      'dependencyKeys': consumedInput.dependencyKeys,
    },
    output: {
      'requiredWh': raw.requiredWh.toMap(),
      'availableWh': raw.availableWh.toMap(),
      'marginWh': raw.marginWh.toMap(),
      'sequenceDurationSeconds': raw.sequenceDurationSeconds.toMap(),
      'estimatedAutonomySeconds': raw.estimatedAutonomySeconds?.toMap(),
    },
    dependencies: segmentDemandEvaluations.map((value) => value.nodeKey),
    quantities: [
      {'code': 'REQUIRED_WH', 'value': raw.requiredWh.toMap()},
      {'code': 'AVAILABLE_WH', 'value': raw.availableWh.toMap()},
      {'code': 'MARGIN_WH', 'value': raw.marginWh.toMap()},
      if (raw.estimatedAutonomySeconds != null)
        {
          'code': 'ESTIMATED_AUTONOMY_SECONDS',
          'value': raw.estimatedAutonomySeconds!.toMap()
        },
    ],
    arithmeticSteps: [
      for (final segment in sequence)
        {
          'operation': 'ENERGY_INTEGRAL_SEGMENT',
          'inputRefs': [
            '${segment.segmentId}:BANK_INPUT_W',
            '${segment.segmentId}:DURATION_SECONDS'
          ],
          'outputRef': '${segment.segmentId}:REQUIRED_WH',
          'value': (segment.bankInputW *
                  segment.durationSeconds /
                  PowerRational.integer(3600))
              .toMap(),
        },
      {
        'operation': 'BATTERY_AVAILABLE_WH',
        'inputRefs': const [
          'MODEL_V',
          'BANK_AH',
          'SOC_WINDOW',
          'TEMPERATURE_FACTOR',
          'AGING_FACTOR',
          'RATE_FACTOR'
        ],
        'outputRef': 'AVAILABLE_WH',
        'value': raw.availableWh.toMap(),
      },
    ],
    findings: result.findings,
    assumptions: const [
      'BATTERY_SIMPLE_WH_MODEL',
      'SOC_WINDOW_APPLIED_ONCE',
      'UNIT_USABLE_FRACTION_IS_AN_ENVELOPE_NOT_AN_EXTRA_MULTIPLIER',
    ],
  );

  return BatterySequenceEvaluationRecord(
    evaluation: evaluation,
    consumedInput: consumedInput,
  );
}

ChargerBoundaryEvaluationRecord buildChargerBoundaryEvaluationRecord({
  required String evaluationId,
  required ChargerEvidenceContext context,
  required PowerChargerDefinition charger,
  required BatteryBankBinding bank,
  required ChargerBankCompatibilityEvidence bankCompatibility,
  required PowerRational operatingOutputW,
  required PowerRational chargeVoltageV,
  required PowerRational selectedChargeCurrentA,
  required bool chargingSelected,
  required bool dischargingSelected,
  required ChargerBankEvaluation result,
  required PowerEvaluationEvidence operatingDemandEvaluation,
  required Map<String, Object?> scenarioFacts,
}) {
  if (bank.componentId != context.bankId) {
    throw ArgumentError('Charger evidence context/bank identity mismatch.');
  }
  _validateOperatingDemand(
    context: context,
    expectedW: operatingOutputW,
    evaluation: operatingDemandEvaluation,
  );
  final consumedInput = PowerConsumedInput(
    algorithmVersion: chargerBoundaryEvidenceAlgorithmVersion,
    inputSchemaVersion: chargerBoundaryInputSchemaVersion,
    numericPolicyVersion: powerNumericPolicyVersion,
    facts: [
      PowerConsumedFact.present(
        key: _chargerKey(
          context,
          kind: PowerDependencyKind.definition,
          entityId: charger.definitionRef.definitionCode,
          purpose: 'CHARGER_DEFINITION',
        ),
        valueSchema: 'electra.elv4.charger-definition.v1',
        value: charger.toMap(),
      ),
      PowerConsumedFact.present(
        key: _chargerKey(
          context,
          kind: PowerDependencyKind.batteryBank,
          entityId: context.bankId,
          purpose: 'CHARGER_BANK',
        ),
        valueSchema: 'electra.elv4.battery-bank.v1',
        value: bank.toMap(),
      ),
      PowerConsumedFact.present(
        key: _chargerKey(
          context,
          kind: PowerDependencyKind.charger,
          entityId: context.chargerId,
          purpose: 'CHARGER_OPERATING_STATE',
        ),
        valueSchema: 'electra.elv4.charger-operating-state.v1',
        value: {
          'chargeVoltageV': chargeVoltageV.toMap(),
          'selectedChargeCurrentA': selectedChargeCurrentA.toMap(),
          'chargingSelected': chargingSelected,
          'dischargingSelected': dischargingSelected,
          'bankCompatibility': bankCompatibility.toMap(),
        },
      ),
      PowerConsumedFact.present(
        key: _chargerKey(
          context,
          kind: PowerDependencyKind.transferLoss,
          entityId: context.chargerId,
          purpose: 'CHARGER_TRANSFER_LOSS',
        ),
        valueSchema: 'electra.elv4.power-loss.v1',
        value: charger.lossDefinition.toMap(),
      ),
      PowerConsumedFact.present(
        key: _chargerKey(
          context,
          kind: PowerDependencyKind.segment,
          entityId: context.segmentId,
          purpose: 'CHARGER_SCENARIO_STATE',
          scenarioScoped: true,
        ),
        valueSchema: 'electra.elv4.charger-scenario.v1',
        value: scenarioFacts,
      ),
    ],
    evaluations: [
      PowerConsumedEvaluationRef(
        logicalNodeKey: operatingDemandEvaluation.nodeKey.encode(),
        evaluationId: operatingDemandEvaluation.evaluationId,
        inputFingerprint: operatingDemandEvaluation.inputFingerprint,
      ),
    ],
  );

  final raw = result.charger;
  final transfer = evaluateTransferInputDemand(
    transferId: 'CHARGER:${context.chargerId}',
    deliveredOutputW: raw.combinedOutputW,
    loss: charger.lossDefinition,
  );
  if (transfer.inputW != raw.upstreamInputW) {
    throw ArgumentError('Charger transfer evidence differs from evaluation result.');
  }

  final evaluation = PowerEvaluationEvidence(
    evaluationId: evaluationId,
    nodeKey: PowerNodeKeyV2(
      revisionId: context.revisionId,
      scenarioId: context.scenarioId,
      scopeKind: PowerEvaluationScopeKind.segment,
      scopeId: context.segmentId,
      processCode: PowerProcessCode.pwr01,
      subjectKind: 'CHARGER_BOUNDARY',
      subjectId: context.chargerId,
    ),
    algorithmVersion: chargerBoundaryEvidenceAlgorithmVersion,
    inputSchemaVersion: chargerBoundaryInputSchemaVersion,
    outputSchemaVersion: chargerBoundaryOutputSchemaVersion,
    inputFingerprint: consumedInput.inputFingerprint,
    status: result.status,
    applicability: PowerEvaluationApplicability.applicable,
    inputs: {
      'chargerId': context.chargerId,
      'bankId': context.bankId,
      'dependencyKeys': consumedInput.dependencyKeys,
    },
    output: {
      'knownW': raw.upstreamInputW.toMap(),
      'completeW': true,
      'operatingOutputW': raw.operatingOutputW.toMap(),
      'chargingOutputW': raw.chargingOutputW.toMap(),
      'combinedOutputW': raw.combinedOutputW.toMap(),
      'upstreamInputW': raw.upstreamInputW.toMap(),
      'chargeCurrentMarginA': raw.chargeCurrentMarginA.toMap(),
    },
    dependencies: [operatingDemandEvaluation.nodeKey],
    quantities: [
      {'code': 'OPERATING_OUTPUT_W', 'value': raw.operatingOutputW.toMap()},
      {'code': 'CHARGING_OUTPUT_W', 'value': raw.chargingOutputW.toMap()},
      {'code': 'COMBINED_OUTPUT_W', 'value': raw.combinedOutputW.toMap()},
      {'code': 'UPSTREAM_INPUT_W', 'value': raw.upstreamInputW.toMap()},
    ],
    arithmeticSteps: [
      {
        'operation': 'MULTIPLY',
        'inputRefs': const ['CHARGE_V', 'CHARGE_CURRENT_A'],
        'outputRef': 'CHARGING_OUTPUT_W',
        'value': raw.chargingOutputW.toMap(),
      },
      ...transfer.steps.map((value) => value.toMap()),
    ],
    findings: result.findings,
    assumptions: const [
      'CHARGE_AND_DISCHARGE_INTERLOCKED',
      'CHARGER_CONVERSION_AND_IDLE_APPLIED_ONCE',
    ],
  );
  return ChargerBoundaryEvaluationRecord(
    evaluation: evaluation,
    consumedInput: consumedInput,
  );
}

List<PowerConsumedEvaluationRef> _validateSequenceDependencies({
  required BackupEvidenceContext context,
  required List<BackupEnergySegment> segments,
  required Iterable<PowerEvaluationEvidence> evaluations,
}) {
  final bySegment = <String, PowerEvaluationEvidence>{};
  for (final evaluation in evaluations) {
    final id = evaluation.nodeKey.scopeId;
    if (bySegment.containsKey(id)) {
      throw ArgumentError('Duplicate PWR-01 sequence dependency for $id.');
    }
    bySegment[id] = evaluation;
  }
  if (bySegment.length != segments.length ||
      !segments.every((segment) => bySegment.containsKey(segment.segmentId))) {
    throw ArgumentError('PWR-04 requires one PWR-01 demand per sequence segment.');
  }
  return [
    for (final segment in segments)
      _sequenceRef(context, segment, bySegment[segment.segmentId]!),
  ];
}

PowerConsumedEvaluationRef _sequenceRef(
  BackupEvidenceContext context,
  BackupEnergySegment segment,
  PowerEvaluationEvidence evaluation,
) {
  final key = evaluation.nodeKey;
  if (key.processCode != PowerProcessCode.pwr01 ||
      key.scopeKind != PowerEvaluationScopeKind.segment ||
      key.revisionId != context.revisionId ||
      key.scenarioId != context.scenarioId ||
      key.scopeId != segment.segmentId ||
      evaluation.output['completeW'] != true) {
    throw ArgumentError('Backup segment requires complete matching PWR-01 evidence.');
  }
  final known = evaluation.output['knownW'];
  if (known is! Map ||
      PowerRational.fromMap(known.cast<String, Object?>()) != segment.bankInputW) {
    throw ArgumentError('Backup segment demand differs from PWR-01 evidence.');
  }
  return PowerConsumedEvaluationRef(
    logicalNodeKey: key.encode(),
    evaluationId: evaluation.evaluationId,
    inputFingerprint: evaluation.inputFingerprint,
  );
}

void _validateOperatingDemand({
  required ChargerEvidenceContext context,
  required PowerRational expectedW,
  required PowerEvaluationEvidence evaluation,
}) {
  final key = evaluation.nodeKey;
  if (key.processCode != PowerProcessCode.pwr01 ||
      key.scopeKind != PowerEvaluationScopeKind.segment ||
      key.revisionId != context.revisionId ||
      key.scenarioId != context.scenarioId ||
      key.scopeId != context.segmentId ||
      evaluation.output['completeW'] != true) {
    throw ArgumentError('Charger requires complete operating PWR-01 evidence.');
  }
  final known = evaluation.output['knownW'];
  if (known is! Map ||
      PowerRational.fromMap(known.cast<String, Object?>()) != expectedW) {
    throw ArgumentError('Charger operating demand differs from PWR-01 evidence.');
  }
}

Map<String, Object?> _availabilityMap(BatteryWhAvailabilityModel value) => {
      'modelVoltageV': value.modelVoltageV.toMap(),
      'bankAh': value.bankAh.toMap(),
      'initialSocFraction': value.initialSocFraction.toMap(),
      'minimumSocFraction': value.minimumSocFraction.toMap(),
      'temperatureFactor': value.temperatureFactor.toMap(),
      'agingFactor': value.agingFactor.toMap(),
      'rateFactor': value.rateFactor.toMap(),
    };

Map<String, Object?> _segmentMap(BackupEnergySegment value) => {
      'segmentId': value.segmentId,
      'durationSeconds': value.durationSeconds.toMap(),
      'bankInputW': value.bankInputW.toMap(),
    };

PowerDependencyKey _backupKey(
  BackupEvidenceContext context, {
  required PowerDependencyKind kind,
  required String entityId,
  required String purpose,
  bool scenarioScoped = false,
}) =>
    PowerDependencyKey(
      projectId: context.projectId,
      revisionId: context.revisionId,
      kind: kind,
      entityId: entityId,
      purpose: purpose,
      scenarioId: scenarioScoped ? context.scenarioId : null,
    );

PowerDependencyKey _chargerKey(
  ChargerEvidenceContext context, {
  required PowerDependencyKind kind,
  required String entityId,
  required String purpose,
  bool scenarioScoped = false,
}) =>
    PowerDependencyKey(
      projectId: context.projectId,
      revisionId: context.revisionId,
      kind: kind,
      entityId: entityId,
      purpose: purpose,
      scenarioId: scenarioScoped ? context.scenarioId : null,
      segmentId: scenarioScoped ? context.segmentId : null,
    );

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
