import 'package:flutter/material.dart';

import '../../application/power_workspace_projection.dart';
import '../../application/power_workspace_state.dart';

final class PowerWorkspacePanel extends StatelessWidget {
  const PowerWorkspacePanel({
    super.key,
    required this.state,
    required this.projection,
    required this.onScenarioChanged,
    required this.onOverlayChanged,
    required this.onPreviousCard,
    required this.onNextCard,
    this.onFindingSelected,
    this.onApplyReviewedRoute,
    this.onDiscardDraft,
    this.canUndo = false,
    this.canRedo = false,
    this.onUndo,
    this.onRedo,
  });

  final PowerWorkspaceState state;
  final PowerWorkspaceProjection projection;
  final ValueChanged<PowerWorkspaceScenarioOption> onScenarioChanged;
  final ValueChanged<PowerWorkspaceOverlayMode> onOverlayChanged;
  final VoidCallback onPreviousCard;
  final VoidCallback onNextCard;
  final ValueChanged<PowerWorkspaceFindingProjection>? onFindingSelected;
  final VoidCallback? onApplyReviewedRoute;
  final VoidCallback? onDiscardDraft;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    final card = projection.card(state.currentCard);
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Material(
        key: const ValueKey('power-workspace-panel'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              state: state,
              projection: projection,
              onScenarioChanged: onScenarioChanged,
              onOverlayChanged: onOverlayChanged,
              canUndo: canUndo,
              canRedo: canRedo,
              onUndo: onUndo,
              onRedo: onRedo,
            ),
            if (projection.readKind == PowerWorkspaceReadKind.notCaptured)
              _StatusBanner(
                icon: Icons.history_toggle_off,
                title: 'Power evidence not captured',
                detail: projection.reasonCode ?? 'ELV4_POWER_NOT_CAPTURED',
              )
            else if (projection.readKind ==
                PowerWorkspaceReadKind.capturedEmpty)
              const _StatusBanner(
                icon: Icons.inventory_2_outlined,
                title: 'Captured power section is empty',
                detail:
                    'The frozen revision contains a valid empty power capture.',
              )
            else if (projection.historical)
              const _StatusBanner(
                icon: Icons.lock_outline,
                title: 'Historical power evidence',
                detail:
                    'Read-only values are resolved from the frozen capture.',
              ),
            if (state.unsavedDraftWarning)
              const _StatusBanner(
                icon: Icons.edit_note,
                title: 'Unsaved reviewed draft',
                detail:
                    'Scenario/revision context changed; review the draft again before applying.',
              ),
            Expanded(
              child:
                  card == null
                      ? const Center(child: Text('No power card data.'))
                      : _CardBody(
                        card: card,
                        budgets:
                            state.currentCard ==
                                    PowerWorkspaceCardCode.sourceCapacity
                                ? projection.budgets
                                : const [],
                        onFindingSelected: onFindingSelected,
                      ),
            ),
            if (state.hasDraft)
              _ReviewedDraftBar(
                state: state,
                onApply:
                    projection.mutationAllowed ? onApplyReviewedRoute : null,
                onDiscard: onDiscardDraft,
              ),
            _NavigationBar(
              state: state,
              onPrevious: onPreviousCard,
              onNext: onNextCard,
            ),
          ],
        ),
      ),
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.projection,
    required this.onScenarioChanged,
    required this.onOverlayChanged,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  final PowerWorkspaceState state;
  final PowerWorkspaceProjection projection;
  final ValueChanged<PowerWorkspaceScenarioOption> onScenarioChanged;
  final ValueChanged<PowerWorkspaceOverlayMode> onOverlayChanged;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;

  @override
  Widget build(BuildContext context) {
    final selected = projection.scenarios.where(
      (option) =>
          option.scenarioId == state.context.scenarioId &&
          option.segmentId == state.context.segmentId,
    );
    final scenario = selected.firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Power · ${state.context.designRevisionId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _CurrentnessChip(currentness: projection.currentness),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: DropdownButton<PowerWorkspaceScenarioOption>(
                  key: const ValueKey('power-scenario-selector'),
                  value: scenario,
                  isExpanded: true,
                  hint: const Text('Scenario'),
                  items: [
                    for (final option in projection.scenarios)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option.label),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onScenarioChanged(value);
                  },
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: DropdownButton<PowerWorkspaceOverlayMode>(
                  key: const ValueKey('power-overlay-selector'),
                  value: state.overlayMode,
                  isExpanded: true,
                  items: [
                    for (final mode in PowerWorkspaceOverlayMode.values)
                      DropdownMenuItem(
                        value: mode,
                        child: Text(_overlayLabel(mode)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onOverlayChanged(value);
                  },
                ),
              ),
              IconButton(
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
            ],
          ),
        ],
      ),
    );
  }
}

