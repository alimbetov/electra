from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one anchor, got {count}: {old[:80]!r}')
    path.write_text(text.replace(old, new, 1))


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)


db = ROOT / 'apps/mobile/lib/data/database/app_database.dart'

p3_tables = r'''@DataClassName('ProjectDesignRevisionRow')
class ProjectDesignRevisions extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get code => text()();
  IntColumn get sequence => integer()();
  TextColumn get state => text()();
  @ReferenceName('basedOnProjectDesignRevision')
  TextColumn get basedOnRevisionId =>
      text().nullable().references(ProjectDesignRevisions, #id)();
  IntColumn get snapshotSchemaVersion => integer().nullable()();
  TextColumn get snapshotHash => text().nullable()();
  DateTimeColumn get frozenAt => dateTime().nullable()();
  DateTimeColumn get supersededAt => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {projectId, code},
        {projectId, sequence},
      ];
}

@DataClassName('DesignRevisionPhysicalSnapshotRow')
class DesignRevisionPhysicalSnapshots extends Table {
  TextColumn get designRevisionId => text().references(ProjectDesignRevisions, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  IntColumn get schemaVersion => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get payloadSha256 => text()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {designRevisionId};
}

@DataClassName('CanonicalCableRunRow')
class CanonicalCableRuns extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get cableId => text().references(ElvCables, #id)();
  TextColumn get designRevisionId => text().references(ProjectDesignRevisions, #id)();
  @ReferenceName('basedOnCanonicalCableRun')
  TextColumn get basedOnCableRunId =>
      text().nullable().references(CanonicalCableRuns, #id)();
  TextColumn get lifecycleState => text()();
  RealColumn get reservePercent => real().withDefault(const Constant(0))();
  IntColumn get terminationAllowanceMm => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CableRunTraversalRow')
class CableRunTraversals extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get cableRunId => text().references(CanonicalCableRuns, #id)();
  IntColumn get sequence => integer()();
  TextColumn get routeSegmentId => text().references(CableRouteSegments, #id)();
  TextColumn get direction => text()();
  TextColumn get physicalCarrierId => text().nullable()();
  TextColumn get carrierCompartmentId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {cableRunId, sequence},
      ];
}

@DataClassName('RouteHandoffRow')
class RouteHandoffs extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  @ReferenceName('handoffFromRouteNode')
  TextColumn get fromRouteNodeId => text().references(CableRouteNodes, #id)();
  @ReferenceName('handoffToRouteNode')
  TextColumn get toRouteNodeId => text().references(CableRouteNodes, #id)();
  TextColumn get kind => text()();
  BoolColumn get bidirectional => boolean().withDefault(const Constant(true))();
  TextColumn get adjacencyRef => text().nullable()();
  TextColumn get evidenceJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('RouteBendEvidenceRow')
class RouteBendEvidence extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get routeNodeId => text().references(CableRouteNodes, #id)();
  RealColumn get radiusMm => real()();
  TextColumn get evidenceKind => text()();
  TextColumn get sourceRef => text().nullable()();
  TextColumn get provenance => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('LegacyRouteAdoptionRow')
class LegacyRouteAdoptions extends Table {
  TextColumn get legacySourceIdentity => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId => text().references(ProjectDesignRevisions, #id)();
  TextColumn get cableId => text().references(ElvCables, #id)();
  TextColumn get canonicalCableRunId => text().references(CanonicalCableRuns, #id)();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {legacySourceIdentity};
}

'''

