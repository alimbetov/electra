import 'dart:convert';
import 'dart:math' as math;

import 'component_catalog.dart';
import 'electrical_load.dart';

final class ElectricalCircuitInputs {
  const ElectricalCircuitInputs(
      {required this.nominalVoltageV,
      required this.phases,
      required this.supplySystem,
      this.demandFactor = 1});
  final double nominalVoltageV;
  final int phases;
  final SupplySystem supplySystem;
  final double demandFactor;

  List<String> validate() => [
        if (!nominalVoltageV.isFinite || nominalVoltageV <= 0)
          'INVALID_VOLTAGE',
        if (phases < 1 || phases > 3) 'INVALID_PHASES',
        if (!demandFactor.isFinite || demandFactor <= 0 || demandFactor > 1)
          'INVALID_DEMAND_FACTOR',
        if ((supplySystem == SupplySystem.threePhaseAc && phases != 3) ||
            ((supplySystem == SupplySystem.singlePhaseAc ||
                    supplySystem == SupplySystem.directCurrent) &&
                phases != 1))
          'SUPPLY_PHASE_MISMATCH',
      ];
}

/// An explicit, immutable set of assigned load IDs; group is source provenance.
final class ElectricalCircuit {
  ElectricalCircuit(
      {required this.id,
      required this.roomId,
      required this.name,
      required this.inputs,
      required Iterable<String> loadIds,
      this.sourceGroupId})
      : loadIds = List.unmodifiable(loadIds);
  final String id;
  final String roomId;
  final String name;
  final ElectricalCircuitInputs inputs;
  final List<String> loadIds;
  final String? sourceGroupId;
}

enum CircuitStatus { proposed, confirmed, reviewRequired }

final class CircuitIssue {
  const CircuitIssue(this.code, this.message, {this.loadId});
  final String code;
  final String message;
  final String? loadId;
}

final class LoadCurrentEvidence {
  const LoadCurrentEvidence(
      {required this.loadId,
      required this.currentA,
      required this.formula,
      required this.inputs});
  final String loadId;
  final double currentA;
  final String formula;
  final Map<String, Object?> inputs;
}

final class CircuitCalculation {
  CircuitCalculation(
      {required this.designCurrentA,
      required Iterable<CircuitIssue> issues,
      required Iterable<LoadCurrentEvidence> evidence,
      required this.inputSignature})
      : issues = List.unmodifiable(issues),
        evidence = List.unmodifiable(evidence);
  static const algorithmVersion = 'fl8-current-v1';
  final double? designCurrentA;
  final List<CircuitIssue> issues;
  final List<LoadCurrentEvidence> evidence;
  final String inputSignature;
  bool get ready => designCurrentA != null && issues.isEmpty;
}

final class CircuitSnapshot {
  const CircuitSnapshot(
      {required this.circuit,
      required this.calculation,
      this.reviewedInputSignature});
  final ElectricalCircuit circuit;
  final CircuitCalculation calculation;
  final String? reviewedInputSignature;
  CircuitStatus get status => reviewedInputSignature == null
      ? CircuitStatus.proposed
      : calculation.ready &&
              reviewedInputSignature == calculation.inputSignature
          ? CircuitStatus.confirmed
          : CircuitStatus.reviewRequired;
}

