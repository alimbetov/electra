import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/power_workspace_projection.dart';
import '../../application/power_workspace_state.dart';
import '../database/app_database.dart';
import 'drift_power_publication_runtime.dart';

/// Read-only P7 adapter. It projects persisted ELV4 evidence into UI data but
/// performs no engineering arithmetic and never mutates canonical state.
final class DriftPowerWorkspaceRepository implements PowerWorkspaceRepository {
  DriftPowerWorkspaceRepository(
    this.database, {
    required this.originDeviceId,
    DriftPowerPublicationRuntime? publicationRuntime,
  }) : publicationRuntime =
           publicationRuntime ??
           DriftPowerPublicationRuntime(
             database,
             originDeviceId: originDeviceId,
           );

  final AppDatabase database;
  final String originDeviceId;
  final DriftPowerPublicationRuntime publicationRuntime;

  @override
  Future<PowerWorkspaceOpenResult?> open(String projectId) async {
    final revision =
        await database
            .customSelect(
              'SELECT id, state FROM project_design_revisions '
              'WHERE project_id = ? AND deleted_at IS NULL '
              "ORDER BY CASE state WHEN 'WORKING' THEN 0 WHEN 'FROZEN' THEN 1 ELSE 2 END, "
              'sequence DESC LIMIT 1',
              variables: [Variable.withString(projectId)],
            )
            .getSingleOrNull();
    if (revision == null) return null;

    final revisionId = revision.read<String>('id');
    final scenarios = await _scenarioOptions(revisionId);
    final initial = await _initialScenario(revisionId, scenarios);
    final state = PowerWorkspaceState(
      context: PowerWorkspaceReadContext(
        projectId: projectId,
        designRevisionId: revisionId,
        lifecycleState: revision.read<String>('state'),
        scenarioId: initial.scenarioId,
        segmentId: initial.segmentId,
        generation: 1,
      ),
      cards: PowerWorkspaceCardCode.values,
    );
    return PowerWorkspaceOpenResult(
      state: state,
      projection: await load(state),
    );
  }

  @override
  Future<PowerWorkspaceProjection> load(PowerWorkspaceState state) async {
    final context = state.context;
    final revision = await publicationRuntime.readRevision(
      projectId: context.projectId,
      designRevisionId: context.designRevisionId,
    );
    final scenarios = await _scenarioOptions(context.designRevisionId);

    if (revision.kind == PowerRevisionReadKind.notCaptured) {
      return PowerWorkspaceProjection(
        contextGeneration: context.generation,
        readKind: PowerWorkspaceReadKind.notCaptured,
        lifecycleState: revision.lifecycleState,
        currentness: PowerWorkspaceCurrentness.empty,
        scenarios: scenarios,
        cards: _emptyCards(
          summary: 'Power evidence was not captured for this revision.',
        ),
        overlay: PowerWorkspaceOverlayProjection(
          highlightedComponentIds: [
            if (state.selectedComponentId != null) state.selectedComponentId!,
          ],
        ),
        reasonCode: revision.reasonCode ?? 'ELV4_POWER_NOT_CAPTURED',
      );
    }

    final records = switch (revision.kind) {
      PowerRevisionReadKind.working => await _workingRecords(context),
      PowerRevisionReadKind.captured || PowerRevisionReadKind.capturedEmpty =>
        await _capturedRecords(context, revision.capturedPayload),
      PowerRevisionReadKind.notCaptured => const <_WorkspaceEvidence>[],
    };

    final scoped = records
        .where(
          (row) =>
              row.nodeKey.scenarioId == context.scenarioId &&
              (row.nodeKey.scopeKind == PowerEvaluationScopeKind.sequence ||
                  row.nodeKey.scopeId == context.segmentId),
        )
        .toList(growable: false);
    final pointerStates = <String, PowerPointerState>{
      for (final row in scoped) row.nodeKey.encode(): row.pointerState,
    };
    final relevant = _relevant(scoped, state.selectedComponentId);
    final overlay = await _overlay(
      context: context,
      selectedComponentId: state.selectedComponentId,
      evidence: relevant,
    );
    final budgets = await _budgets(
      context: context,
      evidence: scoped,
      relevant: relevant,
      selectedGroupIds: overlay.capacityGroupIds.toSet(),
    );

    final readKind = switch (revision.kind) {
      PowerRevisionReadKind.working => PowerWorkspaceReadKind.working,
      PowerRevisionReadKind.captured => PowerWorkspaceReadKind.captured,
      PowerRevisionReadKind.capturedEmpty => PowerWorkspaceReadKind.capturedEmpty,
      PowerRevisionReadKind.notCaptured => PowerWorkspaceReadKind.notCaptured,
    };
    final cardRows = relevant.isEmpty ? scoped : relevant;
    return PowerWorkspaceProjection(
      contextGeneration: context.generation,
      readKind: readKind,
      lifecycleState: revision.lifecycleState,
      currentness: _currentness(scoped),
      scenarios: scenarios,
      cards: _cards(
        context: context,
        evidence: cardRows,
        allEvidence: scoped,
      ),
      overlay: overlay,
      budgets: budgets,
      pointerStates: pointerStates,
    );
  }

