import 'package:flutter/material.dart';

import 'power_workspace_editor_binding.dart';
import 'power_workspace_panel.dart';

final class PowerWorkspacePanelHost extends StatefulWidget {
  const PowerWorkspacePanelHost({
    super.key,
    required this.binding,
  });

  final PowerWorkspaceEditorBinding binding;

  @override
  State<PowerWorkspacePanelHost> createState() =>
      _PowerWorkspacePanelHostState();
}

final class _PowerWorkspacePanelHostState extends State<PowerWorkspacePanelHost> {
  bool canUndo = false;
  bool canRedo = false;
  bool historyLoading = false;

  @override
  void initState() {
    super.initState();
    _reloadHistory();
  }

  @override
  void didUpdateWidget(covariant PowerWorkspacePanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.binding.controller != widget.binding.controller ||
        oldWidget.binding.state.context.generation !=
            widget.binding.state.context.generation) {
      _reloadHistory();
    }
  }

  Future<void> _reloadHistory() async {
    if (historyLoading) return;
    historyLoading = true;
    try {
      final values = await Future.wait([
        widget.binding.canUndo(),
        widget.binding.canRedo(),
      ]);
      if (!mounted) return;
      setState(() {
        canUndo = values[0];
        canRedo = values[1];
      });
    } finally {
      historyLoading = false;
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    setState(() {});
    await _reloadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final binding = widget.binding;
    return PowerWorkspacePanel(
      state: binding.state,
      projection: binding.projection,
      onScenarioChanged: (value) => _run(() => binding.switchScenario(value)),
      onOverlayChanged: (value) => _run(() => binding.setOverlay(value)),
      onPreviousCard: () => _run(binding.previousCard),
      onNextCard: () => _run(binding.nextCard),
      onFindingSelected: binding.onFindingSelected,
      onApplyReviewedRoute: binding.onApplyReviewedRoute == null
          ? null
          : () => _run(binding.onApplyReviewedRoute!),
      onDiscardDraft: binding.onDiscardDraft,
      canUndo: canUndo,
      canRedo: canRedo,
      onUndo: canUndo ? () => _run(binding.undo) : null,
      onRedo: canRedo ? () => _run(binding.redo) : null,
    );
  }
}