final class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.card,
    required this.budgets,
    required this.onFindingSelected,
  });

  final PowerWorkspaceCardProjection card;
  final List<PowerWorkspaceBudgetProjection> budgets;
  final ValueChanged<PowerWorkspaceFindingProjection>? onFindingSelected;

  @override
  Widget build(BuildContext context) => ListView(
    key: ValueKey('power-card-${card.code.name}'),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              card.title,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          _CurrentnessChip(currentness: card.currentness),
        ],
      ),
      const SizedBox(height: 6),
      Text(card.summary),
      if (card.metrics.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final metric in card.metrics) _MetricRow(metric: metric),
      ],
      if (budgets.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          'Shared-source / project budget',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        for (final budget in budgets) _BudgetCard(budget: budget),
      ],
      if (card.explanation.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('How calculated', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        for (final line in card.explanation)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(line)),
      ],
      if (card.findings.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Findings', style: Theme.of(context).textTheme.titleSmall),
        for (var index = 0; index < card.findings.length; index++)
          _FindingTile(
            key: ValueKey('power-finding-$index'),
            value: card.findings[index],
            onTap: onFindingSelected,
          ),
      ],
    ],
  );
}

final class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.metric});
  final PowerWorkspaceMetric metric;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(metric.label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            metric.unit == null
                ? metric.value
                : '${metric.value} ${metric.unit}',
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

final class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});
  final PowerWorkspaceBudgetProjection budget;

  @override
  Widget build(BuildContext context) => Card.outlined(
    key: ValueKey('power-budget-${budget.groupId}'),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (budget.selectedContribution)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.my_location, size: 16),
                ),
              Expanded(child: Text(budget.groupId)),
              _CurrentnessChip(currentness: budget.currentness),
            ],
          ),
          if (budget.ownerComponentId != null)
            Text('Owner: ${budget.ownerComponentId}'),
          const SizedBox(height: 6),
          for (final metric in budget.metrics) _MetricRow(metric: metric),
        ],
      ),
    ),
  );
}

final class _FindingTile extends StatelessWidget {
  const _FindingTile({super.key, required this.value, required this.onTap});

  final PowerWorkspaceFindingProjection value;
  final ValueChanged<PowerWorkspaceFindingProjection>? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.report_outlined),
    title: Text('${value.finding.code} · ${value.finding.severity}'),
    subtitle: Text(value.finding.message),
    trailing:
        value.entityRef == null
            ? null
            : const Icon(Icons.open_in_new, size: 18),
    onTap: onTap == null ? null : () => onTap!(value),
  );
}

final class _ReviewedDraftBar extends StatelessWidget {
  const _ReviewedDraftBar({
    required this.state,
    required this.onApply,
    required this.onDiscard,
  });

  final PowerWorkspaceState state;
  final VoidCallback? onApply;
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 1,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Reviewed route draft',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (state.previewFingerprint != null)
            Text(
              'Fingerprint: ${state.previewFingerprint!.substring(0, 12)}…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('power-route-apply'),
                onPressed: onApply,
                child: const Text('Apply reviewed route'),
              ),
              TextButton(
                key: const ValueKey('power-route-discard'),
                onPressed: onDiscard,
                child: const Text('Discard'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

final class _NavigationBar extends StatelessWidget {
  const _NavigationBar({
    required this.state,
    required this.onPrevious,
    required this.onNext,
  });

  final PowerWorkspaceState state;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          FocusTraversalOrder(
            order: const NumericFocusOrder(20),
            child: IconButton(
              key: const ValueKey('power-card-previous'),
              tooltip: 'Previous power card',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
          ),
          Expanded(
            child: Text(
              '${state.cardIndex + 1}/${state.cards.length} · ${_cardLabel(state.currentCard)}',
              textAlign: TextAlign.center,
            ),
          ),
          FocusTraversalOrder(
            order: const NumericFocusOrder(21),
            child: IconButton(
              key: const ValueKey('power-card-next'),
              tooltip: 'Next power card',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ),
        ],
      ),
    ),
  );
}

final class _CurrentnessChip extends StatelessWidget {
  const _CurrentnessChip({required this.currentness});
  final PowerWorkspaceCurrentness currentness;

  @override
  Widget build(BuildContext context) => Chip(
    key: ValueKey('power-currentness-${currentness.name}'),
    label: Text(currentness.name.toUpperCase()),
    visualDensity: VisualDensity.compact,
  );
}

final class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Card.outlined(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(detail),
      ),
    ),
  );
}

Future<void> showPowerWorkspaceSheet({
  required BuildContext context,
  required FocusNode restoreFocusTo,
  required Widget child,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => SafeArea(
          child: FractionallySizedBox(heightFactor: 0.82, child: child),
        ),
  );
  if (restoreFocusTo.canRequestFocus) restoreFocusTo.requestFocus();
}

String _overlayLabel(PowerWorkspaceOverlayMode mode) => switch (mode) {
  PowerWorkspaceOverlayMode.none => 'Overlay: off',
  PowerWorkspaceOverlayMode.sources => 'Overlay: sources',
  PowerWorkspaceOverlayMode.paths => 'Overlay: supply path',
  PowerWorkspaceOverlayMode.capacity => 'Overlay: capacity',
  PowerWorkspaceOverlayMode.backup => 'Overlay: backup',
  PowerWorkspaceOverlayMode.findings => 'Overlay: findings',
};

String _cardLabel(PowerWorkspaceCardCode code) => switch (code) {
  PowerWorkspaceCardCode.demand => 'Demand',
  PowerWorkspaceCardCode.upstreamPath => 'Upstream path',
  PowerWorkspaceCardCode.profileScenario => 'Profile / scenario',
  PowerWorkspaceCardCode.realization => 'Realization',
  PowerWorkspaceCardCode.sourceCapacity => 'Source capacity',
  PowerWorkspaceCardCode.backup => 'Backup',
  PowerWorkspaceCardCode.findings => 'Findings',
};
