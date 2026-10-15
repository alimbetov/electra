import 'package:engineering_core/engineering_core.dart';

import 'engineering_system_repository.dart';

enum TopologyObjectKind { port, connection, internalMapping, group, assembly }

class ProjectEngineeringTopologySnapshot {
  const ProjectEngineeringTopologySnapshot({
    required this.systems,
    required this.ports,
    required this.connectionProfiles,
    required this.connections,
    required this.internalLinks,
    required this.topologyProfiles,
    required this.groups,
    required this.assemblyProfiles,
    required this.assemblies,
  });
  final ProjectEngineeringSystemsSnapshot systems;
  final List<EngineeringPort> ports;
  final List<ConnectionCompatibilityProfile> connectionProfiles;
  final List<EngineeringConnection> connections;
  final List<InternalConnectivity> internalLinks;
  final List<TopologyProfile> topologyProfiles;
  final List<TopologyGroup> groups;
  final List<AssemblyProfile> assemblyProfiles;
  final List<ComponentAssembly> assemblies;
  static List<T> replace<T>(
    List<T> values,
    T? candidate,
    String Function(T) id,
  ) => candidate == null
      ? values
      : [...values.where((v) => id(v) != id(candidate)), candidate];
  EngineeringTopologyGraph graph({
    EngineeringPort? port,
    EngineeringConnection? connection,
    InternalConnectivity? internal,
    TopologyGroup? group,
    ComponentAssembly? assembly,
  }) => EngineeringTopologyGraph(
    projectId: systems.project?.id ?? '',
    componentIds: systems.components.map((c) => c.id),
    systems: systems.systems,
    families: systems.families,
    memberships: systems.memberships,
    ports: replace(ports, port, (v) => v.id),
    connectionProfiles: connectionProfiles,
    connections: replace(connections, connection, (v) => v.id),
    internalLinks: replace(internalLinks, internal, (v) => v.id),
    topologyProfiles: topologyProfiles,
    groups: replace(groups, group, (v) => v.id),
    assemblyProfiles: assemblyProfiles,
    assemblies: replace(assemblies, assembly, (v) => v.id),
  );
}

abstract interface class EngineeringTopologyRepository {
  Future<ProjectEngineeringTopologySnapshot> load(String projectId);
  Stream<ProjectEngineeringTopologySnapshot> watch(String projectId);
  Future<void> savePort(String projectId, EngineeringPort port);
  Future<void> saveConnectionProfile(ConnectionCompatibilityProfile profile);
  Future<void> saveTopologyProfile(TopologyProfile profile);
  Future<void> saveAssemblyProfile(AssemblyProfile profile);
  Future<void> saveConnection(
    String projectId,
    EngineeringConnection connection,
  );
  Future<void> saveInternal(String projectId, InternalConnectivity mapping);
  Future<void> saveGroup(String projectId, TopologyGroup group);
  Future<void> saveAssembly(String projectId, ComponentAssembly assembly);
  Future<void> archive(String projectId, TopologyObjectKind kind, String id);
}
