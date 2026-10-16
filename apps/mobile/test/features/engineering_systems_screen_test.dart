import 'package:electra_mobile/application/engineering_system_repository.dart';
import 'package:electra_mobile/features/calculations/engineering_systems_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'protection_screen_test.dart' show protectionFixture;

ProjectEngineeringSystemsSnapshot systemsFixture() {
  final project = protectionFixture().recalculation.project!;
  final family = bundledEngineeringSystemFamilies.firstWhere(
    (f) => f.code == 'CCTV',
  );
  final system = EngineeringSystem(
    id: 'cctv',
    projectId: project.id,
    code: 'CCTV-01',
    name: 'Video',
    familyId: family.id,
    familyVersion: family.version,
  );
  return ProjectEngineeringSystemsSnapshot(
    project: project,
    families: bundledEngineeringSystemFamilies,
    systems: [system],
    memberships: const [
      ComponentSystemMembership(
        systemId: 'cctv',
        componentId: 'camera',
        role: 'VIDEO_SOURCE',
      ),
    ],
    components: const [
      EngineeringComponentView(
        id: 'camera',
        name: 'Camera 1',
        roomName: 'Office',
      ),
    ],
  );
}

void main() {
  testWidgets(
    'compact system view shows shared identity and failed archive remains visible',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? archived;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EngineeringSystemsWorkspace(
              snapshot: systemsFixture(),
              nextId: () => 'new',
              onSave: (_) async {},
              onFamily: (_) async {},
              onAssign: (_) async {},
              onDetach: (_, __) async {},
              onArchive: (id) async {
                archived = id;
                throw StateError('Detach participants first');
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Archive system'));
      await tester.tap(find.text('Archive system'));
      await tester.pumpAndSettle();
      expect(archived, 'cctv');
      expect(find.textContaining('Detach participants first'), findsOneWidget);
      expect(find.text('Camera 1'), findsOneWidget);
      expect(find.textContaining('VIDEO_SOURCE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('failed system write preserves pinned family and input draft', (
    tester,
  ) async {
    final snapshot = systemsFixture();
    EngineeringSystem? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EngineeringSystemDialog(
            snapshot: snapshot,
            id: 'cctv',
            initial: snapshot.systems.single,
            onSave: (s) async {
              saved = s;
              throw StateError('write failed');
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Edited video',
    );
    await tester.tap(find.text('Save system'));
    await tester.pumpAndSettle();
    expect(saved?.familyId, snapshot.systems.single.familyId);
    expect(saved?.familyVersion, '1');
    expect(find.textContaining('write failed'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Name'))
          .controller!
          .text,
      'Edited video',
    );
    expect(tester.takeException(), isNull);
  });
}
