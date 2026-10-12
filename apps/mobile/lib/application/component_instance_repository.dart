import 'package:engineering_core/engineering_core.dart';

abstract interface class ComponentInstanceRepository {
  Stream<List<ComponentInstance>> watchRoomComponents(String roomId);

  Future<List<ComponentInstance>> loadRoomComponents(String roomId);

  Future<void> removeComponent(String instanceId);

  Future<void> saveComponent(ComponentInstance instance);

  Future<void> replaceRoomComponents({
    required String roomId,
    required Iterable<ComponentInstance> instances,
  });
}
