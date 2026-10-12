import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('accepts single and three phase explicit loads', () {
    for (final phases in [1, 3]) {
      expect(
          ElectricalLoadValidator.validate(ElectricalLoadProfile(
            nominalVoltageV: phases == 1 ? 230 : 400,
            phases: phases,
            supplySystem: phases == 1
                ? SupplySystem.singlePhaseAc
                : SupplySystem.threePhaseAc,
            ratedPowerW: 1500,
            powerFactor: 0.9,
            efficiency: 0.95,
          )),
          isEmpty);
    }
  });
  test('rejects missing demand, nonfinite values and inconsistent supply', () {
    expect(
        ElectricalLoadValidator.validate(const ElectricalLoadProfile(
          nominalVoltageV: double.nan,
          phases: 1,
          supplySystem: SupplySystem.threePhaseAc,
          powerFactor: 1.1,
          efficiency: 0,
        )),
        containsAll([
          'INVALID_VOLTAGE',
          'MISSING_POWER_OR_CURRENT',
          'SUPPLY_PHASE_MISMATCH',
          'INVALID_POWER_FACTOR',
          'INVALID_EFFICIENCY'
        ]));
    expect(
        ElectricalLoadValidator.validate(const ElectricalLoadProfile(
          nominalVoltageV: 230,
          phases: 1,
          ratedPowerW: -1,
          ratedCurrentA: double.infinity,
        )),
        containsAll(['INVALID_POWER', 'INVALID_CURRENT']));
  });
}
