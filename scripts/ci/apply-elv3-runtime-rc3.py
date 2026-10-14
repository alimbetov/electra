from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected one anchor, got {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)


db = ROOT / 'apps/mobile/lib/data/database/app_database.dart'

p4_tables = r'''@DataClassName('PathwayContextRow')
class PathwayContexts extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get kind => text()();
  TextColumn get hostType => text()();
  TextColumn get hostJson => text()();
  @ReferenceName('parentPathwayContext')
  TextColumn get parentContextId => text().nullable().references(PathwayContexts, #id)();
  TextColumn get provenance => text().nullable()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PhysicalCarrierRow')
class PhysicalCarriers extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get pathwayContextId => text().references(PathwayContexts, #id)();
  TextColumn get code => text()();
  TextColumn get normalizedCode => text()();
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get payloadJson => text()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('PhysicalCarrierCompartmentRow')
class PhysicalCarrierCompartments extends Table with GeometryAuditColumns {
  TextColumn get id => text()();
  TextColumn get carrierId => text().references(PhysicalCarriers, #id)();
  TextColumn get code => text()();
  TextColumn get normalizedCode => text()();
  IntColumn get sequence => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get lifecycleState => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TraversalCarrierAssignmentRow')
class TraversalCarrierAssignments extends Table with GeometryAuditColumns {
  TextColumn get traversalId => text().references(CableRunTraversals, #id)();
  TextColumn get cableRunId => text().references(CanonicalCableRuns, #id)();
  TextColumn get projectId => text().references(Projects, #id)();
  TextColumn get designRevisionId => text().references(ProjectDesignRevisions, #id)();
  TextColumn get carrierId => text().references(PhysicalCarriers, #id)();
  TextColumn get compartmentId => text().nullable().references(PhysicalCarrierCompartments, #id)();

  @override
  Set<Column<Object>> get primaryKey => {traversalId};
}

'''

replace_once(db, "@DriftDatabase(\n", p4_tables + "@DriftDatabase(\n")
replace_once(
    db,
    "    RouteBendEvidence,\n    LegacyRouteAdoptions,\n",
    "    RouteBendEvidence,\n    LegacyRouteAdoptions,\n    PathwayContexts,\n    PhysicalCarriers,\n    PhysicalCarrierCompartments,\n    TraversalCarrierAssignments,\n",
)
replace_once(db, "  int get schemaVersion => 20;", "  int get schemaVersion => 21;")
replace_once(
    db,
    "        if (from < 20) {\n          await migrator.createTable(projectDesignRevisions);\n          await migrator.createTable(designRevisionPhysicalSnapshots);\n          await migrator.createTable(canonicalCableRuns);\n          await migrator.createTable(cableRunTraversals);\n          await migrator.createTable(routeHandoffs);\n          await migrator.createTable(routeBendEvidence);\n          await migrator.createTable(legacyRouteAdoptions);\n        }\n",
    "        if (from < 20) {\n          await migrator.createTable(projectDesignRevisions);\n          await migrator.createTable(designRevisionPhysicalSnapshots);\n          await migrator.createTable(canonicalCableRuns);\n          await migrator.createTable(cableRunTraversals);\n          await migrator.createTable(routeHandoffs);\n          await migrator.createTable(routeBendEvidence);\n          await migrator.createTable(legacyRouteAdoptions);\n        }\n        if (from < 21) {\n          await migrator.createTable(pathwayContexts);\n          await migrator.createTable(physicalCarriers);\n          await migrator.createTable(physicalCarrierCompartments);\n          await migrator.createTable(traversalCarrierAssignments);\n        }\n",
)
replace_once(
    db,
    "    await customStatement(\n      'CREATE INDEX IF NOT EXISTS idx_elv_bend_project ON route_bend_evidence(project_id, route_node_id)',\n    );\n",
    "    await customStatement(\n      'CREATE INDEX IF NOT EXISTS idx_elv_bend_project ON route_bend_evidence(project_id, route_node_id)',\n    );\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_pathway_project ON pathway_contexts(project_id, lifecycle_state)');\n"
    "    await customStatement(\"CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_pathway_active_identity ON pathway_contexts(project_id, id) WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL\");\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_carrier_project ON physical_carriers(project_id, pathway_context_id)');\n"
    "    await customStatement(\"CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_carrier_active_code ON physical_carriers(project_id, normalized_code) WHERE lifecycle_state = 'ACTIVE' AND deleted_at IS NULL\");\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_compartment_carrier ON physical_carrier_compartments(carrier_id, sequence)');\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_traversal_carrier_assignment_run ON traversal_carrier_assignments(cable_run_id)');\n",
)

