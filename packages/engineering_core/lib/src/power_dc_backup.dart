import 'power_assets.dart';
import 'power_catalog.dart';
import 'power_evaluation.dart';
import 'power_load_evaluation.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

enum DcResistanceModel { loopTotalOhm, conductorOhmPerM }

final class DcSection {
  DcSection.loopTotal({
    required String sectionId,
    required String parentNodeId,
    required String childNodeId,
    required PowerRational loopResistanceOhm,
    required this.currentRatingA,
    required String evidenceRef,
  })  : sectionId = _text(sectionId, 'sectionId'),
        parentNodeId = _text(parentNodeId, 'parentNodeId'),
        childNodeId = _text(childNodeId, 'childNodeId'),
        resistanceModel = DcResistanceModel.loopTotalOhm,
        _loopResistanceOhm = loopResistanceOhm,
        installedLengthM = null,
        forwardOhmPerM = null,
        returnOhmPerM = null,
        contactResistanceOhm = null,
        evidenceRef = _text(evidenceRef, 'evidenceRef') {
    _positive(loopResistanceOhm, 'loopResistanceOhm');
    _positive(currentRatingA, 'currentRatingA');
  }

  DcSection.conductorPerMeter({
    required String sectionId,
    required String parentNodeId,
    required String childNodeId,
    required PowerRational installedLengthM,
    required PowerRational forwardOhmPerM,
    required PowerRational returnOhmPerM,
    required PowerRational contactResistanceOhm,
    required this.currentRatingA,
    required String evidenceRef,
  })  : sectionId = _text(sectionId, 'sectionId'),
        parentNodeId = _text(parentNodeId, 'parentNodeId'),
        childNodeId = _text(childNodeId, 'childNodeId'),
        resistanceModel = DcResistanceModel.conductorOhmPerM,
        _loopResistanceOhm = null,
        installedLengthM = installedLengthM,
        forwardOhmPerM = forwardOhmPerM,
        returnOhmPerM = returnOhmPerM,
        contactResistanceOhm = contactResistanceOhm,
        evidenceRef = _text(evidenceRef, 'evidenceRef') {
    _positive(installedLengthM, 'installedLengthM');
    _nonnegative(forwardOhmPerM, 'forwardOhmPerM');
    _nonnegative(returnOhmPerM, 'returnOhmPerM');
    _nonnegative(contactResistanceOhm, 'contactResistanceOhm');
    _positive(currentRatingA, 'currentRatingA');
  }

  final String sectionId;
  final String parentNodeId;
  final String childNodeId;
  final DcResistanceModel resistanceModel;
  final PowerRational? _loopResistanceOhm;
  final PowerRational? installedLengthM;
  final PowerRational? forwardOhmPerM;
  final PowerRational? returnOhmPerM;
  final PowerRational? contactResistanceOhm;
  final PowerRational currentRatingA;
  final String evidenceRef;

  PowerRational get loopResistanceOhm => switch (resistanceModel) {
        DcResistanceModel.loopTotalOhm => _loopResistanceOhm!,
        DcResistanceModel.conductorOhmPerM =>
          (forwardOhmPerM! + returnOhmPerM!) * installedLengthM! +
              contactResistanceOhm!,
      };
}

final class DcConstantCurrentLoad {
  DcConstantCurrentLoad({
    required String loadId,
    required String nodeId,
    required this.currentA,
    required this.allowedMinV,
    required this.allowedMaxV,
  })  : loadId = _text(loadId, 'loadId'),
        nodeId = _text(nodeId, 'nodeId') {
    _nonnegative(currentA, 'currentA');
    _positive(allowedMinV, 'allowedMinV');
    _positive(allowedMaxV, 'allowedMaxV');
    if (allowedMinV > allowedMaxV) {
      throw ArgumentError('DC load voltage bounds are reversed.');
    }
  }

  final String loadId;
  final String nodeId;
  final PowerRational currentA;
  final PowerRational allowedMinV;
  final PowerRational allowedMaxV;
}

final class DcTreeInput {
  DcTreeInput({
    required String sourceNodeId,
    required this.sourceVoltage,
    required Iterable<DcSection> sections,
    required Iterable<DcConstantCurrentLoad> loads,
  })  : sourceNodeId = _text(sourceNodeId, 'sourceNodeId'),
        sections = List.unmodifiable(sections),
        loads = List.unmodifiable(loads) {
    if (sourceVoltage.currentKind != PowerCurrentKind.dc) {
      throw ArgumentError('DC tree source must use a DC envelope.');
    }
  }

