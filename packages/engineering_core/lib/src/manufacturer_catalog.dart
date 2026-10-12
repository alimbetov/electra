enum FunctionalDeviceRole {
  mcb,
  rcbo,
  rcd,
  mccb,
  spd,
  mainIsolator,
  contactor,
  motorProtectionBreaker,
  overloadRelay,
  powerSupply24V,
  plcCpu,
  plcDi,
  plcDo,
  plcAi,
  plcAo,
  terminalBlock,
  vfd,
  softStarter,
  custom,
}

enum ProductLifecycleStatus { active, obsolete, replaced, unknown }

class FunctionalDeviceRequirement {
  const FunctionalDeviceRequirement({
    required this.role,
    this.poles,
    this.ratedCurrentA,
    this.ratedVoltageV,
    this.breakingCapacityKa,
    this.tripCurve,
    this.residualCurrentMa,
    this.residualCurrentType,
    this.moduleWidthUnits,
    this.mountingType,
  });

  final FunctionalDeviceRole role;
  final int? poles;
  final double? ratedCurrentA;
  final double? ratedVoltageV;
  final double? breakingCapacityKa;
  final String? tripCurve;
  final double? residualCurrentMa;
  final String? residualCurrentType;
  final int? moduleWidthUnits;
  final String? mountingType;
}

class ManufacturerProductVariant {
  const ManufacturerProductVariant({
    required this.id,
    required this.manufacturer,
    required this.series,
    required this.sku,
    required this.displayName,
    required this.functionalRole,
    this.ratedCurrentA,
    this.ratedVoltageV,
    this.breakingCapacityKa,
    this.poles,
    this.tripCurve,
    this.residualCurrentMa,
    this.residualCurrentType,
    this.moduleWidthUnits,
    this.widthMm,
    this.heightMm,
    this.depthMm,
    this.lifecycleStatus = ProductLifecycleStatus.active,
    this.metadata = const {},
  });

  final String id;
  final String manufacturer;
  final String series;
  final String sku;
  final String displayName;
  final FunctionalDeviceRole functionalRole;
  final double? ratedCurrentA;
  final double? ratedVoltageV;
  final double? breakingCapacityKa;
  final int? poles;
  final String? tripCurve;
  final double? residualCurrentMa;
  final String? residualCurrentType;
  final int? moduleWidthUnits;
  final double? widthMm;
  final double? heightMm;
  final double? depthMm;
  final ProductLifecycleStatus lifecycleStatus;
  final Map<String, Object?> metadata;
}

class ManufacturerCatalog {
  const ManufacturerCatalog({
    required this.manufacturer,
    required this.catalogVersion,
    required this.products,
    this.region,
  });

  final String manufacturer;
  final String catalogVersion;
  final String? region;
  final List<ManufacturerProductVariant> products;

  Iterable<ManufacturerProductVariant> candidatesFor(
    FunctionalDeviceRequirement requirement,
  ) {
    return products.where((product) {
      if (product.lifecycleStatus == ProductLifecycleStatus.obsolete) {
        return false;
      }
      if (product.functionalRole != requirement.role) return false;
      if (requirement.poles != null && product.poles != requirement.poles) {
        return false;
      }
      if (requirement.ratedCurrentA != null &&
          product.ratedCurrentA != requirement.ratedCurrentA) {
        return false;
      }
      if (requirement.ratedVoltageV != null &&
          product.ratedVoltageV != null &&
          product.ratedVoltageV! < requirement.ratedVoltageV!) {
        return false;
      }
      if (requirement.breakingCapacityKa != null &&
          product.breakingCapacityKa != null &&
          product.breakingCapacityKa! < requirement.breakingCapacityKa!) {
        return false;
      }
      if (requirement.tripCurve != null &&
          product.tripCurve != requirement.tripCurve) {
        return false;
      }
      if (requirement.residualCurrentMa != null &&
          product.residualCurrentMa != requirement.residualCurrentMa) {
        return false;
      }
      if (requirement.residualCurrentType != null &&
          product.residualCurrentType != requirement.residualCurrentType) {
        return false;
      }
      return true;
    });
  }
}

class ProjectManufacturerPolicy {
  const ProjectManufacturerPolicy({
    this.preferredManufacturers = const [],
    this.allowedManufacturers = const [],
    this.preferredSeriesByRole = const {},
  });

  final List<String> preferredManufacturers;
  final List<String> allowedManufacturers;
  final Map<FunctionalDeviceRole, String> preferredSeriesByRole;
}
