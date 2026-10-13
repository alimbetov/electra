import 'package:electra_mobile/application/dependency_recalculation_repository.dart';
import 'package:electra_mobile/application/protection_repository.dart';
import 'package:electra_mobile/features/calculations/protection_screen.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'recalculation_workspace_test.dart' show fixture;

ProjectProtectionSnapshot protectionFixture() {
  final base = fixture(changed: false), doc = bundledNormativeDocuments.last;
  final rule = ProtectionRuleset(
    id: 'rule',
    projectId: 'project',
    normativeDocumentId: doc.id,
    reference: ElectricalRulesetRef(
      id: 'Policy',
      jurisdiction: doc.jurisdiction,
      standardCode: doc.standardCode,
      version: '1',
      sourceReference: doc.source,
    ),
    nominalCurrentsA: const [10, 16, 20],
    tripCurves: const ['B', 'C'],
    residualTypes: const ['A'],
    minimumBreakingCapacityKa: 6,
  );
  const settings = CircuitProtectionInputs(
    circuitId: 'a',
    rulesetId: 'rule',
    allowableCurrentA: 20,
    prospectiveFaultKa: 4,
    poles: 2,
    tripCurve: 'C',
    residualPolicy: ResidualProtectionPolicy.notRequired,
    evidence: 'Test evidence',
  );
  final nodes = [
    ...base.session.nodes.values,
    RecalculationNode(
      key: 'protection:a',
      label: 'Circuit A · Protection',
      version: ProtectionRequirementPlanner.algorithmVersion,
      inputs: settings.toMap(),
      dependencies: const ['circuit:a'],
      evaluate: (deps) {
        final p = ProtectionRequirementPlanner.propose(
          settings: settings,
          ruleset: rule,
          normativeDocument: doc,
          designCurrentA:
              (deps['circuit:a']!.values['designCurrentA'] as num).toDouble(),
          nominalVoltageV: 230,
          phases: 1,
          supplySystem: SupplySystem.singlePhaseAc,
        );
        return DependencyProposal(
          values: p.toMap(),
          issues: p.issues,
          requiresReview: !p.ready,
        );
      },
    ),
  ];
  final first = RecalculationSession(nodes: nodes), cache = first.recalculate();
  final session = RecalculationSession(nodes: nodes, cache: cache.values);
  return ProjectProtectionSnapshot(
    recalculation: ProjectRecalculationSnapshot(
      project: base.project,
      session: session,
    ),
    documents: bundledNormativeDocuments,
    rulesets: [rule],
    circuits: [
      CircuitProtectionView(
        circuitId: 'a',
        label: 'Circuit A',
        settings: settings,
        fingerprint: session.fingerprints['protection:a']!,
        checkpoint: cache['protection:a'],
      ),
    ],
  );
}

void main() {
  testWidgets(
    'compact protection exposes catalog provenance and exact-snapshot confirmation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? confirmed;
      final snapshot = protectionFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProtectionWorkspace(
              snapshot: snapshot,
              nextId: () => 'new',
              onSaveDocument: (_) async {},
              onSaveRuleset: (_) async {},
              onSaveSettings: (_) async {},
              onRecalculate: () async {},
              onConfirm: (_, fingerprint) async {
                confirmed = fingerprint;
              },
              onChanges: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Circuit A'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Confirm functional requirement'),
        250,
        scrollable:
            find
                .descendant(
                  of: find.byKey(const ValueKey('protection-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Confirm functional requirement')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm functional requirement'));
      await tester.pumpAndSettle();
      expect(confirmed, snapshot.circuits.single.fingerprint);
      await tester.tap(find.text('Normatives'));
      await tester.pumpAndSettle();
      final label =
          '${bundledNormativeDocuments.last.standardCode} · ${bundledNormativeDocuments.last.version}';
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable:
            find
                .descendant(
                  of: find.byKey(const ValueKey('normative-list')),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text(label)),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.textContaining('Executable criteria:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'protection input rejects nonfinite numbers and retains failed save draft',
    (tester) async {
      CircuitProtectionInputs? saved;
      final snapshot = protectionFixture();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProtectionInputDialog(
              kind: 'settings',
              snapshot: snapshot,
              id: 'unused',
              circuit: snapshot.circuits.single,
              onSaveDocument: (_) async {},
              onSaveRuleset: (_) async {},
              onSaveSettings: (s) async {
                saved = s;
                throw StateError('write failed');
              },
            ),
          ),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, 'Iz'), 'NaN');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('positive finite Iz'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Iz'), '25');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.allowableCurrentA, 25);
      expect(find.textContaining('write failed'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
