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

history_table = r'''@DataClassName('ElvCommandHistoryEntryRow')
class ElvCommandHistoryEntries extends Table {
  TextColumn get projectId => text().references(Projects, #id)();
  IntColumn get sequence => integer()();
  TextColumn get commandId => text()();
  TextColumn get forwardCommandType => text()();
  TextColumn get forwardPayloadSha256 => text()();
  TextColumn get undoClass => text()();
  TextColumn get preconditionFingerprint => text()();
  TextColumn get state => text()();
  TextColumn get inverseCommandType => text().nullable()();
  TextColumn get inversePayloadJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get originDeviceId => text()();

  @override
  Set<Column<Object>> get primaryKey => {projectId, sequence};
}

'''
replace_once(db, "@DriftDatabase(\n", history_table + "@DriftDatabase(\n")
replace_once(db, "    PhysicalCompatibilityFindings,\n", "    PhysicalCompatibilityFindings,\n    ElvCommandHistoryEntries,\n")
replace_once(db, "  int get schemaVersion => 22;", "  int get schemaVersion => 23;")
replace_once(db,
    "        if (from < 22) {\n          await migrator.createTable(physicalProfileSets);\n          await migrator.createTable(physicalProfileSetEntries);\n          await migrator.createTable(physicalCompatibilityFindings);\n        }\n",
    "        if (from < 22) {\n          await migrator.createTable(physicalProfileSets);\n          await migrator.createTable(physicalProfileSetEntries);\n          await migrator.createTable(physicalCompatibilityFindings);\n        }\n        if (from < 23) {\n          await migrator.createTable(elvCommandHistoryEntries);\n        }\n")
replace_once(db,
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_physical_finding_revision ON physical_compatibility_findings(project_id, design_revision_id, subject_key)');\n",
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_physical_finding_revision ON physical_compatibility_findings(project_id, design_revision_id, subject_key)');\n"
    "    await customStatement('CREATE UNIQUE INDEX IF NOT EXISTS ux_elv_command_history_command ON elv_command_history_entries(project_id, command_id)');\n"
    "    await customStatement('CREATE INDEX IF NOT EXISTS idx_elv_command_history_state ON elv_command_history_entries(project_id, state, sequence)');\n")