write('apps/mobile/lib/data/repositories/drift_elv_pathway_repository.dart', r'''import 'dart:convert';

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
    final rows = await (database.select(database.pathwayContexts)
          ..where((row) => row.projectId.equals(projectId) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.id)]))
        .get();
    return rows.map(_decodeRow).toList(growable: false);
  }

  @override
  Future<PathwayContext?> findContext(String projectId, String contextId) async {
    final row = await (database.select(database.pathwayContexts)
          ..where((candidate) => candidate.projectId.equals(projectId) & candidate.id.equals(contextId) & candidate.deletedAt.isNull()))
        .getSingleOrNull();
    return row == null ? null : _decodeRow(row);
  }

  @override
  Future<ElvCommandResult<PathwayContext>> create(CreatePathwayContextCommand command) =>
      database.transaction(() async {
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
        final contexts = {for (final item in await loadContexts(command.context.projectId)) item.id: item};
        if (contexts.containsKey(command.context.id)) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_EXISTS', ElvFailureCategory.validation, entityType: 'PathwayContext', entityId: command.context.id);
        }
        final errors = PathwayContextValidator.validate(context: command.context, projectContexts: contexts);
        if (errors.isNotEmpty) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_INVALID', ElvFailureCategory.validation, details: {'errors': errors});
        }
        final now = DateTime.now().toUtc();
        final host = _encodeHost(command.context.host);
        await database.into(database.pathwayContexts).insert(
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
  Future<ElvCommandResult<PathwayContext>> update(UpdatePathwayContextCommand command) =>
      database.transaction(() async {
        final current = await findContext(command.context.projectId, command.context.id);
        if (current == null) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_NOT_FOUND', ElvFailureCategory.notFound, entityType: 'PathwayContext', entityId: command.context.id);
        }
        if (current.revision != command.expectedRevision) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_REVISION_CONFLICT', ElvFailureCategory.revisionConflict, expectedRevision: command.expectedRevision, actualRevision: current.revision);
        }
        final expectedImpact = pathwayImpactFingerprint(current);
        if (command.expectedImpactFingerprint != expectedImpact) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_IMPACT_CHANGED', ElvFailureCategory.dependencyImpact, details: {'expected': command.expectedImpactFingerprint, 'actual': expectedImpact});
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
        final contexts = {for (final item in await loadContexts(next.projectId)) item.id: item}..remove(next.id);
        final errors = PathwayContextValidator.validate(context: next, projectContexts: contexts);
        if (errors.isNotEmpty) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_INVALID', ElvFailureCategory.validation, details: {'errors': errors});
        }
        final host = _encodeHost(next.host);
        await (database.update(database.pathwayContexts)..where((row) => row.id.equals(next.id))).write(
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
  Future<ElvCommandResult<void>> archive(ArchivePathwayContextCommand command) =>
      database.transaction(() async {
        final current = await findContext(command.projectId, command.contextId);
        if (current == null) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_NOT_FOUND', ElvFailureCategory.notFound);
        }
        if (current.revision != command.expectedRevision) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_REVISION_CONFLICT', ElvFailureCategory.revisionConflict, expectedRevision: command.expectedRevision, actualRevision: current.revision);
        }
        final activeCarrier = await (database.select(database.physicalCarriers)..where((row) => row.pathwayContextId.equals(command.contextId) & row.lifecycleState.equals('ACTIVE') & row.deletedAt.isNull())).getSingleOrNull();
        if (activeCarrier != null) {
          return elvRuntimeFailure('ELV_PATHWAY_CONTEXT_IN_USE', ElvFailureCategory.referenceIntegrity, entityId: command.contextId);
        }
        await (database.update(database.pathwayContexts)..where((row) => row.id.equals(command.contextId))).write(
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

String pathwayImpactFingerprint(PathwayContext context) => elvRuntimeFingerprint('electra.pathway-impact.v1', _encode(context));

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

(String, Map<String, Object?>) _encodeHost(PathwayContextHost host) => switch (host) {
  RoomHost(:final roomId) => ('ROOM', {'roomId': roomId}),
  FloorHost(:final floorId) => ('FLOOR', {'floorId': floorId}),
  SurfaceVoidHost(:final floorId, :final spatialFeatureId) => ('SURFACE_VOID', {'floorId': floorId, 'spatialFeatureId': spatialFeatureId}),
  VerticalHost(:final fromFloorId, :final toFloorId, :final spatialFeatureId) => ('VERTICAL', {'fromFloorId': fromFloorId, 'toFloorId': toFloorId, 'spatialFeatureId': spatialFeatureId}),
  ProjectHost(:final projectId) => ('PROJECT', {'projectId': projectId}),
};

PathwayContextHost _decodeHost(String type, Map<String, dynamic> map) => switch (type) {
  'ROOM' => RoomHost(map['roomId'] as String),
  'FLOOR' => FloorHost(map['floorId'] as String),
  'SURFACE_VOID' => SurfaceVoidHost(floorId: map['floorId'] as String, spatialFeatureId: map['spatialFeatureId'] as String),
  'VERTICAL' => VerticalHost(fromFloorId: map['fromFloorId'] as String, toFloorId: map['toFloorId'] as String, spatialFeatureId: map['spatialFeatureId'] as String?),
  'PROJECT' => ProjectHost(map['projectId'] as String),
  _ => throw StateError('Unknown pathway host type: $type'),
};

PathwayContext _decodeMap(Map<String, dynamic> map) => PathwayContext(
  id: map['id'] as String,
  projectId: map['projectId'] as String,
  kind: PathwayContextKind.values.byName(map['kind'] as String),
  host: _decodeHost(map['hostType'] as String, (map['host'] as Map).cast<String, dynamic>()),
  parentContextId: map['parentContextId'] as String?,
  provenance: map['provenance'] as String?,
  lifecycleState: PathwayContextLifecycleState.values.byName(map['lifecycleState'] as String),
  revision: map['revision'] as int,
);

PathwayContext _decodeRow(PathwayContextRow row) => PathwayContext(
  id: row.id,
  projectId: row.projectId,
  kind: PathwayContextKind.values.byName(row.kind.toLowerCase()),
  host: _decodeHost(row.hostType, (jsonDecode(row.hostJson) as Map).cast<String, dynamic>()),
  parentContextId: row.parentContextId,
  provenance: row.provenance,
  lifecycleState: PathwayContextLifecycleState.values.byName(row.lifecycleState.toLowerCase()),
  revision: row.revision,
);
''')

