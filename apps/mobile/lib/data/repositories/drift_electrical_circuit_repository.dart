import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/electrical_circuit_repository.dart';
import '../database/app_database.dart';
import 'drift_electrical_load_repository.dart';

final class DriftElectricalCircuitRepository
    implements ElectricalCircuitRepository {
  DriftElectricalCircuitRepository(
    this.database, {
    required this.originDeviceId,
  });
  final AppDatabase database;
  final String originDeviceId;

  JoinedSelectStatement<HasResultSet, dynamic> _query(String roomId) {
    final circuits = database.electricalCircuits;
    final assignments = database.circuitLoadAssignments;
    final loads = database.equipmentElectricalLoads;
    final components = database.componentInstances;
    final rooms = database.rooms;
    return database.select(circuits).join([
        innerJoin(rooms, rooms.id.equalsExp(circuits.roomId)),
        leftOuterJoin(
          assignments,
          assignments.circuitId.equalsExp(circuits.id),
        ),
        leftOuterJoin(
          loads,
          loads.componentInstanceId.equalsExp(assignments.componentInstanceId),
        ),
        leftOuterJoin(
          components,
          components.id.equalsExp(assignments.componentInstanceId),
        ),
      ])
      ..where(
        circuits.roomId.equals(roomId) &
            circuits.deletedAt.isNull() &
            rooms.deletedAt.isNull(),
      )
      ..orderBy([
        OrderingTerm.asc(circuits.name),
        OrderingTerm.asc(circuits.id),
        OrderingTerm.asc(assignments.componentInstanceId),
      ]);
  }

  List<CircuitSnapshot> _snapshots(List<TypedResult> rows) {
    final circuitRows = <String, ElectricalCircuitRow>{};
    final ids = <String, List<String>>{};
    final loads = <String, List<EquipmentElectricalLoad>>{};
    for (final result in rows) {
      final circuit = result.readTable(database.electricalCircuits);
      circuitRows[circuit.id] = circuit;
      ids.putIfAbsent(circuit.id, () => []);
      loads.putIfAbsent(circuit.id, () => []);
      final assignment = result.readTableOrNull(
        database.circuitLoadAssignments,
      );
      if (assignment == null) continue;
      ids[circuit.id]!.add(assignment.componentInstanceId);
      final load = result.readTableOrNull(database.equipmentElectricalLoads);
      final component = result.readTableOrNull(database.componentInstances);
      if (load != null &&
          load.deletedAt == null &&
          component != null &&
          component.deletedAt == null &&
          component.roomId == circuit.roomId) {
        loads[circuit.id]!.add(DriftElectricalLoadRepository.decodeRow(load));
      }
    }
    return circuitRows.values
        .map((row) {
          final circuit = ElectricalCircuit(
            id: row.id,
            roomId: row.roomId,
            name: row.name,
            sourceGroupId: row.sourceGroupId,
            inputs: ElectricalCircuitInputs(
              nominalVoltageV: row.nominalVoltageV,
              phases: row.phases,
              supplySystem: SupplySystem.values.byName(row.supplySystem),
              demandFactor: row.demandFactor,
            ),
            loadIds: ids[row.id]!,
          );
          return CircuitSnapshot(
            circuit: circuit,
            calculation: CircuitCurrentCalculator.calculate(
              circuit,
              loads[row.id]!,
            ),
            reviewedInputSignature: row.reviewedInputSignature,
          );
        })
        .toList(growable: false);
  }

  @override
  Stream<List<CircuitSnapshot>> watchRoomCircuits(String roomId) =>
      _query(roomId).watch().map(_snapshots);
  @override
  Future<List<CircuitSnapshot>> loadRoomCircuits(String roomId) async =>
      _snapshots(await _query(roomId).get());

  @override
  Future<void> saveCircuit(ElectricalCircuit circuit) async {
    if (circuit.id.trim().isEmpty ||
        circuit.roomId.trim().isEmpty ||
        circuit.name.trim().isEmpty)
      throw ArgumentError('Circuit id, room and name are required.');
    final errors = circuit.inputs.validate();
    if (errors.isNotEmpty)
      throw ArgumentError('Check circuit inputs: ${errors.join(', ')}');
    if (circuit.loadIds.any((id) => id.trim().isEmpty) ||
        circuit.loadIds.toSet().length != circuit.loadIds.length)
      throw ArgumentError('Load assignments must be non-empty and unique.');
    await database.transaction(() async {
      final room =
          await (database.select(database.rooms)..where(
            (row) => row.id.equals(circuit.roomId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (room == null) throw StateError('Circuit room is not active.');
      final existing =
          await (database.select(database.electricalCircuits)
            ..where((row) => row.id.equals(circuit.id))).getSingleOrNull();
      if (existing != null && existing.roomId != circuit.roomId)
        throw StateError('Cannot move a circuit between rooms.');
      if (circuit.sourceGroupId != null) {
        final group =
            await (database.select(database.consumptionGroups)..where(
              (row) =>
                  row.id.equals(circuit.sourceGroupId!) &
                  row.deletedAt.isNull(),
            )).getSingleOrNull();
        if (group == null || group.roomId != circuit.roomId)
          throw StateError('Source group must belong to the circuit room.');
      }
      for (final id in circuit.loadIds) {
        final component =
            await (database.select(database.componentInstances)..where(
              (row) => row.id.equals(id) & row.deletedAt.isNull(),
            )).getSingleOrNull();
        final load =
            await (database.select(database.equipmentElectricalLoads)..where(
              (row) =>
                  row.componentInstanceId.equals(id) & row.deletedAt.isNull(),
            )).getSingleOrNull();
        if (component == null ||
            component.roomId != circuit.roomId ||
            load == null)
          throw StateError(
            'Assigned load must be active in the circuit room: $id',
          );
        final assignment =
            await (database.select(database.circuitLoadAssignments)..where(
              (row) => row.componentInstanceId.equals(id),
            )).getSingleOrNull();
        if (assignment != null && assignment.circuitId != circuit.id)
          throw StateError(
            'Load $id is already assigned to another circuit. Remove that assignment first.',
          );
      }
      final now = DateTime.now().toUtc();
      await database
          .into(database.electricalCircuits)
          .insertOnConflictUpdate(
            ElectricalCircuitsCompanion(
              id: Value(circuit.id),
              roomId: Value(circuit.roomId),
              name: Value(circuit.name.trim()),
              nominalVoltageV: Value(circuit.inputs.nominalVoltageV),
              phases: Value(circuit.inputs.phases),
              supplySystem: Value(circuit.inputs.supplySystem.name),
              demandFactor: Value(circuit.inputs.demandFactor),
              sourceGroupId: Value(circuit.sourceGroupId),
              reviewedInputSignature: const Value(null),
              revision: Value((existing?.revision ?? 0) + 1),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
      await (database.delete(database.circuitLoadAssignments)
        ..where((row) => row.circuitId.equals(circuit.id))).go();
      for (final id in circuit.loadIds) {
        await database
            .into(database.circuitLoadAssignments)
            .insert(
              CircuitLoadAssignmentsCompanion.insert(
                componentInstanceId: id,
                circuitId: circuit.id,
              ),
            );
      }
    });
  }

  @override
  Future<void> createFromGroup({
    required String circuitId,
    required String groupId,
    required String name,
    double demandFactor = 1,
  }) async {
    await database.transaction(() async {
      final group =
          await (database.select(database.consumptionGroups)..where(
            (row) => row.id.equals(groupId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (group == null) throw StateError('Consumption group is not active.');
      final loads =
          (await DriftElectricalLoadRepository(
            database,
            originDeviceId: originDeviceId,
          ).loadRoomLoads(
            group.roomId,
          )).where((load) => load.consumptionGroupId == groupId).toList();
      if (loads.isEmpty)
        throw StateError('Configure at least one active load in this group.');
      final profile = loads.first.profile;
      await saveCircuit(
        ElectricalCircuit(
          id: circuitId,
          roomId: group.roomId,
          name: name,
          sourceGroupId: groupId,
          inputs: ElectricalCircuitInputs(
            nominalVoltageV: profile.nominalVoltageV,
            phases: profile.phases,
            supplySystem: profile.supplySystem,
            demandFactor: demandFactor,
          ),
          loadIds: loads.map((load) => load.componentInstanceId),
        ),
      );
    });
  }

  @override
  Future<void> confirmCircuit(String circuitId) async {
    await database.transaction(() async {
      final row =
          await (database.select(database.electricalCircuits)..where(
            (row) => row.id.equals(circuitId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (row == null) throw StateError('Circuit is not active.');
      final room =
          await (database.select(database.rooms)..where(
            (item) => item.id.equals(row.roomId) & item.deletedAt.isNull(),
          )).getSingleOrNull();
      if (room == null) throw StateError('Circuit room is not active.');
      final snapshot = (await loadRoomCircuits(
        row.roomId,
      )).firstWhere((item) => item.circuit.id == circuitId);
      if (!snapshot.calculation.ready)
        throw StateError(
          'Resolve all calculation issues before confirming the proposal.',
        );
      await (database.update(database.electricalCircuits)
        ..where((item) => item.id.equals(circuitId))).write(
        ElectricalCircuitsCompanion(
          reviewedInputSignature: Value(snapshot.calculation.inputSignature),
          revision: Value(row.revision + 1),
          updatedAt: Value(DateTime.now().toUtc()),
          originDeviceId: Value(originDeviceId),
        ),
      );
    });
  }
}
