import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  Mass kg(String value) => Mass(Elv5Rational.parseDecimal(value));
  Length mm(String value) => Length(Elv5Rational.parseDecimal(value));

  test('2 RU + 1 RU + 1 RU spare against 6 RU leaves +2 RU', () {
    final result = const Lan06RackCapacityKernel().evaluate(Lan06Input(
      rackId: 'rack-1',
      equipment: [
        Lan06EquipmentDemand(
          equipmentId: 'eq-1',
          ru: 2,
          weight: kg('10'),
          depth: mm('400'),
        ),
        Lan06EquipmentDemand(
          equipmentId: 'eq-2',
          ru: 1,
          weight: kg('5'),
          depth: mm('300'),
        ),
      ],
      capacityBasis: Lan06CapacityBasis.netUsable,
      capacity: Lan06CapacityFacts(
        ruCapacity: 6,
        weightCapacity: kg('30'),
        depthCapacity: mm('500'),
      ),
      exclusions: const [],
      explicitSpareRu: 1,
    ));

    expect(result.status, Lan06AssessmentStatus.pass);
    expect(result.requiredRu, 4);
    expect(result.ruMargin, 2);
    expect(result.layoutStatus, Lan06AssessmentStatus.notAssessed);
  });

  test('exact RU equality is PASS while layout remains not assessed', () {
    final result = const Lan06RackCapacityKernel().evaluate(Lan06Input(
      rackId: 'rack-1',
      equipment: [
        Lan06EquipmentDemand(
          equipmentId: 'eq-1',
          ru: 4,
          weight: null,
          depth: null,
        ),
      ],
      capacityBasis: Lan06CapacityBasis.netUsable,
      capacity: Lan06CapacityFacts(ruCapacity: 4),
      exclusions: const [],
      explicitSpareRu: 0,
    ));

    expect(result.ruMargin, 0);
    expect(result.layoutStatus, Lan06AssessmentStatus.notAssessed);
  });

  test('weight can fail independently from RU', () {
    final result = const Lan06RackCapacityKernel().evaluate(Lan06Input(
      rackId: 'rack-1',
      equipment: [
        Lan06EquipmentDemand(
          equipmentId: 'eq-1',
          ru: 2,
          weight: kg('110'),
          depth: mm('400'),
        ),
      ],
      capacityBasis: Lan06CapacityBasis.netUsable,
      capacity: Lan06CapacityFacts(
        ruCapacity: 10,
        weightCapacity: kg('100'),
        depthCapacity: mm('500'),
      ),
      exclusions: const [],
      explicitSpareRu: 0,
    ));

    expect(result.ruMargin, 8);
    expect(result.weightStatus, Lan06AssessmentStatus.fail);
    expect(result.weightMargin, kg('-10'));
    expect(result.status, Lan06AssessmentStatus.fail);
  });

  test(
      'net usable capacity does not subtract already-included reservation again',
      () {
    final result = const Lan06RackCapacityKernel().evaluate(Lan06Input(
      rackId: 'rack-1',
      equipment: [
        Lan06EquipmentDemand(
          equipmentId: 'eq-1',
          ru: 6,
          weight: null,
          depth: null,
        ),
      ],
      capacityBasis: Lan06CapacityBasis.netUsable,
      capacity: Lan06CapacityFacts(ruCapacity: 8),
      exclusions: [
        Lan06Exclusion(
          exclusionId: 'reserved-2ru',
          ru: 2,
          alreadyIncludedInNetCapacity: true,
        ),
      ],
      explicitSpareRu: 0,
    ));

    expect(result.availableRu, 8);
    expect(result.ruMargin, 2);
  });
}
