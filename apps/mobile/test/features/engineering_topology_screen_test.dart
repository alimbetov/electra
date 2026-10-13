import 'package:electra_mobile/application/engineering_topology_repository.dart';
import 'package:electra_mobile/features/calculations/engineering_topology_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'engineering_systems_screen_test.dart' show systemsFixture;

ProjectEngineeringTopologySnapshot topologyFixture() =>
    ProjectEngineeringTopologySnapshot(
      systems: systemsFixture(),
      ports: const [
        EngineeringPort(
          id: 'camera.ETH',
          componentId: 'camera',
          code: 'ETH',
          kind: EngineeringPortKind.data,
          direction: PortDirection.bidirectional,
          capacity: 1,
          connector: 'TEST-CONNECTOR',
          protocol: EngineeringProfileReference(id: 'TEST-ETH', version: '1'),
        ),
      ],
      connectionProfiles: const [],
      connections: const [],
      internalLinks: const [],
      topologyProfiles: const [],
      groups: const [],
      assemblyProfiles: const [],
      assemblies: const [],
    );

void main() {
  testWidgets(
    'compact workspace supports trace and reports failed retirement',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EngineeringTopologyWorkspace(
              snapshot: topologyFixture(),
              nextId: () => 'new',
              onSave: (_) async {},
              onArchive: (_, __) async {
                throw StateError('linked port cannot retire');
              },
              onSystems: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Retire'));
      await tester.pumpAndSettle();
      expect(find.textContaining('linked port cannot retire'), findsOneWidget);
      expect(find.text('Camera 1.ETH'), findsOneWidget);
      await tester.tap(find.text('Connections / trace'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String>, 'Trace from port'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camera 1.ETH').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Reachable ports:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed port write keeps identity and edited draft for retry', (
    tester,
  ) async {
    EngineeringPort? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngineeringTopologyDialog(
            kind: TopologyFormKind.port,
            snapshot: topologyFixture(),
            id: 'camera.ETH',
            initial: topologyFixture().ports.single,
            onSave: (value) async {
              saved = value as EngineeringPort;
              throw StateError('write failed');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'ETH2');
    await tester.tap(find.text('Save topology'));
    await tester.pumpAndSettle();
    expect(saved?.id, 'camera.ETH');
    expect(saved?.componentId, 'camera');
    expect(saved?.code, 'ETH2');
    expect(find.textContaining('write failed'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Code'))
          .controller!
          .text,
      'ETH2',
    );
    expect(tester.takeException(), isNull);
  });
}
