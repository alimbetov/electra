import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_cable_run_command.dart';
import '../../application/elv_cable_run_repository.dart';
import '../../application/elv_command_result.dart';
import '../../application/elv_failure_probe.dart';
import '../database/app_database.dart';
import 'drift_elv_runtime_support.dart';

final class DriftElvCableRunRepository implements ElvCableRunRepository {
  DriftElvCableRunRepository(
    this.database, {
    required this.originDeviceId,
    ElvFailureProbe? failureProbe,
    DateTime Function()? now,
  }) : failureProbe = failureProbe ?? const NoopElvFailureProbe(),
       _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final ElvFailureProbe failureProbe;
  final DateTime Function() _now;

  @override
  Future<List<CanonicalCableRun>> loadRuns(
    String projectId,
    String designRevisionId,
  ) async {
    final rows =
        await (database.select(database.canonicalCableRuns)..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.designRevisionId.equals(designRevisionId) &
                  row.deletedAt.isNull(),
            ))
            .get();
    return rows.map(_runFromRow).toList(growable: false);
  }

  @override
  Future<CanonicalCableRun?> findRun(
    String projectId,
    String designRevisionId,
    String cableRunId,
  ) async {
    final row =
        await (database.select(database.canonicalCableRuns)..where(
              (candidate) =>
                  candidate.projectId.equals(projectId) &
                  candidate.designRevisionId.equals(designRevisionId) &
                  candidate.id.equals(cableRunId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _runFromRow(row);
  }

  @override
  Future<List<CableRunTraversal>> loadTraversals(String cableRunId) async {
    final rows =
        await (database.select(database.cableRunTraversals)
              ..where(
                (row) =>
                    row.cableRunId.equals(cableRunId) & row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
            .get();
    return rows.map(_traversalFromRow).toList(growable: false);
  }

  @override
  Future<ElvCommandResult<CanonicalCableRun>> create(
    CreateCableRunCommand command,
  ) => database.transaction(() async {
    const type = 'CREATE_CABLE_RUN';
    const schema = 'electra.command.create-cable-run.v1';
    final payload = _createPayload(command);
    final replay = await replayElvRuntimeCommand<CanonicalCableRun>(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      decode: _runFromMap,
    );
    if (replay != null) return replay;
    final revision = await _workingRevision(
      command.projectId,
      command.designRevisionId,
    );
    if (revision == null) {
      return elvRuntimeFailure(
        'ELV_RUN_WORKING_REVISION_REQUIRED',
        ElvFailureCategory.lifecycle,
      );
    }
    final cable =
        await (database.select(database.elvCables)..where(
              (row) =>
                  row.projectId.equals(command.projectId) &
                  row.id.equals(command.cableId) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (cable == null) {
      return elvRuntimeFailure(
        'ELV_RUN_CABLE_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    }
    final allocation =
        await (database.select(database.cableAllocations)..where(
              (row) =>
                  row.projectId.equals(command.projectId) &
                  row.cableId.equals(command.cableId) &
                  row.lifecycleState.equals('ACTIVE') &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (allocation == null) {
      return elvRuntimeFailure(
        'ELV_RUN_ALLOCATION_REQUIRED',
        ElvFailureCategory.lifecycle,
      );
    }
    final chainErrors = validateTraversalChain(command.traversals);
    if (chainErrors.isNotEmpty) {
      return elvRuntimeFailure(
        'ELV_RUN_TRAVERSAL_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': chainErrors},
      );
    }
    if (!await _segmentsBelongToProject(
      command.projectId,
      command.traversals.map((item) => item.routeSegmentId),
    )) {
      return elvRuntimeFailure(
        'ELV_RUN_ROUTE_PROJECT_MISMATCH',
        ElvFailureCategory.projectIsolation,
      );
    }
    final run = CanonicalCableRun(
      id: command.cableRunId,
      projectId: command.projectId,
      cableId: command.cableId,
      designRevisionId: command.designRevisionId,
      state: CanonicalCableRunState.active,
      reservePercent: command.reservePercent,
      terminationAllowanceMm: command.terminationAllowanceMm,
      revision: 1,
    );
    final instant = _now();
    await database
        .into(database.canonicalCableRuns)
        .insert(
          CanonicalCableRunsCompanion.insert(
            id: run.id,
            projectId: run.projectId,
            cableId: run.cableId,
            designRevisionId: run.designRevisionId,
            lifecycleState: 'ACTIVE',
            reservePercent: Value(run.reservePercent),
            terminationAllowanceMm: Value(run.terminationAllowanceMm),
            createdAt: instant,
            updatedAt: instant,
            originDeviceId: originDeviceId,
          ),
        );
    await _insertTraversalChain(run.id, command.traversals, instant);
    await recordElvRuntimeSuccess(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      result: _runToMap(run),
      originDeviceId: originDeviceId,
      now: instant,
    );
    return ElvCommandSuccess(run);
  });

  @override
  Future<ElvCommandResult<CanonicalCableRun>> reroute(
    RerouteCableRunCommand command,
  ) => database.transaction(() async {
    const type = 'REROUTE_CABLE_RUN';
    const schema = 'electra.command.reroute-cable-run.v1';
    final payload = <String, Object?>{
      'projectId': command.projectId,
      'cableRunId': command.cableRunId,
      'expectedRevision': command.expectedRevision,
      'traversals': command.traversals.map(_traversalToMap).toList(),
    };
    final replay = await replayElvRuntimeCommand<CanonicalCableRun>(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      decode: _runFromMap,
    );
    if (replay != null) return replay;
    final row =
        await (database.select(database.canonicalCableRuns)..where(
              (candidate) =>
                  candidate.projectId.equals(command.projectId) &
                  candidate.id.equals(command.cableRunId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) {
      return elvRuntimeFailure(
        'ELV_RUN_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    }
    if (await _workingRevision(command.projectId, row.designRevisionId) ==
        null) {
      return elvRuntimeFailure(
        'ELV_RUN_WORKING_REVISION_REQUIRED',
        ElvFailureCategory.lifecycle,
      );
    }
    if (row.revision != command.expectedRevision) {
      return elvRuntimeFailure(
        'ELV_RUN_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedRevision,
        actualRevision: row.revision,
      );
    }
    final errors = validateTraversalChain(command.traversals);
    if (errors.isNotEmpty ||
        !await _segmentsBelongToProject(
          command.projectId,
          command.traversals.map((item) => item.routeSegmentId),
        )) {
      return elvRuntimeFailure(
        'ELV_RUN_TRAVERSAL_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    }
    await (database.delete(
      database.cableRunTraversals,
    )..where((item) => item.cableRunId.equals(row.id))).go();
    await failureProbe.hit(ElvFailurePoints.p3RerouteAfterDeleteOldChain);
    final instant = _now();
    await _insertTraversalChain(row.id, command.traversals, instant);
    await (database.update(
      database.canonicalCableRuns,
    )..where((candidate) => candidate.id.equals(row.id))).write(
      CanonicalCableRunsCompanion(
        revision: Value(row.revision + 1),
        updatedAt: Value(instant),
        originDeviceId: Value(originDeviceId),
      ),
    );
    final result = CanonicalCableRun(
      id: row.id,
      projectId: row.projectId,
      cableId: row.cableId,
      designRevisionId: row.designRevisionId,
      basedOnCableRunId: row.basedOnCableRunId,
      state: CanonicalCableRunState.values.byName(
        row.lifecycleState.toLowerCase(),
      ),
      reservePercent: row.reservePercent,
      terminationAllowanceMm: row.terminationAllowanceMm,
      revision: row.revision + 1,
    );
    await recordElvRuntimeSuccess(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      result: _runToMap(result),
      originDeviceId: originDeviceId,
      now: instant,
    );
    return ElvCommandSuccess(result);
  });

  @override
  Future<ElvCommandResult<CanonicalCableRun>> supersede(
    SupersedeCableRunCommand command,
  ) => _changeState(
    commandId: command.commandId,
    projectId: command.projectId,
    cableRunId: command.cableRunId,
    expectedRevision: command.expectedRevision,
    from: 'ACTIVE',
    to: 'SUPERSEDED',
    commandType: 'SUPERSEDE_CABLE_RUN',
  );

  @override
  Future<ElvCommandResult<CanonicalCableRun>> archive(
    ArchiveCableRunCommand command,
  ) => _changeState(
    commandId: command.commandId,
    projectId: command.projectId,
    cableRunId: command.cableRunId,
    expectedRevision: command.expectedRevision,
    from: 'SUPERSEDED',
    to: 'ARCHIVED',
    commandType: 'ARCHIVE_CABLE_RUN',
  );

  Future<ElvCommandResult<CanonicalCableRun>> _changeState({
    required String commandId,
    required String projectId,
    required String cableRunId,
    required int expectedRevision,
    required String from,
    required String to,
    required String commandType,
  }) => database.transaction(() async {
    final row =
        await (database.select(database.canonicalCableRuns)..where(
              (candidate) =>
                  candidate.projectId.equals(projectId) &
                  candidate.id.equals(cableRunId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) {
      return elvRuntimeFailure(
        'ELV_RUN_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    }
    if (row.lifecycleState != from) {
      return elvRuntimeFailure(
        'ELV_RUN_INVALID_TRANSITION',
        ElvFailureCategory.lifecycle,
      );
    }
    if (row.revision != expectedRevision) {
      return elvRuntimeFailure(
        'ELV_RUN_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: expectedRevision,
        actualRevision: row.revision,
      );
    }
    final instant = _now();
    await (database.update(
      database.canonicalCableRuns,
    )..where((candidate) => candidate.id.equals(row.id))).write(
      CanonicalCableRunsCompanion(
        lifecycleState: Value(to),
        revision: Value(row.revision + 1),
        updatedAt: Value(instant),
        originDeviceId: Value(originDeviceId),
      ),
    );
    final result = CanonicalCableRun(
      id: row.id,
      projectId: row.projectId,
      cableId: row.cableId,
      designRevisionId: row.designRevisionId,
      basedOnCableRunId: row.basedOnCableRunId,
      state: CanonicalCableRunState.values.byName(to.toLowerCase()),
      reservePercent: row.reservePercent,
      terminationAllowanceMm: row.terminationAllowanceMm,
      revision: row.revision + 1,
    );
    await recordElvRuntimeSuccess(
      database: database,
      projectId: projectId,
      commandId: commandId,
      commandType: commandType,
      schema: 'electra.command.${commandType.toLowerCase()}.v1',
      payload: {
        'projectId': projectId,
        'cableRunId': cableRunId,
        'expectedRevision': expectedRevision,
      },
      result: _runToMap(result),
      originDeviceId: originDeviceId,
      now: instant,
    );
    return ElvCommandSuccess(result);
  });

  Future<ProjectDesignRevisionRow?> _workingRevision(
    String projectId,
    String designRevisionId,
  ) =>
      (database.select(database.projectDesignRevisions)..where(
            (row) =>
                row.projectId.equals(projectId) &
                row.id.equals(designRevisionId) &
                row.state.equals('WORKING') &
                row.deletedAt.isNull(),
          ))
          .getSingleOrNull();

  Future<bool> _segmentsBelongToProject(
    String projectId,
    Iterable<String> segmentIds,
  ) async {
    for (final segmentId in segmentIds.toSet()) {
      final segment =
          await (database.select(database.cableRouteSegments)..where(
                (row) => row.id.equals(segmentId) & row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (segment == null) return false;
      final route =
          await (database.select(database.cableRoutes)..where(
                (row) =>
                    row.id.equals(segment.routeId) & row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (route == null) return false;
      final room =
          await (database.select(database.rooms)..where(
                (row) => row.id.equals(route.roomId) & row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (room == null) return false;
      final floor =
          await (database.select(database.floors)..where(
                (row) => row.id.equals(room.floorId) & row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (floor == null || floor.projectId != projectId) return false;
    }
    return true;
  }

  Future<void> _insertTraversalChain(
    String cableRunId,
    Iterable<CableRunTraversal> traversals,
    DateTime instant,
  ) async {
    final ordered = traversals.toList()
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final traversal in ordered) {
      await database
          .into(database.cableRunTraversals)
          .insert(
            CableRunTraversalsCompanion.insert(
              id: traversal.id,
              cableRunId: cableRunId,
              sequence: traversal.sequence,
              routeSegmentId: traversal.routeSegmentId,
              direction: traversal.direction.name.toUpperCase(),
              physicalCarrierId: Value(traversal.physicalCarrierId),
              carrierCompartmentId: Value(traversal.carrierCompartmentId),
              createdAt: instant,
              updatedAt: instant,
              originDeviceId: originDeviceId,
            ),
          );
    }
  }
}

Map<String, Object?> _createPayload(CreateCableRunCommand command) => {
  'projectId': command.projectId,
  'cableRunId': command.cableRunId,
  'cableId': command.cableId,
  'designRevisionId': command.designRevisionId,
  'reservePercent': command.reservePercent,
  'terminationAllowanceMm': command.terminationAllowanceMm,
  'traversals': command.traversals.map(_traversalToMap).toList(),
};

Map<String, Object?> _runToMap(CanonicalCableRun run) => {
  'id': run.id,
  'projectId': run.projectId,
  'cableId': run.cableId,
  'designRevisionId': run.designRevisionId,
  'basedOnCableRunId': run.basedOnCableRunId,
  'state': run.state.name,
  'reservePercent': run.reservePercent,
  'terminationAllowanceMm': run.terminationAllowanceMm,
  'revision': run.revision,
};

CanonicalCableRun _runFromMap(Map<String, dynamic> map) => CanonicalCableRun(
  id: map['id']! as String,
  projectId: map['projectId']! as String,
  cableId: map['cableId']! as String,
  designRevisionId: map['designRevisionId']! as String,
  basedOnCableRunId: map['basedOnCableRunId'] as String?,
  state: CanonicalCableRunState.values.byName(map['state']! as String),
  reservePercent: (map['reservePercent'] as num).toDouble(),
  terminationAllowanceMm: (map['terminationAllowanceMm'] as num).toInt(),
  revision: (map['revision'] as num).toInt(),
);

CanonicalCableRun _runFromRow(CanonicalCableRunRow row) => CanonicalCableRun(
  id: row.id,
  projectId: row.projectId,
  cableId: row.cableId,
  designRevisionId: row.designRevisionId,
  basedOnCableRunId: row.basedOnCableRunId,
  state: CanonicalCableRunState.values.byName(row.lifecycleState.toLowerCase()),
  reservePercent: row.reservePercent,
  terminationAllowanceMm: row.terminationAllowanceMm,
  revision: row.revision,
);

CableRunTraversal _traversalFromRow(CableRunTraversalRow row) =>
    CableRunTraversal(
      id: row.id,
      cableRunId: row.cableRunId,
      sequence: row.sequence,
      routeSegmentId: row.routeSegmentId,
      direction: CableTraversalDirection.values.byName(
        row.direction.toLowerCase(),
      ),
      physicalCarrierId: row.physicalCarrierId,
      carrierCompartmentId: row.carrierCompartmentId,
    );

Map<String, Object?> _traversalToMap(CableRunTraversal traversal) => {
  'id': traversal.id,
  'cableRunId': traversal.cableRunId,
  'sequence': traversal.sequence,
  'routeSegmentId': traversal.routeSegmentId,
  'direction': traversal.direction.name,
  'physicalCarrierId': traversal.physicalCarrierId,
  'carrierCompartmentId': traversal.carrierCompartmentId,
};
