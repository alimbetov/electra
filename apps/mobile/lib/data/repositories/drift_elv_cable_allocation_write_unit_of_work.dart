import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_cable_allocation_repository.dart';
import '../../application/elv_write_unit_of_work.dart';
import '../database/app_database.dart';

final class DriftElvCableAllocationWriteUnitOfWork
    implements ElvWriteUnitOfWork<ElvAllocationWriteSession> {
  const DriftElvCableAllocationWriteUnitOfWork(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<T> run<T>(
    Future<T> Function(ElvAllocationWriteSession session) action,
  ) => database.transaction(() async {
    final session = _DriftElvAllocationWriteSession(
      database,
      originDeviceId: originDeviceId,
    );
    return action(session);
  });
}

final class _DriftElvAllocationWriteSession
    implements ElvAllocationWriteSession {
  _DriftElvAllocationWriteSession(
    AppDatabase database, {
    required String originDeviceId,
  }) : commandLedger = _P2CommandLedgerStore(database),
       allocations = _DriftElvAllocationWriteStore(
         database,
         originDeviceId: originDeviceId,
       ),
       references = _P2ReferenceReadStore(database);

  @override
  final ElvCommandLedgerStore commandLedger;

  @override
  final ElvAllocationWriteStore allocations;

  @override
  final ElvReferenceReadStore references;
}

final class _P2CommandLedgerStore implements ElvCommandLedgerStore {
  const _P2CommandLedgerStore(this.database);
  final AppDatabase database;

  @override
  Future<ElvCommandLedgerEntry?> find(
    String projectId,
    String commandId,
  ) async {
    final row =
        await (database.select(database.commandExecutionRecords)..where(
          (candidate) =>
              candidate.projectId.equals(projectId) &
              candidate.commandId.equals(commandId),
        )).getSingleOrNull();
    if (row == null) return null;
    return ElvCommandLedgerEntry(
      projectId: row.projectId,
      commandId: row.commandId,
      commandType: row.commandType,
      payloadSchemaVersion: row.payloadSchemaVersion,
      normalizedPayloadSha256: row.normalizedPayloadSha256,
      outcomeKind: row.outcomeKind,
      logicalResultJson: row.logicalResultJson,
      createdAt: row.createdAt,
      committedAt: row.committedAt,
      originDeviceId: row.originDeviceId,
    );
  }

  @override
  Future<void> save(ElvCommandLedgerEntry entry) async {
    await database
        .into(database.commandExecutionRecords)
        .insert(
          CommandExecutionRecordsCompanion.insert(
            projectId: entry.projectId,
            commandId: entry.commandId,
            commandType: entry.commandType,
            payloadSchemaVersion: entry.payloadSchemaVersion,
            normalizedPayloadSha256: entry.normalizedPayloadSha256,
            outcomeKind: entry.outcomeKind,
            logicalResultJson: entry.logicalResultJson,
            createdAt: entry.createdAt,
            committedAt: entry.committedAt,
            originDeviceId: entry.originDeviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    final persisted = await find(entry.projectId, entry.commandId);
    if (persisted == null ||
        persisted.commandType != entry.commandType ||
        persisted.normalizedPayloadSha256 != entry.normalizedPayloadSha256 ||
        persisted.outcomeKind != entry.outcomeKind ||
        persisted.logicalResultJson != entry.logicalResultJson) {
      throw StateError('ELV command ledger conflict.');
    }
  }
}

final class _P2ReferenceReadStore implements ElvReferenceReadStore {
  const _P2ReferenceReadStore(this.database);
  final AppDatabase database;

  @override
  Future<CableDefinition> resolveCableDefinition(
    String projectId,
    CableDefinitionRef ref,
  ) async {
    final normalized = ref.normalized();
    final row =
        await (database.select(database.engineeringReferenceCatalogs)..where(
          (candidate) =>
              candidate.projectId.equals(projectId) &
              candidate.id.equals(normalized.catalogId) &
              candidate.catalogVersion.equals(normalized.catalogVersion) &
              candidate.deletedAt.isNull(),
        )).getSingleOrNull();
    if (row == null) throw StateError('Catalog edition not found.');
    final catalog = EngineeringReferenceCatalog.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    final definition = catalog.cableDefinition(normalized.definitionCode);
    if (cableDefinitionContentHashV1(definition) !=
        normalized.definitionContentHash) {
      throw StateError('Cable definition hash mismatch.');
    }
    return definition;
  }
}

final class _DriftElvAllocationWriteStore implements ElvAllocationWriteStore {
  const _DriftElvAllocationWriteStore(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<CableAllocation?> findAllocation(
    String projectId,
    String allocationId,
  ) async {
    final row =
        await (database.select(database.cableAllocations)..where(
          (candidate) =>
              candidate.projectId.equals(projectId) &
              candidate.id.equals(allocationId) &
              candidate.deletedAt.isNull(),
        )).getSingleOrNull();
    return row == null ? null : _allocation(row);
  }

  @override
  Future<List<CableAllocation>> loadCableAllocations(
    String projectId,
    String cableId,
  ) async => (await (database.select(database.cableAllocations)..where(
        (row) =>
            row.projectId.equals(projectId) &
            row.cableId.equals(cableId) &
            row.deletedAt.isNull(),
      )).get())
      .map(_allocation)
      .toList(growable: false);

  @override
  Future<CableAllocationResourceSelectionEvidence?> loadSelectionEvidence(
    String projectId,
    String allocationId,
  ) async {
    final allocation = await findAllocation(projectId, allocationId);
    if (allocation == null) return null;
    final row =
        await (database.select(database.cableAllocationResourceSelections)
          ..where(
            (candidate) => candidate.allocationId.equals(allocationId),
          )).getSingleOrNull();
    if (row == null) return null;
    return CableAllocationResourceSelectionEvidence(
      allocationId: row.allocationId,
      cableDefinitionRef: CableDefinitionRef.fromMap(
        jsonDecode(row.cableDefinitionRefJson) as Map<String, dynamic>,
      ),
      selection: cableResourceSelectionFromMap(
        jsonDecode(row.selectionJson) as Map<String, dynamic>,
      ),
      resolvedAtoms: (jsonDecode(row.resolvedAtomsJson) as List).cast<String>(),
      selectionSha256: row.selectionSha256,
    );
  }

  @override
  Future<List<CableTerminationMapping>> loadTerminationMappings(
    String projectId,
    String allocationId,
  ) async {
    if (await findAllocation(projectId, allocationId) == null) return const [];
    final rows =
        await (database.select(database.cableTerminationMappings)..where(
          (row) =>
              row.allocationId.equals(allocationId) & row.deletedAt.isNull(),
        )).get();
    return rows
        .map(
          (row) => CableTerminationMapping(
            id: row.id,
            allocationId: row.allocationId,
            resourceIdentity: row.resourceIdentity,
            end: CableTerminationEnd.values.byName(row.endRole.toLowerCase()),
            endpointPortId: row.endpointPortId,
            endpointTerminalRef: row.endpointTerminalRef,
            terminationRole: row.terminationRole,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Cable?> findCable(String projectId, String cableId) async {
    final row =
        await (database.select(database.elvCables)..where(
          (candidate) =>
              candidate.projectId.equals(projectId) &
              candidate.id.equals(cableId) &
              candidate.deletedAt.isNull(),
        )).getSingleOrNull();
    if (row == null) return null;
    return Cable(
      id: row.id,
      projectId: row.projectId,
      label: row.label,
      name: row.name,
      definitionRef: CableDefinitionRef(
        catalogId: row.definitionCatalogId,
        catalogVersion: row.definitionCatalogVersion,
        definitionCode: row.definitionCode,
        definitionContentHash: row.definitionContentHash,
      ),
      lifecycleState: CableLifecycleState.values.byName(
        row.lifecycleState.toLowerCase(),
      ),
      revision: row.revision,
    );
  }

  @override
  Future<ElvConnectionEndpoints?> findConnection(
    String projectId,
    String connectionId,
  ) async {
    final row =
        await (database.select(database.engineeringPortConnections)..where(
          (candidate) =>
              candidate.projectId.equals(projectId) &
              candidate.id.equals(connectionId) &
              candidate.deletedAt.isNull(),
        )).getSingleOrNull();
    if (row == null) return null;
    final connection = EngineeringConnection.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    return ElvConnectionEndpoints(
      connectionId: row.id,
      projectId: row.projectId,
      fromPortId: row.fromPortId,
      toPortId: row.toPortId,
      wired: connection.medium == ConnectionMedium.wired,
    );
  }

  @override
  Future<bool> connectionHasConsumingAllocation(
    String projectId,
    String connectionId, {
    String? excludingAllocationId,
  }) async {
    final query = database.select(database.cableAllocations)..where(
      (row) =>
          row.projectId.equals(projectId) &
          row.engineeringConnectionId.equals(connectionId) &
          row.lifecycleState.isIn(const ['RESERVED', 'ACTIVE']) &
          row.deletedAt.isNull(),
    );
    if (excludingAllocationId != null) {
      query.where((row) => row.id.isNotValue(excludingAllocationId));
    }
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<bool> insertDraft(CableAllocation allocation) async {
    final now = DateTime.now().toUtc();
    final inserted = await database
        .into(database.cableAllocations)
        .insert(
          CableAllocationsCompanion.insert(
            id: allocation.id,
            projectId: allocation.projectId,
            engineeringConnectionId: allocation.engineeringConnectionId,
            cableId: allocation.cableId,
            lifecycleState: 'DRAFT',
            transitionRef: Value(allocation.transitionRef),
            revision: Value(allocation.revision),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    return inserted > 0;
  }

  @override
  Future<ElvAllocationMutationOutcome> reserve({
    required CableAllocation allocation,
    required int expectedRevision,
    required CableAllocationResourceSelectionEvidence evidence,
  }) async {
    final evidenceInserted = await database
        .into(database.cableAllocationResourceSelections)
        .insert(
          CableAllocationResourceSelectionsCompanion.insert(
            allocationId: allocation.id,
            cableDefinitionRefJson: jsonEncode(
              evidence.cableDefinitionRef.normalized().toMap(),
            ),
            selectionJson: jsonEncode(evidence.selection.toMap()),
            resolvedAtomsJson: jsonEncode(evidence.resolvedAtoms),
            selectionSha256: evidence.selectionSha256,
            createdAt: DateTime.now().toUtc(),
            originDeviceId: originDeviceId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    if (evidenceInserted == 0) {
      return ElvAllocationMutationOutcome.immutableEvidenceConflict;
    }

    final now = DateTime.now().toUtc();
    for (final atom in evidence.resolvedAtoms) {
      final inserted = await database
          .into(database.cableResourceClaims)
          .insert(
            CableResourceClaimsCompanion.insert(
              allocationId: allocation.id,
              cableId: allocation.cableId,
              resourceAtom: atom,
              createdAt: now,
              originDeviceId: originDeviceId,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      if (inserted == 0) {
        await (database.delete(database.cableResourceClaims)
          ..where((row) => row.allocationId.equals(allocation.id))).go();
        await (database.delete(database.cableAllocationResourceSelections)
          ..where((row) => row.allocationId.equals(allocation.id))).go();
        return ElvAllocationMutationOutcome.resourceOverlap;
      }
    }

    final affected = await (database.update(database.cableAllocations)..where(
      (row) =>
          row.id.equals(allocation.id) &
          row.projectId.equals(allocation.projectId) &
          row.revision.equals(expectedRevision) &
          row.lifecycleState.equals('DRAFT') &
          row.deletedAt.isNull(),
    )).write(
      CableAllocationsCompanion(
        lifecycleState: const Value('RESERVED'),
        revision: Value(allocation.revision),
        updatedAt: Value(now),
        originDeviceId: Value(originDeviceId),
      ),
    );
    if (affected != 1) {
      await (database.delete(database.cableResourceClaims)
        ..where((row) => row.allocationId.equals(allocation.id))).go();
      await (database.delete(database.cableAllocationResourceSelections)
        ..where((row) => row.allocationId.equals(allocation.id))).go();
      return ElvAllocationMutationOutcome.revisionConflict;
    }
    return ElvAllocationMutationOutcome.success;
  }

  @override
  Future<ElvAllocationMutationOutcome> replaceTerminations({
    required CableAllocation allocation,
    required int expectedRevision,
    required List<CableTerminationMapping> mappings,
  }) async {
    final ids = mappings.map((mapping) => mapping.id).toSet();
    if (ids.length != mappings.length) {
      return ElvAllocationMutationOutcome.storageConflict;
    }
    if (ids.isNotEmpty) {
      final existing =
          await (database.select(database.cableTerminationMappings)
            ..where((row) => row.id.isIn(ids))).get();
      if (existing.any((row) => row.allocationId != allocation.id)) {
        return ElvAllocationMutationOutcome.storageConflict;
      }
    }

    final affected = await (database.update(database.cableAllocations)..where(
      (row) =>
          row.id.equals(allocation.id) &
          row.projectId.equals(allocation.projectId) &
          row.revision.equals(expectedRevision) &
          row.lifecycleState.isIn(const ['RESERVED', 'ACTIVE']) &
          row.deletedAt.isNull(),
    )).write(
      CableAllocationsCompanion(
        revision: Value(allocation.revision),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    if (affected != 1) return ElvAllocationMutationOutcome.revisionConflict;

    await (database.delete(database.cableTerminationMappings)
      ..where((row) => row.allocationId.equals(allocation.id))).go();
    final now = DateTime.now().toUtc();
    for (final mapping in mappings) {
      await database
          .into(database.cableTerminationMappings)
          .insert(
            CableTerminationMappingsCompanion.insert(
              id: mapping.id,
              allocationId: mapping.allocationId,
              resourceIdentity: mapping.resourceIdentity,
              endRole: mapping.end.name.toUpperCase(),
              endpointPortId: mapping.endpointPortId,
              endpointTerminalRef: Value(mapping.endpointTerminalRef),
              terminationRole: Value(mapping.terminationRole),
              revision: Value(allocation.revision),
              createdAt: now,
              updatedAt: now,
              originDeviceId: originDeviceId,
            ),
          );
    }
    return ElvAllocationMutationOutcome.success;
  }

  @override
  Future<ElvAllocationMutationOutcome> activate({
    required CableAllocation allocation,
    required int expectedRevision,
  }) => _stateUpdate(
    allocation,
    expectedRevision: expectedRevision,
    fromStates: const ['RESERVED'],
    toState: 'ACTIVE',
  );

  @override
  Future<ElvAllocationMutationOutcome> release({
    required CableAllocation allocation,
    required int expectedRevision,
  }) async {
    final outcome = await _stateUpdate(
      allocation,
      expectedRevision: expectedRevision,
      fromStates: const ['RESERVED', 'ACTIVE'],
      toState: 'RELEASED',
    );
    if (outcome != ElvAllocationMutationOutcome.success) return outcome;
    await (database.delete(database.cableResourceClaims)
      ..where((row) => row.allocationId.equals(allocation.id))).go();
    return ElvAllocationMutationOutcome.success;
  }

  @override
  Future<ElvAllocationMutationOutcome> archive({
    required CableAllocation allocation,
    required int expectedRevision,
  }) => _stateUpdate(
    allocation,
    expectedRevision: expectedRevision,
    fromStates: const ['DRAFT', 'RELEASED'],
    toState: 'ARCHIVED',
  );

  Future<ElvAllocationMutationOutcome> _stateUpdate(
    CableAllocation allocation, {
    required int expectedRevision,
    required List<String> fromStates,
    required String toState,
  }) async {
    final affected = await (database.update(database.cableAllocations)..where(
      (row) =>
          row.id.equals(allocation.id) &
          row.projectId.equals(allocation.projectId) &
          row.revision.equals(expectedRevision) &
          row.lifecycleState.isIn(fromStates) &
          row.deletedAt.isNull(),
    )).write(
      CableAllocationsCompanion(
        lifecycleState: Value(toState),
        revision: Value(allocation.revision),
        updatedAt: Value(DateTime.now().toUtc()),
        originDeviceId: Value(originDeviceId),
      ),
    );
    return affected == 1
        ? ElvAllocationMutationOutcome.success
        : ElvAllocationMutationOutcome.revisionConflict;
  }

  @override
  Future<bool> hasActiveCanonicalRun(String projectId, String cableId) async {
    // P3 owns canonical run persistence. P2 must expose the dependency port now;
    // the P3 store replaces this implementation without changing P2 commands.
    return false;
  }

  @override
  Future<int> consumingAllocationCount(String projectId, String cableId) async {
    final count = database.cableAllocations.id.count();
    final query =
        database.selectOnly(database.cableAllocations)
          ..addColumns([count])
          ..where(
            database.cableAllocations.projectId.equals(projectId) &
                database.cableAllocations.cableId.equals(cableId) &
                database.cableAllocations.lifecycleState.isIn(const [
                  'RESERVED',
                  'ACTIVE',
                ]) &
                database.cableAllocations.deletedAt.isNull(),
          );
    return (await query.getSingle()).read(count) ?? 0;
  }

  CableAllocation _allocation(CableAllocationRow row) => CableAllocation(
    id: row.id,
    projectId: row.projectId,
    engineeringConnectionId: row.engineeringConnectionId,
    cableId: row.cableId,
    state: CableAllocationState.values.byName(row.lifecycleState.toLowerCase()),
    revision: row.revision,
    transitionRef: row.transitionRef,
  );
}
