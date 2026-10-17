import 'package:electra_mobile/features/editor/electrical_loads_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'load form rejects missing demand and saves the exact equipment reference',
    (tester) async {
      final saved = <EquipmentElectricalLoad>[];
      const component = ComponentInstance(
        id: 'equipment-1',
        definitionId: 'motor',
        definitionVersion: 1,
        roomId: 'room',
        hostSurfacePatchId: 'wall',
        localPosition: Point2Mm(1000, 300),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => ElectricalLoadDialog(
                    component: component,
                    title: 'Motor',
                    groups: const [],
                    onSave: (load) async => saved.add(load),
                  ),
                ),
                child: const Text('Configure load'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Configure load'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save load'));
      await tester.pump();
      expect(saved, isEmpty);
      expect(
        find.textContaining('Enter rated power or current.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Rated power (W)'),
        '1500',
      );
      await tester.tap(find.text('Save load'));
      await tester.pumpAndSettle();
      expect(saved.single.componentInstanceId, 'equipment-1');
      expect(saved.single.profile.ratedPowerW, 1500);
      expect(saved.single.profile.nominalVoltageV, 230);
      expect(find.text('Save load'), findsNothing);
    },
  );
}