  final String sourceNodeId;
  final PowerVoltageEnvelope sourceVoltage;
  final List<DcSection> sections;
  final List<DcConstantCurrentLoad> loads;
}

final class DcSectionResult {
  const DcSectionResult({
    required this.sectionId,
    required this.currentA,
    required this.resistanceOhm,
    required this.dropV,
    required this.lossW,
    required this.currentMarginA,
  });

  final String sectionId;
  final PowerRational currentA;
  final PowerRational resistanceOhm;
  final PowerRational dropV;
  final PowerRational lossW;
  final PowerRational currentMarginA;
}

final class DcTerminalResult {
  const DcTerminalResult({
    required this.loadId,
    required this.minimumV,
    required this.nominalV,
    required this.maximumV,
    required this.status,
  });

  final String loadId;
  final PowerRational minimumV;
  final PowerRational nominalV;
  final PowerRational maximumV;
  final PowerEvaluationStatus status;
}

final class DcTreeResult {
  const DcTreeResult({
    required this.status,
    required this.sections,
    required this.terminals,
    required this.sourceCurrentA,
    required this.totalLossW,
    required this.sourceNominalW,
    required this.deliveredNominalW,
    required this.conservationResidualW,
  });

  final PowerEvaluationStatus status;
  final List<DcSectionResult> sections;
  final List<DcTerminalResult> terminals;
  final PowerRational sourceCurrentA;
  final PowerRational totalLossW;
  final PowerRational sourceNominalW;
  final PowerRational deliveredNominalW;
  final PowerRational conservationResidualW;
}

DcTreeResult solveDcConstantCurrentTree(DcTreeInput input) {
  final byChild = <String, DcSection>{};
  final children = <String, List<DcSection>>{};
  final allNodes = <String>{input.sourceNodeId};
  for (final section in input.sections) {
    if (byChild.containsKey(section.childNodeId)) {
      throw ArgumentError('Radial DC tree cannot have two parent sections.');
    }
    byChild[section.childNodeId] = section;
    children.putIfAbsent(section.parentNodeId, () => []).add(section);
    allNodes.add(section.parentNodeId);
    allNodes.add(section.childNodeId);
  }
  final reachable = _reachable(input.sourceNodeId, children);
  if (!allNodes.every(reachable.contains) || _hasCycle(input.sourceNodeId, children)) {
    throw ArgumentError('DC constant-current model requires one radial tree.');
  }

  final loadsByNode = <String, List<DcConstantCurrentLoad>>{};
  final loadIds = <String>{};
  for (final load in input.loads) {
    if (!loadIds.add(load.loadId)) {
      throw ArgumentError('DC load identities must be unique.');
    }
    if (!reachable.contains(load.nodeId)) {
      throw ArgumentError('DC load is outside the source tree.');
    }
    loadsByNode.putIfAbsent(load.nodeId, () => []).add(load);
  }

  final subtreeCurrent = <String, PowerRational>{};
  PowerRational currentAt(String node) {
    final cached = subtreeCurrent[node];
    if (cached != null) return cached;
    var result = PowerRational.zero;
    for (final load in loadsByNode[node] ?? const <DcConstantCurrentLoad>[]) {
      result += load.currentA;
    }
    for (final section in children[node] ?? const <DcSection>[]) {
      result += currentAt(section.childNodeId);
    }
    subtreeCurrent[node] = result;
    return result;
  }
  final sourceCurrent = currentAt(input.sourceNodeId);

  final minV = <String, PowerRational>{input.sourceNodeId: input.sourceVoltage.minV};
  final nominalV = <String, PowerRational>{
    input.sourceNodeId: input.sourceVoltage.nominalV,
  };
  final maxV = <String, PowerRational>{input.sourceNodeId: input.sourceVoltage.maxV};
  final sectionResults = <DcSectionResult>[];
  var totalLoss = PowerRational.zero;

  void walk(String node) {
    final outgoing = [...children[node] ?? const <DcSection>[]]
      ..sort((a, b) => a.sectionId.compareTo(b.sectionId));
    for (final section in outgoing) {
      final current = subtreeCurrent[section.childNodeId] ?? PowerRational.zero;
      final resistance = section.loopResistanceOhm;
      final drop = current * resistance;
      final loss = current * current * resistance;
      sectionResults.add(
        DcSectionResult(
          sectionId: section.sectionId,
          currentA: current,
          resistanceOhm: resistance,
          dropV: drop,
          lossW: loss,
          currentMarginA: section.currentRatingA - current,
        ),
      );
      totalLoss += loss;
      minV[section.childNodeId] = minV[node]! - drop;
      nominalV[section.childNodeId] = nominalV[node]! - drop;
      maxV[section.childNodeId] = maxV[node]! - drop;
      walk(section.childNodeId);
    }
  }
  walk(input.sourceNodeId);

  var deliveredNominalW = PowerRational.zero;
  var failed = sectionResults.any((result) => result.currentMarginA.isNegative);
  final terminalResults = <DcTerminalResult>[];
  final sortedLoads = [...input.loads]
    ..sort((a, b) => a.loadId.compareTo(b.loadId));
  for (final load in sortedLoads) {
    final low = minV[load.nodeId]!;
    final nominal = nominalV[load.nodeId]!;
    final high = maxV[load.nodeId]!;
    final pass = low >= load.allowedMinV && high <= load.allowedMaxV;
    failed |= !pass;
    terminalResults.add(
      DcTerminalResult(
        loadId: load.loadId,
        minimumV: low,
        nominalV: nominal,
        maximumV: high,
        status: pass ? PowerEvaluationStatus.pass : PowerEvaluationStatus.fail,
      ),
    );
    deliveredNominalW += nominal * load.currentA;
  }
  sectionResults.sort((a, b) => a.sectionId.compareTo(b.sectionId));
  final sourceNominalW = input.sourceVoltage.nominalV * sourceCurrent;
  return DcTreeResult(
    status: failed ? PowerEvaluationStatus.fail : PowerEvaluationStatus.pass,
    sections: List.unmodifiable(sectionResults),
    terminals: List.unmodifiable(terminalResults),
    sourceCurrentA: sourceCurrent,
    totalLossW: totalLoss,
    sourceNominalW: sourceNominalW,
    deliveredNominalW: deliveredNominalW,
    conservationResidualW: sourceNominalW - deliveredNominalW - totalLoss,
  );
}

