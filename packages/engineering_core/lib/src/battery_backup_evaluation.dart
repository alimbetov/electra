import 'power_assets.dart';
import 'power_catalog.dart';
import 'power_dc_backup.dart';
import 'power_evaluation.dart';
import 'power_numeric.dart';

final class BatteryBankSequenceEvaluation {
  const BatteryBankSequenceEvaluation({
    required this.status,
    required this.sequence,
    required this.findings,
  });

  final PowerEvaluationStatus status;
  final BatterySequenceResult sequence;
  final List<PowerEvaluationFinding> findings;
}

BatteryBankSequenceEvaluation evaluateBatterySequenceForBank({
  required BatteryBankBinding bank,
  required Iterable<BackupEnergySegment> segments,
  required BatteryWhAvailabilityModel availability,
  PowerExtensionPolicy extensionPolicy = PowerExtensionPolicy.none,
}) {
  final findings = <PowerEvaluationFinding>[];
  final unit = bank.unitDefinition;
  if (unit.capacityBasis != BatteryCapacityBasis.ampHour) {
    findings.add(
      _finding(
        'ELV4_UNSUPPORTED_ELECTRICAL_MODEL',
        'BLOCKED',
        'The simple P6 Wh model requires an explicit amp-hour battery rating.',
        [bank.componentId, unit.definitionRef.definitionCode],
      ),
    );
  } else {
    if (availability.modelVoltageV != bank.nominalBankV) {
      findings.add(
        _finding(
          'ELV4_BANK_VOLTAGE_MODEL_MISMATCH',
          'FAIL',
          'Battery availability model voltage does not match the bank arrangement.',
          [bank.componentId],
        ),
      );
    }
    if (availability.bankAh != bank.ratedBankCapacity) {
      findings.add(
        _finding(
          'ELV4_BANK_CAPACITY_MODEL_MISMATCH',
          'FAIL',
          'Battery availability amp-hour basis does not match the bank arrangement.',
          [bank.componentId],
        ),
      );
    }
  }

  final usableSocWindow =
      availability.initialSocFraction - availability.minimumSocFraction;
  if (usableSocWindow > unit.usableFraction) {
    findings.add(
      _finding(
        'ELV4_BANK_USABLE_WINDOW_EXCEEDED',
        'FAIL',
        'Configured SOC window exceeds the unit usable-capacity envelope.',
        [bank.componentId, unit.definitionRef.definitionCode],
      ),
    );
  }

  final sequence = evaluateBatterySequence(
    segments: segments,
    availability: availability,
    extensionPolicy: extensionPolicy,
  );
  final status = findings.any((item) => item.severity == 'BLOCKED')
      ? PowerEvaluationStatus.blocked
      : findings.any((item) => item.severity == 'FAIL')
          ? PowerEvaluationStatus.fail
          : sequence.status;
  final merged = <PowerEvaluationFinding>[
    ...findings,
    if (sequence.status == PowerEvaluationStatus.fail)
      _finding(
        'ELV4_BACKUP_ENERGY_CAPACITY_EXCEEDED',
        'FAIL',
        'Required protected sequence energy exceeds available battery energy.',
        [bank.componentId],
      ),
  ];
  return BatteryBankSequenceEvaluation(
    status: status,
    sequence: sequence,
    findings: List.unmodifiable(merged),
  );
}

final class ChargerBankCompatibilityEvidence {
  ChargerBankCompatibilityEvidence({
    required this.seriesCount,
    required this.compatible,
    required String evidenceRef,
  }) : evidenceRef = _text(evidenceRef, 'evidenceRef') {
    if (seriesCount < 1) {
      throw ArgumentError('Charger compatibility series count must be positive.');
    }
  }

  final int seriesCount;
  final bool compatible;
  final String evidenceRef;

  Map<String, Object?> toMap() => {
        'seriesCount': seriesCount,
        'compatible': compatible,
        'evidenceRef': evidenceRef,
      };
}

final class ChargerBankEvaluation {
  const ChargerBankEvaluation({
    required this.status,
    required this.charger,
    required this.findings,
  });

  final PowerEvaluationStatus status;
  final ChargerEvaluationResult charger;
  final List<PowerEvaluationFinding> findings;
}

ChargerBankEvaluation evaluateChargerForBank({
  required PowerChargerDefinition charger,
  required BatteryBankBinding bank,
  required ChargerBankCompatibilityEvidence bankCompatibility,
  required PowerRational operatingOutputW,
  required PowerRational chargeVoltageV,
  required PowerRational selectedChargeCurrentA,
  required bool chargingSelected,
  required bool dischargingSelected,
}) {
  if (bankCompatibility.seriesCount != bank.seriesCount) {
    throw ArgumentError(
      'Charger compatibility evidence does not match the battery bank series count.',
    );
  }
  final result = evaluateChargerDemand(
    charger: charger,
    battery: bank.unitDefinition,
    operatingOutputW: operatingOutputW,
    chargeVoltageV: chargeVoltageV,
    selectedChargeCurrentA: selectedChargeCurrentA,
    chargingSelected: chargingSelected,
    dischargingSelected: dischargingSelected,
  );
  final findings = <PowerEvaluationFinding>[];
  if (!bankCompatibility.compatible) {
    findings.add(
      _finding(
        'ELV4_BANK_INCOMPATIBLE',
        'FAIL',
        'The charger definition is not compatible with this battery series arrangement.',
        [bank.componentId, bankCompatibility.evidenceRef],
      ),
    );
  }
  if (result.status == PowerEvaluationStatus.fail) {
    findings.add(
      _finding(
        'ELV4_CHARGER_OPERATING_LIMIT_EXCEEDED',
        'FAIL',
        'Charger technology, voltage or current limits are not satisfied.',
        [bank.componentId, charger.definitionRef.definitionCode],
      ),
    );
  }
  final status = findings.any((item) => item.severity == 'FAIL')
      ? PowerEvaluationStatus.fail
      : result.status;
  return ChargerBankEvaluation(
    status: status,
    charger: result,
    findings: List.unmodifiable(findings),
  );
}

PowerEvaluationFinding _finding(
  String code,
  String severity,
  String message,
  Iterable<String> refs,
) =>
    PowerEvaluationFinding(
      code: code,
      severity: severity,
      message: message,
      sourceRefs: refs,
    );

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
