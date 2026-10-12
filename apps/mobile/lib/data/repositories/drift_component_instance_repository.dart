import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/component_instance_repository.dart';
import '../database/app_database.dart';
import '../database/geometry_codec.dart';

final class DriftComponentInstanceRepository
    implements ComponentInstanceRepository {
  DriftComponentInstanceRepository(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _clock;

  @override
  Stream<List<ComponentInstance>> watchRoomComponents(String roomId) {
    final query =
        database.select(database.componentInstances)
          ..where((row) => row.roomId.equals(roomId) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    return query.watch().map(
      (rows) => rows.map(_instanceFromRow).toList(growable: false),
    );
  }

  @override
  Future<List<ComponentInstance>> loadRoomComponents(String roomId) async {
    final query =
        database.select(database.componentInstances)
          ..where((row) => row.roomId.equals(roomId) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    final rows = await query.get();
    return rows.map(_instanceFromRow).toList(growable: false);
  }

  @override
  Future<void> saveComponent(ComponentInstance instance) async {
    await database.transaction(() async {
      final room =
          await (database.select(database.rooms)..where(
            (row) => row.id.equals(instance.roomId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (room == null) {
        throw StateError('Room ${instance.roomId} does not exist.');
      }

      final patchRow =
          await (database.select(database.surfacePatches)..where(
            (row) =>
                row.id.equals(instance.hostSurfacePatchId) &
                row.deletedAt.isNull(),
          )).getSingleOrNull();
      final violations = ComponentPlacementValidator.validate(
        instance: instance,
        patches: patchRow == null ? const [] : [_patchFromRow(patchRow)],
      );
      if (violations.isNotEmpty) {
        throw StateError(
          'Invalid component ${instance.id}: '
          '${violations.map((item) => item.code.name).join(', ')}',
        );
      }

      final existing =
          await (database.select(database.componentInstances)..where(
            (row) => row.id.equals(instance.id),
          )).getSingleOrNull();
      final now = _clock();
      await database.into(database.componentInstances).insertOnConflictUpdate(
            _companion(instance, now, existing: existing),
          );
    });
  }

  @override
  Future<void> replaceRoomComponents({
    required String roomId,
    required Iterable<ComponentInstance> instances,
  }) async {
    if (roomId.isEmpty) {
      throw ArgumentError.value(roomId, 'roomId', 'Must be non-empty.');
    }
    final next = instances.toList(growable: false);
    if (next.any((instance) => instance.roomId != roomId)) {
      throw ArgumentError('Every component instance must belong to roomId.');
    }
    final duplicateIds = <String>{};
    final seenIds = <String>{};
    for (final instance in next) {
      if (!seenIds.add(instance.id)) duplicateIds.add(instance.id);
    }
    if (duplicateIds.isNotEmpty) {
      throw StateError('Duplicate component instance ids: $duplicateIds');
    }

    await database.transaction(() async {
      final room =
          await (database.select(database.rooms)..where(
            (row) => row.id.equals(roomId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (room == null) {
        throw StateError('Room $roomId does not exist.');
      }

      final patchRows =
          await (database.select(database.surfacePatches)..where(
            (row) => row.roomId.equals(roomId) & row.deletedAt.isNull(),
          )).get();
      final patches = patchRows.map(_patchFromRow).toList(growable: false);

      for (final instance in next) {
        final violations = ComponentPlacementValidator.validate(
          instance: instance,
          patches: patches,
        );
        if (violations.isNotEmpty) {
          throw StateError(
            'Invalid component ${instance.id}: '
            '${violations.map((item) => item.code.name).join(', ')}',
          );
        }
      }

      final existingRows =
          await (database.select(database.componentInstances)
            ..where((row) => row.roomId.equals(roomId))).get();
      final existingById = {for (final row in existingRows) row.id: row};
      final nextIds = next.map((instance) => instance.id).toSet();
      final now = _clock();

      for (final row in existingRows) {
        if (!nextIds.contains(row.id) && row.deletedAt == null) {
          await (database.update(database.componentInstances)
            ..where((item) => item.id.equals(row.id))).write(
            ComponentInstancesCompanion(
              revision: Value(row.revision + 1),
              updatedAt: Value(now),
              deletedAt: Value(now),
              originDeviceId: Value(originDeviceId),
            ),
          );
        }
      }

      for (final instance in next) {
        await database
            .into(database.componentInstances)
            .insertOnConflictUpdate(
              _companion(instance, now, existing: existingById[instance.id]),
            );
      }
    });
  }

  ComponentInstancesCompanion _companion(
    ComponentInstance instance,
    DateTime now, {
    ComponentInstanceRow? existing,
  }) => ComponentInstancesCompanion(
    id: Value(instance.id),
    definitionId: Value(instance.definitionId),
    definitionVersion: Value(instance.definitionVersion),
    roomId: Value(instance.roomId),
    hostSurfacePatchId: Value(instance.hostSurfacePatchId),
    localXmm: Value(instance.localPosition.xMm),
    localYmm: Value(instance.localPosition.yMm),
    rotationRadians: Value(instance.rotationRadians),
    displayNameOverride: Value(instance.displayNameOverride),
    metadataOverridesJson: Value(jsonEncode(instance.metadataOverrides)),
    revision: Value((existing?.revision ?? 0) + 1),
    createdAt: Value(existing?.createdAt ?? now),
    updatedAt: Value(now),
    deletedAt: const Value(null),
    originDeviceId: Value(originDeviceId),
  );

  ComponentInstance _instanceFromRow(ComponentInstanceRow row) =>
      ComponentInstance(
        id: row.id,
        definitionId: row.definitionId,
        definitionVersion: row.definitionVersion,
        roomId: row.roomId,
        hostSurfacePatchId: row.hostSurfacePatchId,
        localPosition: Point2Mm(row.localXmm, row.localYmm),
        rotationRadians: row.rotationRadians,
        displayNameOverride: row.displayNameOverride,
        metadataOverrides: Map<String, Object?>.from(
          jsonDecode(row.metadataOverridesJson) as Map<String, dynamic>,
        ),
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
}
