import 'package:drift/drift.dart';

import 'database/app_database.dart';

Future<void> guardComponentElvPorts(
  AppDatabase database,
  Iterable<String> componentIds,
) async {
  final bindings =
      await (database.select(database.componentReferenceBindings)..where(
        (r) => r.componentId.isIn(componentIds) & r.deletedAt.isNull(),
      )).get();
  if (bindings.isNotEmpty)
    throw StateError(
      "Release engineering profile bindings before deleting equipment.",
    );
  final rows =
      await (database.select(database.engineeringPortInstances)..where(
        (r) => r.componentId.isIn(componentIds) & r.deletedAt.isNull(),
      )).get();
  if (rows.isNotEmpty)
    throw StateError(
      'Retire engineering ports and resolve their links before deleting placed equipment.',
    );
}

Future<void> guardSystemElvTopology(
  AppDatabase database,
  String systemId, {
  String? componentId,
}) async {
  if (componentId != null) {
    final binding =
        await (database.select(database.componentReferenceBindings)..where(
          (r) => r.componentId.equals(componentId) & r.deletedAt.isNull(),
        )).getSingleOrNull();
    if (binding != null)
      throw StateError(
        'Release the profile binding before changing system participation.',
      );
    await guardSystemPowerOwnedMembership(database, systemId, componentId);
  }
  final ports =
      componentId == null
          ? <String>[]
          : (await (database.select(database.engineeringPortInstances)
                ..where((r) => r.componentId.equals(componentId))).get())
              .map((p) => p.id)
              .toList();
  final links =
      await (database.select(database.engineeringPortConnections)..where(
        (r) =>
            r.systemId.equals(systemId) &
            r.deletedAt.isNull() &
            (componentId == null
                ? const Constant(true)
                : (r.fromPortId.isIn(ports) | r.toPortId.isIn(ports))),
      )).get();
  final groups =
      await (database.select(database.engineeringTopologyGroups)..where(
        (r) =>
            r.systemId.equals(systemId) &
            r.deletedAt.isNull() &
            (componentId == null
                ? const Constant(true)
                : (r.startPortId.isIn(ports) | r.endPortId.isIn(ports))),
      )).get();
  if (links.isNotEmpty || groups.isNotEmpty)
    throw StateError(
      'Resolve engineering connections and topology groups before changing system participation or ownership.',
    );
}

Future<void> guardSystemPowerOwnedMembership(
  AppDatabase database,
  String systemId,
  String componentId,
) async {
  final row =
      await database
          .customSelect(
            '''
SELECT 1
FROM project_engineering_systems s
WHERE s.id = ?
  AND s.deleted_at IS NULL
  AND (
    EXISTS (
      SELECT 1 FROM power_component_bindings b
      WHERE b.project_id = s.project_id
        AND b.component_id = ?
        AND b.deleted_at IS NULL
    )
    OR EXISTS (
      SELECT 1 FROM power_transfer_bindings b
      WHERE b.project_id = s.project_id
        AND b.component_id = ?
        AND b.deleted_at IS NULL
    )
    OR EXISTS (
      SELECT 1 FROM power_capacity_groups b
      WHERE b.project_id = s.project_id
        AND b.owner_component_id = ?
        AND b.deleted_at IS NULL
    )
    OR EXISTS (
      SELECT 1 FROM power_supply_requirements b
      WHERE b.project_id = s.project_id
        AND b.consumer_component_id = ?
        AND b.deleted_at IS NULL
    )
    OR EXISTS (
      SELECT 1 FROM power_scenario_states b
      WHERE b.project_id = s.project_id
        AND b.component_id = ?
    )
    OR EXISTS (
      SELECT 1 FROM backup_assemblies b
      WHERE b.project_id = s.project_id
        AND b.deleted_at IS NULL
        AND (
          b.ups_component_id = ?
          OR b.charger_component_id = ?
          OR b.bank_component_id = ?
        )
    )
    OR EXISTS (
      SELECT 1 FROM battery_bank_bindings b
      WHERE b.project_id = s.project_id
        AND b.bank_component_id = ?
        AND b.deleted_at IS NULL
    )
    OR EXISTS (
      SELECT 1
      FROM power_port_bindings b
      JOIN engineering_port_instances p ON p.id = b.port_id
      WHERE b.project_id = s.project_id
        AND p.component_id = ?
        AND b.deleted_at IS NULL
        AND p.deleted_at IS NULL
    )
    OR EXISTS (
      SELECT 1
      FROM power_load_bindings b
      JOIN engineering_port_instances p ON p.id = b.input_port_id
      WHERE b.project_id = s.project_id
        AND p.component_id = ?
        AND b.deleted_at IS NULL
        AND p.deleted_at IS NULL
    )
  )
LIMIT 1
''',
            variables: [
              Variable.withString(systemId),
              for (var i = 0; i < 11; i++) Variable.withString(componentId),
            ],
            readsFrom: database.allTables.toSet(),
          )
          .getSingleOrNull();
  if (row != null) {
    throw StateError(
      'ELV4_POWER_MEMBERSHIP_OWNED: Release or replace revision-scoped power '
      'ownership before changing engineering system participation.',
    );
  }
}

enum HierarchyElvScope { project, floor, room }

Future<void> guardHierarchyElvPorts(
  AppDatabase database,
  HierarchyElvScope scope,
  String id,
) async {
  final column = switch (scope) {
    HierarchyElvScope.project => 'f.project_id',
    HierarchyElvScope.floor => 'f.id',
    HierarchyElvScope.room => 'r.id',
  };
  final binding =
      await database
          .customSelect(
            'SELECT b.component_id FROM component_reference_bindings b JOIN component_instances ci ON ci.id=b.component_id JOIN rooms r ON ci.room_id=r.id JOIN floors f ON r.floor_id=f.id WHERE b.deleted_at IS NULL AND $column = ? LIMIT 1',
            variables: [Variable.withString(id)],
            readsFrom: database.allTables.toSet(),
          )
          .getSingleOrNull();
  if (binding != null)
    throw StateError(
      'Release engineering profile bindings before deleting their hierarchy.',
    );
  final row =
      await database
          .customSelect(
            'SELECT ep.id FROM engineering_port_instances ep JOIN component_instances ci ON ci.id = ep.component_id JOIN rooms r ON r.id = ci.room_id JOIN floors f ON f.id = r.floor_id WHERE ep.deleted_at IS NULL AND $column = ? LIMIT 1',
            variables: [Variable.withString(id)],
            readsFrom: database.allTables.toSet(),
          )
          .getSingleOrNull();
  if (row != null)
    throw StateError(
      'Resolve engineering ports before deleting their project/floor/room.',
    );
}