  Future<List<PowerWorkspaceScenarioOption>> _scenarioOptions(
    String revisionId,
  ) async {
    final rows = await database.customSelect(
      'SELECT s.id AS scenario_id, s.role AS role, '
      'g.segment_id AS segment_id, g.ordinal AS ordinal '
      'FROM power_operating_scenarios s '
      'LEFT JOIN power_scenario_segments g '
      'ON g.design_revision_id = s.design_revision_id '
      'AND g.scenario_id = s.id '
      'WHERE s.design_revision_id = ? AND s.deleted_at IS NULL '
      'ORDER BY s.id, g.ordinal, g.segment_id',
      variables: [Variable.withString(revisionId)],
    ).get();
    final result = <PowerWorkspaceScenarioOption>[];
    for (final row in rows) {
      final scenarioId = row.read<String>('scenario_id');
      final segmentId = row.readNullable<String>('segment_id');
      if (segmentId == null) continue;
      final role = row.read<String>('role');
      result.add(
        PowerWorkspaceScenarioOption(
          scenarioId: scenarioId,
          segmentId: segmentId,
          label: '$role · $segmentId',
        ),
      );
    }
    return List.unmodifiable(result);
  }

  Future<PowerWorkspaceScenarioOption> _initialScenario(
    String revisionId,
    List<PowerWorkspaceScenarioOption> configured,
  ) async {
    if (configured.isNotEmpty) return configured.first;
    final pointer =
        await database
            .customSelect(
              'SELECT logical_node_key_json FROM power_evaluation_pointers '
              'WHERE design_revision_id = ? ORDER BY logical_node_key_json LIMIT 1',
              variables: [Variable.withString(revisionId)],
            )
            .getSingleOrNull();
    if (pointer != null) {
      final key = PowerNodeKeyV2.decode(
        pointer.read<String>('logical_node_key_json'),
      );
      return PowerWorkspaceScenarioOption(
        scenarioId: key.scenarioId,
        segmentId: key.scopeId,
        label: '${key.scenarioId} · ${key.scopeId}',
      );
    }
    return PowerWorkspaceScenarioOption(
      scenarioId: 'UNCONFIGURED',
      segmentId: 'UNCONFIGURED',
      label: 'Power scenario not configured',
    );
  }

