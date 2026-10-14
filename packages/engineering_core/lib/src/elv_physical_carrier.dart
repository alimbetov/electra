enum PhysicalCarrierKind {
  tray,
  basketTray,
  ladderTray,
  conduit,
  trunking,
  duct,
  custom,
}

enum PhysicalCarrierLifecycleState { active, archived }

enum CarrierCompartmentLifecycleState { active, archived }

enum CarrierEnclosureExposure { indoor, outdoor, mixed }

enum MaintenanceAccessibility { accessible, restricted, inaccessible }

final class CarrierTemperatureRange {
  const CarrierTemperatureRange({
    required this.minimumC,
    required this.maximumC,
  });

  final double minimumC;
  final double maximumC;

  bool get valid =>
      minimumC.isFinite && maximumC.isFinite && maximumC >= minimumC;
}

final class CarrierEnvironmentFacts {
  const CarrierEnvironmentFacts({
    this.exposure,
    this.moistureClassCode,
    this.contaminationClassCode,
    this.climateClassCode,
    this.temperatureRange,
  });

  final CarrierEnclosureExposure? exposure;
  final String? moistureClassCode;
  final String? contaminationClassCode;
  final String? climateClassCode;
  final CarrierTemperatureRange? temperatureRange;
}

final class CarrierInstallationFacts {
  const CarrierInstallationFacts({
    this.installationClassCode,
    this.accessibility,
    this.barrierPresent = false,
  });

  final String? installationClassCode;
  final MaintenanceAccessibility? accessibility;
  final bool barrierPresent;
}

sealed class CarrierCrossSection {
  const CarrierCrossSection();

  bool get valid;
  double get usableAreaMm2;
}

final class RectangularCarrierCrossSection extends CarrierCrossSection {
  const RectangularCarrierCrossSection({
    required this.widthMm,
    required this.heightMm,
  });

  final double widthMm;
  final double heightMm;

  @override
  bool get valid =>
      widthMm.isFinite && heightMm.isFinite && widthMm > 0 && heightMm > 0;

  @override
  double get usableAreaMm2 => widthMm * heightMm;
}

final class CircularCarrierCrossSection extends CarrierCrossSection {
  const CircularCarrierCrossSection(this.diameterMm);

  final double diameterMm;

  @override
  bool get valid => diameterMm.isFinite && diameterMm > 0;

  @override
  double get usableAreaMm2 => 3.141592653589793 * diameterMm * diameterMm / 4;
}

final class CustomCarrierCrossSection extends CarrierCrossSection {
  const CustomCarrierCrossSection({
    required this.areaMm2,
    required this.provenance,
  });

  final double areaMm2;
  final String provenance;

  @override
  bool get valid =>
      areaMm2.isFinite && areaMm2 > 0 && provenance.trim().isNotEmpty;

  @override
  double get usableAreaMm2 => areaMm2;
}

final class PhysicalCarrier {
  const PhysicalCarrier({
    required this.id,
    required this.projectId,
    required this.pathwayContextId,
    required this.code,
    required this.name,
    required this.kind,
    required this.crossSection,
    required this.environmentFacts,
    required this.installationFacts,
    required this.lifecycleState,
    required this.revision,
  });

  final String id;
  final String projectId;
  final String pathwayContextId;
  final String code;
  final String name;
  final PhysicalCarrierKind kind;
  final CarrierCrossSection crossSection;
  final CarrierEnvironmentFacts environmentFacts;
  final CarrierInstallationFacts installationFacts;
  final PhysicalCarrierLifecycleState lifecycleState;
  final int revision;

  String get normalizedCode => code.trim().toUpperCase();

  List<String> validate() => [
        if (id.trim().isEmpty || projectId.trim().isEmpty)
          'Carrier identity and project are required.',
        if (pathwayContextId.trim().isEmpty)
          'Carrier pathwayContextId is required.',
        if (normalizedCode.isEmpty) 'Carrier code is required.',
        if (!crossSection.valid)
          'Carrier cross-section dimensions must be positive and finite.',
        if (environmentFacts.temperatureRange?.valid == false)
          'Carrier temperature range is invalid.',
        if (revision < 1) 'Carrier revision must be >= 1.',
      ];
}

final class PhysicalCarrierCompartment {
  const PhysicalCarrierCompartment({
    required this.id,
    required this.carrierId,
    required this.code,
    required this.sequence,
    required this.crossSection,
    required this.lifecycleState,
    required this.revision,
  });

  final String id;
  final String carrierId;
  final String code;
  final int sequence;
  final CarrierCrossSection crossSection;
  final CarrierCompartmentLifecycleState lifecycleState;
  final int revision;

  String get normalizedCode => code.trim().toUpperCase();

  List<String> validate() => [
        if (id.trim().isEmpty || carrierId.trim().isEmpty)
          'Carrier compartment identity and carrier are required.',
        if (normalizedCode.isEmpty) 'Carrier compartment code is required.',
        if (sequence < 1) 'Carrier compartment sequence must be >= 1.',
        if (!crossSection.valid)
          'Carrier compartment cross-section must be positive and finite.',
        if (revision < 1) 'Carrier compartment revision must be >= 1.',
      ];
}

List<String> validateCarrierCompartments({
  required PhysicalCarrier carrier,
  required Iterable<PhysicalCarrierCompartment> compartments,
}) {
  final active = compartments
      .where(
        (item) =>
            item.lifecycleState == CarrierCompartmentLifecycleState.active,
      )
      .toList(growable: false);
  final errors = <String>[
    for (final compartment in active) ...compartment.validate(),
  ];

  if (active.any((item) => item.carrierId != carrier.id)) {
    errors.add('Carrier compartments must belong to the same carrier.');
  }
  if (active.map((item) => item.normalizedCode).toSet().length !=
      active.length) {
    errors.add('Active carrier compartment codes must be unique.');
  }
  if (active.map((item) => item.sequence).toSet().length != active.length) {
    errors.add('Active carrier compartment sequences must be unique.');
  }
  if (active.every((item) => item.crossSection.valid) &&
      carrier.crossSection.valid) {
    final sum = active.fold<double>(
      0,
      (value, item) => value + item.crossSection.usableAreaMm2,
    );
    if (sum > carrier.crossSection.usableAreaMm2) {
      errors.add('Active compartment usable area exceeds carrier usable area.');
    }
  }

  return errors;
}
