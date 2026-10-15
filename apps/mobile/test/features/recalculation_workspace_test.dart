import 'package:electra_mobile/application/dependency_recalculation_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:electra_mobile/features/calculations/project_recalculation_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProjectRecalculationSnapshot fixture({bool changed = true}) {
  final date = DateTime.utc(2026, 10, 13);
  List<RecalculationNode> nodes(double power) => [
    RecalculationNode(
      key: 'consumer:a',
      label: 'Motor A',
      version: 'v1',
      inputs: {'ratedPowerW': power},
      evaluate: (_) => DependencyProposal(values: {'ratedPowerW': power}),
    ),
    RecalculationNode(
      key: 'circuit:a',
      label: 'Circuit A',
      version: 'v1',
      inputs: const {},
      dependencies: const ['consumer:a'],
      evaluate: (deps) => DependencyProposal(
        values: {
          'designCurrentA':
              (deps['consumer:a']!.values['ratedPowerW'] as num) / 230,
        },
      ),
    ),
  ];
  final saved = RecalculationSession(nodes: nodes(2300)).recalculate();
  return ProjectRecalculationSnapshot(
    project: ProjectRecord(
      id: 'project',
      name: 'Workshop',
      reference: 'P1',
      measurementSystem: MeasurementSystem.metric,
      defaultStructuralHeightMm: 3200,
      defaultFinishedCeilingHeightMm: 3000,
      revision: 1,
      createdAt: date,
      updatedAt: date,
      originDeviceId: 'test',
    ),
    session: RecalculationSession(
      nodes: nodes(changed ? 4600 : 2300),
      cache: saved.values,
    ),
  );
}

void main() {
  Future<void> render(
    WidgetTester tester,
    ProjectRecalculationSnapshot snapshot,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecalculationWorkspace(
            snapshot: snapshot,
            onRecalculate: () async => throw StateError('write failed'),
            onManualDecision: (_, __, ___) async =>
                throw StateError('manual write failed'),
            onReviewManual: (_) async {},
            onClearManual: (_) async {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'compact changes distinguish old output and retain it after failed recalculation',
    (tester) async {
      await render(tester, fixture());
      expect(find.text('2 affected nodes · 0 removed records'), findsOneWidget);
      await tester.tap(find.text('Circuit A'));
      await tester.pumpAndSettle();
      expect(
        find.text('Previous snapshot · recalculation required'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.textContaining('ratedPowerW:'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('2300.0 → 4600.0'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Recalculate affected'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Recalculate affected')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recalculate affected'));
      await tester.pumpAndSettle();
      expect(find.textContaining('write failed'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'manual decision requires reason and preserves draft after failed write',
    (tester) async {
      await render(tester, fixture(changed: false));
      await tester.tap(find.text('Affected or review required only'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Circuit A'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Record manual decision'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Record manual decision')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record manual decision'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Decision'),
        'Site decision',
      );
      await tester.tap(find.text('Save decision'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a decision and its reason.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason'),
        'Site requirement',
      );
      await tester.tap(find.text('Save decision'));
      await tester.pumpAndSettle();
      expect(find.textContaining('manual write failed'), findsOneWidget);
      expect(find.text('Site decision'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
