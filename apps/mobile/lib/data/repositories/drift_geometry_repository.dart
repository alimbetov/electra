import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/geometry_repository.dart';
import '../database/app_database.dart';
import '../database/geometry_codec.dart';

final class DriftGeometryRepository implements GeometryRepository {
  DriftGeometryRepository(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _clock;

  @override
  Stream<RoomGeometrySnapshot> watchRoomGeometry(String roomId) {
    return database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            database.surfacePatches,
            database.surfaceEdges,
            database.surfaceAdjacencies,
            database.openings,
            database.spatialFeatures,
          },
        )
        .watch()
        .asyncMap((_) => loadRoomGeometry(roomId));
  }

  @override
  Future<RoomGeometrySnapshot> loadRoomGeometry(String roomId) async {
    final patchQuery = database.select(database.surfacePatches)
      ..where((row) => row.roomId.equals(roomId) & row.deletedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    final patchRows = await patchQuery.get();
    final patchIds = patchRows.map((row) => row.id).toList(growable: false);

    if (patchIds.isEmpty) {
      return RoomGeometrySnapshot(roomId: roomId);
    }

    final edgeQuery = database.select(database.surfaceEdges)
      ..where(
        (row) => row.patchId.isIn(patchIds) & row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    final adjacencyQuery = database.select(database.surfaceAdjacencies)
      ..where(
        (row) => row.fromPatchId.isIn(patchIds) & row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    final openingQuery = database.select(database.openings)
      ..where(
        (row) =>
            row.hostSurfacePatchId.isIn(patchIds) & row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    final featureQuery = database.select(database.spatialFeatures)
      ..where(
        (row) =>
            row.hostSurfacePatchId.isIn(patchIds) & row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.id)]);

    final edgeRows = await edgeQuery.get();
    final adjacencyRows = await adjacencyQuery.get();
    final openingRows = await openingQuery.get();
    final featureRows = await featureQuery.get();

    return RoomGeometrySnapshot(
      roomId: roomId,
      patches: patchRows.map(_patchFromRow).toList(growable: false),
      edges: edgeRows.map(_edgeFromRow).toList(growable: false),
      adjacencies:
          adjacencyRows.map(_adjacencyFromRow).toList(growable: false),
      openings: openingRows.map(_openingFromRow).toList(growable: false),
      features: featureRows.map(_featureFromRow).toList(growable: false),
    );
  }

  @override
  Future<void> replaceRoomGeometry(RoomGeometrySnapshot snapshot) async {
    if (snapshot.roomId.isEmpty) {
      throw ArgumentError.value(snapshot.roomId, 'roomId', 'Must be non-empty.');
    }
    if (snapshot.patches.any((patch) => patch.roomId != snapshot.roomId)) {
      throw ArgumentError('Every patch must belong to snapshot.roomId.');
    }
    final violations = snapshot.validate();
    if (violations.isNotEmpty) {
      throw StateError(
        'Invalid room geometry: ${violations.map((e) => e.code).join(', ')}',
      );
    }

    await database.transaction(() async {
      final room = await (database.select(database.rooms)
            ..where(
              (row) =>
                  row.id.equals(snapshot.roomId) & row.deletedAt.isNull(),
            ))
          .getSingleOrNull();
      if (room == null) {
        throw StateError('Room ${snapshot.roomId} does not exist.');
      }

      final existingPatchRows = await (database.select(database.surfacePatches)
            ..where((row) => row.roomId.equals(snapshot.roomId)))
          .get();
      final existingPatchIds =
          existingPatchRows.map((row) => row.id).toList(growable: false);
      final now = _clock();

      if (existingPatchIds.isNotEmpty) {
        await (database.update(database.surfaceAdjacencies)
              ..where((row) => row.fromPatchId.isIn(existingPatchIds)))
            .write(SurfaceAdjacenciesCompanion(deletedAt: Value(now)));
        await (database.update(database.openings)
              ..where((row) => row.hostSurfacePatchId.isIn(existingPatchIds)))
            .write(OpeningsCompanion(deletedAt: Value(now)));
        await (database.update(database.spatialFeatures)
              ..where((row) => row.hostSurfacePatchId.isIn(existingPatchIds)))
            .write(SpatialFeaturesCompanion(deletedAt: Value(now)));
        await (database.update(database.surfaceEdges)
              ..where((row) => row.patchId.isIn(existingPatchIds)))
            .write(SurfaceEdgesCompanion(deletedAt: Value(now)));
        await (database.update(database.surfacePatches)
              ..where((row) => row.roomId.equals(snapshot.roomId)))
            .write(SurfacePatchesCompanion(deletedAt: Value(now)));
      }

      for (final patch in snapshot.patches) {
        await database.into(database.surfacePatches).insertOnConflictUpdate(
              _patchCompanion(patch, now),
            );
      }
      for (final edge in snapshot.edges) {
        await database.into(database.surfaceEdges).insertOnConflictUpdate(
              _edgeCompanion(edge, now),
            );
      }
      for (final opening in snapshot.openings) {
        await database.into(database.openings).insertOnConflictUpdate(
              _openingCompanion(opening, now),
            );
      }
      for (final feature in snapshot.features) {
        await database.into(database.spatialFeatures).insertOnConflictUpdate(
              _featureCompanion(feature, now),
            );
      }
      for (final adjacency in snapshot.adjacencies) {
        await database
            .into(database.surfaceAdjacencies)
            .insertOnConflictUpdate(_adjacencyCompanion(adjacency, now));
      }
    });
  }

  SurfacePatchesCompanion _patchCompanion(SurfacePatch patch, DateTime now) =>
      SurfacePatchesCompanion(
        id: Value(patch.id),
        roomId: Value(patch.roomId),
        surfaceId: Value(patch.surfaceId),
        originXmm: Value(patch.frame.origin.xMm),
        originYmm: Value(patch.frame.origin.yMm),
        originZmm: Value(patch.frame.origin.zMm),
        uAxisX: Value(patch.frame.uAxis.x),
        uAxisY: Value(patch.frame.uAxis.y),
        uAxisZ: Value(patch.frame.uAxis.z),
        vAxisX: Value(patch.frame.vAxis.x),
        vAxisY: Value(patch.frame.vAxis.y),
        vAxisZ: Value(patch.frame.vAxis.z),
        orientation: Value(patch.orientation.name),
        boundaryJson: Value(GeometryCodec.encodePolygon(patch.boundary)),
        revision: const Value(1),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        originDeviceId: Value(originDeviceId),
      );

  SurfaceEdgesCompanion _edgeCompanion(SurfaceEdge edge, DateTime now) =>
      SurfaceEdgesCompanion(
        id: Value(edge.id),
        patchId: Value(edge.patchId),
        startXmm: Value(edge.start.xMm),
        startYmm: Value(edge.start.yMm),
        endXmm: Value(edge.end.xMm),
        endYmm: Value(edge.end.yMm),
        kind: Value(edge.kind.name),
        revision: const Value(1),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        originDeviceId: Value(originDeviceId),
      );

  SurfaceAdjacenciesCompanion _adjacencyCompanion(
    SurfaceAdjacency adjacency,
    DateTime now,
  ) =>
      SurfaceAdjacenciesCompanion(
        id: Value(adjacency.id),
        fromPatchId: Value(adjacency.fromPatchId),
        fromEdgeId: Value(adjacency.fromEdgeId),
        toPatchId: Value(adjacency.toPatchId),
        toEdgeId: Value(adjacency.toEdgeId),
        revision: const Value(1),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        originDeviceId: Value(originDeviceId),
      );

  OpeningsCompanion _openingCompanion(Opening opening, DateTime now) =>
      OpeningsCompanion(
        id: Value(opening.id),
        hostSurfacePatchId: Value(opening.hostSurfacePatchId),
        boundaryJson: Value(GeometryCodec.encodePolygon(opening.boundary)),
        openingType: Value(opening.type.name),
        depthMm: Value(opening.depthMm),
        sillHeightMm: Value(opening.sillHeightMm),
        headHeightMm: Value(opening.headHeightMm),
        revision: const Value(1),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        originDeviceId: Value(originDeviceId),
      );

  SpatialFeaturesCompanion _featureCompanion(
    SpatialFeature feature,
    DateTime now,
  ) =>
      SpatialFeaturesCompanion(
        id: Value(feature.id),
        hostSurfacePatchId: Value(feature.hostSurfacePatchId),
        featureType: Value(feature.type.name),
        footprintJson: Value(GeometryCodec.encodePolygon(feature.footprint)),
        depthMm: Value(feature.depthMm),
        elevationMm: Value(feature.elevationMm),
        revision: const Value(1),
        createdAt: Value(now),
        updatedAt: Value(now),
        deletedAt: const Value(null),
        originDeviceId: Value(originDeviceId),
      );

  SurfacePatch _patchFromRow(SurfacePatchRow row) => SurfacePatch(
        id: row.id,
        roomId: row.roomId,
        surfaceId: row.surfaceId,
        frame: LocalCoordinateFrame(
          origin: Point3Mm(row.originXmm, row.originYmm, row.originZmm),
          uAxis: Vector3D(row.uAxisX, row.uAxisY, row.uAxisZ),
          vAxis: Vector3D(row.vAxisX, row.vAxisY, row.vAxisZ),
        ),
        boundary: GeometryCodec.decodePolygon(row.boundaryJson),
        orientation: SurfaceOrientation.values.byName(row.orientation),
      );

  SurfaceEdge _edgeFromRow(SurfaceEdgeRow row) => SurfaceEdge(
        id: row.id,
        patchId: row.patchId,
        start: Point2Mm(row.startXmm, row.startYmm),
        end: Point2Mm(row.endXmm, row.endYmm),
        kind: SurfaceEdgeKind.values.byName(row.kind),
      );

  SurfaceAdjacency _adjacencyFromRow(SurfaceAdjacencyRow row) =>
      SurfaceAdjacency(
        id: row.id,
        fromPatchId: row.fromPatchId,
        fromEdgeId: row.fromEdgeId,
        toPatchId: row.toPatchId,
        toEdgeId: row.toEdgeId,
      );

  Opening _openingFromRow(OpeningRow row) => Opening(
        id: row.id,
        hostSurfacePatchId: row.hostSurfacePatchId,
        boundary: GeometryCodec.decodePolygon(row.boundaryJson),
        type: OpeningType.values.byName(row.openingType),
        depthMm: row.depthMm,
        sillHeightMm: row.sillHeightMm,
        headHeightMm: row.headHeightMm,
      );

  SpatialFeature _featureFromRow(SpatialFeatureRow row) => SpatialFeature(
        id: row.id,
        hostSurfacePatchId: row.hostSurfacePatchId,
        type: SpatialFeatureType.values.byName(row.featureType),
        footprint: GeometryCodec.decodePolygon(row.footprintJson),
        depthMm: row.depthMm,
        elevationMm: row.elevationMm,
      );
}