final class ConstantPowerFeederResult {
  const ConstantPowerFeederResult({
    required this.status,
    required this.terminalVoltage,
    required this.current,
    required this.lossW,
    required this.iterations,
  });

  final PowerEvaluationStatus status;
  final PowerInterval? terminalVoltage;
  final PowerInterval? current;
  final PowerInterval? lossW;
  final int iterations;
}

ConstantPowerFeederResult solveSingleConstantPowerFeeder({
  required PowerRational sourceVoltageV,
  required PowerRational loadPowerW,
  required PowerRational loopResistanceOhm,
  int maxIterations = 128,
  PowerRational? toleranceV,
}) {
  _positive(sourceVoltageV, 'sourceVoltageV');
  _nonnegative(loadPowerW, 'loadPowerW');
  _positive(loopResistanceOhm, 'loopResistanceOhm');
  if (maxIterations < 1 || maxIterations > 1024) {
    throw ArgumentError('Invalid constant-power iteration bound.');
  }
  final tolerance = toleranceV ??
      PowerRational(BigInt.one, BigInt.from(1000000000));
  _positive(tolerance, 'toleranceV');
  if (loadPowerW.isZero) {
    return ConstantPowerFeederResult(
      status: PowerEvaluationStatus.pass,
      terminalVoltage: PowerInterval.exact(sourceVoltageV),
      current: PowerInterval.exact(PowerRational.zero),
      lossW: PowerInterval.exact(PowerRational.zero),
      iterations: 0,
    );
  }

  PowerRational equation(PowerRational voltage) => voltage * voltage -
      sourceVoltageV * voltage +
      loadPowerW * loopResistanceOhm;
  var low = sourceVoltageV / PowerRational.integer(2);
  var high = sourceVoltageV;
  if (equation(low) > PowerRational.zero) {
    return const ConstantPowerFeederResult(
      status: PowerEvaluationStatus.fail,
      terminalVoltage: null,
      current: null,
      lossW: null,
      iterations: 0,
    );
  }

  var iterations = 0;
  while (high - low > tolerance && iterations < maxIterations) {
    final mid = (low + high) / PowerRational.integer(2);
    if (equation(mid) <= PowerRational.zero) {
      low = mid;
    } else {
      high = mid;
    }
    iterations++;
  }
  final voltage = PowerInterval(low, high);
  if (voltage.width > tolerance) {
    return ConstantPowerFeederResult(
      status: PowerEvaluationStatus.unresolved,
      terminalVoltage: voltage,
      current: null,
      lossW: null,
      iterations: iterations,
    );
  }
  final current = PowerInterval(loadPowerW / high, loadPowerW / low);
  final loss = PowerInterval(
    current.lower * current.lower * loopResistanceOhm,
    current.upper * current.upper * loopResistanceOhm,
  );
  return ConstantPowerFeederResult(
    status: PowerEvaluationStatus.pass,
    terminalVoltage: voltage,
    current: current,
    lossW: loss,
    iterations: iterations,
  );
}

