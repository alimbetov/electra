import 'package:electra_mobile/domain/system_component_catalog.dart';
import 'package:electra_mobile/features/editor/component_catalog_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('favorite action updates Favorites after persistence succeeds', (
    tester,
  ) async {
    final writes = <(String, bool)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComponentCatalogSheet(
            definitions: electricalSystemComponentLibrary.definitions,
            onSetFavorite: (id, favorite) async => writes.add((id, favorite)),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add favorite').first);
    await tester.pumpAndSettle();
    expect(writes, [
      (electricalSystemComponentLibrary.definitions.first.id, true),
    ]);
    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove favorite'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove favorite'));
    await tester.pumpAndSettle();
    expect(find.text('No matching components'), findsOneWidget);
    expect(writes.last.$2, false);
  });

  testWidgets('failed favorite write does not change displayed state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ComponentCatalogSheet(
            definitions: electricalSystemComponentLibrary.definitions,
            onSetFavorite: (_, _) async => throw StateError('disk failure'),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Add favorite').first);
    await tester.pump();
    expect(find.byTooltip('Remove favorite'), findsNothing);
    expect(find.textContaining('Unable to save favorite'), findsOneWidget);
  });
}