replace_once(db, "@DriftDatabase(\n", p3_tables + "@DriftDatabase(\n")
replace_once(
    db,
    "    ElvCables, CableAllocations, CableAllocationResourceSelections,\n    CableResourceClaims, CableTerminationMappings, CommandExecutionRecords,\n",
    "    ElvCables, CableAllocations, CableAllocationResourceSelections,\n    CableResourceClaims, CableTerminationMappings, CommandExecutionRecords,\n    ProjectDesignRevisions, DesignRevisionPhysicalSnapshots, CanonicalCableRuns,\n    CableRunTraversals, RouteHandoffs, RouteBendEvidence, LegacyRouteAdoptions,\n",
)
replace_once(db, "  int get schemaVersion => 19;", "  int get schemaVersion => 20;")
replace_once(
    db,
    "        if (from < 19) {\n          await migrator.createTable(cableAllocations);\n          await migrator.createTable(cableAllocationResourceSelections);\n          await migrator.createTable(cableResourceClaims);\n          await migrator.createTable(cableTerminationMappings);\n        }\n",
    "        if (from < 19) {\n          await migrator.createTable(cableAllocations);\n          await migrator.createTable(cableAllocationResourceSelections);\n          await migrator.createTable(cableResourceClaims);\n          await migrator.createTable(cableTerminationMappings);\n        }\n        if (from < 20) {\n          await migrator.createTable(projectDesignRevisions);\n          await migrator.createTable(designRevisionPhysicalSnapshots);\n          await migrator.createTable(canonicalCableRuns);\n          await migrator.createTable(cableRunTraversals);\n          await migrator.createTable(routeHandoffs);\n          await migrator.createTable(routeBendEvidence);\n          await migrator.createTable(legacyRouteAdoptions);\n        }\n",
)
replace_once(
    db,
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_termination_allocation ON cable_termination_mappings(allocation_id)');\n",
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_termination_allocation ON cable_termination_mappings(allocation_id)');\n"
    "    await customStatement(\"CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_design_revision_working ON project_design_revisions(project_id) WHERE state = 'WORKING' AND deleted_at IS NULL\");\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_design_revision_project ON project_design_revisions(project_id, sequence)');\n"
    "    await customStatement(\"CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_active_run_per_cable_revision ON canonical_cable_runs(cable_id, design_revision_id) WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL\");\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_run_revision ON canonical_cable_runs(project_id, design_revision_id)');\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_traversal_run_order ON cable_run_traversals(cable_run_id, sequence)');\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_traversal_segment ON cable_run_traversals(route_segment_id)');\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_handoff_project ON route_handoffs(project_id)');\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_bend_project ON route_bend_evidence(project_id, route_node_id)');\n",
)

write('apps/mobile/lib/data/repositories/drift_elv_runtime_support.dart', r'''import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../database/app_database.dart';

String elvRuntimeFingerprint(String schema, Map<String, Object?> payload) =>
    sha256HexUtf8(
      canonicalEngineeringJsonV1({
        'schema': schema,
        'payload': payload,
      }),
    );

Future<ElvCommandResult<T>?> replayElvRuntimeCommand<T>({
  required AppDatabase database,
  required String projectId,
  required String commandId,
  required String commandType,
  required String schema,
  required Map<String, Object?> payload,
  required T Function(Map<String, dynamic>) decode,
}) async {
  final row = await (database.select(database.commandExecutionRecords)
        ..where(
          (candidate) =>
              candidate.projectId.equals(projectId) &
              candidate.commandId.equals(commandId),
        ))
      .getSingleOrNull();
  if (row == null) return null;
  final expected = elvRuntimeFingerprint(schema, payload);
  if (row.commandType != commandType ||
      row.normalizedPayloadSha256 != expected) {
    return const ElvCommandFailureResult(
      ElvFailure(
        code: 'ELV_IDEMPOTENCY_CONFLICT',
        category: ElvFailureCategory.commandEnvelope,
      ),
    );
  }
  if (row.outcomeKind != 'SUCCESS') {
    return ElvCommandFailureResult(
      ElvFailure(
        code: 'ELV_REPLAYED_REJECTION',
        category: ElvFailureCategory.validation,
        details: {'logicalResultJson': row.logicalResultJson},
      ),
    );
  }
  return ElvCommandSuccess(
    decode(jsonDecode(row.logicalResultJson) as Map<String, dynamic>),
  );
}

Future<void> recordElvRuntimeSuccess({
  required AppDatabase database,
  required String projectId,
  required String commandId,
  required String commandType,
  required String schema,
  required Map<String, Object?> payload,
  required Map<String, Object?> result,
  required String originDeviceId,
  DateTime? now,
}) async {
  final instant = (now ?? DateTime.now()).toUtc();
  await database.into(database.commandExecutionRecords).insert(
        CommandExecutionRecordsCompanion.insert(
          projectId: projectId,
          commandId: commandId,
          commandType: commandType,
          payloadSchemaVersion: 1,
          normalizedPayloadSha256: elvRuntimeFingerprint(schema, payload),
          outcomeKind: 'SUCCESS',
          logicalResultJson: canonicalEngineeringJsonV1(result),
          createdAt: instant,
          committedAt: instant,
          originDeviceId: originDeviceId,
        ),
      );
}

ElvCommandFailureResult<T> elvRuntimeFailure<T>(
  String code,
  ElvFailureCategory category, {
  String? entityType,
  String? entityId,
  int? expectedRevision,
  int? actualRevision,
  Map<String, Object?> details = const {},
}) =>
    ElvCommandFailureResult(
      ElvFailure(
        code: code,
        category: category,
        entityType: entityType,
        entityId: entityId,
        expectedRevision: expectedRevision,
        actualRevision: actualRevision,
        details: details,
      ),
    );
''')