final class BackupEnergySegment {
  BackupEnergySegment({
    required String segmentId,
    required this.durationSeconds,
    required this.bankInputW,
  }) : segmentId = _text(segmentId, 'segmentId') {
    _positive(durationSeconds, 'durationSeconds');
    _nonnegative(bankInputW, 'bankInputW');
  }

  final String segmentId;
  final PowerRational durationSeconds;
  final PowerRational bankInputW;
}

final class BatteryWhAvailabilityModel {
  BatteryWhAvailabilityModel({
    required this.modelVoltageV,
    required this.bankAh,
    required this.initialSocFraction,
    required this.minimumSocFraction,
    required this.temperatureFactor,
    required this.agingFactor,
    required this.rateFactor,
  }) {
    _positive(modelVoltageV, 'modelVoltageV');
    _positive(bankAh, 'bankAh');
    for (final entry in {
      'initialSocFraction': initialSocFraction,
      'minimumSocFraction': minimumSocFraction,
      'temperatureFactor': temperatureFactor,
      'agingFactor': agingFactor,
      'rateFactor': rateFactor,
    }.entries) {
      _factor(entry.value, entry.key);
    }
    if (minimumSocFraction >= initialSocFraction) {
      throw ArgumentError('Battery usable SOC window must be positive.');
    }
  }

  final PowerRational modelVoltageV;
  final PowerRational bankAh;
  final PowerRational initialSocFraction;
  final PowerRational minimumSocFraction;
  final PowerRational temperatureFactor;
  final PowerRational agingFactor;
  final PowerRational rateFactor;

  PowerRational get availableWh => modelVoltageV *
      bankAh *
      (initialSocFraction - minimumSocFraction) *
      temperatureFactor *
      agingFactor *
      rateFactor;
}

final class BatterySequenceResult {
  const BatterySequenceResult({
    required this.status,
    required this.requiredWh,
    required this.availableWh,
    required this.marginWh,
    required this.sequenceDurationSeconds,
    required this.estimatedAutonomySeconds,
  });

  final PowerEvaluationStatus status;
  final PowerRational requiredWh;
  final PowerRational availableWh;
  final PowerRational marginWh;
  final PowerRational sequenceDurationSeconds;
  final PowerRational? estimatedAutonomySeconds;
}

BatterySequenceResult evaluateBatterySequence({
  required Iterable<BackupEnergySegment> segments,
  required BatteryWhAvailabilityModel availability,
  PowerExtensionPolicy extensionPolicy = PowerExtensionPolicy.none,
}) {
  final sequence = segments.toList();
  if (sequence.isEmpty) throw ArgumentError('Backup sequence cannot be empty.');
  if (sequence.map((item) => item.segmentId).toSet().length != sequence.length) {
    throw ArgumentError('Backup segment identities must be unique.');
  }
  var requiredWh = PowerRational.zero;
  var durationSeconds = PowerRational.zero;
  for (final segment in sequence) {
    requiredWh += segment.bankInputW * segment.durationSeconds /
        PowerRational.integer(3600);
    durationSeconds += segment.durationSeconds;
  }
  final availableWh = availability.availableWh;
  final marginWh = availableWh - requiredWh;
  PowerRational? autonomySeconds;
  if (extensionPolicy == PowerExtensionPolicy.continueLast) {
    final lastPower = sequence.last.bankInputW;
    if (!lastPower.isZero) {
      autonomySeconds = durationSeconds +
          (marginWh > PowerRational.zero
              ? marginWh * PowerRational.integer(3600) / lastPower
              : PowerRational.zero);
    }
  } else if (extensionPolicy == PowerExtensionPolicy.repeatSequence &&
      !requiredWh.isZero) {
    autonomySeconds = availableWh * durationSeconds / requiredWh;
  }
  return BatterySequenceResult(
    status: marginWh.isNegative
        ? PowerEvaluationStatus.fail
        : PowerEvaluationStatus.pass,
    requiredWh: requiredWh,
    availableWh: availableWh,
    marginWh: marginWh,
    sequenceDurationSeconds: durationSeconds,
    estimatedAutonomySeconds: autonomySeconds,
  );
}