  Future<List<_WorkspaceEvidence>> _workingRecords(
    PowerWorkspaceReadContext context,
  ) async {
    final rows = await database.customSelect(
      'SELECT p.logical_node_key_json, p.state, p.generation, '
      'p.evaluation_id, p.evidence_sha256, r.evidence_json '
      'FROM power_evaluation_pointers p '
      'LEFT JOIN power_evaluation_records r '
      'ON r.design_revision_id = p.design_revision_id '
      'AND r.logical_node_key_sha256 = p.logical_node_key_sha256 '
      'AND r.evaluation_id = p.evaluation_id '
      'WHERE p.project_id = ? AND p.design_revision_id = ? '
      'ORDER BY p.logical_node_key_json',
      variables: [
        Variable.withString(context.projectId),
        Variable.withString(context.designRevisionId),
      ],
    ).get();
    return [
      for (final row in rows)
        if (row.readNullable<String>('evaluation_id') != null &&
            row.readNullable<String>('evidence_json') != null)
          _WorkspaceEvidence.fromStored(
            nodeKeyJson: row.read<String>('logical_node_key_json'),
            pointerState: _pointerState(row.read<String>('state')),
            generation: row.read<int>('generation'),
            evaluationId: row.read<String>('evaluation_id'),
            evidenceSha256: row.readNullable<String>('evidence_sha256'),
            storedJson: row.read<String>('evidence_json'),
          ),
    ];
  }

  Future<List<_WorkspaceEvidence>> _capturedRecords(
    PowerWorkspaceReadContext context,
    Map<String, Object?>? capturedPayload,
  ) async {
    final pointerValues = capturedPayload?['pointers'];
    if (pointerValues is! List || pointerValues.isEmpty) return const [];
    final result = <_WorkspaceEvidence>[];
    for (final value in pointerValues) {
      if (value is! Map) continue;
      final pointer = value.cast<String, Object?>();
      final nodeTuple = pointer['logicalNodeKey'];
      final evaluationId = pointer['evaluationId'];
      final expectedSha = pointer['evidenceSha256'];
      if (nodeTuple is! List || evaluationId is! String) continue;
      final nodeKeyJson = canonicalEngineeringJsonV1(nodeTuple);
      final nodeKey = PowerNodeKeyV2.decode(nodeKeyJson);
      final row =
          await database
              .customSelect(
                'SELECT evidence_json, evidence_sha256 FROM power_evaluation_records '
                'WHERE project_id = ? AND design_revision_id = ? '
                'AND logical_node_key_sha256 = ? AND evaluation_id = ?',
                variables: [
                  Variable.withString(context.projectId),
                  Variable.withString(context.designRevisionId),
                  Variable.withString(nodeKey.sha256),
                  Variable.withString(evaluationId),
                ],
              )
              .getSingleOrNull();
      if (row == null) {
        throw StateError('ELV4_FROZEN_POWER_EVIDENCE_MISSING');
      }
      final storedSha = row.read<String>('evidence_sha256');
      if (expectedSha is String && expectedSha != storedSha) {
        throw StateError('ELV4_FROZEN_POWER_EVIDENCE_HASH_MISMATCH');
      }
      result.add(
        _WorkspaceEvidence.fromStored(
          nodeKeyJson: nodeKeyJson,
          pointerState: _pointerState(pointer['state']! as String),
          generation: pointer['generation']! as int,
          evaluationId: evaluationId,
          evidenceSha256: storedSha,
          storedJson: row.read<String>('evidence_json'),
        ),
      );
    }
    result.sort((a, b) => a.nodeKey.compareTo(b.nodeKey));
    return List.unmodifiable(result);
  }

  List<_WorkspaceEvidence> _relevant(
    List<_WorkspaceEvidence> values,
    String? selectedComponentId,
  ) {
    if (selectedComponentId == null) return values;
    final selected = values
        .where((row) => row.referencesEntity(selectedComponentId))
        .toList(growable: false);
    return selected;
  }