write('apps/mobile/lib/data/repositories/drift_elv_command_history_repository.dart', r'''import 'package:drift/drift.dart';

import '../../application/elv_command_history_repository.dart';
import '../database/app_database.dart';

final class DriftElvCommandHistoryRepository implements ElvCommandHistoryWriteStore {
  DriftElvCommandHistoryRepository(this.database, {required this.originDeviceId});

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<ElvCommandHistoryRecord?> findUndoCandidate(String projectId) async {
    final row = await (database.select(database.elvCommandHistoryEntries)
          ..where((candidate) => candidate.projectId.equals(projectId) & candidate.state.equals('APPLIED') & candidate.undoClass.equals('REVERSIBLE'))
          ..orderBy([(candidate) => OrderingTerm.desc(candidate.sequence)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _record(row);
  }

  @override
  Future<ElvCommandHistoryRecord?> findRedoCandidate(String projectId) async {
    final row = await (database.select(database.elvCommandHistoryEntries)
          ..where((candidate) => candidate.projectId.equals(projectId) & candidate.state.equals('UNDONE') & candidate.undoClass.equals('REVERSIBLE'))
          ..orderBy([(candidate) => OrderingTerm.asc(candidate.sequence)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _record(row);
  }

  @override
  Future<void> appendCommitted(ElvCommandHistoryRecord record) => database.transaction(() async {
    final errors = record.validate();
    if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
    final maxRow = await database.customSelect(
      'SELECT MAX(sequence) AS max_sequence FROM elv_command_history_entries WHERE project_id = ?',
      variables: [Variable.withString(record.projectId)],
      readsFrom: {database.elvCommandHistoryEntries},
    ).getSingle();
    final expected = (maxRow.readNullable<int>('max_sequence') ?? 0) + 1;
    if (record.sequence != expected) {
      throw StateError('ELV command history sequence must be gap-free. expected=$expected actual=${record.sequence}');
    }
    final now = DateTime.now().toUtc();
    await database.into(database.elvCommandHistoryEntries).insert(ElvCommandHistoryEntriesCompanion.insert(
      projectId: record.projectId,
      sequence: record.sequence,
      commandId: record.commandId,
      forwardCommandType: record.forwardCommandType,
      forwardPayloadSha256: record.forwardPayloadSha256,
      undoClass: record.undoClass.name.toUpperCase(),
      preconditionFingerprint: record.preconditionFingerprint,
      state: record.state.name.toUpperCase(),
      inverseCommandType: Value(record.inverseCommandType),
      inversePayloadJson: Value(record.inversePayloadJson),
      createdAt: now,
      updatedAt: now,
      originDeviceId: originDeviceId,
    ));
  });

  @override
  Future<bool> markUndone({required String projectId, required int sequence, required String expectedPreconditionFingerprint}) => database.transaction(() async {
    final row = await _row(projectId, sequence);
    if (row == null || row.state != 'APPLIED' || row.undoClass != 'REVERSIBLE' || row.preconditionFingerprint != expectedPreconditionFingerprint) return false;
    return (database.update(database.elvCommandHistoryEntries)..where((candidate) => candidate.projectId.equals(projectId) & candidate.sequence.equals(sequence))).write(
      ElvCommandHistoryEntriesCompanion(state: const Value('UNDONE'), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId)),
    ).then((count) => count == 1);
  });

  @override
  Future<bool> markReapplied({required String projectId, required int sequence, required String expectedPreconditionFingerprint}) => database.transaction(() async {
    final row = await _row(projectId, sequence);
    if (row == null || row.state != 'UNDONE' || row.undoClass != 'REVERSIBLE' || row.preconditionFingerprint != expectedPreconditionFingerprint) return false;
    return (database.update(database.elvCommandHistoryEntries)..where((candidate) => candidate.projectId.equals(projectId) & candidate.sequence.equals(sequence))).write(
      ElvCommandHistoryEntriesCompanion(state: const Value('APPLIED'), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId)),
    ).then((count) => count == 1);
  });

  @override
  Future<void> abandonRedoBranch({required String projectId, required int afterSequence}) async {
    await (database.update(database.elvCommandHistoryEntries)..where((candidate) => candidate.projectId.equals(projectId) & candidate.sequence.isBiggerThanValue(afterSequence) & candidate.state.equals('UNDONE'))).write(
      ElvCommandHistoryEntriesCompanion(state: const Value('REDO_ABANDONED'), updatedAt: Value(DateTime.now().toUtc()), originDeviceId: Value(originDeviceId)),
    );
  }

  Future<ElvCommandHistoryEntryRow?> _row(String projectId, int sequence) =>
      (database.select(database.elvCommandHistoryEntries)..where((candidate) => candidate.projectId.equals(projectId) & candidate.sequence.equals(sequence))).getSingleOrNull();

  ElvCommandHistoryRecord _record(ElvCommandHistoryEntryRow row) => ElvCommandHistoryRecord(
    projectId: row.projectId,
    sequence: row.sequence,
    commandId: row.commandId,
    forwardCommandType: row.forwardCommandType,
    forwardPayloadSha256: row.forwardPayloadSha256,
    undoClass: ElvCommandUndoClass.values.byName(_camel(row.undoClass)),
    preconditionFingerprint: row.preconditionFingerprint,
    state: ElvCommandHistoryRecordState.values.byName(_camel(row.state)),
    inverseCommandType: row.inverseCommandType,
    inversePayloadJson: row.inversePayloadJson,
  );
}

String _camel(String value) {
  final parts = value.toLowerCase().split('_');
  if (parts.length == 1) return parts.single;
  return parts.first + parts.skip(1).map((part) => part[0].toUpperCase() + part.substring(1)).join();
}
''')

