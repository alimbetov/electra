import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

void main() {
  test('manufacturer catalog resolves compatible product variants', () {
    const catalog = ManufacturerCatalog(
      manufacturer: 'Example Electric',
      catalogVersion: '2026.1',
      products: [
        ManufacturerProductVariant(
          id: 'p1',
          manufacturer: 'Example Electric',
          series: 'Acti Example',
          sku: 'MCB-16-C-6KA',
          displayName: 'MCB 16 A C 6 kA',
          functionalRole: FunctionalDeviceRole.mcb,
          ratedCurrentA: 16,
          ratedVoltageV: 230,
          breakingCapacityKa: 6,
          poles: 1,
          tripCurve: 'C',
          moduleWidthUnits: 1,
        ),
      ],
    );

    const requirement = FunctionalDeviceRequirement(
      role: FunctionalDeviceRole.mcb,
      ratedCurrentA: 16,
      ratedVoltageV: 230,
      breakingCapacityKa: 6,
      poles: 1,
      tripCurve: 'C',
    );

    expect(catalog.candidatesFor(requirement).single.sku, 'MCB-16-C-6KA');
  });
}
