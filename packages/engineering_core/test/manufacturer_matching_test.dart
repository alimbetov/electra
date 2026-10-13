import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  const requirement = FunctionalDeviceRequirement(
      role: FunctionalDeviceRole.mcb,
      ratedCurrentA: 10,
      ratedVoltageV: 230,
      breakingCapacityKa: 6,
      poles: 2,
      tripCurve: 'C',
      currentKind: ProductCurrentKind.ac);
  ManufacturerProductVariant product(
          {String id = 'a',
          String brand = 'Brand A',
          double? voltage = 230,
          double? breaking = 6,
          double current = 10,
          ProductCurrentKind? kind = ProductCurrentKind.ac,
          ProductLifecycleStatus lifecycle = ProductLifecycleStatus.active,
          FunctionalDeviceRole role = FunctionalDeviceRole.mcb,
          double? residual,
          String? residualType,
          String series = 'Series'}) =>
      ManufacturerProductVariant(
          id: id,
          manufacturer: brand,
          series: series,
          sku: id,
          displayName: id,
          functionalRole: role,
          ratedCurrentA: current,
          ratedVoltageV: voltage,
          breakingCapacityKa: breaking,
          poles: 2,
          tripCurve: 'C',
          currentKind: kind,
          lifecycleStatus: lifecycle,
          residualCurrentMa: residual,
          residualCurrentType: residualType);
  test('required voltage and breaking capacity must be present and adequate',
      () {
    expect(ManufacturerProductMatcher.match(requirement, product()).compatible,
        isTrue);
    expect(
        ManufacturerProductMatcher.match(requirement, product(voltage: null))
            .issues,
        contains('Missing rated voltage.'));
    expect(
        ManufacturerProductMatcher.match(requirement, product(breaking: null))
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(requirement, product(voltage: 220))
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(requirement, product(breaking: 4.5))
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(
                requirement, product(voltage: 400, breaking: 10))
            .compatible,
        isTrue);
    expect(
        ManufacturerProductMatcher.match(requirement, product(current: 16))
            .compatible,
        isFalse);
  });
  test('AC/DC and lifecycle cannot silently substitute', () {
    for (final state in ProductLifecycleStatus.values
        .where((s) => s != ProductLifecycleStatus.active)) {
      expect(
          ManufacturerProductMatcher.match(
                  requirement, product(lifecycle: state))
              .compatible,
          isFalse);
    }
    expect(
        ManufacturerProductMatcher.match(requirement, product(kind: null))
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(
                requirement, product(kind: ProductCurrentKind.dc))
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(
                requirement, product(kind: ProductCurrentKind.acDc))
            .compatible,
        isTrue);
  });
  test('RCBO residual values, type and role match exactly', () {
    const r = FunctionalDeviceRequirement(
        role: FunctionalDeviceRole.rcbo,
        ratedCurrentA: 10,
        residualCurrentMa: 30,
        residualCurrentType: 'A');
    expect(
        ManufacturerProductMatcher.match(
                r,
                product(
                    role: FunctionalDeviceRole.rcbo,
                    residual: 30,
                    residualType: 'A'))
            .compatible,
        isTrue);
    expect(
        ManufacturerProductMatcher.match(
                r,
                product(
                    role: FunctionalDeviceRole.rcbo,
                    residual: 100,
                    residualType: 'A'))
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(
                r,
                product(
                    role: FunctionalDeviceRole.rcbo,
                    residual: 30,
                    residualType: 'AC'))
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(
                r, product(residual: 30, residualType: 'A'))
            .compatible,
        isFalse);
  });
  test(
      'project policy restricts candidates and preferences rank only compatible items',
      () {
    const policy = ProjectManufacturerPolicy(
        allowedManufacturers: ['Brand A', 'Brand B'],
        preferredManufacturers: ['Brand B'],
        requiredRegion: 'KZ');
    final a = product(), b = product(id: 'b', brand: 'Brand B');
    expect(
        ManufacturerProductMatcher.match(requirement, a,
                policy: policy, catalogRegion: 'kz')
            .compatible,
        isTrue);
    expect(
        ManufacturerProductMatcher.match(requirement, a,
                policy: policy, catalogRegion: null)
            .compatible,
        isFalse);
    expect(
        ManufacturerProductMatcher.match(requirement, product(brand: 'Brand C'),
                policy: policy, catalogRegion: 'KZ')
            .compatible,
        isFalse);
    final list = [a, b]
      ..sort((a, b) => ManufacturerProductMatcher.compare(a, b, policy));
    expect(list.first.manufacturer, 'Brand B');
    expect(
        ManufacturerProductMatcher.match(
                requirement, product(brand: 'Brand B', breaking: 1),
                policy: policy, catalogRegion: 'KZ')
            .compatible,
        isFalse);
  });
  test(
      'catalog and policy round-trip without losing SKU dimensions or provenance',
      () {
    final catalog = ManufacturerCatalog(
        id: 'catalog',
        manufacturer: 'Brand A',
        catalogVersion: '1',
        region: 'KZ',
        sourceReference: 'Test fixture datasheet',
        products: [product()]);
    final copy = ManufacturerCatalogCodec.decodeCatalog(
        ManufacturerCatalogCodec.catalog(catalog));
    expect(ManufacturerCatalogCodec.catalog(copy),
        ManufacturerCatalogCodec.catalog(catalog));
    const policy = ProjectManufacturerPolicy(
        preferredSeriesByRole: {FunctionalDeviceRole.mcb: 'Series'});
    expect(
        ManufacturerCatalogCodec.policy(ManufacturerCatalogCodec.decodePolicy(
            ManufacturerCatalogCodec.policy(policy))),
        ManufacturerCatalogCodec.policy(policy));
    expect(catalog.candidatesFor(requirement).single.sku, 'a');
  });
  test(
      'nonfinite product attributes are rejected and physical constraints are enforced',
      () {
    expect(
        ManufacturerProductMatcher.match(
                requirement, product(voltage: double.infinity))
            .compatible,
        isFalse);
    const r = FunctionalDeviceRequirement(
        role: FunctionalDeviceRole.mcb,
        moduleWidthUnits: 2,
        mountingType: 'DIN');
    expect(ManufacturerProductMatcher.match(r, product()).compatible, isFalse);
  });
}
