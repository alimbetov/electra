from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:160]!r}')
    path.write_text(text.replace(old, new, 1))


panel = ROOT / 'apps/mobile/lib/features/editor/power_workspace_panel.dart'
text = panel.read_text()
if "order: const NumericFocusOrder(3)" not in text:
    old = """              IconButton(
                key: const ValueKey('power-undo'),
                tooltip: 'Undo ELV change',
                onPressed:
                    projection.mutationAllowed && canUndo ? onUndo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                key: const ValueKey('power-redo'),
                tooltip: 'Redo ELV change',
                onPressed:
                    projection.mutationAllowed && canRedo ? onRedo : null,
                icon: const Icon(Icons.redo),
              ),
"""
    new = """              FocusTraversalOrder(
                order: const NumericFocusOrder(3),
                child: IconButton(
                  key: const ValueKey('power-undo'),
                  tooltip: 'Undo ELV change',
                  onPressed:
                      projection.mutationAllowed && canUndo ? onUndo : null,
                  icon: const Icon(Icons.undo),
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(4),
                child: IconButton(
                  key: const ValueKey('power-redo'),
                  tooltip: 'Redo ELV change',
                  onPressed:
                      projection.mutationAllowed && canRedo ? onRedo : null,
                  icon: const Icon(Icons.redo),
                ),
              ),
"""
    if old not in text:
        raise SystemExit('power header focus anchor missing')
    text = text.replace(old, new, 1)
if "NumericFocusOrder(30 + index)" not in text:
    old = """            for (var index = 0; index < card.findings.length; index++)
              _FindingTile(
                key: ValueKey('power-finding-$index'),
                value: card.findings[index],
                onTap: onFindingSelected,
              ),
"""
    new = """            for (var index = 0; index < card.findings.length; index++)
              FocusTraversalOrder(
                order: NumericFocusOrder(30 + index),
                child: _FindingTile(
                  key: ValueKey('power-finding-$index'),
                  value: card.findings[index],
                  onTap: onFindingSelected,
                ),
              ),
"""
    if old not in text:
        raise SystemExit('power finding focus anchor missing')
    text = text.replace(old, new, 1)
if "order: const NumericFocusOrder(10)" not in text:
    old = """                  FilledButton(
                    key: const ValueKey('power-route-apply'),
                    onPressed: onApply,
                    child: const Text('Apply reviewed route'),
                  ),
                  TextButton(
                    key: const ValueKey('power-route-discard'),
                    onPressed: onDiscard,
                    child: const Text('Discard'),
                  ),
"""
    new = """                  FocusTraversalOrder(
                    order: const NumericFocusOrder(10),
                    child: FilledButton(
                      key: const ValueKey('power-route-apply'),
                      onPressed: onApply,
                      child: const Text('Apply reviewed route'),
                    ),
                  ),
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(11),
                    child: TextButton(
                      key: const ValueKey('power-route-discard'),
                      onPressed: onDiscard,
                      child: const Text('Discard'),
                    ),
                  ),
"""
    if old not in text:
        raise SystemExit('power draft focus anchor missing')
    text = text.replace(old, new, 1)
panel.write_text(text)

screen = ROOT / 'apps/mobile/lib/features/editor/room_editor_screen.dart'
text = screen.read_text()
if 'onPopInvokedWithResult' not in text:
    text = text.replace(
        """      body: LayoutBuilder(
        builder: (context, constraints) {
""",
        """      body: PopScope<void>(
        canPop: !powerInspectorVisible,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && powerInspectorVisible) {
            setState(() => powerInspectorVisible = false);
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
""",
        1,
    )
    old_tail = """          );
        },
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
"""
    new_tail = """          );
          },
        ),
      ),
    );
  }
}

class _EditorToolbar extends StatelessWidget {
"""
    if old_tail not in text:
        raise SystemExit('room editor PopScope closing anchor missing')
    text = text.replace(old_tail, new_tail, 1)
screen.write_text(text)

room_test = ROOT / 'apps/mobile/test/features/editor/room_editor_screen_test.dart'
text = room_test.read_text()
imports = """import 'package:electra_mobile/application/power_workspace_controller.dart';
import 'package:electra_mobile/application/power_workspace_projection.dart';
import 'package:electra_mobile/application/power_workspace_state.dart';
import 'package:electra_mobile/features/editor/power_workspace_editor_binding.dart';
"""
if "power_workspace_controller.dart" not in text:
    text = text.replace(
        "import 'package:electra_mobile/application/geometry_repository.dart';\n",
        "import 'package:electra_mobile/application/geometry_repository.dart';\n" + imports,
        1,
    )
if "wide Back closes power inspector before leaving RoomEditor" not in text:
    anchor = """  testWidgets('measure tool captures two canvas points in millimetres', (
"""
    if anchor not in text:
        raise SystemExit('room editor test insertion anchor missing')
    test = r'''  testWidgets('wide Back closes power inspector before leaving RoomEditor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final powerController = PowerWorkspaceController(repository: _PowerRepository());
    await powerController.open('project-editor');
    final binding = PowerWorkspaceEditorBinding(
      controller: powerController,
      onSessionChanged: (_) async {},
    );
    final surface = patch();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (launcherContext) => Scaffold(
            body: ElevatedButton(
              key: const ValueKey('open-editor'),
              onPressed: () => Navigator.of(launcherContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => RoomEditorScreen(
                    project: project(),
                    room: room(),
                    geometry: RoomGeometrySnapshot(
                      roomId: 'room-editor',
                      patches: [surface],
                    ),
                    powerWorkspace: binding,
                  ),
                ),
              ),
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-editor')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('power-workspace-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('power-workspace-panel')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('power-workspace-panel')), findsNothing);
    expect(find.textContaining('Workshop 01'), findsWidgets);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-editor')), findsOneWidget);
  });

'''
    text = text.replace(anchor, test + anchor, 1)
if 'final class _PowerRepository implements PowerWorkspaceRepository' not in text:
    text += r'''

final class _PowerRepository implements PowerWorkspaceRepository {
  @override
  Future<PowerWorkspaceOpenResult?> open(String projectId) async {
    final state = PowerWorkspaceState(
      context: PowerWorkspaceReadContext(
        projectId: projectId,
        designRevisionId: 'rev-1',
        lifecycleState: 'WORKING',
        scenarioId: 'NORMAL',
        segmentId: 'SEG-1',
        generation: 1,
      ),
      cards: PowerWorkspaceCardCode.values,
    );
    return PowerWorkspaceOpenResult(state: state, projection: _projection(state));
  }

  @override
  Future<PowerWorkspaceProjection> load(PowerWorkspaceState state) async =>
      _projection(state);

  PowerWorkspaceProjection _projection(PowerWorkspaceState state) =>
      PowerWorkspaceProjection(
        contextGeneration: state.context.generation,
        readKind: PowerWorkspaceReadKind.working,
        lifecycleState: state.context.lifecycleState,
        currentness: PowerWorkspaceCurrentness.current,
        scenarios: const [
          PowerWorkspaceScenarioOption(
            scenarioId: 'NORMAL',
            segmentId: 'SEG-1',
            label: 'Normal · SEG-1',
          ),
        ],
        cards: [
          for (final code in PowerWorkspaceCardCode.values)
            PowerWorkspaceCardProjection(
              code: code,
              title: code.name,
              summary: '${code.name} summary',
              currentness: PowerWorkspaceCurrentness.current,
            ),
        ],
        overlay: PowerWorkspaceOverlayProjection(),
      );
}
'''
room_test.write_text(text)
