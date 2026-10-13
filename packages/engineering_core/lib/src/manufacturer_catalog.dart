enum ProductCurrentKind { ac, dc, acDc }

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
    this.currentKind,
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
  final ProductCurrentKind? currentKind;
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
    this.currentKind,
    this.mountingType,
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
  final ProductCurrentKind? currentKind;
  final String? mountingType;
}

class ManufacturerCatalog {
  const ManufacturerCatalog({
    required this.manufacturer,
    required this.catalogVersion,
    required this.products,
    this.region,
    this.id,
    this.sourceReference,
  });

  final String manufacturer;
  final String catalogVersion;
  final String? region;
  final String? id, sourceReference;
  final List<ManufacturerProductVariant> products;

  Iterable<ManufacturerProductVariant> candidatesFor(
    FunctionalDeviceRequirement requirement,
  ) {
    return products.where((product) =>
        ManufacturerProductMatcher.match(requirement, product).compatible);
  }
}

class ProjectManufacturerPolicy {
  const ProjectManufacturerPolicy({
    this.preferredManufacturers = const [],
    this.allowedManufacturers = const [],
    this.preferredSeriesByRole = const {},
    this.requiredRegion,
  });

  final List<String> preferredManufacturers;
  final List<String> allowedManufacturers;
  final Map<FunctionalDeviceRole, String> preferredSeriesByRole;
  final String? requiredRegion;
}

class ManufacturerMatch {
  ManufacturerMatch(Iterable<String> issues)
      : issues = List.unmodifiable(issues);
  final List<String> issues;
  bool get compatible => issues.isEmpty;
}

abstract final class ManufacturerProductMatcher {
  static const algorithmVersion = 'fl14-strict-product-match-v1';
  static String normalize(String value) => value.trim().toLowerCase();
  static List<String> validateProduct(ManufacturerProductVariant p) => [
        if ([p.id, p.manufacturer, p.series, p.sku, p.displayName]
            .any((v) => v.trim().isEmpty))
          'Product identity, manufacturer, series, SKU and name are required.',
        for (final v in [
          p.ratedCurrentA,
          p.ratedVoltageV,
          p.breakingCapacityKa,
          p.residualCurrentMa,
          p.widthMm,
          p.heightMm,
          p.depthMm
        ])
          if (v != null && (!v.isFinite || v <= 0))
            'Technical quantities must be positive and finite.',
        if (p.poles != null && p.poles! <= 0) 'Invalid pole count.',
        if (p.moduleWidthUnits != null && p.moduleWidthUnits! <= 0)
          'Invalid module width.',
      ];
  static ManufacturerMatch match(
      FunctionalDeviceRequirement r, ManufacturerProductVariant p,
      {ProjectManufacturerPolicy policy = const ProjectManufacturerPolicy(),
      String? catalogRegion}) {
    final errors = [...validateProduct(p)];
    if (p.lifecycleStatus != ProductLifecycleStatus.active)
      errors.add('Product lifecycle is not active.');
    if (p.functionalRole != r.role) errors.add('Functional role mismatch.');
    if (policy.allowedManufacturers.isNotEmpty &&
        !policy.allowedManufacturers
            .any((b) => normalize(b) == normalize(p.manufacturer)))
      errors.add('Manufacturer is outside the project allowlist.');
    if (policy.requiredRegion != null &&
        policy.requiredRegion!.trim().isNotEmpty &&
        (catalogRegion == null ||
            normalize(catalogRegion) != normalize(policy.requiredRegion!)))
      errors.add('Required catalog region is not evidenced.');
    void min(double? needed, double? available, String label,
        {bool exact = false}) {
      if (needed == null) return;
      if (!needed.isFinite || needed <= 0) {
        errors.add('Invalid requirement: $label.');
        return;
      }
      if (available == null)
        errors.add('Missing $label.');
      else if (exact ? available != needed : available < needed)
        errors.add('$label does not satisfy the requirement.');
    }

    void equal(Object? needed, Object? available, String label) {
      if (needed != null &&
          (available == null ||
              (needed is String && available is String
                  ? normalize(needed) != normalize(available)
                  : needed != available)))
        errors.add('Missing or mismatched $label.');
    }

    min(r.ratedCurrentA, p.ratedCurrentA, 'rated current', exact: true);
    min(r.ratedVoltageV, p.ratedVoltageV, 'rated voltage');
    min(r.breakingCapacityKa, p.breakingCapacityKa, 'breaking capacity');
    min(r.residualCurrentMa, p.residualCurrentMa, 'residual trip current',
        exact: true);
    equal(r.poles, p.poles, 'poles');
    equal(r.tripCurve, p.tripCurve, 'trip characteristic');
    equal(r.residualCurrentType, p.residualCurrentType, 'residual type');
    equal(r.moduleWidthUnits, p.moduleWidthUnits, 'module width');
    equal(r.mountingType, p.mountingType, 'mounting type');
    if (r.currentKind != null &&
        p.currentKind != r.currentKind &&
        p.currentKind != ProductCurrentKind.acDc)
      errors.add('Missing or incompatible AC/DC declaration.');
    return ManufacturerMatch(errors);
  }

  static int compare(ManufacturerProductVariant a, ManufacturerProductVariant b,
      ProjectManufacturerPolicy policy) {
    if (a.functionalRole != b.functionalRole) {
      return a.functionalRole.name.compareTo(b.functionalRole.name);
    }
    int rank(String brand) {
      final i = policy.preferredManufacturers
          .indexWhere((v) => normalize(v) == normalize(brand));
      return i < 0 ? policy.preferredManufacturers.length : i;
    }

    var n = rank(a.manufacturer).compareTo(rank(b.manufacturer));
    if (n != 0) return n;
    final series = policy.preferredSeriesByRole[a.functionalRole];
    n = (series != null && normalize(a.series) == normalize(series) ? 0 : 1)
        .compareTo(
            series != null && normalize(b.series) == normalize(series) ? 0 : 1);
    if (n != 0) return n;
    n = normalize(a.manufacturer).compareTo(normalize(b.manufacturer));
    if (n != 0) return n;
    n = a.sku.compareTo(b.sku);
    return n == 0 ? a.id.compareTo(b.id) : n;
  }
}
