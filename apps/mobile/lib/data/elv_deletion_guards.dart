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
