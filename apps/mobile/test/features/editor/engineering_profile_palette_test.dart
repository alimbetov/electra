import 'package:electra_mobile/application/engineering_profile_palette.dart';
import 'package:electra_mobile/features/editor/engineering_profile_palette.dart';
import 'package:electra_mobile/features/editor/engineering_placement_preview.dart';
import 'package:electra_mobile/features/editor/room_editor_screen.dart';
import 'package:electra_mobile/features/editor/editor_interaction.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/engineering_palette_fixture.dart';

Future<void> pickCandidate(
  WidgetTester tester,
  String label,
  String value,
) async {
  final field = find.byKey(ValueKey('candidate-$label'));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(value).last);
  await tester.pumpAndSettle();
}

Future<void> chooseCameraPreview(WidgetTester tester) async {
  await tester.tap(find.text('equipment'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('ELV profiles'));
  await tester.pumpAndSettle();
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('CCTV · CCTV').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(paletteCatalog().profile('CAMERA').label));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Preview on surface'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'legacy and deprecated editions remain inspectable and explicit',
    (tester) async {
      for (final deprecated in [false, true]) {
        final catalog = paletteCatalog();
        final legacy = EngineeringReferenceCatalog.fromMap({
          ...catalog.toMap(),
          'profiles': [
            {
              ...catalog.profile('CAMERA').toMap(),
              'constraintsState': 'legacyUnspecified',
              'constraints': null,
              'deprecated': deprecated,
            },
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EngineeringProfilePalette(
                key: ValueKey(deprecated),
                snapshot: paletteSnapshot(catalog: legacy),
                projectId: 'p1',
                initialSystemId: 'CCTV',
              ),
            ),
          ),
        );
        await tester.tap(find.text(legacy.profile('CAMERA').label));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Preview remains UNRESOLVED'),
          findsOneWidget,
        );
        final preview = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Preview on surface'),
        );
        expect(preview.onPressed == null, deprecated);
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'missing pinned topology cannot be overwritten by candidate input',
    (tester) async {
      final system = EngineeringSystem.fromMap({
        ...paletteSnapshot().systems.systems.first.toMap(),
        'topologyProfile': {'id': 'missing', 'version': '2'},
      });
      PlacementCandidateContext? candidate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () async {
                      candidate = await showDialog<PlacementCandidateContext>(
                        context: context,
                        builder:
                            (_) => CandidateConditionsDialog(
                              initial: knownCandidate('CAMERA'),
                              system: system,
                            ),
                      );
                    },
                    child: const Text('Open'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('candidate-Intended topology shape')),
        findsNothing,
      );
      expect(find.textContaining('unresolved edition'), findsOneWidget);
      await tester.tap(find.text('Apply to preview'));
      await tester.pumpAndSettle();
      expect(candidate!.topologyShape, isNull);
      final catalog = paletteCatalog();
      expect(
        const PlacementCompatibilityEngine()
            .evaluate(
              profile: catalog.profile('CAMERA'),
              catalogId: catalog.id,
              catalogVersion: catalog.version,
              context: candidate!,
            )
            .status,
        PlacementCompatibilityStatus.unresolved,
      );
    },
  );
  for (final pair
      in {
        'CCTV': 'CAMERA',
        'LAN': 'OUTLET',
        'ACS': 'READER',
        'FIRE': 'DETECTOR',
      }.entries) {
    testWidgets(
      'compact ${pair.key} palette inspects exact edition and constraints before selection',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final snapshot = paletteSnapshot(),
            p = paletteCatalog().profile(pair.value);
        CanonicalProfileChoice? selected;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => TextButton(
                      onPressed: () async {
                        selected = await EngineeringProfilePalette.show(
                          context,
                          snapshot: snapshot,
                          projectId: 'p1',
                          initialSystemId: pair.key,
                        );
                      },
                      child: const Text('Open'),
                    ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Discipline: ${pair.key}'), findsOneWidget);
        await tester.tap(find.text(p.label));
        await tester.pumpAndSettle();
        expect(find.textContaining('Catalog: TEST-ELV2 / 1'), findsOneWidget);
        expect(find.textContaining('Capabilities:'), findsOneWidget);
        for (final title in [
          'Ports and interfaces',
          'Mounting',
          'Environment',
          'Topology',
        ]) {
          await tester.ensureVisible(find.text(title));
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
        }
        expect(find.textContaining('Closed loop required:'), findsOneWidget);
        expect(find.textContaining('Connector:'), findsWidgets);
        await tester.tap(find.text('Preview on surface'));
        await tester.pumpAndSettle();
        expect(selected?.profile.code, pair.value);
        expect(selected?.catalog.version, '1');
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets('${pair.key} candidate form forwards explicit facts to P2', (
      tester,
    ) async {
      PlacementCandidateContext? candidate;
      final snapshot = paletteSnapshot();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder:
                  (context) => TextButton(
                    onPressed: () async {
                      candidate = await showDialog<PlacementCandidateContext>(
                        context: context,
                        builder:
                            (_) => CandidateConditionsDialog(
                              initial: knownCandidate(pair.value),
                              system: snapshot.systems.systems.singleWhere(
                                (s) => s.id == pair.key,
                              ),
                            ),
                      );
                    },
                    child: const Text('Conditions'),
                  ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Conditions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply to preview'));
      await tester.pumpAndSettle();
      final result = const PlacementCompatibilityEngine().evaluate(
        profile: paletteCatalog().profile(pair.value),
        catalogId: paletteCatalog().id,
        catalogVersion: '1',
        context: candidate!,
      );
      expect(result.status, PlacementCompatibilityStatus.compatible);
    });
  }
  testWidgets(
    'all four statuses render text, accessible severity and exact provenance',
    (tester) async {
      for (final status in PlacementCompatibilityStatus.values) {
        final result = PlacementCompatibilityResult(
          profileCode: 'CAMERA',
          catalogId: 'frozen-catalog',
          catalogVersion: '7',
          findings:
              status == PlacementCompatibilityStatus.compatible
                  ? []
                  : [
                    PlacementFinding(
                      code: PlacementFindingCode.mountingContextIncomplete,
                      severity: switch (status) {
                        PlacementCompatibilityStatus.warning =>
                          PlacementFindingSeverity.warning,
                        PlacementCompatibilityStatus.forbidden =>
                          PlacementFindingSeverity.error,
                        _ => PlacementFindingSeverity.unresolved,
                      },
                      dimension: PlacementFindingDimension.mounting,
                      explanation: 'Check candidate',
                      expected: 'wall:bracket',
                      actual: 'floor:surface',
                      remediationHint: 'Select a supported location',
                    ),
                  ],
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlacementFindingsView(result: result),
              ),
            ),
          ),
        );
        expect(find.text(status.name.toUpperCase()), findsOneWidget);
        expect(find.textContaining('frozen-catalog / 7'), findsOneWidget);
        if (result.findings.isNotEmpty)
          expect(find.textContaining('Expected: wall:bracket'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'surface preview uses P2, resets candidate facts, and never calls placement',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var writes = 0;
      final references = paletteSnapshot();
      await tester.pumpWidget(
        MaterialApp(
          home: RoomEditorScreen(
            project: paletteProject,
            room: paletteRoom,
            geometry: paletteGeometry,
            engineeringReferences: references,
            onPlaceComponent: (_, __, ___) async {
              writes++;
            },
          ),
        ),
      );
      await chooseCameraPreview(tester);
      Future<void> tapPoint(Point2Mm point) async {
        final rect = tester.getRect(find.byType(InteractiveViewer));
        final tr = SurfaceViewportTransform(
          boundary: paletteGeometry.patches.first.boundary,
          viewportWidth: rect.width,
          viewportHeight: rect.height,
        );
        final p = tr.localToViewport(point);
        await tester.tapAt(rect.topLeft + Offset(p.x, p.y));
        await tester.pumpAndSettle();
      }

      await tapPoint(const Point2Mm(1000, 700));
      expect(find.text('UNRESOLVED'), findsWidgets);
      await tester.tap(find.text('Candidate conditions'));
      await tester.pumpAndSettle();
      await pickCandidate(tester, 'Installation surface', 'wall');
      await pickCandidate(tester, 'Mounting method', 'bracket');
      await tester.ensureVisible(
        find.byKey(const ValueKey('candidate-Available clearance (mm)')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('candidate-Available clearance (mm)')),
        '50',
      );
      await pickCandidate(tester, 'Exposure', 'indoor');
      await pickCandidate(tester, 'Climate', 'conditioned');
      await tester.ensureVisible(
        find.byKey(const ValueKey('candidate-Ambient temperature (°C)')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('candidate-Ambient temperature (°C)')),
        '20',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('candidate-IP')));
      await tester.enterText(
        find.byKey(const ValueKey('candidate-IP')),
        'IP54',
      );
      await pickCandidate(tester, 'Intended topology shape', 'star');
      await pickCandidate(tester, 'Intended topology role', 'endpoint');
      await tester.tap(find.text('Apply to preview'));
      await tester.pumpAndSettle();
      expect(find.text('COMPATIBLE'), findsWidgets);
      expect(writes, 0);
      await tester.tap(find.text('Candidate conditions'));
      await tester.pumpAndSettle();
      await pickCandidate(tester, 'Installation surface', 'floor');
      await tester.tap(find.text('Apply to preview'));
      await tester.pumpAndSettle();
      expect(find.text('FORBIDDEN'), findsWidgets);
      await tester.tap(find.text('wall-2'));
      await tester.pumpAndSettle();
      expect(find.text('FORBIDDEN'), findsNothing);
      await tapPoint(const Point2Mm(2000, 700));
      expect(find.text('UNRESOLVED'), findsWidgets);
      expect(writes, 0);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.byType(EngineeringPlacementFeedback), findsNothing);
      expect(writes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('invalid numeric and IP drafts stay visible without applying', (
    tester,
  ) async {
    var applied = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () async {
                    applied =
                        await showDialog<PlacementCandidateContext>(
                          context: context,
                          builder:
                              (_) => CandidateConditionsDialog(
                                initial: knownCandidate('CAMERA'),
                                system: paletteSnapshot().systems.systems.first,
                              ),
                        ) !=
                        null;
                  },
                  child: const Text('Open'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('candidate-Ambient temperature (°C)')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('candidate-Ambient temperature (°C)')),
      'NaN',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('candidate-IP')));
    await tester.enterText(find.byKey(const ValueKey('candidate-IP')), 'IP99');
    await tester.tap(find.text('Apply to preview'));
    await tester.pumpAndSettle();
    expect(applied, isFalse);
    expect(find.textContaining('Enter a finite'), findsOneWidget);
    expect(find.textContaining('Enter an IP protection'), findsOneWidget);
  });
}
