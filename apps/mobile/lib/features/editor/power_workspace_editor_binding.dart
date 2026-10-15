import 'package:flutter/foundation.dart';

import '../../application/power_workspace_controller.dart';
import '../../application/power_workspace_projection.dart';
import '../../application/power_workspace_state.dart';

/// Presentation adapter between the persisted editor shell and the P7 power
/// application controller. Widgets can issue intents through this boundary but
/// cannot reach persistence repositories or engineering evaluators directly.
final class PowerWorkspaceEditorBinding {
  PowerWorkspaceEditorBinding({
    required this.controller,
    required this.onSessionChanged,
    this.onApplyReviewedRoute,
    this.onDiscardDraft,
  });

  final PowerWorkspaceController controller;
  final Future<void> Function(PowerWorkspaceSessionSnapshot snapshot)
  onSessionChanged;
  final Future<void> Function()? onApplyReviewedRoute;
  final VoidCallback? onDiscardDraft;

  PowerWorkspaceState get state => controller.state;
  PowerWorkspaceProjection get projection => controller.projection;

  Future<void> selectComponent(String? componentId) async {
    final snapshot = await controller.select(componentId: componentId);
    await onSessionChanged(snapshot);
  }

  Future<void> switchScenario(PowerWorkspaceScenarioOption value) async {
    final snapshot = await controller.switchScenario(
      scenarioId: value.scenarioId,
      segmentId: value.segmentId,
    );
    await onSessionChanged(snapshot);
  }

  Future<void> setOverlay(PowerWorkspaceOverlayMode mode) async {
    final snapshot = controller.setOverlay(mode);
    await onSessionChanged(snapshot);
  }

  Future<void> previousCard() async {
    final snapshot = controller.previousCard();
    await onSessionChanged(snapshot);
  }

  Future<void> nextCard() async {
    final snapshot = controller.nextCard();
    await onSessionChanged(snapshot);
  }

  Future<void> showCard(PowerWorkspaceCardCode card) async {
    final snapshot = controller.showCard(card);
    await onSessionChanged(snapshot);
  }

  Future<bool> canUndo() => controller.canUndo();
  Future<bool> canRedo() => controller.canRedo();

  Future<void> undo() async {
    await controller.undo();
    await onSessionChanged(controller.snapshot);
  }

  Future<void> redo() async {
    await controller.redo();
    await onSessionChanged(controller.snapshot);
  }
}
