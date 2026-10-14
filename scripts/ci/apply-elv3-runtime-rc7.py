from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def write(path: str, content: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)

write('apps/mobile/test/data/elv_p8_vertical_matrix_test.dart', r'''import 'dart:io';

import 'package:drift/drift.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv_database_reopen.dart';
import '../support/elv_vertical_fixture_plan.dart';

String _name(ElvVerticalDiscipline discipline) => discipline.name.toUpperCase();

Future<void> _seedVertical(AppDatabase db, ElvVerticalFixturePlan plan) async {
  final d = _name(plan.discipline);
  final projectId = 'p-$d';
  final revisionId = 'rev-$d';
  final now = DateTime.utc(2026, 10, 14);
  await db.customStatement('PRAGMA foreign_keys = OFF');
  await db.into(db.projects).insert(ProjectsCompanion.insert(
    id: projectId,
    name: '$d vertical',
    measurementSystem: 'metric',
    defaultStructuralHeightMm: 3000,
    defaultFinishedCeilingHeightMm: 2700,
    createdAt: now,
    updatedAt: now,
    originDeviceId: 'p8',
  ));
  await db.into(db.projectDesignRevisions).insert(ProjectDesignRevisionsCompanion.insert(
    id: revisionId,
    projectId: projectId,
    code: 'R1',
    sequence: 1,
    state: 'WORKING',
    revision: const Value(1),
    createdAt: now,
    updatedAt: now,
    originDeviceId: 'p8',
  ));
  await db.into(db.pathwayContexts).insert(PathwayContextsCompanion.insert(
    id: 'path-$d',
    projectId: projectId,
    kind: 'PROJECT_SHARED',
    hostType: 'PROJECT',
    hostJson: '{"projectId":"$projectId"}',
    lifecycleState: 'ACTIVE',
    revision: const Value(1),
    createdAt: now,
    updatedAt: now,
    originDeviceId: 'p8',
  ));
  await db.into(db.physicalCarriers).insert(PhysicalCarriersCompanion.insert(
    id: 'carrier-$d',
    projectId: projectId,
    pathwayContextId: 'path-$d',
    code: 'TRAY-$d',
    normalizedCode: 'TRAY-$d',
    name: '$d carrier',
    kind: 'TRAY',
    payloadJson: '{"crossSection":{"type":"RECTANGULAR","widthMm":200,"heightMm":50},"environmentFacts":{},"installationFacts":{}}',
    lifecycleState: 'ACTIVE',
    revision: const Value(1),
    createdAt: now,
    updatedAt: now,
    originDeviceId: 'p8',
  ));

  for (var i = 0; i < plan.connectionCount; i++) {
    final connectionId = 'conn-$d-$i';
    await db.into(db.engineeringPortConnections).insert(EngineeringPortConnectionsCompanion.insert(
      id: connectionId,
      projectId: projectId,
      systemId: 'system-$d',
      fromPortId: 'from-$d-$i',
      toPortId: 'to-$d-$i',
      profileId: 'profile-$d',
      payloadJson: '{"id":"$connectionId","systemId":"system-$d","fromPortId":"from-$d-$i","toPortId":"to-$d-$i","profileId":"profile-$d","medium":"copper","groupId":null}',
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p8',
    ));
  }

  for (var i = 0; i < plan.cableCount; i++) {
    await db.into(db.elvCables).insert(ElvCablesCompanion.insert(
      id: 'cable-$d-$i',
      projectId: projectId,
      label: '$d-${i + 1}',
      normalizedLabel: '$d-${i + 1}',
      name: '$d cable ${i + 1}',
      definitionCatalogId: 'catalog-$d',
      definitionCatalogVersion: '1',
      definitionCode: 'DEF-$d',
      definitionContentHash: 'hash-$d',
      lifecycleState: 'ACTIVE',
      revision: const Value(1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p8',
    ));
  }

  for (var i = 0; i < plan.allocationCount; i++) {
    final allocationId = 'alloc-$d-$i';
    final cableId = 'cable-$d-${i % plan.cableCount}';
    final connectionId = 'conn-$d-${i % plan.connectionCount}';
    await db.into(db.cableAllocations).insert(CableAllocationsCompanion.insert(
      id: allocationId,
      projectId: projectId,
      engineeringConnectionId: connectionId,
      cableId: cableId,
      lifecycleState: 'ACTIVE',
      revision: const Value(1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p8',
    ));
    await db.into(db.cableTerminationMappings).insert(CableTerminationMappingsCompanion.insert(
      id: 'term-$d-$i',
      allocationId: allocationId,
      resourceIdentity: '__WHOLE_CABLE__',
      endRole: 'FROM',
      endpointPortId: 'from-$d-${i % plan.connectionCount}',
      revision: const Value(1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p8',
    ));
  }

  for (var i = 0; i < plan.cableCount; i++) {
    await db.into(db.canonicalCableRuns).insert(CanonicalCableRunsCompanion.insert(
      id: 'run-$d-$i',
      projectId: projectId,
      cableId: 'cable-$d-$i',
      designRevisionId: revisionId,
      lifecycleState: 'ACTIVE',
      revision: const Value(1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p8',
    ));
  }

  for (var i = 0; i < plan.minimumTraversalCount; i++) {
    final runId = 'run-$d-${i % plan.cableCount}';
    final traversalId = 'traversal-$d-$i';
    await db.into(db.cableRunTraversals).insert(CableRunTraversalsCompanion.insert(
      id: traversalId,
      cableRunId: runId,
      sequence: i + 1,
      routeSegmentId: 'segment-$d-$i',
      direction: 'FORWARD',
      physicalCarrierId: plan.requiresCarrierAssignment ? Value('carrier-$d') : const Value.absent(),
      revision: const Value(1),
      createdAt: now,
      updatedAt: now,
      originDeviceId: 'p8',
    ));
    if (plan.requiresCarrierAssignment) {
      await db.into(db.traversalCarrierAssignments).insert(TraversalCarrierAssignmentsCompanion.insert(
        traversalId: traversalId,
        cableRunId: runId,
        projectId: projectId,
        designRevisionId: revisionId,
        carrierId: 'carrier-$d',
        revision: const Value(1),
        createdAt: now,
        updatedAt: now,
        originDeviceId: 'p8',
      ));
    }
  }

  await db.into(db.commandExecutionRecords).insert(CommandExecutionRecordsCompanion.insert(
    projectId: projectId,
    commandId: 'vertical-$d',
    commandType: 'P8_VERTICAL_FIXTURE',
    payloadSchemaVersion: 1,
    normalizedPayloadSha256: 'sha-$d',
    outcomeKind: 'SUCCESS',
    logicalResultJson: '{"discipline":"$d"}',
    createdAt: now,
    committedAt: now,
    originDeviceId: 'p8',
  ));
  await db.into(db.commandExecutionRecords).insertOnConflictUpdate(CommandExecutionRecordsCompanion.insert(
    projectId: projectId,
    commandId: 'vertical-$d',
    commandType: 'P8_VERTICAL_FIXTURE',
    payloadSchemaVersion: 1,
    normalizedPayloadSha256: 'sha-$d',
    outcomeKind: 'SUCCESS',
    logicalResultJson: '{"discipline":"$d"}',
    createdAt: now,
    committedAt: now,
    originDeviceId: 'p8',
  ));

  await db.into(db.designRevisionPhysicalSnapshots).insert(DesignRevisionPhysicalSnapshotsCompanion.insert(
    designRevisionId: revisionId,
    projectId: projectId,
    schemaVersion: 23,
    payloadJson: '{"discipline":"$d","state":"FROZEN"}',
    payloadSha256: 'snapshot-$d',
    createdAt: now,
    originDeviceId: 'p8',
  ));
  await (db.update(db.projectDesignRevisions)..where((row) => row.id.equals(revisionId))).write(ProjectDesignRevisionsCompanion(
    state: const Value('FROZEN'),
    snapshotSchemaVersion: const Value(23),
    snapshotHash: Value('snapshot-$d'),
    frozenAt: Value(now),
    revision: const Value(2),
    updatedAt: Value(now),
    originDeviceId: const Value('p8'),
  ));
  await db.customStatement('PRAGMA foreign_keys = ON');
}

Future<int> _count(AppDatabase db, String table, String projectId) async {
  final row = await db.customSelect('SELECT COUNT(*) AS c FROM $table WHERE project_id = ?', variables: [Variable.withString(projectId)]).getSingle();
  return row.read<int>('c');
}

void main() {
  for (final plan in ElvVerticalFixturePlans.all) {
    test('${plan.discipline.name} survives SQLite reopen with frozen physical chain and exact cardinality', () async {
      final directory = await Directory.systemTemp.createTemp('electra-p8-${plan.discipline.name}-');
      addTearDown(() async { if (await directory.exists()) await directory.delete(recursive: true); });
      final harness = ElvDatabaseReopenHarness(File('${directory.path}/vertical.sqlite'));
      var db = harness.open();
      await _seedVertical(db, plan);
      db = await harness.reopen(db);
      addTearDown(db.close);
      final d = _name(plan.discipline);
      final projectId = 'p-$d';
      expect(await _count(db, 'engineering_port_connections', projectId), plan.connectionCount);
      expect(await _count(db, 'elv_cables', projectId), plan.cableCount);
      expect(await _count(db, 'cable_allocations', projectId), plan.allocationCount);
      expect(await _count(db, 'canonical_cable_runs', projectId), plan.cableCount);
      expect(await _count(db, 'traversal_carrier_assignments', projectId), plan.requiresCarrierAssignment ? plan.minimumTraversalCount : 0);
      final revision = await (db.select(db.projectDesignRevisions)..where((row) => row.id.equals('rev-$d'))).getSingle();
      expect(revision.state, 'FROZEN');
      expect(revision.snapshotHash, 'snapshot-$d');
      expect(await (db.select(db.designRevisionPhysicalSnapshots)..where((row) => row.designRevisionId.equals('rev-$d'))).getSingle(), isNotNull);
      final ledger = await (db.select(db.commandExecutionRecords)..where((row) => row.projectId.equals(projectId) & row.commandId.equals('vertical-$d'))).get();
      expect(ledger, hasLength(1), reason: 'same command identity must remain a single persisted ledger record');
    });
  }
}
''')
