import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/floor_routing_repository.dart';
import '../../application/cable_routing_repository.dart';
import '../../domain/project_models.dart';
import '../database/app_database.dart';
import 'drift_project_hierarchy_repository.dart';
import 'drift_cable_routing_repository.dart';

class DriftFloorRoutingRepository implements FloorRoutingRepository {
  DriftFloorRoutingRepository(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;
  @override
  Stream<FloorRoutingSnapshot> watch(String floorId) => database
      .customSelect(
        'SELECT id, revision FROM floors WHERE id = ?',
        variables: [Variable.withString(floorId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(floorId));
  @override
  Future<FloorRoutingSnapshot> load(String floorId) => database.transaction(
    () async {
      final hierarchy = DriftProjectHierarchyRepository(database);
      final floor = await hierarchy.findFloor(floorId);
      if (floor == null) return const FloorRoutingSnapshot();
      final project = await hierarchy.findProject(floor.projectId);
      if (project == null) return const FloorRoutingSnapshot();
      final rows =
          await (database.select(database.rooms)
                ..where((r) => r.floorId.equals(floorId) & r.deletedAt.isNull())
                ..orderBy([
                  (r) => OrderingTerm.asc(r.name),
                  (r) => OrderingTerm.asc(r.id),
                ]))
              .get();
      final rooms = <RoomRecord>[];
      final routing = <String, RoomRoutingSnapshot>{};
      final roomRepository = DriftCableRoutingRepository(
        database,
        originDeviceId: originDeviceId,
      );
      for (final row in rows) {
        final room = await hierarchy.findRoom(row.id);
        if (room == null) continue;
        rooms.add(room);
        routing[row.id] = await roomRepository.loadRoomRouting(row.id);
      }
      final panels =
          await (database.select(database.floorRoutingPanels)
                ..where((r) => r.floorId.equals(floorId) & r.deletedAt.isNull())
                ..orderBy([
                  (r) => OrderingTerm.asc(r.code),
                  (r) => OrderingTerm.asc(r.id),
                ]))
              .get();
      final feeds =
          await (database.select(database.floorPanelFeeds)
                ..where((r) => r.panelId.isIn(panels.map((p) => p.id)))
                ..orderBy([(r) => OrderingTerm.asc(r.runId)]))
              .get();
      final handoffs =
          await (database.select(database.floorRoutingHandoffs)
                ..where((r) => r.floorId.equals(floorId) & r.deletedAt.isNull())
                ..orderBy([
                  (r) => OrderingTerm.asc(r.name),
                  (r) => OrderingTerm.asc(r.id),
                ]))
              .get();
      return FloorRoutingSnapshot(
        project: project,
        floor: floor,
        rooms: List.unmodifiable(rooms),
        routing: Map.unmodifiable(routing),
        panels: panels
            .map(
              (p) => FloorRoutingPanel(
                id: p.id,
                floorId: p.floorId,
                code: p.code,
                name: p.name,
                feeds: feeds
                    .where((f) => f.panelId == p.id)
                    .map(
                      (f) => FloorPanelFeed(
                        runId: f.runId,
                        endpointSignature: f.endpointSignature,
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
        handoffs: handoffs
            .map(
              (h) => FloorRoutingHandoff(
                id: h.id,
                floorId: h.floorId,
                name: h.name,
                fromRunId: h.fromRunId,
                toRunId: h.toRunId,
                fromSignature: h.fromSignature,
                toSignature: h.toSignature,
              ),
            )
            .toList(growable: false),
      );
    },
  );
  @override
  Future<void> savePanel(FloorRoutingPanel panel) =>
      database.transaction(() async {
        final snapshot = await load(panel.floorId);
        if (snapshot.floor == null)
          throw StateError('Floor/project is unavailable.');
        final graph = snapshot.graph();
        final errors = graph.panelIssues(panel);
        if (snapshot.panels.any(
          (p) => p.id != panel.id && p.code == panel.code.trim(),
        )) {
          errors.add('Panel code must be unique on the floor.');
        }
        if (errors.isNotEmpty) throw StateError(errors.join(' '));
        final old =
            await (database.select(database.floorRoutingPanels)
              ..where((r) => r.id.equals(panel.id))).getSingleOrNull();
        if (old != null && old.floorId != panel.floorId)
          throw StateError('Cannot move a source panel between floors.');
        final now = DateTime.now().toUtc();
        await database
            .into(database.floorRoutingPanels)
            .insertOnConflictUpdate(
              FloorRoutingPanelsCompanion(
                id: Value(panel.id),
                floorId: Value(panel.floorId),
                code: Value(panel.code.trim()),
                name: Value(panel.name.trim()),
                revision: Value((old?.revision ?? 0) + 1),
                createdAt: Value(old?.createdAt ?? now),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
        await (database.delete(database.floorPanelFeeds)
          ..where((r) => r.panelId.equals(panel.id))).go();
        for (final feed in panel.feeds) {
          await database
              .into(database.floorPanelFeeds)
              .insert(
                FloorPanelFeedsCompanion.insert(
                  panelId: panel.id,
                  runId: feed.runId,
                  endpointSignature: feed.endpointSignature,
                ),
              );
        }
      });
  @override
  Future<void> saveHandoff(FloorRoutingHandoff handoff) =>
      database.transaction(() async {
        final snapshot = await load(handoff.floorId);
        if (snapshot.floor == null)
          throw StateError('Floor/project is unavailable.');
        final graph = snapshot.graph(
          handoffs: [
            ...snapshot.handoffs.where((h) => h.id != handoff.id),
            handoff,
          ],
        );
        final errors = graph.handoffIssues(handoff);
        errors.addAll(graph.issues['handoff:${handoff.id}'] ?? []);
        if (errors.isNotEmpty) throw StateError(errors.toSet().join(' '));
        final old =
            await (database.select(database.floorRoutingHandoffs)
              ..where((r) => r.id.equals(handoff.id))).getSingleOrNull();
        if (old != null && old.floorId != handoff.floorId)
          throw StateError('Cannot move a handoff between floors.');
        final now = DateTime.now().toUtc();
        await database
            .into(database.floorRoutingHandoffs)
            .insertOnConflictUpdate(
              FloorRoutingHandoffsCompanion(
                id: Value(handoff.id),
                floorId: Value(handoff.floorId),
                name: Value(handoff.name.trim()),
                fromRunId: Value(handoff.fromRunId),
                toRunId: Value(handoff.toRunId),
                fromSignature: Value(handoff.fromSignature),
                toSignature: Value(handoff.toSignature),
                revision: Value((old?.revision ?? 0) + 1),
                createdAt: Value(old?.createdAt ?? now),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      });
  @override
  Future<void> deletePanel(String id) => database.transaction(() async {
    final row =
        await (database.select(database.floorRoutingPanels)
          ..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final now = DateTime.now().toUtc();
    await (database.update(database.floorRoutingPanels)
      ..where((r) => r.id.equals(id))).write(
      FloorRoutingPanelsCompanion(
        revision: Value(row.revision + 1),
        updatedAt: Value(now),
        deletedAt: Value(now),
        originDeviceId: Value(originDeviceId),
      ),
    );
  });
  @override
  Future<void> deleteHandoff(String id) => database.transaction(() async {
    final row =
        await (database.select(database.floorRoutingHandoffs)
          ..where((r) => r.id.equals(id))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final now = DateTime.now().toUtc();
    await (database.update(database.floorRoutingHandoffs)
      ..where((r) => r.id.equals(id))).write(
      FloorRoutingHandoffsCompanion(
        revision: Value(row.revision + 1),
        updatedAt: Value(now),
        deletedAt: Value(now),
        originDeviceId: Value(originDeviceId),
      ),
    );
  });
}