write('apps/mobile/lib/data/repositories/drift_elv_physical_carrier_repository.dart', r'''import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_command_result.dart';
import '../../application/elv_failure_probe.dart';
import '../../application/elv_physical_carrier_command.dart';
import '../../application/elv_physical_carrier_repository.dart';
import '../database/app_database.dart';
import 'drift_elv_runtime_support.dart';

final class DriftElvPhysicalCarrierRepository implements ElvPhysicalCarrierRepository {
  DriftElvPhysicalCarrierRepository(
    this.database, {
    required this.originDeviceId,
    ElvFailureProbe? failureProbe,
  }) : failureProbe = failureProbe ?? const NoopElvFailureProbe();

  final AppDatabase database;
  final String originDeviceId;
  final ElvFailureProbe failureProbe;

  @override
  Future<List<PhysicalCarrier>> loadCarriers(String projectId) async {
    final rows = await (database.select(database.physicalCarriers)
          ..where((row) => row.projectId.equals(projectId) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.normalizedCode)]))
        .get();
    return rows.map(_carrierFromRow).toList(growable: false);
  }

  @override
  Future<List<PhysicalCarrierCompartment>> loadCompartments(String carrierId) async {
    final rows = await (database.select(database.physicalCarrierCompartments)
          ..where((row) => row.carrierId.equals(carrierId) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.asc(row.sequence)]))
        .get();
    return rows.map(_compartmentFromRow).toList(growable: false);
  }

  @override
  Future<CarrierImpactPreview> previewCarrierImpact(String projectId, String carrierId) async {
    final rows = await database.customSelect(
      'SELECT DISTINCT a.cable_run_id FROM traversal_carrier_assignments a WHERE a.project_id = ? AND a.carrier_id = ? AND a.deleted_at IS NULL ORDER BY a.cable_run_id',
      variables: [Variable.withString(projectId), Variable.withString(carrierId)],
    ).get();
    final ids = rows.map((row) => row.read<String>('cable_run_id')).toList(growable: false);
    return CarrierImpactPreview(
      affectedCableRunIds: ids,
      impactFingerprint: elvRuntimeFingerprint('electra.carrier-impact.v1', {'projectId': projectId, 'carrierId': carrierId, 'cableRunIds': ids}),
    );
  }

  @override
  Future<ElvCommandResult<PhysicalCarrier>> create(CreatePhysicalCarrierCommand command) => database.transaction(() async {
    final carrier = command.carrier;
    final errors = carrier.validate();
    if (errors.isNotEmpty) return elvRuntimeFailure('ELV_CARRIER_INVALID', ElvFailureCategory.validation, details: {'errors': errors});
    final pathway = await (database.select(database.pathwayContexts)..where((row) => row.id.equals(carrier.pathwayContextId) & row.projectId.equals(carrier.projectId) & row.lifecycleState.equals('ACTIVE') & row.deletedAt.isNull())).getSingleOrNull();
    if (pathway == null) return elvRuntimeFailure('ELV_CARRIER_PATHWAY_NOT_FOUND', ElvFailureCategory.referenceIntegrity);
    final duplicate = await (database.select(database.physicalCarriers)..where((row) => row.projectId.equals(carrier.projectId) & row.normalizedCode.equals(carrier.normalizedCode) & row.lifecycleState.equals('ACTIVE') & row.deletedAt.isNull())).getSingleOrNull();
    if (duplicate != null) return elvRuntimeFailure('ELV_CARRIER_CODE_EXISTS', ElvFailureCategory.validation);
    final now = DateTime.now().toUtc();
    await database.into(database.physicalCarriers).insert(PhysicalCarriersCompanion.insert(
      id: carrier.id,
      projectId: carrier.projectId,
      pathwayContextId: carrier.pathwayContextId,
      code: carrier.code,
      normalizedCode: carrier.normalizedCode,
      name: carrier.name,
      kind: carrier.kind.name.toUpperCase(),
      payloadJson: jsonEncode(_carrierPayload(carrier)),
      lifecycleState: carrier.lifecycleState.name.toUpperCase(),
      revision: Value(carrier.revision),
      createdAt: now,
      updatedAt: now,
      originDeviceId: originDeviceId,
    ));
    return ElvCommandSuccess(carrier);
  });

  @override
  Future<ElvCommandResult<PhysicalCarrier>> update(UpdatePhysicalCarrierCommand command) => database.transaction(() async {
    final row = await (database.select(database.physicalCarriers)..where((candidate) => candidate.id.equals(command.carrier.id) & candidate.projectId.equals(command.carrier.projectId) & candidate.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return elvRuntimeFailure('ELV_CARRIER_NOT_FOUND', ElvFailureCategory.notFound);
    if (row.revision != command.expectedRevision) return elvRuntimeFailure('ELV_CARRIER_REVISION_CONFLICT', ElvFailureCategory.revisionConflict, expectedRevision: command.expectedRevision, actualRevision: row.revision);
    final preview = await previewCarrierImpact(command.carrier.projectId, command.carrier.id);
    if (preview.impactFingerprint != command.expectedImpactFingerprint) return elvRuntimeFailure('ELV_CARRIER_IMPACT_CHANGED', ElvFailureCategory.dependencyImpact);
    final next = PhysicalCarrier(
      id: command.carrier.id,
      projectId: command.carrier.projectId,
      pathwayContextId: command.carrier.pathwayContextId,
      code: command.carrier.code,
      name: command.carrier.name,
      kind: command.carrier.kind,
      crossSection: command.carrier.crossSection,
      environmentFacts: command.carrier.environmentFacts,
      installationFacts: command.carrier.installationFacts,
      lifecycleState: command.carrier.lifecycleState,
      revision: row.revision + 1,
    );
    final errors = next.validate();
    if (errors.isNotEmpty) return elvRuntimeFailure('ELV_CARRIER_INVALID', ElvFailureCategory.validation, details: {'errors': errors});
    await (database.update(database.physicalCarriers)..where((candidate) => candidate.id.equals(next.id))).write(PhysicalCarriersCompanion(
      pathwayContextId: Value(next.pathwayContextId),
      code: Value(next.code),
      normalizedCode: Value(next.normalizedCode),
      name: Value(next.name),
      kind: Value(next.kind.name.toUpperCase()),
      payloadJson: Value(jsonEncode(_carrierPayload(next))),
      lifecycleState: Value(next.lifecycleState.name.toUpperCase()),
      revision: Value(next.revision),
      updatedAt: Value(DateTime.now().toUtc()),
      originDeviceId: Value(originDeviceId),
    ));
    return ElvCommandSuccess(next);
  });

  @override
  Future<ElvCommandResult<void>> archive(ArchivePhysicalCarrierCommand command) => database.transaction(() async {
    final row = await (database.select(database.physicalCarriers)..where((candidate) => candidate.id.equals(command.carrierId) & candidate.projectId.equals(command.projectId) & candidate.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return elvRuntimeFailure('ELV_CARRIER_NOT_FOUND', ElvFailureCategory.notFound);
    if (row.revision != command.expectedRevision) return elvRuntimeFailure('ELV_CARRIER_REVISION_CONFLICT', ElvFailureCategory.revisionConflict, expectedRevision: command.expectedRevision, actualRevision: row.revision);
    final assignment = await (database.select(database.traversalCarrierAssignments)..where((candidate) => candidate.carrierId.equals(command.carrierId) & candidate.deletedAt.isNull())).getSingleOrNull();
    if (assignment != null) return elvRuntimeFailure('ELV_CARRIER_IN_USE', ElvFailureCategory.referenceIntegrity);
    await (database.update(database.physicalCarriers)..where((candidate) => candidate.id.equals(command.carrierId))).write(PhysicalCarriersCompanion(
      lifecycleState: const Value('ARCHIVED'), revision: Value(row.revision + 1), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId),
    ));
    return const ElvCommandSuccess<void>(null);
  });

  @override
  Future<ElvCommandResult<PhysicalCarrierCompartment>> createCompartment(CreateCarrierCompartmentCommand command) => database.transaction(() async {
    final carrierRow = await (database.select(database.physicalCarriers)..where((row) => row.id.equals(command.compartment.carrierId) & row.projectId.equals(command.projectId) & row.lifecycleState.equals('ACTIVE') & row.deletedAt.isNull())).getSingleOrNull();
    if (carrierRow == null) return elvRuntimeFailure('ELV_CARRIER_NOT_FOUND', ElvFailureCategory.notFound);
    final existing = await loadCompartments(command.compartment.carrierId);
    final carrier = _carrierFromRow(carrierRow);
    final errors = validateCarrierCompartments(carrier: carrier, compartments: [...existing, command.compartment]);
    if (errors.isNotEmpty) return elvRuntimeFailure('ELV_CARRIER_COMPARTMENT_INVALID', ElvFailureCategory.validation, details: {'errors': errors});
    final now = DateTime.now().toUtc();
    await database.into(database.physicalCarrierCompartments).insert(PhysicalCarrierCompartmentsCompanion.insert(
      id: command.compartment.id,
      carrierId: command.compartment.carrierId,
      code: command.compartment.code,
      normalizedCode: command.compartment.normalizedCode,
      sequence: command.compartment.sequence,
      payloadJson: jsonEncode(_crossSectionToMap(command.compartment.crossSection)),
      lifecycleState: command.compartment.lifecycleState.name.toUpperCase(),
      revision: Value(command.compartment.revision),
      createdAt: now,
      updatedAt: now,
      originDeviceId: originDeviceId,
    ));
    return ElvCommandSuccess(command.compartment);
  });

  @override
  Future<ElvCommandResult<PhysicalCarrierCompartment>> updateCompartment(UpdateCarrierCompartmentCommand command) => database.transaction(() async {
    final row = await (database.select(database.physicalCarrierCompartments)..where((candidate) => candidate.id.equals(command.compartment.id) & candidate.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return elvRuntimeFailure('ELV_CARRIER_COMPARTMENT_NOT_FOUND', ElvFailureCategory.notFound);
    if (row.revision != command.expectedRevision) return elvRuntimeFailure('ELV_CARRIER_COMPARTMENT_REVISION_CONFLICT', ElvFailureCategory.revisionConflict, expectedRevision: command.expectedRevision, actualRevision: row.revision);
    final preview = await previewCarrierImpact(command.projectId, row.carrierId);
    if (preview.impactFingerprint != command.expectedImpactFingerprint) return elvRuntimeFailure('ELV_CARRIER_IMPACT_CHANGED', ElvFailureCategory.dependencyImpact);
    final next = PhysicalCarrierCompartment(id: command.compartment.id, carrierId: command.compartment.carrierId, code: command.compartment.code, sequence: command.compartment.sequence, crossSection: command.compartment.crossSection, lifecycleState: command.compartment.lifecycleState, revision: row.revision + 1);
    final carrierRow = await (database.select(database.physicalCarriers)..where((candidate) => candidate.id.equals(next.carrierId))).getSingle();
    final others = (await loadCompartments(next.carrierId)).where((item) => item.id != next.id);
    final errors = validateCarrierCompartments(carrier: _carrierFromRow(carrierRow), compartments: [...others, next]);
    if (errors.isNotEmpty) return elvRuntimeFailure('ELV_CARRIER_COMPARTMENT_INVALID', ElvFailureCategory.validation, details: {'errors': errors});
    await (database.update(database.physicalCarrierCompartments)..where((candidate) => candidate.id.equals(next.id))).write(PhysicalCarrierCompartmentsCompanion(
      code: Value(next.code), normalizedCode: Value(next.normalizedCode), sequence: Value(next.sequence), payloadJson: Value(jsonEncode(_crossSectionToMap(next.crossSection))), lifecycleState: Value(next.lifecycleState.name.toUpperCase()), revision: Value(next.revision), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId),
    ));
    return ElvCommandSuccess(next);
  });

  @override
  Future<ElvCommandResult<CanonicalCableRun>> attachTraversal(AttachTraversalToCarrierCommand command) => database.transaction(() async {
    final run = await (database.select(database.canonicalCableRuns)..where((row) => row.id.equals(command.cableRunId) & row.projectId.equals(command.projectId) & row.deletedAt.isNull())).getSingleOrNull();
    if (run == null) return elvRuntimeFailure('ELV_CABLE_RUN_NOT_FOUND', ElvFailureCategory.notFound);
    if (run.revision != command.expectedCableRunRevision) return elvRuntimeFailure('ELV_CABLE_RUN_REVISION_CONFLICT', ElvFailureCategory.revisionConflict, expectedRevision: command.expectedCableRunRevision, actualRevision: run.revision);
    final traversal = await (database.select(database.cableRunTraversals)..where((row) => row.id.equals(command.traversalId) & row.cableRunId.equals(command.cableRunId) & row.deletedAt.isNull())).getSingleOrNull();
    if (traversal == null) return elvRuntimeFailure('ELV_TRAVERSAL_NOT_FOUND', ElvFailureCategory.notFound);
    final carrier = await (database.select(database.physicalCarriers)..where((row) => row.id.equals(command.carrierId) & row.projectId.equals(command.projectId) & row.lifecycleState.equals('ACTIVE') & row.deletedAt.isNull())).getSingleOrNull();
    if (carrier == null) return elvRuntimeFailure('ELV_CARRIER_NOT_FOUND', ElvFailureCategory.notFound);
    PhysicalCarrierCompartmentRow? compartment;
    if (command.compartmentId != null) {
      compartment = await (database.select(database.physicalCarrierCompartments)..where((row) => row.id.equals(command.compartmentId!) & row.carrierId.equals(command.carrierId) & row.lifecycleState.equals('ACTIVE') & row.deletedAt.isNull())).getSingleOrNull();
      if (compartment == null) return elvRuntimeFailure('ELV_CARRIER_COMPARTMENT_NOT_FOUND', ElvFailureCategory.referenceIntegrity);
    }
    final revisionRow = await (database.select(database.projectDesignRevisions)..where((row) => row.id.equals(run.designRevisionId) & row.state.equals('WORKING') & row.deletedAt.isNull())).getSingleOrNull();
    if (revisionRow == null) return elvRuntimeFailure('ELV_DESIGN_REVISION_READ_ONLY', ElvFailureCategory.lifecycle);
    await (database.update(database.cableRunTraversals)..where((row) => row.id.equals(command.traversalId))).write(CableRunTraversalsCompanion(
      physicalCarrierId: Value(command.carrierId), carrierCompartmentId: Value(command.compartmentId), revision: Value(traversal.revision + 1), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId),
    ));
    final now = DateTime.now().toUtc();
    await database.into(database.traversalCarrierAssignments).insertOnConflictUpdate(TraversalCarrierAssignmentsCompanion.insert(
      traversalId: command.traversalId,
      cableRunId: command.cableRunId,
      projectId: command.projectId,
      designRevisionId: run.designRevisionId,
      carrierId: command.carrierId,
      compartmentId: Value(command.compartmentId),
      revision: Value((await (database.select(database.traversalCarrierAssignments)..where((row) => row.traversalId.equals(command.traversalId))).getSingleOrNull())?.revision ?? 0 + 1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: originDeviceId,
    ));
    await failureProbe.hit(ElvFailurePoints.p4AttachCarrierAfterTraversalUpdate);
    await (database.update(database.canonicalCableRuns)..where((row) => row.id.equals(run.id))).write(CanonicalCableRunsCompanion(revision: Value(run.revision + 1), updatedAt: Value(now), originDeviceId: Value(originDeviceId)));
    final next = CanonicalCableRun(id: run.id, projectId: run.projectId, cableId: run.cableId, designRevisionId: run.designRevisionId, basedOnCableRunId: run.basedOnCableRunId, state: CanonicalCableRunState.values.byName(run.lifecycleState.toLowerCase()), reservePercent: run.reservePercent, terminationAllowanceMm: run.terminationAllowanceMm, revision: run.revision + 1);
    return ElvCommandSuccess(next);
  });
}

Map<String, Object?> _carrierPayload(PhysicalCarrier carrier) => {
  'crossSection': _crossSectionToMap(carrier.crossSection),
  'environmentFacts': {
    'exposure': carrier.environmentFacts.exposure?.name,
    'moistureClassCode': carrier.environmentFacts.moistureClassCode,
    'contaminationClassCode': carrier.environmentFacts.contaminationClassCode,
    'climateClassCode': carrier.environmentFacts.climateClassCode,
    'temperatureRange': carrier.environmentFacts.temperatureRange == null ? null : {'minimumC': carrier.environmentFacts.temperatureRange!.minimumC, 'maximumC': carrier.environmentFacts.temperatureRange!.maximumC},
  },
  'installationFacts': {
    'installationClassCode': carrier.installationFacts.installationClassCode,
    'accessibility': carrier.installationFacts.accessibility?.name,
    'barrierPresent': carrier.installationFacts.barrierPresent,
  },
};

Map<String, Object?> _crossSectionToMap(CarrierCrossSection value) => switch (value) {
  RectangularCarrierCrossSection(:final widthMm, :final heightMm) => {'type': 'RECTANGULAR', 'widthMm': widthMm, 'heightMm': heightMm},
  CircularCarrierCrossSection(:final diameterMm) => {'type': 'CIRCULAR', 'diameterMm': diameterMm},
  CustomCarrierCrossSection(:final areaMm2, :final provenance) => {'type': 'CUSTOM', 'areaMm2': areaMm2, 'provenance': provenance},
};

CarrierCrossSection _crossSectionFromMap(Map<String, dynamic> map) => switch (map['type']) {
  'RECTANGULAR' => RectangularCarrierCrossSection(widthMm: (map['widthMm'] as num).toDouble(), heightMm: (map['heightMm'] as num).toDouble()),
  'CIRCULAR' => CircularCarrierCrossSection((map['diameterMm'] as num).toDouble()),
  'CUSTOM' => CustomCarrierCrossSection(areaMm2: (map['areaMm2'] as num).toDouble(), provenance: map['provenance'] as String),
  _ => throw StateError('Unknown carrier cross-section'),
};

PhysicalCarrier _carrierFromRow(PhysicalCarrierRow row) {
  final payload = (jsonDecode(row.payloadJson) as Map).cast<String, dynamic>();
  final env = (payload['environmentFacts'] as Map).cast<String, dynamic>();
  final install = (payload['installationFacts'] as Map).cast<String, dynamic>();
  final temperature = env['temperatureRange'] == null ? null : (env['temperatureRange'] as Map).cast<String, dynamic>();
  return PhysicalCarrier(
    id: row.id,
    projectId: row.projectId,
    pathwayContextId: row.pathwayContextId,
    code: row.code,
    name: row.name,
    kind: PhysicalCarrierKind.values.byName(row.kind.toLowerCase()),
    crossSection: _crossSectionFromMap((payload['crossSection'] as Map).cast<String, dynamic>()),
    environmentFacts: CarrierEnvironmentFacts(
      exposure: env['exposure'] == null ? null : CarrierEnclosureExposure.values.byName(env['exposure'] as String),
      moistureClassCode: env['moistureClassCode'] as String?,
      contaminationClassCode: env['contaminationClassCode'] as String?,
      climateClassCode: env['climateClassCode'] as String?,
      temperatureRange: temperature == null ? null : CarrierTemperatureRange(minimumC: (temperature['minimumC'] as num).toDouble(), maximumC: (temperature['maximumC'] as num).toDouble()),
    ),
    installationFacts: CarrierInstallationFacts(
      installationClassCode: install['installationClassCode'] as String?,
      accessibility: install['accessibility'] == null ? null : MaintenanceAccessibility.values.byName(install['accessibility'] as String),
      barrierPresent: install['barrierPresent'] as bool? ?? false,
    ),
    lifecycleState: PhysicalCarrierLifecycleState.values.byName(row.lifecycleState.toLowerCase()),
    revision: row.revision,
  );
}

PhysicalCarrierCompartment _compartmentFromRow(PhysicalCarrierCompartmentRow row) => PhysicalCarrierCompartment(
  id: row.id,
  carrierId: row.carrierId,
  code: row.code,
  sequence: row.sequence,
  crossSection: _crossSectionFromMap((jsonDecode(row.payloadJson) as Map).cast<String, dynamic>()),
  lifecycleState: CarrierCompartmentLifecycleState.values.byName(row.lifecycleState.toLowerCase()),
  revision: row.revision,
);
''')