write('apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart', r'''import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../../application/elv_design_revision_command.dart';
import '../../application/elv_design_revision_repository.dart';
import '../../application/elv_failure_probe.dart';
import '../database/app_database.dart';
import 'drift_elv_runtime_support.dart';

final class DriftElvDesignRevisionRepository
    implements ElvDesignRevisionRepository {
  DriftElvDesignRevisionRepository(
    this.database, {
    required this.originDeviceId,
    ElvFailureProbe? failureProbe,
    DateTime Function()? now,
  })  : failureProbe = failureProbe ?? const NoopElvFailureProbe(),
        _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final ElvFailureProbe failureProbe;
  final DateTime Function() _now;

  @override
  Future<PhysicalDesignContext> context(String projectId) async {
    final rows = await (database.select(database.projectDesignRevisions)
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
    final project = await (database.select(database.projects)
          ..where(
            (row) =>
                row.id.equals(command.projectId) & row.deletedAt.isNull(),
          ))
        .getSingleOrNull();
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
    await database.into(database.projectDesignRevisions).insert(
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
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_NOT_FOUND',
        ElvFailureCategory.notFound,
      );
    }
    if (row.state != 'WORKING') {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_NOT_WORKING',
        ElvFailureCategory.lifecycle,
      );
    }
    if (row.revision != command.expectedRevision) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_REVISION_CONFLICT',
        ElvFailureCategory.revisionConflict,
        expectedRevision: command.expectedRevision,
        actualRevision: row.revision,
      );
    }
    final snapshot = await _buildP3Snapshot(command.projectId, row.id);
    final instant = _now();
    await database.into(database.designRevisionPhysicalSnapshots).insert(
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
    await failureProbe.hit(ElvFailurePoints.p3FreezeAfterSnapshotInsert);
    await (database.update(database.projectDesignRevisions)
          ..where(
            (candidate) =>
                candidate.id.equals(row.id) &
                candidate.revision.equals(command.expectedRevision),
          ))
        .write(
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
    final snapshot = await (database.select(database.designRevisionPhysicalSnapshots)
          ..where((row) => row.designRevisionId.equals(base.id)))
        .getSingleOrNull();
    if (snapshot == null || snapshot.payloadSha256 != base.snapshotHash) {
      return elvRuntimeFailure(
        'ELV_DESIGN_REVISION_SNAPSHOT_INVALID',
        ElvFailureCategory.referenceIntegrity,
      );
    }
    final instant = _now();
    final revision = ProjectDesignRevision(
      id: command.newRevisionId,
      projectId: command.projectId,
      code: command.code.trim(),
      sequence: base.sequence + 1,
      state: ProjectDesignRevisionState.working,
      basedOnRevisionId: base.id,
      revision: 1,
    );
    await database.into(database.projectDesignRevisions).insert(
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
    final payloadMap = jsonDecode(snapshot.payloadJson) as Map<String, dynamic>;
    final runs = (payloadMap['runs'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final source in runs) {
      final sourceRunId = source['id']! as String;
      final newRunId = '${revision.id}:run:$sourceRunId';
      await database.into(database.canonicalCableRuns).insert(
            CanonicalCableRunsCompanion.insert(
              id: newRunId,
              projectId: revision.projectId,
              cableId: source['cableId']! as String,
              designRevisionId: revision.id,
              basedOnCableRunId: Value(sourceRunId),
              lifecycleState: 'ACTIVE',
              reservePercent: Value((source['reservePercent'] as num).toDouble()),
              terminationAllowanceMm:
                  Value((source['terminationAllowanceMm'] as num).toInt()),
              createdAt: instant,
              updatedAt: instant,
              originDeviceId: originDeviceId,
            ),
          );
      final traversals = (source['traversals'] as List? ?? const [])
          .cast<Map<String, dynamic>>();
      for (final traversal in traversals) {
        final sequence = (traversal['sequence'] as num).toInt();
        await database.into(database.cableRunTraversals).insert(
              CableRunTraversalsCompanion.insert(
                id: '$newRunId:trv:$sequence',
                cableRunId: newRunId,
                sequence: sequence,
                routeSegmentId: traversal['routeSegmentId']! as String,
                direction: traversal['direction']! as String,
                physicalCarrierId:
                    Value(traversal['physicalCarrierId'] as String?),
                carrierCompartmentId:
                    Value(traversal['carrierCompartmentId'] as String?),
                createdAt: instant,
                updatedAt: instant,
                originDeviceId: originDeviceId,
              ),
            );
      }
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
          ..where((candidate) => candidate.id.equals(row.id)))
        .write(companion);
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
  ) => (database.select(database.projectDesignRevisions)
        ..where(
          (row) =>
              row.projectId.equals(projectId) &
              row.id.equals(revisionId) &
              row.deletedAt.isNull(),
        ))
      .getSingleOrNull();

  Future<DesignRevisionPhysicalSnapshot> _buildP3Snapshot(
    String projectId,
    String designRevisionId,
  ) async {
    final runs = await (database.select(database.canonicalCableRuns)
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
      final traversals = await (database.select(database.cableRunTraversals)
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
''')

