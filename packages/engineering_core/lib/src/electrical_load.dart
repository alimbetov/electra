import 'component_catalog.dart';

final class RoomConsumptionGroup {
  const RoomConsumptionGroup(
      {required this.id, required this.roomId, required this.name});
  final String id;
  final String roomId;
  final String name;
}

/// Explicit project load, traceable to one placed equipment instance.
final class EquipmentElectricalLoad {
  const EquipmentElectricalLoad(
      {required this.componentInstanceId,
      required this.profile,
      this.consumptionGroupId});
  final String componentInstanceId;
  final ElectricalLoadProfile profile;
  final String? consumptionGroupId;
}

abstract final class ElectricalLoadValidator {
  static List<String> validate(ElectricalLoadProfile profile) {
    final errors = <String>[];
    void positive(double? value, String code) {
      if (value != null && (!value.isFinite || value <= 0)) errors.add(code);
    }

    positive(profile.nominalVoltageV, 'INVALID_VOLTAGE');
    positive(profile.ratedPowerW, 'INVALID_POWER');
    positive(profile.ratedCurrentA, 'INVALID_CURRENT');
    positive(profile.frequencyHz, 'INVALID_FREQUENCY');
    positive(profile.startingCurrentFactor, 'INVALID_STARTING_FACTOR');
    if (profile.ratedPowerW == null && profile.ratedCurrentA == null)
      errors.add('MISSING_POWER_OR_CURRENT');
    if (profile.phases < 1 || profile.phases > 3) errors.add('INVALID_PHASES');
    if ((profile.supplySystem == SupplySystem.threePhaseAc &&
            profile.phases != 3) ||
        (profile.supplySystem == SupplySystem.singlePhaseAc &&
            profile.phases != 1)) errors.add('SUPPLY_PHASE_MISMATCH');
    for (final entry in {
      'INVALID_POWER_FACTOR': profile.powerFactor,
      'INVALID_EFFICIENCY': profile.efficiency
    }.entries) {
      final value = entry.value;
      if (value != null && (!value.isFinite || value <= 0 || value > 1))
        errors.add(entry.key);
    }
    return List.unmodifiable(errors);
  }
}
