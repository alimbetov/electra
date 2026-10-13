import 'package:electra_mobile/application/dependency_recalculation_repository.dart';
import 'package:electra_mobile/application/panel_generation_repository.dart';
import 'package:electra_mobile/application/protection_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:electra_mobile/features/calculations/panel_generation_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'protection_screen_test.dart' show protectionFixture;

ProjectPanelGenerationSnapshot fixture({bool stale = false}) {
  final p = protectionFixture();
  final rule = p.rulesets.single;
  final config = PanelGenerationPolicy(
    id: 'panel',
    projectId: p.recalculation.project!.id,
    floorId: 'floor',
    name: 'DB01',
    rulesetId: rule.id,
    phases: 1,
    phaseVoltageV: 230,
    lineVoltageV: 400,
    demandFactor: 1,
    reservePercent: 25,
    minimumSpareModules: 2,
    moduleWidths: const {'mcb:2': 2},
    outgoing: p.circuits.single.settings,
    incoming: p.circuits.single.settings,
  );
  final node = RecalculationNode(
    key: 'panelProposal:panel',
    label: 'Panel',
    version: 'test',
    inputs: {'revision': stale ? 2 : 1},
    evaluate:
        (_) => DependencyProposal(
          values: {
            'proposalState': 'proposed',
            'circuits': [],
            'incoming': {},
            'warnings': [],
            'inputIssues': [],
            'recommendedCapacityModules': 8,
          },
        ),
  );
  final original = RecalculationSession(
    nodes: [
      RecalculationNode(
        key: node.key,
        label: 'Panel',
        version: 'test',
        inputs: {'revision': 1},
        evaluate: node.evaluate,
      ),
    ],
  );
  final session = RecalculationSession(
    nodes: [node],
    cache: original.recalculate().values,
  );
  return ProjectPanelGenerationSnapshot(
    protection: ProjectProtectionSnapshot(
      recalculation: ProjectRecalculationSnapshot(
        project: p.recalculation.project,
        session: session,
      ),
      documents: p.documents,
      rulesets: p.rulesets,
      circuits: p.circuits,
    ),
    floors: [
      FloorRecord(
        id: 'floor',
        projectId: config.projectId,
        name: 'Floor 1',
        code: 'F1',
        sortOrder: 0,
        revision: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        originDeviceId: 'test',
      ),
    ],
    panels: [PanelGenerationView(config, null)],
  );
}

void main() {
  testWidgets(
    'compact proposal confirms exact fingerprint and preserves view after failure',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = fixture();
      String? fingerprint;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PanelGenerationWorkspace(
              snapshot: snapshot,
              nextId: () => 'new',
              onSave: (_) async {},
              onRecalculate: () async {},
              onRules: () {},
              onConfirm: (_, value) async {
                fingerprint = value;
                throw StateError('write failed');
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Confirm proposal'));
      await tester.pumpAndSettle();
      expect(
        fingerprint,
        snapshot
            .protection
            .recalculation
            .session
            .fingerprints['panelProposal:panel'],
      );
      expect(find.textContaining('write failed'), findsOneWidget);
      expect(find.text('DB01 · Proposed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('stale proposal is labelled and cannot be confirmed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PanelGenerationWorkspace(
            snapshot: fixture(stale: true),
            nextId: () => 'new',
            onSave: (_) async {},
            onRecalculate: () async {},
            onRules: () {},
            onConfirm: (_, __) async {},
          ),
        ),
      ),
    );
    expect(
      find.text('Previous proposal. Recalculate before use.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Confirm proposal'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });
}