write('apps/mobile/lib/data/repositories/drift_elv_cable_run_repository.dart', r'''import 'package:drift/drift.dart';
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
  })  : failureProbe = failureProbe ?? const NoopElvFailureProbe(),
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
    final rows = await (database.select(database.canonicalCableRuns)
          ..where(
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
    final row = await (database.select(database.canonicalCableRuns)
          ..where(
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
    final rows = await (database.select(database.cableRunTraversals)
          ..where(
            (row) => row.cableRunId.equals(cableRunId) & row.deletedAt.isNull(),
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
    final cable = await (database.select(database.elvCables)
          ..where(
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
    final allocation = await (database.select(database.cableAllocations)
          ..where(
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
    await database.into(database.canonicalCableRuns).insert(
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
    final row = await (database.select(database.canonicalCableRuns)
          ..where(
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
    if (await _workingRevision(command.projectId, row.designRevisionId) == null) {
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
    await (database.delete(database.cableRunTraversals)
          ..where((item) => item.cableRunId.equals(row.id)))
        .go();
    await failureProbe.hit(ElvFailurePoints.p3RerouteAfterDeleteOldChain);
    final instant = _now();
    await _insertTraversalChain(row.id, command.traversals, instant);
    await (database.update(database.canonicalCableRuns)
          ..where((candidate) => candidate.id.equals(row.id)))
        .write(
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
    final row = await (database.select(database.canonicalCableRuns)
          ..where(
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
    await (database.update(database.canonicalCableRuns)
          ..where((candidate) => candidate.id.equals(row.id)))
        .write(
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
  ) => (database.select(database.projectDesignRevisions)
        ..where(
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
      final segment = await (database.select(database.cableRouteSegments)
            ..where((row) => row.id.equals(segmentId) & row.deletedAt.isNull()))
          .getSingleOrNull();
      if (segment == null) return false;
      final route = await (database.select(database.cableRoutes)
            ..where((row) => row.id.equals(segment.routeId) & row.deletedAt.isNull()))
          .getSingleOrNull();
      if (route == null) return false;
      final room = await (database.select(database.rooms)
            ..where((row) => row.id.equals(route.roomId) & row.deletedAt.isNull()))
          .getSingleOrNull();
      if (room == null) return false;
      final floor = await (database.select(database.floors)
            ..where((row) => row.id.equals(room.floorId) & row.deletedAt.isNull()))
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
      await database.into(database.cableRunTraversals).insert(
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
      state: CanonicalCableRunState.values.byName(
        row.lifecycleState.toLowerCase(),
      ),
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
      direction: CableTraversalDirection.values.byName(row.direction.toLowerCase()),
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
''')

# Close the P1 dependency seam now that P3 persistence exists.
p1_uow = ROOT / 'apps/mobile/lib/data/repositories/drift_elv_cable_write_unit_of_work.dart'
replace_once(
    p1_uow,
    "  Future<bool> hasCanonicalRunHistory(String projectId, String cableId) async {\n    // P3 replaces this branch with canonical run persistence.\n    return false;\n  }\n",
    "  Future<bool> hasCanonicalRunHistory(String projectId, String cableId) async =>\n      await (database.select(database.canonicalCableRuns)\n            ..where(\n              (row) =>\n                  row.projectId.equals(projectId) &\n                  row.cableId.equals(cableId) &\n                  row.deletedAt.isNull(),\n            ))\n          .getSingleOrNull() !=\n      null;\n",
)