write('apps/mobile/test/data/elv_p4_runtime_closure_test.dart', r'''import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv_command_result.dart';
import 'package:electra_mobile/application/elv_pathway_command.dart';
import 'package:electra_mobile/application/elv_physical_carrier_command.dart';
import 'package:electra_mobile/application/elv_failure_probe.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_pathway_repository.dart';
import 'package:electra_mobile/data/repositories/drift_elv_physical_carrier_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seedProject(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14);
  await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'p', name: 'P4', measurementSystem: 'metric', defaultStructuralHeightMm: 3000, defaultFinishedCeilingHeightMm: 2700, createdAt: now, updatedAt: now, originDeviceId: 'test'));
}

final class _ThrowProbe implements ElvFailureProbe {
  const _ThrowProbe(this.point);
  final String point;
  @override
  Future<void> hit(String actual) async {
    if (actual == point) throw StateError('probe:$actual');
  }
}

void main() {
  test('schema 21 exposes P4 pathway/carrier persistence roots', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 21);
    final names = (await db.customSelect("SELECT name FROM sqlite_master WHERE type='table'").get()).map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll({'pathway_contexts', 'physical_carriers', 'physical_carrier_compartments', 'traversal_carrier_assignments'}));
  });

  test('pathway and carrier round-trip through SQLite', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final pathwayRepo = DriftElvPathwayRepository(db, originDeviceId: 'test');
    const context = PathwayContext(id: 'path-1', projectId: 'p', kind: PathwayContextKind.projectShared, host: ProjectHost('p'), lifecycleState: PathwayContextLifecycleState.active, revision: 1);
    final createdPath = await pathwayRepo.create(const CreatePathwayContextCommand(commandId: 'path-cmd', context: context));
    expect(createdPath, isA<ElvCommandSuccess<PathwayContext>>());
    final carrierRepo = DriftElvPhysicalCarrierRepository(db, originDeviceId: 'test');
    const carrier = PhysicalCarrier(id: 'carrier-1', projectId: 'p', pathwayContextId: 'path-1', code: 'TRAY-01', name: 'Main tray', kind: PhysicalCarrierKind.tray, crossSection: RectangularCarrierCrossSection(widthMm: 200, heightMm: 50), environmentFacts: CarrierEnvironmentFacts(exposure: CarrierEnclosureExposure.indoor), installationFacts: CarrierInstallationFacts(accessibility: MaintenanceAccessibility.accessible), lifecycleState: PhysicalCarrierLifecycleState.active, revision: 1);
    final createdCarrier = await carrierRepo.create(const CreatePhysicalCarrierCommand(commandId: 'carrier-cmd', carrier: carrier));
    expect(createdCarrier, isA<ElvCommandSuccess<PhysicalCarrier>>());
    final reloaded = await carrierRepo.loadCarriers('p');
    expect(reloaded.single.normalizedCode, 'TRAY-01');
    expect(reloaded.single.crossSection.usableAreaMm2, 10000);
  });

  test('pathway hierarchy cycle is rejected before persistence', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final repo = DriftElvPathwayRepository(db, originDeviceId: 'test');
    const a = PathwayContext(id: 'a', projectId: 'p', kind: PathwayContextKind.projectShared, host: ProjectHost('p'), parentContextId: 'b', lifecycleState: PathwayContextLifecycleState.active, revision: 1);
    final result = await repo.create(const CreatePathwayContextCommand(commandId: 'a', context: a));
    expect(result, isA<ElvCommandFailureResult<PathwayContext>>());
    expect(await repo.loadContexts('p'), isEmpty);
  });

  test('P4 attach failure probe rolls back traversal carrier assignment', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final pathwayRepo = DriftElvPathwayRepository(db, originDeviceId: 'test');
    await pathwayRepo.create(const CreatePathwayContextCommand(commandId: 'pc', context: PathwayContext(id: 'path-1', projectId: 'p', kind: PathwayContextKind.projectShared, host: ProjectHost('p'), lifecycleState: PathwayContextLifecycleState.active, revision: 1)));
    final carrierRepo = DriftElvPhysicalCarrierRepository(db, originDeviceId: 'test');
    await carrierRepo.create(const CreatePhysicalCarrierCommand(commandId: 'cc', carrier: PhysicalCarrier(id: 'carrier-1', projectId: 'p', pathwayContextId: 'path-1', code: 'T1', name: 'Tray', kind: PhysicalCarrierKind.tray, crossSection: RectangularCarrierCrossSection(widthMm: 100, heightMm: 50), environmentFacts: CarrierEnvironmentFacts(), installationFacts: CarrierInstallationFacts(), lifecycleState: PhysicalCarrierLifecycleState.active, revision: 1)));
    final now = DateTime.utc(2026, 10, 14);
    await db.into(db.projectDesignRevisions).insert(ProjectDesignRevisionsCompanion.insert(id: 'rev', projectId: 'p', code: 'R1', sequence: 1, state: 'WORKING', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    // P4 rollback is verified at the SQLite transaction boundary with a minimal P3 run/traversal chain.
    await db.customStatement("PRAGMA foreign_keys = OFF");
    await db.into(db.canonicalCableRuns).insert(CanonicalCableRunsCompanion.insert(id: 'run', projectId: 'p', cableId: 'cable-fixture', designRevisionId: 'rev', lifecycleState: 'ACTIVE', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.into(db.cableRunTraversals).insert(CableRunTraversalsCompanion.insert(id: 'tr', cableRunId: 'run', sequence: 1, routeSegmentId: 'segment-fixture', direction: 'FORWARD', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.customStatement("PRAGMA foreign_keys = ON");
    final failingRepo = DriftElvPhysicalCarrierRepository(db, originDeviceId: 'test', failureProbe: const _ThrowProbe(ElvFailurePoints.p4AttachCarrierAfterTraversalUpdate));
    await expectLater(() => failingRepo.attachTraversal(const AttachTraversalToCarrierCommand(commandId: 'attach', projectId: 'p', cableRunId: 'run', traversalId: 'tr', carrierId: 'carrier-1', expectedCableRunRevision: 1)), throwsStateError);
    final traversal = await db.select(db.cableRunTraversals).getSingle();
    expect(traversal.physicalCarrierId, isNull);
    expect(await db.select(db.traversalCarrierAssignments).get(), isEmpty);
  });
}
''')
