import 'package:engineering_core/engineering_core.dart';

import 'power_workspace_state.dart';

enum PowerWorkspaceReadKind {
  working,
  captured,
  capturedEmpty,
  notCaptured,
}

enum PowerWorkspaceCurrentness {
  current,
  stale,
  mixed,
  empty,
}

final class PowerWorkspaceScenarioOption {
  PowerWorkspaceScenarioOption({
    required String scenarioId,
    required String segmentId,
    required String label,
  }) : scenarioId = _text(scenarioId, 'scenarioId'),
       segmentId = _text(segmentId, 'segmentId'),
       label = _text(label, 'label');

  final String scenarioId;
  final String segmentId;
  final String label;

  String get key => '$scenarioId\u0000$segmentId';
}

final class PowerWorkspaceMetric {
  PowerWorkspaceMetric({
    required String key,
    required String label,
    required String value,
    this.unit,
  }) : key = _text(key, 'key'),
       label = _text(label, 'label'),
       value = _text(value, 'value'),
       unit = unit == null ? null : _text(unit, 'unit');

  final String key;
  final String label;
  final String value;
  final String? unit;
}

final class PowerWorkspaceFindingProjection {
  PowerWorkspaceFindingProjection({
    required this.finding,
    String? entityRef,
    String? fieldRef,
  }) : entityRef = _nullableText(entityRef, 'entityRef'),
       fieldRef = _nullableText(fieldRef, 'fieldRef');

  final PowerEvaluationFinding finding;
  final String? entityRef;
  final String? fieldRef;
}

final class PowerWorkspaceCardProjection {
  PowerWorkspaceCardProjection({
    required this.code,
    required String title,
    required String summary,
    required this.currentness,
    Iterable<PowerWorkspaceMetric> metrics = const [],
    Iterable<String> explanation = const [],
    Iterable<PowerWorkspaceFindingProjection> findings = const [],
  }) : title = _text(title, 'title'),
       summary = _text(summary, 'summary'),
       metrics = List.unmodifiable(metrics),
       explanation = List.unmodifiable(
         explanation.map((value) => _text(value, 'explanation')),
       ),
       findings = List.unmodifiable(findings);

  final PowerWorkspaceCardCode code;
  final String title;
  final String summary;
  final PowerWorkspaceCurrentness currentness;
  final List<PowerWorkspaceMetric> metrics;
  final List<String> explanation;
  final List<PowerWorkspaceFindingProjection> findings;
}

final class PowerWorkspaceBudgetProjection {
  PowerWorkspaceBudgetProjection({
    required String groupId,
    String? ownerComponentId,
    required this.currentness,
    Iterable<PowerWorkspaceMetric> metrics = const [],
    this.selectedContribution = false,
  }) : groupId = _text(groupId, 'groupId'),
       ownerComponentId = _nullableText(ownerComponentId, 'ownerComponentId'),
       metrics = List.unmodifiable(metrics);

  final String groupId;
  final String? ownerComponentId;
  final PowerWorkspaceCurrentness currentness;
  final List<PowerWorkspaceMetric> metrics;
  final bool selectedContribution;
}

final class PowerWorkspaceOverlayProjection {
  PowerWorkspaceOverlayProjection({
    Iterable<String> highlightedComponentIds = const [],
    Iterable<String> sourceComponentIds = const [],
    Iterable<String> highlightedCableRunIds = const [],
    Iterable<String> capacityGroupIds = const [],
  }) : highlightedComponentIds = _sortedUnique(highlightedComponentIds),
       sourceComponentIds = _sortedUnique(sourceComponentIds),
       highlightedCableRunIds = _sortedUnique(highlightedCableRunIds),
       capacityGroupIds = _sortedUnique(capacityGroupIds);

  final List<String> highlightedComponentIds;
  final List<String> sourceComponentIds;
  final List<String> highlightedCableRunIds;
  final List<String> capacityGroupIds;

  bool get isEmpty =>
      highlightedComponentIds.isEmpty &&
      sourceComponentIds.isEmpty &&
      highlightedCableRunIds.isEmpty &&
      capacityGroupIds.isEmpty;
}

final class PowerWorkspaceProjection {
  PowerWorkspaceProjection({
    required this.contextGeneration,
    required this.readKind,
    required String lifecycleState,
    required this.currentness,
    required Iterable<PowerWorkspaceScenarioOption> scenarios,
    required Iterable<PowerWorkspaceCardProjection> cards,
    required this.overlay,
    Iterable<PowerWorkspaceBudgetProjection> budgets = const [],
    this.reasonCode,
  }) : lifecycleState = _text(lifecycleState, 'lifecycleState').toUpperCase(),
       scenarios = List.unmodifiable(scenarios),
       cards = Map.unmodifiable({for (final card in cards) card.code: card}),
       budgets = List.unmodifiable(budgets) {
    if (contextGeneration < 1) {
      throw ArgumentError.value(
        contextGeneration,
        'contextGeneration',
        'Must be positive.',
      );
    }
    if (this.cards.length != List<PowerWorkspaceCardProjection>.from(cards).length) {
      throw ArgumentError('Workspace cards must be unique by code.');
    }
    if (readKind == PowerWorkspaceReadKind.notCaptured &&
        (reasonCode == null || reasonCode!.trim().isEmpty)) {
      throw ArgumentError('NOT_CAPTURED projection requires a reason code.');
    }
  }

  final int contextGeneration;
  final PowerWorkspaceReadKind readKind;
  final String lifecycleState;
  final PowerWorkspaceCurrentness currentness;
  final List<PowerWorkspaceScenarioOption> scenarios;
  final Map<PowerWorkspaceCardCode, PowerWorkspaceCardProjection> cards;
  final PowerWorkspaceOverlayProjection overlay;
  final List<PowerWorkspaceBudgetProjection> budgets;
  final String? reasonCode;

  bool get mutationAllowed => lifecycleState == 'WORKING';
  bool get historical => readKind != PowerWorkspaceReadKind.working;
  bool get hasCapturedPower =>
      readKind == PowerWorkspaceReadKind.captured ||
      readKind == PowerWorkspaceReadKind.capturedEmpty;

  PowerWorkspaceCardProjection? card(PowerWorkspaceCardCode code) => cards[code];
}

final class PowerWorkspaceOpenResult {
  const PowerWorkspaceOpenResult({
    required this.state,
    required this.projection,
  });

  final PowerWorkspaceState state;
  final PowerWorkspaceProjection projection;
}

abstract interface class PowerWorkspaceRepository {
  Future<PowerWorkspaceOpenResult?> open(String projectId);

  Future<PowerWorkspaceProjection> load(PowerWorkspaceState state);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String? _nullableText(String? value, String field) {
  if (value == null) return null;
  return _text(value, field);
}

List<String> _sortedUnique(Iterable<String> values) {
  final result = values.map((value) => _text(value, 'overlayRef')).toSet().toList()
    ..sort();
  return List.unmodifiable(result);
}