write('apps/mobile/lib/data/repositories/drift_elv_physical_routing_workspace_data_source.dart', r'''import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/default_elv_physical_routing_workspace_service.dart';
import '../../application/elv_physical_routing_workspace_state.dart';
import '../database/app_database.dart';
import 'drift_elv_design_revision_repository.dart';

final class DriftElvPhysicalRoutingWorkspaceDataSource implements ElvPhysicalRoutingWorkspaceDataSource {
  DriftElvPhysicalRoutingWorkspaceDataSource(this.database, {required this.originDeviceId});

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<PhysicalDesignContext> loadDesignContext(String projectId) =>
      DriftElvDesignRevisionRepository(database, originDeviceId: originDeviceId).context(projectId);

  @override
  Future<PhysicalRoutingSelectionSnapshot> loadSelection({required String projectId, String? connectionId}) async {
    if (connectionId == null) return const PhysicalRoutingSelectionSnapshot();
    final connection = await (database.select(database.engineeringPortConnections)..where((row) => row.projectId.equals(projectId) & row.id.equals(connectionId) & row.deletedAt.isNull())).getSingleOrNull();
    if (connection == null) {
      return PhysicalRoutingSelectionSnapshot(connectionId: connectionId, commandMutationsAllowed: false, blockingIssues: [PhysicalRoutingBlockingIssue(code: 'ELV_CONNECTION_NOT_FOUND', message: 'Engineering connection is unavailable.', entityId: connectionId)]);
    }
    final allocation = await (database.select(database.cableAllocations)
          ..where((row) => row.projectId.equals(projectId) & row.engineeringConnectionId.equals(connectionId) & row.lifecycleState.isIn(['RESERVED', 'ACTIVE']) & row.deletedAt.isNull())
          ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (allocation == null) return PhysicalRoutingSelectionSnapshot(connectionId: connectionId);
    final terminations = await (database.select(database.cableTerminationMappings)..where((row) => row.allocationId.equals(allocation.id) & row.deletedAt.isNull())).get();
    final design = await loadDesignContext(projectId);
    CanonicalCableRunRow? run;
    if (design.workingDesignRevisionId != null) {
      run = await (database.select(database.canonicalCableRuns)
            ..where((row) => row.projectId.equals(projectId) & row.cableId.equals(allocation.cableId) & row.designRevisionId.equals(design.workingDesignRevisionId!) & row.lifecycleState.equals('ACTIVE') & row.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();
    } else if (design.latestFrozenRevisionId != null) {
      run = await (database.select(database.canonicalCableRuns)
            ..where((row) => row.projectId.equals(projectId) & row.cableId.equals(allocation.cableId) & row.designRevisionId.equals(design.latestFrozenRevisionId!) & row.deletedAt.isNull())
            ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])
            ..limit(1))
          .getSingleOrNull();
    }
    var carrierComplete = false;
    if (run != null) {
      final traversals = await (database.select(database.cableRunTraversals)..where((row) => row.cableRunId.equals(run!.id) & row.deletedAt.isNull())).get();
      carrierComplete = traversals.isNotEmpty && traversals.every((row) => row.physicalCarrierId != null);
    }
    return PhysicalRoutingSelectionSnapshot(
      connectionId: connectionId,
      cableId: allocation.cableId,
      allocationId: allocation.id,
      cableRunId: run?.id,
      terminationSetComplete: terminations.isNotEmpty,
      carrierAssignmentComplete: carrierComplete,
      commandMutationsAllowed: design.editingAllowed,
    );
  }

  @override
  Stream<void> watchChanges(String projectId) => database.customSelect(
    'SELECT ? AS project_id',
    variables: [Variable.withString(projectId)],
    readsFrom: {
      database.projectDesignRevisions,
      database.engineeringPortConnections,
      database.cableAllocations,
      database.cableTerminationMappings,
      database.canonicalCableRuns,
      database.cableRunTraversals,
      database.traversalCarrierAssignments,
      database.physicalCompatibilityFindings,
    },
  ).watch().map((_) {});
}
''')

