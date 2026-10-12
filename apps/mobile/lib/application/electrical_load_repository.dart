import 'package:engineering_core/engineering_core.dart';

abstract interface class ElectricalLoadRepository {
  Stream<List<EquipmentElectricalLoad>> watchRoomLoads(String roomId);
  Future<List<EquipmentElectricalLoad>> loadRoomLoads(String roomId);
  Stream<List<RoomConsumptionGroup>> watchRoomGroups(String roomId);
  Future<List<RoomConsumptionGroup>> loadRoomGroups(String roomId);
  Future<void> saveLoad(EquipmentElectricalLoad load);
  Future<void> saveGroup(RoomConsumptionGroup group);
}
