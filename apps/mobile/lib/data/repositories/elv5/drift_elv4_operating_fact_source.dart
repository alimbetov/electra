import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../../application/elv5/power/elv4_operating_fact_source.dart';
import '../../database/app_database.dart';

final class DriftElv4OperatingFactSource implements Elv4OperatingFactSource {
  const DriftElv4OperatingFactSource(this.database);

  final AppDatabase database;

  @override
  Future<List<Elv4ScenarioSegmentFact>> loadScenarioSegments({
    required String projectId,
    required String designRevisionId,
    Set<PowerScenarioRole>? roles,
  }) async {
    final scenarios = await database.customSelect(
      'SELECT id, revision, role FROM power_operating_scenarios '
      'WHERE project_id = ? AND design_revision_id = ? AND deleted_at IS NULL '
      'ORDER BY id',
      variables: <Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
      ],
    ).get();
    final result = <Elv4ScenarioSegmentFact>[];
    for (final scenario in scenarios) {
      final role = PowerScenarioRole.values.singleWhere(
        (value) => value.name.toUpperCase() == scenario.read<String>('role'),
      );
      if (roles != null && !roles.contains(role)) continue;
      final scenarioId = scenario.read<String>('id');
      final segments = await database.customSelect(
        'SELECT segment_id, ordinal, duration_json FROM power_scenario_segments '
        'WHERE project_id = ? AND design_revision_id = ? AND scenario_id = ? '
        'ORDER BY ordinal, segment_id',
        variables: <Variable>[
          Variable.withString(projectId),
          Variable.withString(designRevisionId),
          Variable.withString(scenarioId),
        ],
      ).get();
      for (final segment in segments) {
        final segmentId = segment.read<String>('segment_id');
        final states = await database.customSelect(
          'SELECT component_id, state_code FROM power_scenario_states '
          'WHERE project_id = ? AND design_revision_id = ? '
          'AND scenario_id = ? AND segment_id = ? ORDER BY component_id',
          variables: <Variable>[
            Variable.withString(projectId),
            Variable.withString(designRevisionId),
            Variable.withString(scenarioId),
            Variable.withString(segmentId),
          ],
        ).get();
        final byComponent = <String, PowerDeviceState>{};
        for (final state in states) {
          final componentId = state.read<String>('component_id');
          final value = PowerDeviceState.values.singleWhere(
            (candidate) =>
                candidate.name.toUpperCase() == state.read<String>('state_code'),
          );
          if (byComponent.putIfAbsent(componentId, () => value) != value) {
            throw StateError('ELV4_SCENARIO_DUPLICATE_COMPONENT_STATE:$scenarioId:$segmentId:$componentId');
          }
        }
        final durationJson = segment.readNullable<String>('duration_json');
        result.add(
          Elv4ScenarioSegmentFact(
            scenarioId: scenarioId,
            role: role,
            scenarioRevision: scenario.read<int>('revision'),
            segmentId: segmentId,
            ordinal: segment.read<int>('ordinal'),
            durationSeconds: durationJson == null
                ? null
                : PowerRational.fromWireDecimal(jsonDecode(durationJson)),
            componentStates: byComponent,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  @override
  Future<List<Elv4ExactDcLoadFact>> loadExactDcLoads({
    required String projectId,
    required String designRevisionId,
    required Set<String> componentIds,
  }) async {
    if (componentIds.isEmpty) return const <Elv4ExactDcLoadFact>[];
    final rows = await database.customSelect(
      'SELECT l.id, l.revision, l.input_port_id, l.state_code, '
      'l.accounting_kind, l.origin_id, l.typed_demand_json, p.component_id '
      'FROM power_load_bindings l '
      'JOIN engineering_port_instances p ON p.id = l.input_port_id '
      'WHERE l.project_id = ? AND l.design_revision_id = ? '
      'AND l.deleted_at IS NULL AND p.deleted_at IS NULL '
      'ORDER BY p.component_id, l.origin_id, l.state_code, l.id',
      variables: <Variable>[
        Variable.withString(projectId),
        Variable.withString(designRevisionId),
      ],
    ).get();
    final result = <Elv4ExactDcLoadFact>[];
    for (final row in rows) {
      final componentId = row.read<String>('component_id');
      if (!componentIds.contains(componentId)) continue;
      final raw = jsonDecode(row.read<String>('typed_demand_json'));
      if (raw is! Map) {
        throw StateError('ELV4_TYPED_DEMAND_NOT_OBJECT:${row.read<String>('id')}');
      }
      final demand = PowerDemand.fromMap(raw.cast<String, Object?>());
      if (demand is! DcConstantCurrentDemand) {
        continue;
      }
      result.add(
        Elv4ExactDcLoadFact(
          bindingId: row.read<String>('id'),
          bindingRevision: row.read<int>('revision'),
          componentId: componentId,
          inputPortId: row.read<String>('input_port_id'),
          originId: row.read<String>('origin_id'),
          stateCode: row.read<String>('state_code'),
          currentA: demand.currentA,
          accountingKind: PowerAccountingKind.values.singleWhere(
            (value) =>
                value.name.toUpperCase() == row.read<String>('accounting_kind'),
          ),
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