write('apps/mobile/test/data/elv_p3_runtime_closure_test.dart', r'''import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_design_revision_command.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_design_revision_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seedProject(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14, 11);
  await db.into(db.projects).insert(
        ProjectsCompanion.insert(
          id: 'project-1',
          name: 'ELV3 runtime',
          measurementSystem: 'metric',
          defaultStructuralHeightMm: 3000,
          defaultFinishedCeilingHeightMm: 2700,
          createdAt: now,
          updatedAt: now,
          originDeviceId: 'test',
        ),
      );
}

DriftElvDesignRevisionRepository _repository(AppDatabase db) =>
    DriftElvDesignRevisionRepository(
      db,
      originDeviceId: 'test',
      now: () => DateTime.utc(2026, 10, 14, 11, 30),
    );

void main() {
  test('schema 20 exposes canonical P3 tables and keeps legacy CableRuns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 20);
    final names = (await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type='table'",
    ).get()).map((row) => row.read<String>('name')).toSet();
    expect(
      names,
      containsAll({
        'project_design_revisions',
        'design_revision_physical_snapshots',
        'canonical_cable_runs',
        'cable_run_traversals',
        'route_handoffs',
        'route_bend_evidence',
        'legacy_route_adoptions',
        'cable_runs',
      }),
    );
  });

  test('bootstrap freeze close/reopen preserves frozen snapshot exactly', () async {
    final dir = await Directory.systemTemp.createTemp('electra-elv3-p3-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/electra.sqlite');

    var db = AppDatabase(NativeDatabase(file));
    await _seedProject(db);
    final repo = _repository(db);
    final boot = await repo.bootstrap(
      const BootstrapProjectDesignRevisionCommand(
        commandId: 'cmd-bootstrap',
        projectId: 'project-1',
        revisionId: 'REV-1',
        code: 'R1',
      ),
    );
    expect(boot, isA<ElvCommandSuccess<ProjectDesignRevision>>());
    final frozen = await repo.freeze(
      const FreezeProjectDesignRevisionCommand(
        commandId: 'cmd-freeze',
        projectId: 'project-1',
        designRevisionId: 'REV-1',
        expectedRevision: 1,
      ),
    );
    expect(frozen, isA<ElvCommandSuccess<ProjectDesignRevision>>());
    final before = await db.select(db.designRevisionPhysicalSnapshots).getSingle();
    expect(before.payloadSha256, isNotEmpty);
    expect(jsonDecode(before.payloadJson), {'runs': []});
    await db.close();

    db = AppDatabase(NativeDatabase(file));
    addTearDown(db.close);
    final after = await db.select(db.designRevisionPhysicalSnapshots).getSingle();
    expect(after.designRevisionId, before.designRevisionId);
    expect(after.payloadJson, before.payloadJson);
    expect(after.payloadSha256, before.payloadSha256);
    final context = await _repository(db).context('project-1');
    expect(context.workingDesignRevisionId, isNull);
    expect(context.latestFrozenRevisionId, 'REV-1');
  });

  test('create-next materializes an independent WORKING revision', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final repo = _repository(db);
    await repo.bootstrap(
      const BootstrapProjectDesignRevisionCommand(
        commandId: 'b',
        projectId: 'project-1',
        revisionId: 'REV-1',
        code: 'R1',
      ),
    );
    await repo.freeze(
      const FreezeProjectDesignRevisionCommand(
        commandId: 'f',
        projectId: 'project-1',
        designRevisionId: 'REV-1',
        expectedRevision: 1,
      ),
    );
    final next = await repo.createNext(
      const CreateNextWorkingDesignRevisionCommand(
        commandId: 'n',
        projectId: 'project-1',
        newRevisionId: 'REV-2',
        code: 'R2',
        basedOnRevisionId: 'REV-1',
      ),
    );
    expect(next, isA<ElvCommandSuccess<ProjectDesignRevision>>());
    final context = await repo.context('project-1');
    expect(context.workingDesignRevisionId, 'REV-2');
    expect(context.latestFrozenRevisionId, 'REV-1');
    final old = await (db.select(db.projectDesignRevisions)
          ..where((row) => row.id.equals('REV-1')))
        .getSingle();
    expect(old.state, 'FROZEN');
  });
}
''')

print('ELV3 RC1/RC2 patch applied')