  Future<PowerWorkspaceOverlayProjection> _overlay({
    required PowerWorkspaceReadContext context,
    required String? selectedComponentId,
    required List<_WorkspaceEvidence> evidence,
  }) async {
    final componentIds = <String>{
      if (selectedComponentId != null) selectedComponentId,
    };
    final cableRunIds = <String>{};
    final groupIds = <String>{};
    for (final row in evidence) {
      if (row.nodeKey.subjectKind.contains('COMPONENT')) {
        componentIds.add(row.nodeKey.subjectId);
      }
      for (final dependency in row.dependencies) {
        switch (dependency.kind) {
          case PowerDependencyKind.cableRun:
            cableRunIds.add(dependency.entityId);
          case PowerDependencyKind.capacityGroup ||
                PowerDependencyKind.groupMembership:
            groupIds.add(dependency.entityId);
          default:
            break;
        }
      }
    }

    final sourceIds = <String>{};
    if (groupIds.isNotEmpty) {
      final rows = await database.customSelect(
        'SELECT id, owner_component_id FROM power_capacity_groups '
        'WHERE project_id = ? AND design_revision_id = ? '
        'AND deleted_at IS NULL',
        variables: [
          Variable.withString(context.projectId),
          Variable.withString(context.designRevisionId),
        ],
      ).get();
      for (final row in rows) {
        if (groupIds.contains(row.read<String>('id'))) {
          sourceIds.add(row.read<String>('owner_component_id'));
        }
      }
    }
    componentIds.addAll(sourceIds);
    return PowerWorkspaceOverlayProjection(
      highlightedComponentIds: componentIds,
      sourceComponentIds: sourceIds,
      highlightedCableRunIds: cableRunIds,
      capacityGroupIds: groupIds,
    );
  }

  Future<List<PowerWorkspaceBudgetProjection>> _budgets({
    required PowerWorkspaceReadContext context,
    required List<_WorkspaceEvidence> evidence,
    required List<_WorkspaceEvidence> relevant,
    required Set<String> selectedGroupIds,
  }) async {
    final rows = await database.customSelect(
      'SELECT id, owner_component_id, limits_json FROM power_capacity_groups '
      'WHERE project_id = ? AND design_revision_id = ? '
      'AND deleted_at IS NULL ORDER BY id',
      variables: [
        Variable.withString(context.projectId),
        Variable.withString(context.designRevisionId),
      ],
    ).get();
    final selectedEvidenceGroups = <String>{
      for (final row in relevant)
        for (final dependency in row.dependencies)
          if (dependency.kind == PowerDependencyKind.capacityGroup ||
              dependency.kind == PowerDependencyKind.groupMembership)
            dependency.entityId,
    };
    final result = <PowerWorkspaceBudgetProjection>[];
    for (final row in rows) {
      final groupId = row.read<String>('id');
      final map = _jsonMap(row.read<String>('limits_json'));
      final capacityEvidence = evidence.where(
        (item) =>
            item.nodeKey.processCode == PowerProcessCode.pwr02 &&
            (item.nodeKey.subjectId == groupId ||
                item.dependencies.any(
                  (dependency) => dependency.entityId == groupId,
                )),
      );
      final metrics = <PowerWorkspaceMetric>[
        ..._metrics(map, prefix: 'limit'),
        for (final item in capacityEvidence)
          ..._metrics(item.output, prefix: item.nodeKey.subjectId),
      ];
      result.add(
        PowerWorkspaceBudgetProjection(
          groupId: groupId,
          ownerComponentId: row.read<String>('owner_component_id'),
          currentness: _currentness(capacityEvidence.toList()),
          metrics: _dedupeMetrics(metrics),
          selectedContribution:
              selectedGroupIds.contains(groupId) ||
              selectedEvidenceGroups.contains(groupId),
        ),
      );
    }
    return List.unmodifiable(result);
  }

