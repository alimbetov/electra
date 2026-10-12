import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

ElectricalCircuit circuit(
        {List<String> ids = const ['load'],
        double voltage = 230,
        int phases = 1,
        SupplySystem supply = SupplySystem.singlePhaseAc,
        double demand = 1}) =>
    ElectricalCircuit(
        id: 'circuit',
        roomId: 'room',
        name: 'Circuit 1',
        inputs: ElectricalCircuitInputs(
            nominalVoltageV: voltage,
            phases: phases,
            supplySystem: supply,
            demandFactor: demand),
        loadIds: ids);
EquipmentElectricalLoad load(
        {String id = 'load',
        double voltage = 230,
        int phases = 1,
        SupplySystem supply = SupplySystem.singlePhaseAc,
        double? power = 2300,
        double? current,
        double? pf = 1,
        double? efficiency,
        ElectricalPowerBasis? basis = ElectricalPowerBasis.electricalInput}) =>
    EquipmentElectricalLoad(
        componentInstanceId: id,
        powerBasis: basis,
        profile: ElectricalLoadProfile(
            nominalVoltageV: voltage,
            phases: phases,
            supplySystem: supply,
            ratedPowerW: power,
            ratedCurrentA: current,
            powerFactor: pf,
            efficiency: efficiency));

void main() {
  test('single phase input power uses PF and never double-applies efficiency',
      () {
    final result =
        CircuitCurrentCalculator.calculate(circuit(), [load(efficiency: 0.5)]);
    expect(result.ready, isTrue);
    expect(result.designCurrentA, 10);
    expect(result.evidence.single.formula, 'I = P / (U × cosφ)');
  });
  test('balanced three phase motor output applies line voltage and efficiency',
      () {
    final result = CircuitCurrentCalculator.calculate(
        circuit(voltage: 400, phases: 3, supply: SupplySystem.threePhaseAc), [
      load(
          voltage: 400,
          phases: 3,
          supply: SupplySystem.threePhaseAc,
          power: 7500,
          pf: 0.8,
          efficiency: 0.9,
          basis: ElectricalPowerBasis.mechanicalOutput)
    ]);
    expect(result.designCurrentA, closeTo(15.035163, 0.000001));
    expect(result.evidence.single.formula, 'I = P / (√3 × U × cosφ × η)');
  });
  test('DC power requires neither PF nor efficiency for input power', () {
    final result = CircuitCurrentCalculator.calculate(
        circuit(voltage: 48, supply: SupplySystem.directCurrent), [
      load(
          voltage: 48, supply: SupplySystem.directCurrent, power: 480, pf: null)
    ]);
    expect(result.designCurrentA, 10);
    expect(result.evidence.single.formula, 'I = P / U');
  });
  test('explicit rated current has priority over power and unknown basis', () {
    final result = CircuitCurrentCalculator.calculate(
        circuit(), [load(power: 9999, current: 16, pf: null, basis: null)]);
    expect(result.designCurrentA, 16);
    expect(result.evidence.single.formula, 'I = rated current');
  });
  test('conservative current sum applies the persisted explicit demand factor',
      () {
    final result = CircuitCurrentCalculator.calculate(
        circuit(ids: ['a', 'b'], demand: 0.5),
        [load(id: 'a'), load(id: 'b', current: 20)]);
    expect(result.designCurrentA, 15);
    expect(result.evidence.map((item) => item.loadId), ['a', 'b']);
  });
  test('incomplete data never produces a partial circuit total', () {
    for (final entry in [
      (load(basis: null), 'MISSING_POWER_BASIS'),
      (load(pf: null), 'MISSING_POWER_FACTOR'),
      (
        load(basis: ElectricalPowerBasis.mechanicalOutput),
        'MISSING_EFFICIENCY'
      ),
      (load(voltage: 400), 'INCOMPATIBLE_SUPPLY'),
    ]) {
      final result = CircuitCurrentCalculator.calculate(circuit(), [entry.$1]);
      expect(result.designCurrentA, isNull);
      expect(result.issues.map((issue) => issue.code), contains(entry.$2));
    }
    expect(
        CircuitCurrentCalculator.calculate(
            circuit(ids: ['a', 'missing']), [load(id: 'a')]).designCurrentA,
        isNull);
  });
  test(
      'rejects empty, duplicate, unsupported and nonfinite inputs without throwing',
      () {
    for (final proposal in [
      circuit(ids: []),
      circuit(ids: ['load', 'load']),
      circuit(demand: double.nan),
      circuit(voltage: double.infinity),
      circuit(supply: SupplySystem.custom)
    ]) {
      final result = CircuitCurrentCalculator.calculate(proposal, [load()]);
      expect(result.ready, isFalse);
      expect(result.inputSignature, isNotEmpty);
    }
    expect(
        CircuitCurrentCalculator.calculate(circuit(), [load(power: double.nan)])
            .ready,
        isFalse);
    expect(
        CircuitCurrentCalculator.calculate(circuit(), [load(), load()]).ready,
        isFalse);
  });
  test(
      'confirmation is bound to canonical sorted inputs and becomes stale on edits',
      () {
    final proposal = circuit(ids: ['b', 'a']);
    final original = CircuitCurrentCalculator.calculate(
        proposal, [load(id: 'a'), load(id: 'b')]);
    final reordered = CircuitCurrentCalculator.calculate(
        circuit(ids: ['a', 'b']), [load(id: 'b'), load(id: 'a')]);
    expect(reordered.inputSignature, original.inputSignature);
    expect(
        CircuitSnapshot(
                circuit: proposal,
                calculation: original,
                reviewedInputSignature: original.inputSignature)
            .status,
        CircuitStatus.confirmed);
    final changed = CircuitCurrentCalculator.calculate(
        proposal, [load(id: 'a', power: 4600), load(id: 'b')]);
    expect(
        CircuitSnapshot(
                circuit: proposal,
                calculation: changed,
                reviewedInputSignature: original.inputSignature)
            .status,
        CircuitStatus.reviewRequired);
    expect(CircuitSnapshot(circuit: proposal, calculation: changed).status,
        CircuitStatus.proposed);
  });
}