write('apps/mobile/lib/data/repositories/drift_elv_physical_trace_service.dart', r'''import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_physical_trace_service.dart';
import '../database/app_database.dart';
import 'drift_elv_cable_allocation_repository.dart';
import 'drift_elv_cable_repository.dart';
import 'drift_elv_cable_run_repository.dart';
import 'drift_elv_design_revision_repository.dart';
import 'drift_elv_pathway_repository.dart';
import 'drift_elv_physical_calculation_result_store.dart';
import 'drift_elv_physical_carrier_repository.dart';
import 'drift_elv_physical_compatibility_repository.dart';

final class DriftElvPhysicalTraceService implements ElvPhysicalTraceService {
  DriftElvPhysicalTraceService(
    this.database, {
    required this.originDeviceId,
    required this.compatibilityRepository,
  });

  final AppDatabase database;
  final String originDeviceId;
  final DriftElvPhysicalCompatibilityRepository compatibilityRepository;

  @override
  Future<PhysicalTraceResult> traceConnection(String projectId, String connectionId) async {
    final row = await (database.select(database.engineeringPortConnections)..where((candidate) => candidate.projectId.equals(projectId) & candidate.id.equals(connectionId) & candidate.deletedAt.isNull())).getSingleOrNull();
    if (row == null) throw StateError('Engineering connection not found: $connectionId');
    final connection = EngineeringConnection.fromMap(jsonDecode(row.payloadJson) as Map<String, dynamic>);
    final allocationRow = await (database.select(database.cableAllocations)
          ..where((candidate) => candidate.projectId.equals(projectId) & candidate.engineeringConnectionId.equals(connectionId) & candidate.lifecycleState.isIn(['RESERVED', 'ACTIVE']) & candidate.deletedAt.isNull())
          ..orderBy([(candidate) => OrderingTerm.desc(candidate.updatedAt)])
          ..limit(1))
        .getSingleOrNull();
    return _trace(projectId: projectId, connection: connection, allocationId: allocationRow?.id, cableId: allocationRow?.cableId);
  }

  @override
  Future<PhysicalTraceResult> traceCable(String projectId, String cableId) async {
    final allocationRow = await (database.select(database.cableAllocations)
          ..where((candidate) => candidate.projectId.equals(projectId) & candidate.cableId.equals(cableId) & candidate.lifecycleState.isIn(['RESERVED', 'ACTIVE']) & candidate.deletedAt.isNull())
          ..orderBy([(candidate) => OrderingTerm.asc(candidate.id)])
          ..limit(1))
        .getSingleOrNull();
    if (allocationRow == null) throw StateError('Active cable allocation not found: $cableId');
    final connectionRow = await (database.select(database.engineeringPortConnections)..where((candidate) => candidate.id.equals(allocationRow.engineeringConnectionId) & candidate.projectId.equals(projectId) & candidate.deletedAt.isNull())).getSingle();
    final connection = EngineeringConnection.fromMap(jsonDecode(connectionRow.payloadJson) as Map<String, dynamic>);
    return _trace(projectId: projectId, connection: connection, allocationId: allocationRow.id, cableId: cableId);
  }

  Future<PhysicalTraceResult> _trace({required String projectId, required EngineeringConnection connection, String? allocationId, String? cableId}) async {
    final design = await DriftElvDesignRevisionRepository(database, originDeviceId: originDeviceId).context(projectId);
    final revisionId = design.workingDesignRevisionId ?? design.latestFrozenRevisionId;
    if (revisionId == null) throw StateError('Physical design revision not found for project $projectId');
    final cableRepo = DriftElvCableRepository(database);
    final allocationRepo = DriftElvCableAllocationRepository(database);
    final runRepo = DriftElvCableRunRepository(database, originDeviceId: originDeviceId);
    final carrierRepo = DriftElvPhysicalCarrierRepository(database, originDeviceId: originDeviceId);
    final pathwayRepo = DriftElvPathwayRepository(database, originDeviceId: originDeviceId);
    final calculationStore = DriftElvPhysicalCalculationResultStore(database, originDeviceId: originDeviceId);
    final cable = cableId == null ? null : await cableRepo.findCable(projectId, cableId);
    final allocation = allocationId == null ? null : await allocationRepo.findAllocation(projectId, allocationId);
    final selection = allocationId == null ? null : await allocationRepo.loadSelectionEvidence(projectId, allocationId);
    final terminations = allocationId == null ? <CableTerminationMapping>[] : await allocationRepo.loadTerminationMappings(projectId, allocationId);
    CanonicalCableRun? run;
    List<CableRunTraversal> traversals = const [];
    if (cableId != null) {
      final runs = await runRepo.loadRuns(projectId, revisionId);
      final candidates = runs.where((candidate) => candidate.cableId == cableId && candidate.state == CanonicalCableRunState.active).toList(growable: false);
      if (candidates.isNotEmpty) {
        run = candidates.first;
        traversals = await runRepo.loadTraversals(run.id);
      }
    }
    final allCarriers = await carrierRepo.loadCarriers(projectId);
    final carrierIds = traversals.map((item) => item.physicalCarrierId).whereType<String>().toSet();
    final carriers = allCarriers.where((item) => carrierIds.contains(item.id)).toList(growable: false);
    final allPathways = await pathwayRepo.loadContexts(projectId);
    final pathwayIds = carriers.map((item) => item.pathwayContextId).toSet();
    final pathways = allPathways.where((item) => pathwayIds.contains(item.id)).toList(growable: false);
    final subjectKey = run?.id ?? cableId ?? connection.id;
    final findings = await compatibilityRepository.loadFindings(projectId: projectId, designRevisionId: revisionId, subjectKey: subjectKey);
    final calculations = <ElvPhysicalCalculationResult<Object?>>[];
    for (final row in await (database.select(database.projectDerivedResults)..where((candidate) => candidate.projectId.equals(projectId) & candidate.nodeKey.like('elv3:$revisionId:%') & candidate.deletedAt.isNull())).get()) {
      final result = await calculationStore.find(projectId, row.nodeKey);
      if (result != null && (result.subjectId == run?.id || result.subjectId == subjectKey)) calculations.add(result);
    }
    return PhysicalTraceResult(
      projectId: projectId,
      designRevisionId: revisionId,
      connection: connection,
      cable: cable,
      allocation: allocation,
      resourceSelection: selection,
      terminations: terminations,
      run: run,
      traversals: traversals,
      carriers: carriers,
      pathwayContexts: pathways,
      findings: findings,
      calculations: calculations,
    );
  }
}
''')

