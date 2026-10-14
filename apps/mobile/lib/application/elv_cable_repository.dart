import 'package:engineering_core/engineering_core.dart';

abstract interface class ElvCableRepository {
  Future<List<Cable>> loadProjectCables(String projectId);
  Future<Cable?> findCable(String projectId, String cableId);
  Stream<List<Cable>> watchProjectCables(String projectId);
  Future<CableDefinition> resolveDefinition(
    String projectId,
    CableDefinitionRef ref,
  );
}
