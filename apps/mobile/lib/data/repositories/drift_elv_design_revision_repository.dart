import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../../application/elv_design_revision_command.dart';
import '../../application/elv_design_revision_repository.dart';
import '../../application/elv_failure_probe.dart';
import '../database/app_database.dart';
import 'drift_elv_runtime_support.dart';
import 'drift_power_publication_runtime.dart';
import 'drift_power_snapshot_facts.dart';
import 'elv5/drift_elv5_discipline_snapshot_store.dart';

final class DriftElvDesignRevisionRepository
    implements ElvDesignRevisionRepository {
  DriftElvDesignRevisionRepository(
    this.database, {
    required this.originDeviceId,
    ElvFailureProbe? failureProbe,
    DateTime Function()? now,
    DriftPowerPublicationRuntime? powerRuntime,
  }) : failureProbe = failureProbe ?? const NoopElvFailureProbe(),
       _now = now ?? (() => DateTime.now().toUtc()),
       powerRuntime =
           powerRuntime ??
           DriftPowerPublicationRuntime(
             database,
             originDeviceId: originDeviceId,
             now: now,
           );

  final AppDatabase database;
  final String originDeviceId;
  final ElvFailureProbe failureProbe;
  final DateTime Function() _now;
  final DriftPowerPublicationRuntime powerRuntime;

  @override
  Future<PhysicalDesignContext> context(String projectId) async {
    final rows =
        await (database.select(database.projectDesignRevisions)
              ..where(
                (row) =>
                    row.projectId.equals(projectId) & row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.sequence)]))
            .get();
    final working = rows.where((row) => row.state == 'WORKING').firstOrNull;
    final frozen = rows.where((row) => row.state == 'FROZEN').firstOrNull;
    return PhysicalDesignContext(
      projectId: projectId,
      workingDesignRevisionId: working?.id,
      latestFrozenRevisionId: frozen?.id,
      editingAllowed: working != null,
    );
  }

  @override
  Future<ElvCommandResult<ProjectDesignRevision>> bootstrap(
    BootstrapProjectDesignRevisionCommand command,
  ) => database.transaction(() async {
    const type = 'BOOTSTRAP_PROJECT_DESIGN_REVISION';
    const schema = 'electra.command.bootstrap-design-revision.v1';
    final payload = <String, Object?>{
      'projectId': command.projectId,
      'revisionId': command.revisionId,
      'code': command.code,
    };
    final replay = await replayElvRuntimeCommand<ProjectDesignRevision>(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      decode: _revisionFromMap,
    );
    if (replay != null) return replay;
    if ((await context(command.projectId)).workingDesignRevisionId != null) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_WORKING_EXISTS',
        ElvFailureCategory.lifecycle,
      );
    }
    final project =
        await (database.select(database.projects)..where(
          (row) => row.id.equals(command.projectId) & row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (project == null) {
      return elvRuntimeFailure(
        'ELV_PROJECT_NOT_FOUND',
        ElvFailureCategory.notFound,
        entityType: 'Project',
        entityId: command.projectId,
      );
    }
    final revision = ProjectDesignRevision(
      id: command.revisionId,
      projectId: command.projectId,
      code: command.code.trim(),
      sequence: 1,
      state: ProjectDesignRevisionState.working,
      revision: 1,
    );
    final errors = revision.validate();
    if (errors.isNotEmpty) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_INVALID',
        ElvFailureCategory.validation,
        details: {'errors': errors},
      );
    }
    final instant = _now();
    await database
        .into(database.projectDesignRevisions)
        .insert(
          ProjectDesignRevisionsCompanion.insert(
            id: revision.id,
            projectId: revision.projectId,
            code: revision.code,
            sequence: revision.sequence,
            state: 'WORKING',
            createdAt: instant,
            updatedAt: instant,
            originDeviceId: originDeviceId,
          ),
        );
    await recordElvRuntimeSuccess(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      result: _revisionToMap(revision),
      originDeviceId: originDeviceId,
      now: instant,
    );
    return ElvCommandSuccess(revision);
  });

  @override
  Future<ElvCommandResult<ProjectDesignRevision>> freeze(
    FreezeProjectDesignRevisionCommand command,
  ) => database.transaction(() async {
    const type = 'FREEZE_PROJECT_DESIGN_REVISION';
    const schema = 'electra.command.freeze-design-revision.v1';
    final payload = <String, Object?>{
      'projectId': command.projectId,
      'designRevisionId': command.designRevisionId,
      'expectedRevision': command.expectedRevision,
    };
    final replay = await replayElvRuntimeCommand<ProjectDesignRevision>(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      decode: _revisionFromMap,
    );
    if (replay != null) return replay;
    final row = await _findRow(command.projectId, command.designRevisionId);
    if (row == null) {
      return recordElvRuntimeRejection<ProjectDesignRevision>(
        database: database,
        projectId: command.projectId,
        commandId: command.commandId,
        commandType: type,
        schema: schema,
        payload: payload,
        failure: const ElvFailure(
          code: 'ELV_DESIGN_REVISION_NOT_FOUND',
          category: ElvFailureCategory.notFound,
        ),
        originDeviceId: originDeviceId,
        now: _now(),
      );
    }
    if (row.state != 'WORKING') {
      return recordElvRuntimeRejection<ProjectDesignRevision>(
        database: database,
        projectId: command.projectId,
        commandId: command.commandId,
        commandType: type,
        schema: schema,
        payload: payload,
        failure: const ElvFailure(
          code: 'ELV_DESIGN_REVISION_NOT_WORKING',
          category: ElvFailureCategory.lifecycle,
        ),
        originDeviceId: originDeviceId,
        now: _now(),
      );
    }
    if (row.revision != command.expectedRevision) {
      return recordElvRuntimeRejection<ProjectDesignRevision>(
        database: database,
        projectId: command.projectId,
        commandId: command.commandId,
        commandType: type,
        schema: schema,
        payload: payload,
        failure: ElvFailure(
          code: 'ELV_DESIGN_REVISION_REVISION_CONFLICT',
          category: ElvFailureCategory.revisionConflict,
          expectedRevision: command.expectedRevision,
          actualRevision: row.revision,
        ),
        originDeviceId: originDeviceId,
        now: _now(),
      );
    }
    final snapshot = await _buildP3Snapshot(command.projectId, row.id);
    final instant = _now();
    await database
        .into(database.designRevisionPhysicalSnapshots)
        .insert(
          DesignRevisionPhysicalSnapshotsCompanion.insert(
            designRevisionId: row.id,
            projectId: row.projectId,
            schemaVersion: snapshot.schemaVersion,
            payloadJson: canonicalEngineeringJsonV1(snapshot.payload),
            payloadSha256: snapshot.contentSha256,
            createdAt: instant,
            originDeviceId: originDeviceId,
          ),
        );
    final powerSha256 = await powerRuntime
        .captureCommittedPowerSectionForFreeze(
          projectId: row.projectId,
          designRevisionId: row.id,
          expectedRevisionToken: row.revision,
          physicalSha256: snapshot.contentSha256,
        );
    await DriftElv5DisciplineSnapshotStore(
      database,
      originDeviceId: originDeviceId,
      nowUtc: _now,
    ).capture(
      projectId: row.projectId,
      designRevisionId: row.id,
      expectedRevision: row.revision,
      physicalSha256: snapshot.contentSha256,
      powerSha256: powerSha256,
    );
    await failureProbe.hit(ElvFailurePoints.p3FreezeAfterSnapshotInsert);
    await (database.update(database.projectDesignRevisions)..where(
      (candidate) =>
          candidate.id.equals(row.id) &
          candidate.revision.equals(command.expectedRevision),
    )).write(
      ProjectDesignRevisionsCompanion(
        state: const Value('FROZEN'),
        revision: Value(row.revision + 1),
        snapshotSchemaVersion: Value(snapshot.schemaVersion),
        snapshotHash: Value(snapshot.contentSha256),
        frozenAt: Value(instant),
        updatedAt: Value(instant),
        originDeviceId: Value(originDeviceId),
      ),
    );
    final result = ProjectDesignRevision(
      id: row.id,
      projectId: row.projectId,
      code: row.code,
      sequence: row.sequence,
      state: ProjectDesignRevisionState.frozen,
      basedOnRevisionId: row.basedOnRevisionId,
      revision: row.revision + 1,
    );
    await recordElvRuntimeSuccess(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      result: _revisionToMap(result),
      originDeviceId: originDeviceId,
      now: instant,
    );
    return ElvCommandSuccess(result);
  });

  @override
  Future<ElvCommandResult<ProjectDesignRevision>> createNext(
    CreateNextWorkingDesignRevisionCommand command,
  ) => database.transaction(() async {
    const type = 'CREATE_NEXT_WORKING_DESIGN_REVISION';
    const schema = 'electra.command.create-next-design-revision.v1';
    final payload = <String, Object?>{
      'projectId': command.projectId,
      'newRevisionId': command.newRevisionId,
      'code': command.code,
      'basedOnRevisionId': command.basedOnRevisionId,
    };
    final replay = await replayElvRuntimeCommand<ProjectDesignRevision>(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      decode: _revisionFromMap,
    );
    if (replay != null) return replay;
    if ((await context(command.projectId)).workingDesignRevisionId != null) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_WORKING_EXISTS',
        ElvFailureCategory.lifecycle,
      );
    }
    final base = await _findRow(command.projectId, command.basedOnRevisionId);
    if (base == null || base.state != 'FROZEN') {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_BASE_NOT_FROZEN',
        ElvFailureCategory.lifecycle,
      );
    }
    final snapshot =
        await (database.select(database.designRevisionPhysicalSnapshots)..where(
          (row) => row.designRevisionId.equals(base.id),
        )).getSingleOrNull();
    if (snapshot == null ||
        snapshot.projectId != command.projectId ||
        snapshot.payloadSha256 != base.snapshotHash ||
        !_validPhysicalSnapshot(snapshot)) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_SNAPSHOT_INVALID',
        ElvFailureCategory.referenceIntegrity,
      );
    }
    // Restoring an older frozen base must not reuse a later revision's sequence.
    final latestSequence =
        await (database.select(database.projectDesignRevisions)
              ..where((row) => row.projectId.equals(command.projectId))
              ..orderBy([(row) => OrderingTerm.desc(row.sequence)])
              ..limit(1))
            .getSingle();
    final instant = _now();
    final revision = ProjectDesignRevision(
      id: command.newRevisionId,
      projectId: command.projectId,
      code: command.code.trim(),
      sequence: latestSequence.sequence + 1,
      state: ProjectDesignRevisionState.working,
      basedOnRevisionId: base.id,
      revision: 1,
    );
    await database
        .into(database.projectDesignRevisions)
        .insert(
          ProjectDesignRevisionsCompanion.insert(
            id: revision.id,
            projectId: revision.projectId,
            code: revision.code,
            sequence: revision.sequence,
            state: 'WORKING',
            basedOnRevisionId: Value(base.id),
            createdAt: instant,
            updatedAt: instant,
            originDeviceId: originDeviceId,
          ),
        );
    await failureProbe.hit(ElvFailurePoints.p3CreateNextAfterRevisionInsert);
    final capturedPower = await powerRuntime.readRevision(
      projectId: command.projectId,
      designRevisionId: base.id,
    );
    final physicalIds = <String, String>{};
    final payloadMap = jsonDecode(snapshot.payloadJson) as Map<String, dynamic>;
    final runs =
        (payloadMap['runs'] as List? ?? const []).cast<Map<String, dynamic>>();
    for (final source in runs) {
      final sourceRunId = source['id']! as String;
      final newRunId = '${revision.id}:run:$sourceRunId';
      physicalIds[sourceRunId] = newRunId;
      await database
          .into(database.canonicalCableRuns)
          .insert(
            CanonicalCableRunsCompanion.insert(
              id: newRunId,
              projectId: revision.projectId,
              cableId: source['cableId']! as String,
              designRevisionId: revision.id,
              basedOnCableRunId: Value(sourceRunId),
              lifecycleState: 'ACTIVE',
              reservePercent: Value(
                (source['reservePercent'] as num).toDouble(),
              ),
              terminationAllowanceMm: Value(
                (source['terminationAllowanceMm'] as num).toInt(),
              ),
              createdAt: instant,
              updatedAt: instant,
              originDeviceId: originDeviceId,
            ),
          );
      final traversals =
          (source['traversals'] as List? ?? const [])
              .cast<Map<String, dynamic>>();
      for (final traversal in traversals) {
        final sequence = (traversal['sequence'] as num).toInt();
        if (traversal['id'] is String)
          physicalIds[traversal['id']! as String] = '$newRunId:trv:$sequence';
        await database
            .into(database.cableRunTraversals)
            .insert(
              CableRunTraversalsCompanion.insert(
                id: '$newRunId:trv:$sequence',
                cableRunId: newRunId,
                sequence: sequence,
                routeSegmentId: traversal['routeSegmentId']! as String,
                direction: traversal['direction']! as String,
                physicalCarrierId: Value(
                  traversal['physicalCarrierId'] as String?,
                ),
                carrierCompartmentId: Value(
                  traversal['carrierCompartmentId'] as String?,
                ),
                createdAt: instant,
                updatedAt: instant,
                originDeviceId: originDeviceId,
              ),
            );
      }
    }
    if (capturedPower.capturedPayload != null) {
      await DriftPowerSnapshotFacts(database).materialize(
        projectId: revision.projectId,
        revisionId: revision.id,
        captured: capturedPower.capturedPayload!,
        physicalIds: physicalIds,
        now: instant,
        originDeviceId: originDeviceId,
      );
    }
    await recordElvRuntimeSuccess(
      database: database,
      projectId: command.projectId,
      commandId: command.commandId,
      commandType: type,
      schema: schema,
      payload: payload,
      result: _revisionToMap(revision),
      originDeviceId: originDeviceId,
      now: instant,
    );
    return ElvCommandSuccess(revision);
  });

  bool _validPhysicalSnapshot(DesignRevisionPhysicalSnapshotRow snapshot) {
    try {
      final payload = jsonDecode(snapshot.payloadJson);
      if (payload is! Map<String, dynamic>) return false;
      return DesignRevisionPhysicalSnapshot(
            designRevisionId: snapshot.designRevisionId,
            projectId: snapshot.projectId,
            schemaVersion: snapshot.schemaVersion,
            payload: payload,
          ).contentSha256 ==
          snapshot.payloadSha256;
    } on FormatException {
      return false;
    }
  }

  @override
  Future<ElvCommandResult<ProjectDesignRevision>> supersede(
    SupersedeProjectDesignRevisionCommand command,
  ) => _transition(
    commandId: command.commandId,
    projectId: command.projectId,
    designRevisionId: command.designRevisionId,
    expectedRevision: command.expectedRevision,
    from: 'FROZEN',
    to: 'SUPERSEDED',
    commandType: 'SUPERSEDE_PROJECT_DESIGN_REVISION',
  );

  @override
  Future<ElvCommandResult<ProjectDesignRevision>> archive(
    ArchiveProjectDesignRevisionCommand command,
  ) => _transition(
    commandId: command.commandId,
    projectId: command.projectId,
    designRevisionId: command.designRevisionId,
    expectedRevision: command.expectedRevision,
    from: 'SUPERSEDED',
    to: 'ARCHIVED',
    commandType: 'ARCHIVE_PROJECT_DESIGN_REVISION',
  );

  Future<ElvCommandResult<ProjectDesignRevision>> _transition({
    required String commandId,
    required String projectId,
    required String designRevisionId,
    required int expectedRevision,
    required String from,
    required String to,
    required String commandType,
  }) => database.transaction(() async {
    final schema = 'electra.command.${commandType.toLowerCase()}.v1';
    final payload = <String, Object?>{
      'projectId': projectId,
      'designRevisionId': designRevisionId,
      'expectedRevision': expectedRevision,
    };
    final replay = await replayElvRuntimeCommand<ProjectDesignRevision>(
      database: database,
      projectId: projectId,
      commandId: commandId,
      commandType: commandType,
      schema: schema,
      payload: payload,
      decode: _revisionFromMap,
    );
    if (replay != null) return replay;
    final row = await _findRow(projectId, designRevisionId);
    if (row == null) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    }
    if (row.state != from) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_INVALID_TRANSITION',
        ElvFailureCategory.lifecycle,
      );
    }
    if (row.revision != expectedRevision) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: expectedRevision,
        actualRevision: row.revision,
      );
    }
    final instant = _now();
    final companion = ProjectDesignRevisionsCompanion(
      state: Value(to),
      revision: Value(row.revision + 1),
      updatedAt: Value(instant),
      originDeviceId: Value(originDeviceId),
      supersededAt: to == 'SUPERSEDED' ? Value(instant) : const Value.absent(),
      archivedAt: to == 'ARCHIVED' ? Value(instant) : const Value.absent(),
    );
    await (database.update(database.projectDesignRevisions)
      ..where((candidate) => candidate.id.equals(row.id))).write(companion);
    final result = ProjectDesignRevision(
      id: row.id,
      projectId: row.projectId,
      code: row.code,
      sequence: row.sequence,
      state: ProjectDesignRevisionState.values.byName(to.toLowerCase()),
      basedOnRevisionId: row.basedOnRevisionId,
      revision: row.revision + 1,
    );
    await recordElvRuntimeSuccess(
      database: database,
      projectId: projectId,
      commandId: commandId,
      commandType: commandType,
      schema: schema,
      payload: payload,
      result: _revisionToMap(result),
      originDeviceId: originDeviceId,
      now: instant,
    );
    return ElvCommandSuccess(result);
  });

  Future<ProjectDesignRevisionRow?> _findRow(
    String projectId,
    String revisionId,
  ) =>
      (database.select(database.projectDesignRevisions)..where(
        (row) =>
            row.projectId.equals(projectId) &
            row.id.equals(revisionId) &
            row.deletedAt.isNull(),
      )).getSingleOrNull();

  Future<DesignRevisionPhysicalSnapshot> _buildP3Snapshot(
    String projectId,
    String designRevisionId,
  ) async {
    final runs =
        await (database.select(database.canonicalCableRuns)
              ..where(
                (row) =>
                    row.projectId.equals(projectId) &
                    row.designRevisionId.equals(designRevisionId) &
                    row.lifecycleState.equals('ACTIVE') &
                    row.deletedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.asc(row.id)]))
            .get();
    final payloadRuns = <Map<String, Object?>>[];
    for (final run in runs) {
      final traversals =
          await (database.select(database.cableRunTraversals)
                ..where(
                  (row) =>
                      row.cableRunId.equals(run.id) & row.deletedAt.isNull(),
                )
                ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
              .get();
      payloadRuns.add({
        'id': run.id,
        'projectId': run.projectId,
        'cableId': run.cableId,
        'designRevisionId': run.designRevisionId,
        'basedOnCableRunId': run.basedOnCableRunId,
        'state': run.lifecycleState,
        'reservePercent': run.reservePercent,
        'terminationAllowanceMm': run.terminationAllowanceMm,
        'revision': run.revision,
        'traversals': [
          for (final traversal in traversals)
            {
              'id': traversal.id,
              'sequence': traversal.sequence,
              'routeSegmentId': traversal.routeSegmentId,
              'direction': traversal.direction,
              'physicalCarrierId': traversal.physicalCarrierId,
              'carrierCompartmentId': traversal.carrierCompartmentId,
            },
        ],
      });
    }
    return DesignRevisionPhysicalSnapshot(
      designRevisionId: designRevisionId,
      projectId: projectId,
      schemaVersion: 1,
      payload: {'runs': payloadRuns},
    );
  }
}

Map<String, Object?> _revisionToMap(ProjectDesignRevision value) => {
  'id': value.id,
  'projectId': value.projectId,
  'code': value.code,
  'sequence': value.sequence,
  'state': value.state.name,
  'basedOnRevisionId': value.basedOnRevisionId,
  'revision': value.revision,
};

ProjectDesignRevision _revisionFromMap(Map<String, dynamic> map) =>
    ProjectDesignRevision(
      id: map['id']! as String,
      projectId: map['projectId']! as String,
      code: map['code']! as String,
      sequence: (map['sequence'] as num).toInt(),
      state: ProjectDesignRevisionState.values.byName(map['state']! as String),
      basedOnRevisionId: map['basedOnRevisionId'] as String?,
      revision: (map['revision'] as num).toInt(),
    );
