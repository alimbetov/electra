import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_cable_allocation_repository.dart';
import '../database/app_database.dart';

final class DriftElvCableAllocationRepository
    implements ElvCableAllocationRepository {
  const DriftElvCableAllocationRepository(this.database);

  final AppDatabase database;

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
  ) async => (await (database.select(database.cableAllocations)
            ..where(
              (row) =>
                  row.projectId.equals(projectId) &
                  row.cableId.equals(cableId) &
                  row.deletedAt.isNull(),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.id)]))
          .get())
      .map(_allocation)
      .toList(growable: false);

  @override
  Future<CableAllocationResourceSelectionEvidence?> loadSelectionEvidence(
    String projectId,
    String allocationId,
  ) async {
    if (await findAllocation(projectId, allocationId) == null) return null;
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
        await (database.select(database.cableTerminationMappings)
              ..where(
                (row) =>
                    row.allocationId.equals(allocationId) &
                    row.deletedAt.isNull(),
              )
              ..orderBy([
                (row) => OrderingTerm.asc(row.resourceIdentity),
                (row) => OrderingTerm.asc(row.endRole),
              ]))
            .get();
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