abstract final class CircuitCurrentCalculator {
  /// Conservative sum of load-current magnitudes, multiplied by explicit kD.
  /// Three-phase inputs describe balanced loads at line-to-line voltage.
  static CircuitCalculation calculate(
      ElectricalCircuit circuit, Iterable<EquipmentElectricalLoad> loads) {
    final issues = <CircuitIssue>[];
    final evidence = <LoadCurrentEvidence>[];
    final byId = <String, EquipmentElectricalLoad>{};
    for (final load in loads) {
      if (byId.containsKey(load.componentInstanceId)) {
        issues.add(CircuitIssue('DUPLICATE_LOAD', 'Load IDs must be unique.',
            loadId: load.componentInstanceId));
      }
      byId[load.componentInstanceId] = load;
    }
    for (final code in circuit.inputs.validate()) {
      issues.add(CircuitIssue(
          code, 'Check circuit voltage, phase count and demand factor.'));
    }
    if (circuit.loadIds.isEmpty)
      issues.add(
          const CircuitIssue('EMPTY_CIRCUIT', 'Assign at least one load.'));
    final supported =
        circuit.inputs.supplySystem == SupplySystem.singlePhaseAc ||
            circuit.inputs.supplySystem == SupplySystem.threePhaseAc ||
            circuit.inputs.supplySystem == SupplySystem.directCurrent;
    if (!supported)
      issues.add(const CircuitIssue('UNSUPPORTED_SUPPLY',
          'Current calculation supports single-phase AC, balanced three-phase AC and DC.'));
    final ids = circuit.loadIds.toList()..sort();
    final seen = <String>{};
    final signatureLoads = <Object?>[];
    var total = 0.0;
    for (final id in ids) {
      final load = byId[id];
      if (!seen.add(id)) {
        issues.add(CircuitIssue(
            'DUPLICATE_ASSIGNMENT', 'Each load can appear only once.',
            loadId: id));
        continue;
      }
      if (load == null) {
        issues.add(CircuitIssue('LOAD_UNAVAILABLE',
            'Assigned equipment or load is missing or inactive.',
            loadId: id));
        signatureLoads.add([id, null]);
        continue;
      }
      final profile = load.profile;
      signatureLoads.add([
        id,
        profile.nominalVoltageV,
        profile.phases,
        profile.supplySystem.name,
        profile.ratedCurrentA,
        profile.ratedPowerW,
        profile.powerFactor,
        profile.efficiency,
        load.powerBasis?.name
      ]);
      if (ElectricalLoadValidator.validate(profile).isNotEmpty) {
        issues.add(CircuitIssue('INVALID_LOAD', 'Check the load parameters.',
            loadId: id));
        continue;
      }
      if (profile.phases != circuit.inputs.phases ||
          profile.supplySystem != circuit.inputs.supplySystem ||
          (profile.nominalVoltageV - circuit.inputs.nominalVoltageV).abs() >
              1e-6) {
        issues.add(CircuitIssue('INCOMPATIBLE_SUPPLY',
            'Load voltage, supply and phases must match the circuit.',
            loadId: id));
        continue;
      }
      if (!supported) continue;
      double current;
      String formula;
      if (profile.ratedCurrentA != null) {
        current = profile.ratedCurrentA!;
        formula = 'I = rated current';
      } else {
        if (load.powerBasis == null) {
          issues.add(CircuitIssue('MISSING_POWER_BASIS',
              'Specify electrical input or mechanical output power.',
              loadId: id));
          continue;
        }
        final dc = profile.supplySystem == SupplySystem.directCurrent;
        if (!dc && profile.powerFactor == null) {
          issues.add(CircuitIssue(
              'MISSING_POWER_FACTOR', 'Enter the load power factor.',
              loadId: id));
          continue;
        }
        final output = load.powerBasis == ElectricalPowerBasis.mechanicalOutput;
        if (output && profile.efficiency == null) {
          issues.add(CircuitIssue('MISSING_EFFICIENCY',
              'Enter efficiency for mechanical output power.',
              loadId: id));
          continue;
        }
        final efficiency = output ? profile.efficiency! : 1.0;
        final factor = dc ? 1.0 : profile.powerFactor!;
        final phaseMultiplier =
            profile.supplySystem == SupplySystem.threePhaseAc
                ? math.sqrt(3)
                : 1.0;
        current = profile.ratedPowerW! /
            (phaseMultiplier * profile.nominalVoltageV * factor * efficiency);
        formula = dc
            ? (output ? 'I = P / (U × η)' : 'I = P / U')
            : 'I = P / (${profile.phases == 3 ? '√3 × ' : ''}U × cosφ${output ? ' × η' : ''})';
      }
      if (!current.isFinite || current <= 0) {
        issues.add(CircuitIssue(
            'INVALID_RESULT', 'Current must be finite and positive.',
            loadId: id));
        continue;
      }
      total += current;
      evidence.add(LoadCurrentEvidence(
          loadId: id,
          currentA: current,
          formula: formula,
          inputs: Map.unmodifiable({
            'voltageV': profile.nominalVoltageV,
            'phases': profile.phases,
            'ratedCurrentA': profile.ratedCurrentA,
            'ratedPowerW': profile.ratedPowerW,
            'powerFactor': profile.powerFactor,
            'efficiency': profile.efficiency,
            'powerBasis': load.powerBasis?.name
          })));
    }
    final result = circuit.inputs.demandFactor * total;
    if (!result.isFinite)
      issues.add(const CircuitIssue(
          'INVALID_RESULT', 'Aggregated current is not finite.'));
    return CircuitCalculation(
        designCurrentA: issues.isEmpty ? result : null,
        issues: issues,
        evidence: evidence,
        inputSignature: jsonEncode(_signatureValue([
          CircuitCalculation.algorithmVersion,
          circuit.id,
          circuit.roomId,
          circuit.name,
          circuit.sourceGroupId,
          circuit.inputs.nominalVoltageV,
          circuit.inputs.phases,
          circuit.inputs.supplySystem.name,
          circuit.inputs.demandFactor,
          signatureLoads
        ])));
  }

  static Object? _signatureValue(Object? value) {
    if (value is num && !value.isFinite) return value.toString();
    if (value is List) return value.map(_signatureValue).toList();
    return value;
  }
}
