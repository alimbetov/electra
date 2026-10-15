import 'package:flutter/foundation.dart';

import '../../application/power_workspace_projection.dart';
import '../../application/power_workspace_state.dart';

/// Presentation-only bridge between the persisted editor shell and the P7
/// power workspace. It carries immutable state plus intents; no repository or
/// engineering evaluator is reachable from the widget tree through this type.
final class PowerWorkspaceEditorBinding {
  const PowerWorkspaceEditorBinding({
    required this.state,
    required this.projection,
    required this.onSelectComponent,
    required this.onScenarioChanged,
    required this.onOverlayChanged,
    required this.onPreviousCard,
    required this.onNextCard,
    required this.onFindingSelected,
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
    this.onApplyReviewedRoute,
    this.onDiscardDraft,
  });

  final PowerWorkspaceState state;
  final PowerWorkspaceProjection projection;
  final Future<void> Function(String? componentId) onSelectComponent;
  final Future<void> Function(PowerWorkspaceScenarioOption value)
  onScenarioChanged;
  final ValueChanged<PowerWorkspaceOverlayMode> onOverlayChanged;
  final VoidCallback onPreviousCard;
  final VoidCallback onNextCard;
  final ValueChanged<PowerWorkspaceFindingProjection> onFindingSelected;
  final bool canUndo;
  final bool canRedo;
  final Future<void> Function()? onUndo;
  final Future<void> Function()? onRedo;
  final Future<void> Function()? onApplyReviewedRoute;
  final VoidCallback? onDiscardDraft;
}