  List<PowerWorkspaceCardProjection> _cards({
    required PowerWorkspaceReadContext context,
    required List<_WorkspaceEvidence> evidence,
    required List<_WorkspaceEvidence> allEvidence,
  }) {
    Iterable<_WorkspaceEvidence> process(Set<PowerProcessCode> codes) =>
        evidence.where((row) => codes.contains(row.nodeKey.processCode));

    final demand = process({PowerProcessCode.pwr01}).toList();
    final path = process({PowerProcessCode.pwr03, PowerProcessCode.pwr06}).toList();
    final capacity = process({PowerProcessCode.pwr02}).toList();
    final backup = process({PowerProcessCode.pwr04}).toList();
    final allFindings = [
      for (final row in allEvidence) ...row.findings,
    ];
    return [
      _card(
        PowerWorkspaceCardCode.demand,
        'Demand',
        demand,
        emptySummary: 'No demand evaluation for this scope.',
      ),
      _card(
        PowerWorkspaceCardCode.upstreamPath,
        'Upstream path',
        path,
        emptySummary: 'No PoE/DC upstream-path evaluation for this scope.',
      ),
      PowerWorkspaceCardProjection(
        code: PowerWorkspaceCardCode.profileScenario,
        title: 'Profile / scenario',
        summary: '${context.scenarioId} · ${context.segmentId}',
        currentness: _currentness(evidence),
        metrics: [
          PowerWorkspaceMetric(
            key: 'scenario',
            label: 'Scenario',
            value: context.scenarioId,
          ),
          PowerWorkspaceMetric(
            key: 'segment',
            label: 'Segment',
            value: context.segmentId,
          ),
        ],
        explanation: const [
          'Scenario filtering changes the read context only; canonical port bindings remain static.',
        ],
      ),
      PowerWorkspaceCardProjection(
        code: PowerWorkspaceCardCode.realization,
        title: 'Realization',
        summary:
            path.isEmpty
                ? 'No physical realization evidence for this scope.'
                : '${_dependencyCount(path)} consumed physical dependencies',
        currentness: _currentness(path),
        metrics: _dependencyMetrics(path),
        findings: [for (final row in path) ...row.findings],
        explanation: const [
          'Allocation, CableRun and traversal facts are displayed from the consumed-input envelope; the UI does not infer missing physical realization.',
        ],
      ),
      _card(
        PowerWorkspaceCardCode.sourceCapacity,
        'Source / group capacity',
        capacity,
        emptySummary: 'No source-capability evaluation for this scope.',
      ),
      _card(
        PowerWorkspaceCardCode.backup,
        'Backup',
        backup,
        emptySummary: 'No backup-duration evaluation for this scope.',
      ),
      PowerWorkspaceCardProjection(
        code: PowerWorkspaceCardCode.findings,
        title: 'Findings / how calculated',
        summary:
            allFindings.isEmpty
                ? 'No findings in the selected scenario.'
                : '${allFindings.length} finding(s)',
        currentness: _currentness(allEvidence),
        metrics: const [],
        findings: allFindings,
        explanation: [
          for (final row in evidence)
            '${_processLabel(row.nodeKey.processCode)} · ${row.nodeKey.subjectKind}:${row.nodeKey.subjectId} · evaluation ${row.evaluationId}',
        ],
      ),
    ];
  }

  PowerWorkspaceCardProjection _card(
    PowerWorkspaceCardCode code,
    String title,
    List<_WorkspaceEvidence> rows, {
    required String emptySummary,
  }) => PowerWorkspaceCardProjection(
    code: code,
    title: title,
    summary:
        rows.isEmpty
            ? emptySummary
            : '${rows.length} evaluation(s) · ${_currentness(rows).name.toUpperCase()}',
    currentness: _currentness(rows),
    metrics: _dedupeMetrics([
      for (final row in rows)
        ..._metrics(row.output, prefix: _processLabel(row.nodeKey.processCode)),
    ]),
    findings: [for (final row in rows) ...row.findings],
    explanation: [
      for (final row in rows)
        '${_processLabel(row.nodeKey.processCode)} · ${row.nodeKey.subjectKind}:${row.nodeKey.subjectId}',
    ],
  );

  List<PowerWorkspaceCardProjection> _emptyCards({required String summary}) => [
    for (final code in PowerWorkspaceCardCode.values)
      PowerWorkspaceCardProjection(
        code: code,
        title: _cardTitle(code),
        summary: summary,
        currentness: PowerWorkspaceCurrentness.empty,
      ),
  ];
}