final class ChargerEvaluationResult {
  const ChargerEvaluationResult({
    required this.status,
    required this.operatingOutputW,
    required this.chargingOutputW,
    required this.combinedOutputW,
    required this.upstreamInputW,
    required this.chargeCurrentMarginA,
  });

  final PowerEvaluationStatus status;
  final PowerRational operatingOutputW;
  final PowerRational chargingOutputW;
  final PowerRational combinedOutputW;
  final PowerRational upstreamInputW;
  final PowerRational chargeCurrentMarginA;
}

ChargerEvaluationResult evaluateChargerDemand({
  required PowerChargerDefinition charger,
  required BatteryUnitDefinition battery,
  required PowerRational operatingOutputW,
  required PowerRational chargeVoltageV,
  required PowerRational selectedChargeCurrentA,
  required bool chargingSelected,
  required bool dischargingSelected,
}) {
  _nonnegative(operatingOutputW, 'operatingOutputW');
  _positive(chargeVoltageV, 'chargeVoltageV');
  _nonnegative(selectedChargeCurrentA, 'selectedChargeCurrentA');
  if (chargingSelected && dischargingSelected) {
    throw ArgumentError('Charge/discharge directions are interlocked.');
  }
  var status = PowerEvaluationStatus.pass;
  if (!charger.supports(battery) ||
      chargeVoltageV < charger.outputVoltage.minV ||
      chargeVoltageV > charger.outputVoltage.maxV) {
    status = PowerEvaluationStatus.fail;
  }
  final chargeCurrent = chargingSelected
      ? selectedChargeCurrentA
      : PowerRational.zero;
  final currentMargin = charger.maxChargeCurrentA - chargeCurrent;
  if (currentMargin.isNegative) status = PowerEvaluationStatus.fail;
  final chargingOutputW = chargeVoltageV * chargeCurrent;
  final combinedOutputW = operatingOutputW + chargingOutputW;
  final upstreamInputW = evaluateTransferInputDemand(
    transferId: 'CHARGER',
    deliveredOutputW: combinedOutputW,
    loss: charger.lossDefinition,
  ).inputW;
  return ChargerEvaluationResult(
    status: status,
    operatingOutputW: operatingOutputW,
    chargingOutputW: chargingOutputW,
    combinedOutputW: combinedOutputW,
    upstreamInputW: upstreamInputW,
    chargeCurrentMarginA: currentMargin,
  );
}

Set<String> _reachable(String root, Map<String, List<DcSection>> children) {
  final result = <String>{};
  void visit(String node) {
    if (!result.add(node)) return;
    for (final section in children[node] ?? const <DcSection>[]) {
      visit(section.childNodeId);
    }
  }
  visit(root);
  return result;
}

bool _hasCycle(String root, Map<String, List<DcSection>> children) {
  final visiting = <String>{};
  final visited = <String>{};
  bool visit(String node) {
    if (visiting.contains(node)) return true;
    if (!visited.add(node)) return false;
    visiting.add(node);
    for (final section in children[node] ?? const <DcSection>[]) {
      if (visit(section.childNodeId)) return true;
    }
    visiting.remove(node);
    return false;
  }
  return visit(root);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

void _positive(PowerRational value, String field) {
  if (value <= PowerRational.zero) {
    throw ArgumentError.value(value, field, 'Must be positive.');
  }
}

void _nonnegative(PowerRational value, String field) {
  if (value.isNegative) {
    throw ArgumentError.value(value, field, 'Must be nonnegative.');
  }
}

void _factor(PowerRational value, String field) {
  if (value.isNegative || value > PowerRational.one) {
    throw ArgumentError.value(value, field, 'Must be in [0,1].');
  }
}
