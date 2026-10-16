import 'package:engineering_core/engineering_core.dart';

import '../domain/project_models.dart';

class EngineeringComponentView {
  const EngineeringComponentView({
    required this.id,
    required this.name,
    required this.roomName,
  });
  final String id, name, roomName;
}

class ProjectEngineeringSystemsSnapshot {
  const ProjectEngineeringSystemsSnapshot({
    required this.project,
    required this.families,
    required this.systems,
    this.archivedSystems = const [],
    required this.memberships,
    required this.components,
  });
  final ProjectRecord? project;
  final List<EngineeringSystemFamily> families;
  final List<EngineeringSystem> systems, archivedSystems;
  final List<ComponentSystemMembership> memberships;
  final List<EngineeringComponentView> components;
}

abstract interface class EngineeringSystemRepository {
  Future<ProjectEngineeringSystemsSnapshot> load(String projectId);
  Stream<ProjectEngineeringSystemsSnapshot> watch(String projectId);
  Future<void> saveFamily(EngineeringSystemFamily family);
  Future<void> saveSystem(EngineeringSystem system);
  Future<void> archiveSystem(String projectId, String systemId);
  Future<void> assign(String projectId, ComponentSystemMembership membership);
  Future<void> detach(String projectId, String systemId, String componentId);
}
