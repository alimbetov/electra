import 'dart:convert';
import 'dart:io';
import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:electra_mobile/features/calculations/engineering_reference_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'engineering_systems_screen_test.dart' show systemsFixture;

void main() {
  final text =
      File(
        '../../docs/examples/elv2-reference-catalog.json',
      ).readAsStringSync();
  final catalog = EngineeringReferenceCatalog.fromMap(
    jsonDecode(text) as Map<String, dynamic>,
  );
  testWidgets('compact reference workspace shows product neutral provenance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngineeringReferenceWorkspace(
            snapshot: ProjectEngineeringReferences(
              systems: systemsFixture(),
              catalogs: [catalog],
              bindings: [],
            ),
            onImport: (_) async {},
            onBind: (_, __, ___) async {},
            onUnbind: (_) async {},
          ),
        ),
      ),
    );
    expect(find.text('TEST-ELV2 / 1'), findsOneWidget);
    expect(find.textContaining('Fictional acceptance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('import error preserves exact edition JSON draft', (
    tester,
  ) async {
    EngineeringReferenceCatalog? imported;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReferenceCatalogImportDialog(
            onImport: (c) async {
              imported = c;
              throw StateError('edition conflict');
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Catalog JSON'),
      text,
    );
    await tester.tap(find.text('Import edition'));
    await tester.pumpAndSettle();
    expect(imported?.version, '1');
    expect(find.textContaining('edition conflict'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Catalog JSON'))
          .controller!
          .text,
      text,
    );
    expect(tester.takeException(), isNull);
  });
}