final class _WorkspaceEvidence {
  _WorkspaceEvidence({
    required this.nodeKey,
    required this.pointerState,
    required this.generation,
    required this.evaluationId,
    required this.evidenceSha256,
    required this.output,
    required this.dependencies,
    required this.findings,
    required this.envelope,
  });

  factory _WorkspaceEvidence.fromStored({
    required String nodeKeyJson,
    required PowerPointerState pointerState,
    required int generation,
    required String evaluationId,
    required String? evidenceSha256,
    required String storedJson,
  }) {
    final envelope = _jsonMap(storedJson);
    final rawEvidence = envelope['evidence'];
    final evidence = rawEvidence is Map
        ? rawEvidence.cast<String, Object?>()
        : envelope;
    final outputValue = evidence['output'];
    final output =
        outputValue is Map
            ? Map<String, Object?>.unmodifiable(
              outputValue.cast<String, Object?>(),
            )
            : const <String, Object?>{};
    final dependencies = <PowerDependencyKey>[];
    final dependencyValues = envelope['dependencyKeys'];
    if (dependencyValues is List) {
      for (final value in dependencyValues) {
        if (value is! String) continue;
        try {
          dependencies.add(PowerDependencyKey.decode(value));
        } on FormatException {
          // Corrupt/foreign dependency refs are not interpreted by the UI.
        }
      }
    }
    final findings = <PowerWorkspaceFindingProjection>[];
    final findingValues = evidence['findings'];
    if (findingValues is List) {
      for (final value in findingValues) {
        if (value is! Map) continue;
        final map = value.cast<String, Object?>();
        final refs = switch (map['sourceRefs']) {
          final List values => values.whereType<String>().toList(),
          _ => const <String>[],
        };
        findings.add(
          PowerWorkspaceFindingProjection(
            finding: PowerEvaluationFinding(
              code: map['code']! as String,
              severity: map['severity']! as String,
              message: map['message']! as String,
              sourceRefs: refs,
            ),
            entityRef: refs.firstOrNull,
          ),
        );
      }
    }
    return _WorkspaceEvidence(
      nodeKey: PowerNodeKeyV2.decode(nodeKeyJson),
      pointerState: pointerState,
      generation: generation,
      evaluationId: evaluationId,
      evidenceSha256: evidenceSha256,
      output: output,
      dependencies: List.unmodifiable(dependencies),
      findings: List.unmodifiable(findings),
      envelope: Map.unmodifiable(envelope),
    );
  }

  final PowerNodeKeyV2 nodeKey;
  final PowerPointerState pointerState;
  final int generation;
  final String evaluationId;
  final String? evidenceSha256;
  final Map<String, Object?> output;
  final List<PowerDependencyKey> dependencies;
  final List<PowerWorkspaceFindingProjection> findings;
  final Map<String, Object?> envelope;

  bool referencesEntity(String entityId) =>
      nodeKey.subjectId == entityId ||
      dependencies.any((dependency) => dependency.entityId == entityId) ||
      findings.any(
        (finding) => finding.finding.sourceRefs.contains(entityId),
      );
}

PowerPointerState _pointerState(String value) => switch (value) {
  'CURRENT' => PowerPointerState.current,
  'STALE' => PowerPointerState.stale,
  _ => throw StateError('ELV4_POINTER_STATE_CORRUPT:$value'),
};

PowerWorkspaceCurrentness _currentness(List<_WorkspaceEvidence> values) {
  if (values.isEmpty) return PowerWorkspaceCurrentness.empty;
  final current = values.where(
    (value) => value.pointerState == PowerPointerState.current,
  ).length;
  if (current == values.length) return PowerWorkspaceCurrentness.current;
  if (current == 0) return PowerWorkspaceCurrentness.stale;
  return PowerWorkspaceCurrentness.mixed;
}

int _dependencyCount(List<_WorkspaceEvidence> values) => {
  for (final value in values)
    for (final dependency in value.dependencies) dependency.encode(),
}.length;