write('apps/mobile/test/data/elv_p7_runtime_closure_test.dart', r'''import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/default_elv_physical_routing_workspace_service.dart';
import 'package:electra_mobile/application/elv_command_history_repository.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_command_history_repository.dart';
import 'package:electra_mobile/data/repositories/drift_elv_physical_routing_workspace_data_source.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _seedProject(AppDatabase db) async {
  final now = DateTime.utc(2026, 10, 14);
  await db.into(db.projects).insert(ProjectsCompanion.insert(id: 'p', name: 'P7', measurementSystem: 'metric', defaultStructuralHeightMm: 3000, defaultFinishedCeilingHeightMm: 2700, createdAt: now, updatedAt: now, originDeviceId: 'test'));
}

void main() {
  test('schema 23 persists command history and undo/redo state across reopen semantics', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    expect(db.schemaVersion, 23);
    final history = DriftElvCommandHistoryRepository(db, originDeviceId: 'test');
    const record = ElvCommandHistoryRecord(projectId: 'p', sequence: 1, commandId: 'cmd-1', forwardCommandType: 'RerouteCableRun', forwardPayloadSha256: 'sha', undoClass: ElvCommandUndoClass.reversible, preconditionFingerprint: 'fp', state: ElvCommandHistoryRecordState.applied, inverseCommandType: 'RerouteCableRun', inversePayloadJson: '{}');
    await history.appendCommitted(record);
    expect((await history.findUndoCandidate('p'))!.commandId, 'cmd-1');
    expect(await history.markUndone(projectId: 'p', sequence: 1, expectedPreconditionFingerprint: 'wrong'), isFalse);
    expect(await history.markUndone(projectId: 'p', sequence: 1, expectedPreconditionFingerprint: 'fp'), isTrue);
    expect((await history.findRedoCandidate('p'))!.commandId, 'cmd-1');
    expect(await history.markReapplied(projectId: 'p', sequence: 1, expectedPreconditionFingerprint: 'fp'), isTrue);
    expect((await history.findUndoCandidate('p'))!.sequence, 1);
  });

  test('workspace data source derives WORKING editable and FROZEN read-only state from persisted revisions', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final now = DateTime.utc(2026, 10, 14);
    await db.into(db.projectDesignRevisions).insert(ProjectDesignRevisionsCompanion.insert(id: 'rev-w', projectId: 'p', code: 'R1', sequence: 1, state: 'WORKING', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    final source = DriftElvPhysicalRoutingWorkspaceDataSource(db, originDeviceId: 'test');
    var context = await source.loadDesignContext('p');
    expect(context.workingDesignRevisionId, 'rev-w');
    expect(context.editingAllowed, isTrue);
    await (db.update(db.projectDesignRevisions)..where((row) => row.id.equals('rev-w'))).write(const ProjectDesignRevisionsCompanion(state: Value('FROZEN'), revision: Value(2)));
    context = await source.loadDesignContext('p');
    expect(context.workingDesignRevisionId, isNull);
    expect(context.latestFrozenRevisionId, 'rev-w');
    expect(context.editingAllowed, isFalse);
  });

  test('workspace selection is reconstructed from persisted connection allocation termination run and carrier assignment', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await _seedProject(db);
    final now = DateTime.utc(2026, 10, 14);
    await db.into(db.projectDesignRevisions).insert(ProjectDesignRevisionsCompanion.insert(id: 'rev', projectId: 'p', code: 'R1', sequence: 1, state: 'WORKING', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final connection = EngineeringConnection(id: 'conn', systemId: 'sys', fromPortId: 'a', toPortId: 'b', profileId: 'profile', medium: ConnectionMedium.copper);
    await db.into(db.engineeringPortConnections).insert(EngineeringPortConnectionsCompanion.insert(id: 'conn', projectId: 'p', systemId: 'sys', fromPortId: 'a', toPortId: 'b', profileId: 'profile', payloadJson: jsonEncode(connection.toMap()), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.into(db.cableAllocations).insert(CableAllocationsCompanion.insert(id: 'alloc', projectId: 'p', engineeringConnectionId: 'conn', cableId: 'cable', lifecycleState: 'ACTIVE', createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.into(db.cableTerminationMappings).insert(CableTerminationMappingsCompanion.insert(id: 'term', allocationId: 'alloc', resourceIdentity: '__WHOLE_CABLE__', endRole: 'FROM', endpointPortId: 'a', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.into(db.canonicalCableRuns).insert(CanonicalCableRunsCompanion.insert(id: 'run', projectId: 'p', cableId: 'cable', designRevisionId: 'rev', lifecycleState: 'ACTIVE', revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.into(db.cableRunTraversals).insert(CableRunTraversalsCompanion.insert(id: 'tr', cableRunId: 'run', sequence: 1, routeSegmentId: 'segment', direction: 'FORWARD', physicalCarrierId: const Value('carrier'), revision: const Value(1), createdAt: now, updatedAt: now, originDeviceId: 'test'));
    await db.customStatement('PRAGMA foreign_keys = ON');
    final source = DriftElvPhysicalRoutingWorkspaceDataSource(db, originDeviceId: 'test');
    final selection = await source.loadSelection(projectId: 'p', connectionId: 'conn');
    expect(selection.cableId, 'cable');
    expect(selection.allocationId, 'alloc');
    expect(selection.terminationSetComplete, isTrue);
    expect(selection.cableRunId, 'run');
    expect(selection.carrierAssignmentComplete, isTrue);
    expect(selection.commandMutationsAllowed, isTrue);
  });
}
''')
