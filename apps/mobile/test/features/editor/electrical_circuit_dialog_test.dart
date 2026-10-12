import 'package:electra_mobile/features/editor/electrical_circuits_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const group = RoomConsumptionGroup(
    id: 'group',
    roomId: 'room',
    name: 'Sockets',
  );
  const load = EquipmentElectricalLoad(
    componentInstanceId: 'socket-1',
    consumptionGroupId: 'group',
    powerBasis: ElectricalPowerBasis.electricalInput,
    profile: ElectricalLoadProfile(
      nominalVoltageV: 230,
      phases: 1,
      ratedPowerW: 2300,
      powerFactor: 1,
    ),
  );
  testWidgets(
    'group proposal previews current and persists exact assignments and kD',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final saved = <ElectricalCircuit>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed:
                        () => showDialog<void>(
                          context: context,
                          builder:
                              (_) => ElectricalCircuitDialog(
                                circuitId: 'circuit-1',
                                roomId: 'room',
                                sourceGroup: group,
                                loads: const [load],
                                titles: const {'socket-1': 'Bench socket'},
                                onSave: (circuit) async => saved.add(circuit),
                              ),
                        ),
                    child: const Text('From group'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('From group'));
      await tester.pumpAndSettle();
      expect(find.text('Design current Ib: 10.00 A'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Demand factor kD (above 0, up to 1)'),
        '0.8',
      );
      await tester.pump();
      expect(find.text('Design current Ib: 8.00 A'), findsOneWidget);
      await tester.tap(find.text('Save circuit'));
      await tester.pumpAndSettle();
      expect(saved.single.loadIds, ['socket-1']);
      expect(saved.single.sourceGroupId, 'group');
      expect(saved.single.inputs.demandFactor, 0.8);
      expect(saved.single.name, 'Sockets circuit');
    },
  );
  testWidgets(
    'invalid circuit fields are rejected and failed writes keep dialog open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElectricalCircuitDialog(
              circuitId: 'circuit',
              roomId: 'room',
              loads: const [load],
              onSave: (_) async {
                calls++;
                throw StateError('disk failure');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Save circuit'));
      await tester.pump();
      expect(calls, 0);
      expect(find.textContaining('Enter a name'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Circuit name'),
        'Workshop circuit',
      );
      await tester.tap(find.text('Save circuit'));
      await tester.pump();
      expect(calls, 1);
      expect(find.textContaining('Unable to save circuit'), findsOneWidget);
      expect(find.text('Save circuit'), findsOneWidget);
    },
  );
}
