import 'package:engineering_core/engineering_core.dart';

abstract interface class ElectricalCircuitRepository {
  Stream<List<CircuitSnapshot>> watchRoomCircuits(String roomId);
  Future<List<CircuitSnapshot>> loadRoomCircuits(String roomId);
  Future<void> saveCircuit(ElectricalCircuit circuit);
  Future<void> createFromGroup({
    required String circuitId,
    required String groupId,
    required String name,
    double demandFactor = 1,
  });
  Future<void> confirmCircuit(String circuitId);
}