List<PowerWorkspaceMetric> _dependencyMetrics(
  List<_WorkspaceEvidence> values,
) {
  final byKind = <PowerDependencyKind, int>{};
  for (final value in values) {
    for (final dependency in value.dependencies) {
      byKind.update(dependency.kind, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final kinds = byKind.keys.toList()..sort((a, b) => a.name.compareTo(b.name));
  return [
    for (final kind in kinds)
      PowerWorkspaceMetric(
        key: 'dependency.${kind.name}',
        label: _words(kind.name),
        value: '${byKind[kind]}',
      ),
  ];
}

List<PowerWorkspaceMetric> _metrics(
  Map<String, Object?> values, {
  required String prefix,
}) {
  final keys = values.keys.toList()..sort();
  final result = <PowerWorkspaceMetric>[];
  for (final key in keys) {
    final rendered = _display(values[key]);
    if (rendered == null) continue;
    result.add(
      PowerWorkspaceMetric(
        key: '$prefix.$key',
        label: _words(key),
        value: rendered,
        unit: _unit(key),
      ),
    );
    if (result.length == 10) break;
  }
  return result;
}

List<PowerWorkspaceMetric> _dedupeMetrics(
  Iterable<PowerWorkspaceMetric> metrics,
) {
  final byKey = <String, PowerWorkspaceMetric>{};
  for (final metric in metrics) {
    byKey.putIfAbsent(metric.key, () => metric);
  }
  return List.unmodifiable(byKey.values.take(16));
}

String? _display(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return '$value';
  if (value is Map) {
    final map = value.cast<Object?, Object?>();
    if (map.containsKey('numerator') && map.containsKey('denominator')) {
      return '${map['numerator']}/${map['denominator']}';
    }
    if (map.containsKey('lower') && map.containsKey('upper')) {
      return '[${_display(map['lower']) ?? '?'} … ${_display(map['upper']) ?? '?'}]';
    }
    if (map.length <= 4) return canonicalEngineeringJsonV1(value);
    return null;
  }
  if (value is List && value.length <= 4) {
    return canonicalEngineeringJsonV1(value);
  }
  return null;
}

String? _unit(String key) {
  final normalized = key.toLowerCase();
  if (normalized.endsWith('w') || normalized.contains('watt')) return 'W';
  if (normalized.endsWith('va')) return 'VA';
  if (normalized.endsWith('a') || normalized.contains('current')) return 'A';
  if (normalized.endsWith('v') || normalized.contains('voltage')) return 'V';
  if (normalized.contains('minute')) return 'min';
  if (normalized.contains('hour') || normalized.endsWith('wh')) return 'Wh';
  return null;
}

String _processLabel(PowerProcessCode code) => switch (code) {
  PowerProcessCode.pwr01 => 'PWR-01',
  PowerProcessCode.pwr02 => 'PWR-02',
  PowerProcessCode.pwr03 => 'PWR-03',
  PowerProcessCode.pwr04 => 'PWR-04',
  PowerProcessCode.pwr05 => 'PWR-05',
  PowerProcessCode.pwr06 => 'PWR-06',
};

String _cardTitle(PowerWorkspaceCardCode code) => switch (code) {
  PowerWorkspaceCardCode.demand => 'Demand',
  PowerWorkspaceCardCode.upstreamPath => 'Upstream path',
  PowerWorkspaceCardCode.profileScenario => 'Profile / scenario',
  PowerWorkspaceCardCode.realization => 'Realization',
  PowerWorkspaceCardCode.sourceCapacity => 'Source / group capacity',
  PowerWorkspaceCardCode.backup => 'Backup',
  PowerWorkspaceCardCode.findings => 'Findings / how calculated',
};

String _words(String value) {
  final spaced = value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match[1]} ${match[2]}',
      )
      .replaceAll(RegExp(r'[_\-.]+'), ' ')
      .trim();
  if (spaced.isEmpty) return value;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

Map<String, Object?> _jsonMap(String encoded) {
  final decoded = jsonDecode(encoded);
  if (decoded is! Map) return const {};
  return decoded.cast<String, Object?>();
}
