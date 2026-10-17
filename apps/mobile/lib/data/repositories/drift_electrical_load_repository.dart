import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/electrical_load_repository.dart';
import '../database/app_database.dart';

final class DriftElectricalLoadRepository implements ElectricalLoadRepository {
  DriftElectricalLoadRepository(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;

  JoinedSelectStatement<HasResultSet, dynamic> _loads(String roomId) {
    final loads = database.equipmentElectricalLoads;
    final components = database.componentInstances;
    return database.select(loads).join([
        innerJoin(
          components,
          components.id.equalsExp(loads.componentInstanceId),
        ),
      ])
      ..where(
        components.roomId.equals(roomId) &
            components.deletedAt.isNull() &
            loads.deletedAt.isNull(),
      )
      ..orderBy([OrderingTerm.asc(loads.componentInstanceId)]);
  }

  List<EquipmentElectricalLoad> _mapLoads(List<TypedResult> rows) => rows
      .map(
        (result) =>
            decodeRow(result.readTable(database.equipmentElectricalLoads)),
      )
      .toList(growable: false);

  @override
  Stream<List<EquipmentElectricalLoad>> watchRoomLoads(String roomId) =>
      _loads(roomId).watch().map(_mapLoads);
  @override
  Future<List<EquipmentElectricalLoad>> loadRoomLoads(String roomId) async =>
      _mapLoads(await _loads(roomId).get());

  SimpleSelectStatement<$ConsumptionGroupsTable, ConsumptionGroupRow> _groups(
    String roomId,
  ) =>
      database.select(database.consumptionGroups)
        ..where((row) => row.roomId.equals(roomId) & row.deletedAt.isNull())
        ..orderBy([
          (row) => OrderingTerm.asc(row.name),
          (row) => OrderingTerm.asc(row.id),
        ]);

  List<RoomConsumptionGroup> _mapGroups(List<ConsumptionGroupRow> rows) => rows
      .map(
        (row) => RoomConsumptionGroup(
          id: row.id,
          roomId: row.roomId,
          name: row.name,
        ),
      )
      .toList(growable: false);
  @override
  Stream<List<RoomConsumptionGroup>> watchRoomGroups(String roomId) =>
      _groups(roomId).watch().map(_mapGroups);
  @override
  Future<List<RoomConsumptionGroup>> loadRoomGroups(String roomId) async =>
      _mapGroups(await _groups(roomId).get());

  @override
  Future<void> saveGroup(RoomConsumptionGroup group) async {
    if (group.id.trim().isEmpty ||
        group.roomId.trim().isEmpty ||
        group.name.trim().isEmpty)
      throw ArgumentError('Group id, room and name are required.');
    await database.transaction(() async {
      final room =
          await (database.select(database.rooms)..where(
            (row) => row.id.equals(group.roomId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (room == null) throw StateError('Group room is not active.');
      final existing =
          await (database.select(database.consumptionGroups)
            ..where((row) => row.id.equals(group.id))).getSingleOrNull();
      if (existing != null && existing.roomId != group.roomId)
        throw StateError('Cannot move a group between rooms.');
      final now = DateTime.now().toUtc();
      await database
          .into(database.consumptionGroups)
          .insertOnConflictUpdate(
            ConsumptionGroupsCompanion(
              id: Value(group.id),
              roomId: Value(group.roomId),
              name: Value(group.name.trim()),
              revision: Value((existing?.revision ?? 0) + 1),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
    });
  }

  @override
  Future<void> saveLoad(EquipmentElectricalLoad load) async {
    if (load.componentInstanceId.trim().isEmpty)
      throw ArgumentError('Equipment instance is required.');
    final profile = load.profile;
    final errors = ElectricalLoadValidator.validate(profile);
    if (errors.isNotEmpty)
      throw ArgumentError('Invalid electrical load: ${errors.join(', ')}');
    await database.transaction(() async {
      final component =
          await (database.select(database.componentInstances)..where(
            (row) =>
                row.id.equals(load.componentInstanceId) &
                row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (component == null)
        throw StateError('Equipment instance is not active.');
      final room =
          await (database.select(database.rooms)..where(
            (row) => row.id.equals(component.roomId) & row.deletedAt.isNull(),
          )).getSingleOrNull();
      if (room == null) throw StateError('Equipment room is not active.');
      final groupId = load.consumptionGroupId;
      if (groupId != null) {
        final group =
            await (database.select(database.consumptionGroups)..where(
              (row) => row.id.equals(groupId) & row.deletedAt.isNull(),
            )).getSingleOrNull();
        if (group == null || group.roomId != component.roomId)
          throw StateError(
            'Consumption group must belong to the equipment room.',
          );
      }
      final existing =
          await (database.select(database.equipmentElectricalLoads)..where(
            (row) => row.componentInstanceId.equals(load.componentInstanceId),
          )).getSingleOrNull();
      final now = DateTime.now().toUtc();
      await database
          .into(database.equipmentElectricalLoads)
          .insertOnConflictUpdate(
            EquipmentElectricalLoadsCompanion(
              componentInstanceId: Value(load.componentInstanceId),
              consumptionGroupId: Value(load.consumptionGroupId),
              nominalVoltageV: Value(profile.nominalVoltageV),
              phases: Value(profile.phases),
              supplySystem: Value(profile.supplySystem.name),
              phaseConfiguration: Value(profile.phaseConfiguration?.name),
              frequencyHz: Value(profile.frequencyHz),
              ratedPowerW: Value(profile.ratedPowerW),
              ratedCurrentA: Value(profile.ratedCurrentA),
              powerFactor: Value(profile.powerFactor),
              efficiency: Value(profile.efficiency),
              startingMethod: Value(profile.startingMethod.name),
              startingCurrentFactor: Value(profile.startingCurrentFactor),
              loadType: Value(profile.loadType),
              powerBasis: Value(load.powerBasis?.name),
              dedicatedCircuitRecommended: Value(
                profile.dedicatedCircuitRecommended,
              ),
              requiresNeutral: Value(profile.requiresNeutral),
              requiresProtectiveEarth: Value(profile.requiresProtectiveEarth),
              revision: Value((existing?.revision ?? 0) + 1),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
    });
  }

  static EquipmentElectricalLoad decodeRow(EquipmentElectricalLoadRow row) =>
      EquipmentElectricalLoad(
        componentInstanceId: row.componentInstanceId,
        consumptionGroupId: row.consumptionGroupId,
        powerBasis:
            row.powerBasis == null
                ? null
                : ElectricalPowerBasis.values.byName(row.powerBasis!),
        profile: ElectricalLoadProfile(
          nominalVoltageV: row.nominalVoltageV,
          phases: row.phases,
          supplySystem: SupplySystem.values.byName(row.supplySystem),
          phaseConfiguration:
              row.phaseConfiguration == null
                  ? null
                  : PhaseConfiguration.values.byName(row.phaseConfiguration!),
          frequencyHz: row.frequencyHz,
          ratedPowerW: row.ratedPowerW,
          ratedCurrentA: row.ratedCurrentA,
          powerFactor: row.powerFactor,
          efficiency: row.efficiency,
          startingMethod: StartingMethod.values.byName(row.startingMethod),
          startingCurrentFactor: row.startingCurrentFactor,
          loadType: row.loadType,
          dedicatedCircuitRecommended: row.dedicatedCircuitRecommended,
          requiresNeutral: row.requiresNeutral,
          requiresProtectiveEarth: row.requiresProtectiveEarth,
        ),
      );
}
