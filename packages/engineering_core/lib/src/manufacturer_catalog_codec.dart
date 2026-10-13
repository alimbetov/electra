import 'manufacturer_catalog.dart';

abstract final class ManufacturerCatalogCodec {
  static Map<String, Object?> product(ManufacturerProductVariant p) => {
        'id': p.id,
        'manufacturer': p.manufacturer,
        'series': p.series,
        'sku': p.sku,
        'displayName': p.displayName,
        'functionalRole': p.functionalRole.name,
        'ratedCurrentA': p.ratedCurrentA,
        'ratedVoltageV': p.ratedVoltageV,
        'breakingCapacityKa': p.breakingCapacityKa,
        'poles': p.poles,
        'tripCurve': p.tripCurve,
        'residualCurrentMa': p.residualCurrentMa,
        'residualCurrentType': p.residualCurrentType,
        'moduleWidthUnits': p.moduleWidthUnits,
        'widthMm': p.widthMm,
        'heightMm': p.heightMm,
        'depthMm': p.depthMm,
        'currentKind': p.currentKind?.name,
        'mountingType': p.mountingType,
        'lifecycleStatus': p.lifecycleStatus.name,
        'metadata': p.metadata,
      };
  static ManufacturerProductVariant decodeProduct(Map<String, dynamic> m) =>
      ManufacturerProductVariant(
          id: m['id'] as String,
          manufacturer: m['manufacturer'] as String,
          series: m['series'] as String,
          sku: m['sku'] as String,
          displayName: m['displayName'] as String,
          functionalRole:
              FunctionalDeviceRole.values.byName(m['functionalRole'] as String),
          ratedCurrentA: (m['ratedCurrentA'] as num?)?.toDouble(),
          ratedVoltageV: (m['ratedVoltageV'] as num?)?.toDouble(),
          breakingCapacityKa: (m['breakingCapacityKa'] as num?)?.toDouble(),
          poles: m['poles'] as int?,
          tripCurve: m['tripCurve'] as String?,
          residualCurrentMa: (m['residualCurrentMa'] as num?)?.toDouble(),
          residualCurrentType: m['residualCurrentType'] as String?,
          moduleWidthUnits: m['moduleWidthUnits'] as int?,
          widthMm: (m['widthMm'] as num?)?.toDouble(),
          heightMm: (m['heightMm'] as num?)?.toDouble(),
          depthMm: (m['depthMm'] as num?)?.toDouble(),
          currentKind: m['currentKind'] == null
              ? null
              : ProductCurrentKind.values.byName(m['currentKind'] as String),
          mountingType: m['mountingType'] as String?,
          lifecycleStatus: ProductLifecycleStatus.values
              .byName(m['lifecycleStatus'] as String),
          metadata: Map<String, Object?>.from(m['metadata'] as Map? ?? {}));
  static Map<String, Object?> catalog(ManufacturerCatalog c) => {
        'id': c.id,
        'manufacturer': c.manufacturer,
        'catalogVersion': c.catalogVersion,
        'region': c.region,
        'sourceReference': c.sourceReference,
        'products': c.products.map(product).toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String)),
      };
  static ManufacturerCatalog decodeCatalog(Map<String, dynamic> m) =>
      ManufacturerCatalog(
          id: m['id'] as String,
          manufacturer: m['manufacturer'] as String,
          catalogVersion: m['catalogVersion'] as String,
          region: m['region'] as String?,
          sourceReference: m['sourceReference'] as String?,
          products: (m['products'] as List)
              .map((p) => decodeProduct(Map<String, dynamic>.from(p as Map)))
              .toList(growable: false));
  static Map<String, Object?> policy(ProjectManufacturerPolicy p) => {
        'preferredManufacturers': p.preferredManufacturers,
        'allowedManufacturers': p.allowedManufacturers.toList()..sort(),
        'preferredSeriesByRole': {
          for (final e in p.preferredSeriesByRole.entries) e.key.name: e.value
        },
        'requiredRegion': p.requiredRegion,
      };
  static ProjectManufacturerPolicy decodePolicy(Map<String, dynamic> m) =>
      ProjectManufacturerPolicy(
          preferredManufacturers:
              (m['preferredManufacturers'] as List).cast<String>(),
          allowedManufacturers:
              (m['allowedManufacturers'] as List).cast<String>(),
          preferredSeriesByRole: {
            for (final e
                in (m['preferredSeriesByRole'] as Map<String, dynamic>).entries)
              FunctionalDeviceRole.values.byName(e.key): e.value as String
          },
          requiredRegion: m['requiredRegion'] as String?);
  static FunctionalDeviceRequirement? protectionRequirement(
      Map<String, Object?> m) {
    if (m['proposalState'] != 'proposed' || m['role'] == null) return null;
    final supply = (m['inputs'] as Map?)?['supplySystem'];
    return FunctionalDeviceRequirement(
        role: FunctionalDeviceRole.values.byName(m['role'] as String),
        poles: m['poles'] as int?,
        ratedCurrentA: (m['ratedCurrentA'] as num?)?.toDouble(),
        ratedVoltageV: (m['ratedVoltageV'] as num?)?.toDouble(),
        breakingCapacityKa: (m['breakingCapacityKa'] as num?)?.toDouble(),
        tripCurve: m['tripCurve'] as String?,
        residualCurrentMa: (m['residualCurrentMa'] as num?)?.toDouble(),
        residualCurrentType: m['residualType'] as String?,
        currentKind: supply == 'directCurrent'
            ? ProductCurrentKind.dc
            : supply == 'singlePhaseAc' || supply == 'threePhaseAc'
                ? ProductCurrentKind.ac
                : null);
  }
}
