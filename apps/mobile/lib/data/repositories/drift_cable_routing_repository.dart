import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/cable_routing_repository.dart';
import '../../application/geometry_repository.dart';
import '../database/app_database.dart';
import 'drift_geometry_repository.dart';

final class DriftCableRoutingRepository implements CableRoutingRepository {
  DriftCableRoutingRepository(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;

  @override
  Stream<RoomRoutingSnapshot> watchRoomRouting(String roomId) => database
      .customSelect(
        '''
    WITH scope AS (SELECT ? AS room_id)
    SELECT 'room' AS kind, id, revision FROM rooms WHERE id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'route', id, revision FROM cable_routes WHERE room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'node', n.id, n.revision FROM cable_route_nodes n JOIN cable_routes r ON r.id = n.route_id WHERE r.room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'segment', n.id, n.revision FROM cable_route_segments n JOIN cable_routes r ON r.id = n.route_id WHERE r.room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'run', id, revision FROM cable_runs WHERE room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'channel', id, revision FROM physical_channels WHERE room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'circuit', id, revision FROM electrical_circuits WHERE room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'patch', id, revision FROM surface_patches WHERE room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'edge', e.id, e.revision FROM surface_edges e JOIN surface_patches p ON p.id = e.patch_id WHERE p.room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'adjacency', a.id, a.revision FROM surface_adjacencies a JOIN surface_patches p ON p.id = a.from_patch_id WHERE p.room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'opening', o.id, o.revision FROM openings o JOIN surface_patches p ON p.id = o.host_surface_patch_id WHERE p.room_id = (SELECT room_id FROM scope)
    UNION ALL SELECT 'feature', f.id, f.revision FROM spatial_features f JOIN surface_patches p ON p.id = f.host_surface_patch_id WHERE p.room_id = (SELECT room_id FROM scope)
    ORDER BY kind, id
  ''',
        variables: [Variable.withString(roomId)],
        readsFrom: {
          database.rooms,
          database.cableRoutes,
          database.cableRouteNodes,
          database.cableRouteSegments,
          database.cableRuns,
          database.physicalChannels,
          database.electricalCircuits,
          database.surfacePatches,
          database.surfaceEdges,
          database.surfaceAdjacencies,
          database.openings,
          database.spatialFeatures,
        },
      )
      .watch()
      .asyncMap((_) => loadRoomRouting(roomId));

  @override
  Future<RoomRoutingSnapshot> loadRoomRouting(String roomId) =>
      database.transaction(() async {
        final room =
            await (database.select(database.rooms)..where(
              (row) => row.id.equals(roomId) & row.deletedAt.isNull(),
            )).getSingleOrNull();
        if (room == null)
          return RoomRoutingSnapshot(
            geometry: RoomGeometrySnapshot(roomId: roomId),
          );
        final geometry = await DriftGeometryRepository(
          database,
          originDeviceId: originDeviceId,
        ).loadRoomGeometry(roomId);
        final routeRows =
            await (database.select(database.cableRoutes)
                  ..where(
                    (row) => row.roomId.equals(roomId) & row.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.name),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        final routeIds = routeRows.map((row) => row.id).toList();
        final nodeRows =
            routeIds.isEmpty
                ? <CableRouteNodeRow>[]
                : await (database.select(database.cableRouteNodes)
                      ..where(
                        (row) =>
                            row.routeId.isIn(routeIds) & row.deletedAt.isNull(),
                      )
                      ..orderBy([
                        (row) => OrderingTerm.asc(row.sequence),
                        (row) => OrderingTerm.asc(row.id),
                      ]))
                    .get();
        final segmentRows =
            routeIds.isEmpty
                ? <CableRouteSegmentRow>[]
                : await (database.select(database.cableRouteSegments)
                      ..where(
                        (row) =>
                            row.routeId.isIn(routeIds) & row.deletedAt.isNull(),
                      )
                      ..orderBy([
                        (row) => OrderingTerm.asc(row.sequence),
                        (row) => OrderingTerm.asc(row.id),
                      ]))
                    .get();
        final channels =
            await (database.select(database.physicalChannels)
                  ..where(
                    (row) => row.roomId.equals(roomId) & row.deletedAt.isNull(),
                  )
                  ..orderBy([(row) => OrderingTerm.asc(row.name)]))
                .get();
        final runs =
            await (database.select(database.cableRuns)
                  ..where(
                    (row) => row.roomId.equals(roomId) & row.deletedAt.isNull(),
                  )
                  ..orderBy([
                    (row) => OrderingTerm.asc(row.name),
                    (row) => OrderingTerm.asc(row.id),
                  ]))
                .get();
        final circuits =
            await (database.select(database.electricalCircuits)..where(
              (row) => row.roomId.equals(roomId) & row.deletedAt.isNull(),
            )).get();
        return RoomRoutingSnapshot(
          geometry: geometry,
          routes: routeRows
              .map(
                (row) => CableRoute(
                  id: row.id,
                  roomId: row.roomId,
                  name: row.name,
                  nodes: nodeRows
                      .where((node) => node.routeId == row.id)
                      .map(_node),
                  segments: segmentRows
                      .where((segment) => segment.routeId == row.id)
                      .map(_segment),
                ),
              )
              .toList(growable: false),
          channels: channels
              .map(
                (row) => PhysicalChannel(
                  id: row.id,
                  roomId: row.roomId,
                  name: row.name,
                  kind: PhysicalChannelKind.values.byName(row.kind),
                ),
              )
              .toList(growable: false),
          runs: runs
              .map(
                (row) => CableRun(
                  id: row.id,
                  roomId: row.roomId,
                  name: row.name,
                  circuitId: row.circuitId,
                  routeId: row.routeId,
                  reservePercent: row.reservePercent,
                  terminationAllowanceMm: row.terminationAllowanceMm,
                ),
              )
              .toList(growable: false),
          activeCircuitIds: circuits.map((row) => row.id).toSet(),
        );
      });

  static RouteNode _node(CableRouteNodeRow row) {
    if ((row.otherPatchId == null) != (row.otherLocalXmm == null) ||
        (row.otherPatchId == null) != (row.otherLocalYmm == null))
      throw StateError('Incomplete saved transition anchor: ${row.id}');
    return RouteNode(
      id: row.id,
      kind: RouteNodeKind.values.byName(row.kind),
      worldPosition: Point3Mm(row.worldXmm, row.worldYmm, row.worldZmm),
      anchor: SurfaceRouteAnchor(
        patchId: row.patchId,
        localPosition: Point2Mm(row.localXmm, row.localYmm),
      ),
      otherAnchor:
          row.otherPatchId == null
              ? null
              : SurfaceRouteAnchor(
                patchId: row.otherPatchId!,
                localPosition: Point2Mm(row.otherLocalXmm!, row.otherLocalYmm!),
              ),
      adjacencyId: row.adjacencyId,
    );
  }

  static RouteSegment _segment(CableRouteSegmentRow row) => RouteSegment(
    id: row.id,
    fromNodeId: row.fromNodeId,
    toNodeId: row.toNodeId,
    surfacePatchId: row.surfacePatchId,
    layingMethod: LayingMethod.values.byName(row.layingMethod),
    physicalChannelId: row.physicalChannelId,
  );

  @override
  Future<void> saveChannel(PhysicalChannel channel) async {
    if ([
      channel.id,
      channel.roomId,
      channel.name,
    ].any((value) => value.trim().isEmpty))
      throw ArgumentError('Channel id, room and name are required.');
    await database.transaction(() async {
      final room =
          await (database.select(database.rooms)..where(
            (row) => row.id.equals(channel.roomId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (room == null) throw StateError('Channel room is not active.');
      final existing =
          await (database.select(database.physicalChannels)
            ..where((row) => row.id.equals(channel.id))).getSingleOrNull();
      if (existing != null && existing.roomId != channel.roomId)
        throw StateError('Cannot move a channel between rooms.');
      final now = DateTime.now().toUtc();
      await database
          .into(database.physicalChannels)
          .insertOnConflictUpdate(
            PhysicalChannelsCompanion(
              id: Value(channel.id),
              roomId: Value(channel.roomId),
              name: Value(channel.name.trim()),
              kind: Value(channel.kind.name),
              revision: Value((existing?.revision ?? 0) + 1),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
    });
  }

  @override
  Future<void> saveRouteWithRun({
    required CableRoute route,
    required CableRun run,
  }) async {
    if (run.validate().isNotEmpty ||
        run.routeId != route.id ||
        run.roomId != route.roomId)
      throw ArgumentError(
        'CableRun must have valid allowances and reference this route in the same room.',
      );
    await database.transaction(() async {
      final snapshot = await loadRoomRouting(route.roomId);
      if (!snapshot.activeCircuitIds.contains(run.circuitId))
        throw StateError('Choose an active circuit in the route room.');
      final calculation = snapshot.calculate(route);
      if (!calculation.ready || calculation.cableLengthMm(run) == null)
        throw StateError(
          'Invalid cable route: ${calculation.issues.map((issue) => issue.message).join(' ')}',
        );
      final existing =
          await (database.select(database.cableRoutes)
            ..where((row) => row.id.equals(route.id))).getSingleOrNull();
      if (existing != null && existing.roomId != route.roomId)
        throw StateError('Cannot move a route between rooms.');
      final existingRun =
          await (database.select(database.cableRuns)
            ..where((row) => row.id.equals(run.id))).getSingleOrNull();
      if (existingRun != null && existingRun.roomId != run.roomId)
        throw StateError('Cannot move a CableRun between rooms.');
      final oldNodes =
          await (database.select(database.cableRouteNodes)
            ..where((row) => row.routeId.equals(route.id))).get();
      final oldSegments =
          await (database.select(database.cableRouteSegments)
            ..where((row) => row.routeId.equals(route.id))).get();
      final ownedNodes = {for (final row in oldNodes) row.id: row};
      final ownedSegments = {for (final row in oldSegments) row.id: row};
      final nodeIds = route.nodes.map((node) => node.id).toSet();
      final segmentIds = route.segments.map((segment) => segment.id).toSet();
      final collidingNodes =
          await (database.select(database.cableRouteNodes)..where(
            (row) => row.id.isIn(nodeIds) & row.routeId.equals(route.id).not(),
          )).get();
      final collidingSegments =
          await (database.select(database.cableRouteSegments)..where(
            (row) =>
                row.id.isIn(segmentIds) & row.routeId.equals(route.id).not(),
          )).get();
      if (collidingNodes.isNotEmpty || collidingSegments.isNotEmpty)
        throw StateError(
          'Node and segment IDs cannot be reused from another route.',
        );
      final now = DateTime.now().toUtc();
      await database
          .into(database.cableRoutes)
          .insertOnConflictUpdate(
            CableRoutesCompanion(
              id: Value(route.id),
              roomId: Value(route.roomId),
              name: Value(route.name.trim()),
              revision: Value((existing?.revision ?? 0) + 1),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
      for (final row in oldSegments.where(
        (row) => row.deletedAt == null && !segmentIds.contains(row.id),
      )) {
        await (database.update(database.cableRouteSegments)
          ..where((item) => item.id.equals(row.id))).write(
          CableRouteSegmentsCompanion(
            revision: Value(row.revision + 1),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
      }
      for (final row in oldNodes.where(
        (row) => row.deletedAt == null && !nodeIds.contains(row.id),
      )) {
        await (database.update(database.cableRouteNodes)
          ..where((item) => item.id.equals(row.id))).write(
          CableRouteNodesCompanion(
            revision: Value(row.revision + 1),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
      }
      for (var i = 0; i < route.nodes.length; i++) {
        final node = route.nodes[i];
        final row = ownedNodes[node.id];
        await database
            .into(database.cableRouteNodes)
            .insertOnConflictUpdate(
              CableRouteNodesCompanion(
                id: Value(node.id),
                routeId: Value(route.id),
                sequence: Value(i),
                kind: Value(node.kind.name),
                patchId: Value(node.anchor.patchId),
                localXmm: Value(node.anchor.localPosition.xMm),
                localYmm: Value(node.anchor.localPosition.yMm),
                worldXmm: Value(node.worldPosition.xMm),
                worldYmm: Value(node.worldPosition.yMm),
                worldZmm: Value(node.worldPosition.zMm),
                otherPatchId: Value(node.otherAnchor?.patchId),
                otherLocalXmm: Value(node.otherAnchor?.localPosition.xMm),
                otherLocalYmm: Value(node.otherAnchor?.localPosition.yMm),
                adjacencyId: Value(node.adjacencyId),
                revision: Value((row?.revision ?? 0) + 1),
                createdAt: Value(row?.createdAt ?? now),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      }
      for (var i = 0; i < route.segments.length; i++) {
        final segment = route.segments[i];
        final row = ownedSegments[segment.id];
        await database
            .into(database.cableRouteSegments)
            .insertOnConflictUpdate(
              CableRouteSegmentsCompanion(
                id: Value(segment.id),
                routeId: Value(route.id),
                sequence: Value(i),
                fromNodeId: Value(segment.fromNodeId),
                toNodeId: Value(segment.toNodeId),
                surfacePatchId: Value(segment.surfacePatchId),
                layingMethod: Value(segment.layingMethod.name),
                physicalChannelId: Value(segment.physicalChannelId),
                revision: Value((row?.revision ?? 0) + 1),
                createdAt: Value(row?.createdAt ?? now),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      }
      await database
          .into(database.cableRuns)
          .insertOnConflictUpdate(
            CableRunsCompanion(
              id: Value(run.id),
              roomId: Value(run.roomId),
              name: Value(run.name.trim()),
              circuitId: Value(run.circuitId),
              routeId: Value(run.routeId),
              reservePercent: Value(run.reservePercent),
              terminationAllowanceMm: Value(run.terminationAllowanceMm),
              revision: Value((existingRun?.revision ?? 0) + 1),
              createdAt: Value(existingRun?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
    });
  }
}
