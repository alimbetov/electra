import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../../application/elv_pathway_command.dart';
import '../../application/elv_pathway_repository.dart';
import '../database/app_database.dart';
import 'drift_elv_runtime_support.dart';

final class DriftElvPathwayRepository implements ElvPathwayRepository {
  DriftElvPathwayRepository(this.database, {required this.originDeviceId});

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<List<PathwayContext>> loadContexts(String projectId) async {
    final rows =
        await (database.select(database.pathwayContexts)
              ..where(
                (row) =>
                    row.projectId.equals(projectId) & row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    return rows.map(_decodeRow).toList(growable: false);
  }

  @override
  Future<PathwayContext?> findContext(
    String projectId,
    String contextId,
  ) async {
    final row =
        await (database.select(database.pathwayContexts)..where(
              (candidate) =>
                  candidate.projectId.equals(projectId) &
                  candidate.id.equals(contextId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _decodeRow(row);
  }

  @override
  Future<ElvCommandResult<PathwayContext>> create(
    CreatePathwayContextCommand command,
  ) => database.transaction(() async {
    const type = 'CREATE_PATHWAY_CONTEXT';
    const schema = 'electra.command.create-pathway-context.v1';
    final payload = _encode(command.context);
    final replay = await replayElvRuntimeCommand<PathwayContext>(
      database: database,
      projectId: command.context.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      decode: _decodeMap,
    );
    if (replay != null) return replay;
    final contexts = {
      for (final item in await loadContexts(command.context.projectId))
        item.id: item,
    };
    if (contexts.containsKey(command.context.id)) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_EXISTS',
        ElvFailureCategory.validation,
        entityType: 'PathwayContext',
        entityId: command.context.id,
      );
    }
    final errors = PathwayContextValidator.validate(
      context: command.context,
      projectContexts: contexts,
    );
    if (errors.isNotEmpty) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    }
    final now = DateTime.now().toUtc();
    final host = _encodeHost(command.context.host);
    await database
        .into(database.pathwayContexts)
        .insert(
          PathwayContextsCompanion.insert(
            id: command.context.id,
            projectId: command.context.projectId,
            kind: command.context.kind.name.toUpperCase(),
            hostType: host.$1,
            hostJson: jsonEncode(host.$2),
            parentContextId: Value(command.context.parentContextId),
            provenance: Value(command.context.provenance),
            lifecycleState: command.context.lifecycleState.name.toUpperCase(),
            revision: Value(command.context.revision),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
    await recordElvRuntimeSuccess(
      database: database,
      projectId: command.context.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      result: payload,
      originDeviceId: originDeviceId,
    );
    return ElvCommandSuccess(command.context);
  });

  @override
  Future<ElvCommandResult<PathwayContext>> update(
    UpdatePathwayContextCommand command,
  ) => database.transaction(() async {
    final current = await findContext(
      command.context.projectId,
      command.context.id,
    );
    if (current == null) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_NOT_FOUND',
        ElvFailureCategory.notFound,
        entityType: 'PathwayContext',
        entityId: command.context.id,
      );
    }
    if (current.revision != command.expectedRevision) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedRevision,
        actualRevision: current.revision,
      );
    }
    final expectedImpact = pathwayImpactFingerprint(current);
    if (command.expectedImpactFingerprint != expectedImpact) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_IMPACT_CHANGED',
        ElvFailureCategory.dependencyImpact,
        details: {
          'expected': command.expectedImpactFingerprint,
          'actual': expectedImpact,
        },
      );
    }
    final next = PathwayContext(
      id: command.context.id,
      projectId: command.context.projectId,
      kind: command.context.kind,
      host: command.context.host,
      parentContextId: command.context.parentContextId,
      provenance: command.context.provenance,
      lifecycleState: command.context.lifecycleState,
      revision: current.revision + 1,
    );
    final contexts = {
      for (final item in await loadContexts(next.projectId)) item.id: item,
    }..remove(next.id);
    final errors = PathwayContextValidator.validate(
      context: next,
      projectContexts: contexts,
    );
    if (errors.isNotEmpty) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    }
    final host = _encodeHost(next.host);
    await (database.update(
      database.pathwayContexts,
    )..where((row) => row.id.equals(next.id))).write(
      PathwayContextsCompanion(
        kind: Value(next.kind.name.toUpperCase()),
        hostType: Value(host.$1),
        hostJson: Value(jsonEncode(host.$2)),
        parentContextId: Value(next.parentContextId),
        provenance: Value(next.provenance),
        lifecycleState: Value(next.lifecycleState.name.toUpperCase()),
        revision: Value(next.revision),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return ElvCommandSuccess(next);
  });

  @override
  Future<ElvCommandResult<void>> archive(
    ArchivePathwayContextCommand command,
  ) => database.transaction(() async {
    final current = await findContext(command.projectId, command.contextId);
    if (current == null) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    }
    if (current.revision != command.expectedRevision) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedRevision,
        actualRevision: current.revision,
      );
    }
    final activeCarrier =
        await (database.select(database.physicalCarriers)..where(
              (row) =>
                  row.pathwayContextId.equals(command.contextId) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (activeCarrier != null) {
      return elvRuntimeFailure(
        'ELV_PATHWAY_CONTEXT_IN_USE',
        ElvFailureCategory.referenceIntegrity,
        entityId: command.contextId,
      );
    }
    await (database.update(
      database.pathwayContexts,
    )..where((row) => row.id.equals(command.contextId))).write(
      PathwayContextsCompanion(
        lifecycleState: const Value('ARCHIVED'),
        revision: Value(current.revision + 1),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return const ElvCommandSuccess<void>(null);
  });
}

String pathwayImpactFingerprint(PathwayContext context) =>
    elvRuntimeFingerprint('electra.pathway-impact.v1', _encode(context));

Map<String, Object?> _encode(PathwayContext context) {
  final host = _encodeHost(context.host);
  return {
    'id': context.id,
    'projectId': context.projectId,
    'kind': context.kind.name,
    'hostType': host.$1,
    'host': host.$2,
    'parentContextId': context.parentContextId,
    'provenance': context.provenance,
    'lifecycleState': context.lifecycleState.name,
    'revision': context.revision,
  };
}

(String, Map<String, Object?>) _encodeHost(PathwayContextHost host) =>
    switch (host) {
      RoomHost(:final roomId) => ('ROOM', {'roomId': roomId}),
      FloorHost(:final floorId) => ('FLOOR', {'floorId': floorId}),
      SurfaceVoidHost(:final floorId, :final spatialFeatureId) => (
        'SURFACE_VOID',
        {'floorId': floorId, 'spatialFeatureId': spatialFeatureId},
      ),
      VerticalHost(
        :final fromFloorId,
        :final toFloorId,
        :final spatialFeatureId,
      ) =>
        (
          'VERTICAL',
          {
            'fromFloorId': fromFloorId,
            'toFloorId': toFloorId,
            'spatialFeatureId': spatialFeatureId,
          },
        ),
      ProjectHost(:final projectId) => ('PROJECT', {'projectId': projectId}),
    };

PathwayContextHost _decodeHost(String type, Map<String, dynamic> map) =>
    switch (type) {
      'ROOM' => RoomHost(map['roomId'] as String),
      'FLOOR' => FloorHost(map['floorId'] as String),
      'SURFACE_VOID' => SurfaceVoidHost(
        floorId: map['floorId'] as String,
        spatialFeatureId: map['spatialFeatureId'] as String,
      ),
      'VERTICAL' => VerticalHost(
        fromFloorId: map['fromFloorId'] as String,
        toFloorId: map['toFloorId'] as String,
        spatialFeatureId: map['spatialFeatureId'] as String?,
      ),
      'PROJECT' => ProjectHost(map['projectId'] as String),
      _ => throw StateError('Unknown pathway host type: $type'),
    };

PathwayContext _decodeMap(Map<String, dynamic> map) => PathwayContext(
  id: map['id'] as String,
  projectId: map['projectId'] as String,
  kind: PathwayContextKind.values.byName(map['kind'] as String),
  host: _decodeHost(
    map['hostType'] as String,
    (map['host'] as Map).cast<String, dynamic>(),
  ),
  parentContextId: map['parentContextId'] as String?,
  provenance: map['provenance'] as String?,
  lifecycleState: PathwayContextLifecycleState.values.byName(
    map['lifecycleState'] as String,
  ),
  revision: map['revision'] as int,
);

PathwayContext _decodeRow(PathwayContextRow row) => PathwayContext(
  id: row.id,
  projectId: row.projectId,
  kind: PathwayContextKind.values.byName(row.kind.toLowerCase()),
  host: _decodeHost(
    row.hostType,
    (jsonDecode(row.hostJson) as Map).cast<String, dynamic>(),
  ),
  parentContextId: row.parentContextId,
  provenance: row.provenance,
  lifecycleState: PathwayContextLifecycleState.values.byName(
    row.lifecycleState.toLowerCase(),
  ),
  revision: row.revision,
);
