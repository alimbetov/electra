import 'dart:convert';

import 'package:electra_mobile/application/manufacturer_repository.dart';
import 'package:electra_mobile/features/calculations/manufacturer_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'protection_screen_test.dart' show protectionFixture;

ProjectManufacturerSnapshot manufacturerFixture() {
  final protection = protectionFixture();
  ManufacturerCatalog catalog(String brand, String id) => ManufacturerCatalog(
    id: id,
    manufacturer: brand,
    catalogVersion: '1',
    sourceReference: 'Fictional test fixture',
    products: [
      ManufacturerProductVariant(
        id: id,
        manufacturer: brand,
        series: 'Test',
        sku: 'TEST-$id',
        displayName: 'Fictional test product',
        functionalRole: FunctionalDeviceRole.mcb,
        ratedCurrentA: 10,
        ratedVoltageV: 230,
        breakingCapacityKa: 6,
        poles: 2,
        tripCurve: 'C',
        currentKind: ProductCurrentKind.ac,
      ),
    ],
  );
  return ProjectManufacturerSnapshot(
    protection: protection,
    catalogs: [catalog('Brand A', 'a'), catalog('Brand B', 'b')],
    policy: const ProjectManufacturerPolicy(),
    selections: const {},
  );
}

void main() {
  testWidgets(
    'compact candidates select exact requirement and retain state after failed write',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? selected, signature;
      final snapshot = manufacturerFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManufacturerWorkspace(
              snapshot: snapshot,
              nextId: () => 'new',
              onImport: (_) async {},
              onArchive: (_) async {},
              onPolicy: (_) async {},
              onClear: (_) async {},
              onRequirements: () {},
              onSelect: (_, product, fingerprint) async {
                selected = product;
                signature = fingerprint;
                throw StateError('write failed');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Circuit A'));
      await tester.pumpAndSettle();
      final buttons = find.text('Select');
      await tester.scrollUntilVisible(
        buttons.last,
        100,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('manufacturer-selection')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await Scrollable.ensureVisible(
        tester.element(buttons.last),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(buttons.last);
      await tester.pumpAndSettle();
      expect(selected, 'b');
      expect(signature, snapshot.protection.circuits.single.fingerprint);
      expect(find.textContaining('write failed'), findsOneWidget);
      expect(find.text('Not selected'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'catalog JSON errors are recoverable and failed import keeps source data',
    (tester) async {
      ManufacturerCatalog? imported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManufacturerDataDialog(
              policy: false,
              onCatalog: (c) async {
                imported = c;
                throw StateError('catalog write failed');
              },
              onPolicy: (_) async {},
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Catalog JSON'),
        '{',
      );
      await tester.tap(find.text('Import catalog'));
      await tester.pumpAndSettle();
      expect(imported, isNull);
      expect(find.textContaining('FormatException'), findsOneWidget);
      final json = jsonEncode(
        ManufacturerCatalogCodec.catalog(manufacturerFixture().catalogs.first),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Catalog JSON'),
        json,
      );
      await tester.tap(find.text('Import catalog'));
      await tester.pumpAndSettle();
      expect(imported?.products.single.sku, 'TEST-a');
      expect(find.textContaining('catalog write failed'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Catalog JSON'))
            .controller!
            .text,
        json,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
