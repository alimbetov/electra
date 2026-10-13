import 'engineering_topology.dart';
import 'engineering_system.dart';

class TopologyFinding {
  TopologyFinding(this.code, this.message, Iterable<String> objectIds,
      {this.profile, this.draft = false})
      : objectIds = List.unmodifiable(objectIds);
  final String code, message;
  final List<String> objectIds;
  final ProfileIdentity? profile;
  final bool draft;
  Map<String, Object?> toMap() => {
        'code': code,
        'message': message,
        'objectIds': objectIds,
        'profile': profile?.toMap(),
        'draft': draft
      };
}

class TopologyTraceResult {
  TopologyTraceResult(
      {required Iterable<String> portIds,
      required Iterable<String> connectionIds,
      required Iterable<String> internalLinkIds})
      : portIds = List.unmodifiable(portIds.toList()..sort()),
        connectionIds = List.unmodifiable(connectionIds.toList()..sort()),
        internalLinkIds = List.unmodifiable(internalLinkIds.toList()..sort());
  final List<String> portIds, connectionIds, internalLinkIds;
}

class _Edge {
  const _Edge(this.id, this.from, this.to,
      {required this.bidirectional, this.internal = false});
  final String id, from, to;
  final bool bidirectional, internal;
}

class EngineeringTopologyGraph {
  EngineeringTopologyGraph(
      {required this.projectId,
      required Iterable<String> componentIds,
      required Iterable<EngineeringSystem> systems,
      required Iterable<EngineeringSystemFamily> families,
      required Iterable<ComponentSystemMembership> memberships,
      required Iterable<EngineeringPort> ports,
      required Iterable<ConnectionCompatibilityProfile> connectionProfiles,
      required Iterable<EngineeringConnection> connections,
      required Iterable<InternalConnectivity> internalLinks,
      required Iterable<TopologyProfile> topologyProfiles,
      required Iterable<TopologyGroup> groups,
      required Iterable<AssemblyProfile> assemblyProfiles,
      required Iterable<ComponentAssembly> assemblies})
      : componentIds = Set.unmodifiable(componentIds),
        systems = _index(systems, (v) => v.id),
        families = _index(families, (v) => v.id),
        memberships = List.unmodifiable(memberships),
        ports = _index(ports, (v) => v.id),
        connectionProfiles = _index(connectionProfiles, (v) => v.id),
        connections = _index(connections, (v) => v.id),
        internalLinks = _index(internalLinks, (v) => v.id),
        topologyProfiles = _index(topologyProfiles, (v) => v.id),
        groups = _index(groups, (v) => v.id),
        assemblyProfiles = _index(assemblyProfiles, (v) => v.id),
        assemblies = _index(assemblies, (v) => v.id);
  final String projectId;
  final Set<String> componentIds;
  final Map<String, EngineeringSystem> systems;
  final Map<String, EngineeringSystemFamily> families;
  final List<ComponentSystemMembership> memberships;
  final Map<String, EngineeringPort> ports;
  final Map<String, ConnectionCompatibilityProfile> connectionProfiles;
  final Map<String, EngineeringConnection> connections;
  final Map<String, InternalConnectivity> internalLinks;
  final Map<String, TopologyProfile> topologyProfiles;
  final Map<String, TopologyGroup> groups;
  final Map<String, AssemblyProfile> assemblyProfiles;
  final Map<String, ComponentAssembly> assemblies;
  static Map<String, T> _index<T>(Iterable<T> values, String Function(T) id) {
    final result = <String, T>{};
    for (final v in values) {
      if (result.containsKey(id(v)))
        throw StateError('Duplicate topology identity: ${id(v)}');
      result[id(v)] = v;
    }
    return Map.unmodifiable(result);
  }

  bool _participates(String component, String system) => memberships
      .any((m) => m.componentId == component && m.systemId == system);
  bool _sameRef(
          EngineeringProfileReference? a, EngineeringProfileReference? b) =>
      a != null && b != null && a.id == b.id && a.version == b.version;
  List<TopologyFinding> portFindings(EngineeringPort p) => [
        for (final message in p.validate())
          TopologyFinding('INVALID_PORT', message, [p.id]),
        if (!componentIds.contains(p.componentId))
          TopologyFinding(
              'COMPONENT_UNAVAILABLE',
              'Port owner is unavailable in this project.',
              [p.id, p.componentId]),
        if (ports.values.any((v) =>
            v.id != p.id &&
            v.componentId == p.componentId &&
            v.code.trim().toUpperCase() == p.code.trim().toUpperCase()))
          TopologyFinding('DUPLICATE_PORT_CODE',
              'Port code is already used by its owner.', [p.id]),
        if (connections.values
                .where((c) => c.fromPortId == p.id || c.toPortId == p.id)
                .length >
            p.capacity)
          TopologyFinding(
              'PORT_CAPACITY',
              'External connection count exceeds declared port capacity.',
              [p.id]),
      ];
  List<TopologyFinding> connectionFindings(EngineeringConnection c) {
    final result = <TopologyFinding>[];
    final profile = connectionProfiles[c.profileId],
        system = systems[c.systemId],
        a = ports[c.fromPortId],
        b = ports[c.toPortId];
    void issue(String code, String message) => result.add(TopologyFinding(
        code, message, [c.id, c.fromPortId, c.toPortId],
        profile: profile?.identity));
    if ([c.id, c.systemId, c.fromPortId, c.toPortId, c.profileId]
        .any((s) => s.trim().isEmpty))
      issue('INVALID_CONNECTION',
          'Connection identity and references are required.');
    if (profile == null ||
        profile.identity.projectId != projectId ||
        profile.validate().isNotEmpty)
      issue('PROFILE_UNRESOLVED',
          'Resolve an exact valid compatibility profile of this project.');
    if (system == null || system.projectId != projectId)
      issue('SYSTEM_UNAVAILABLE', 'Resolve the owning system.');
    if (a == null || b == null) {
      issue('PORT_UNAVAILABLE',
          'Both endpoints must be active ports of this project.');
      return result;
    }
    if (a.id == b.id)
      issue('EXTERNAL_SELF_LINK',
          'An external connection needs two distinct ports. Passive internal mapping is a separate operation.');
    for (final p in [a, b]) {
      result.addAll(portFindings(p));
      if (!_participates(p.componentId, c.systemId))
        issue('MEMBERSHIP_REQUIRED',
            'Both endpoint components must participate in the owning system.');
    }
    if (connections.values.any((v) =>
        v.id != c.id && {v.fromPortId, v.toPortId}.containsAll([a.id, b.id])))
      issue('DUPLICATE_CONNECTION',
          'This port pair already has an external connection; model distinct channels with distinct ports.');
    if (profile != null) {
      final family = families[system?.familyId];
      if (family == null ||
          family.version != system?.familyVersion ||
          !profile.familyCodes.contains(family.code))
        issue('FAMILY_PROFILE',
            'The profile does not allow the exact system family edition.');
      if (!profile.media.contains(c.medium))
        issue('MEDIUM_PROFILE',
            'Connection medium is not allowed by this profile.');
      if (a.kind != profile.kindA || b.kind != profile.kindB)
        issue('PORT_KIND', 'Endpoint kinds do not match the ordered profile.');
      if (a.connector?.trim().isNotEmpty != true ||
          b.connector?.trim().isNotEmpty != true ||
          a.protocol == null ||
          b.protocol == null)
        issue('COMPATIBILITY_UNRESOLVED',
            'Declare both connector and exact protocol editions.');
      else if (a.connector != profile.connectorA ||
          b.connector != profile.connectorB ||
          !_sameRef(a.protocol, profile.protocolA) ||
          !_sameRef(b.protocol, profile.protocolB))
        issue('INTERFACE_PROTOCOL',
            'Connector or protocol edition differs from this profile.');
      if (profile.flow == CompatibilityFlow.directed) {
        if (a.direction == PortDirection.input ||
            b.direction == PortDirection.output)
          issue('DIRECTION',
              'Directed external link requires an output/bidirectional source and input/bidirectional target.');
      } else if (a.direction != PortDirection.bidirectional ||
          b.direction != PortDirection.bidirectional) {
        issue('DIRECTION',
            'Bidirectional profile requires two bidirectional interfaces.');
      }
      if (carriesPower(profile.layer)) {
        if (a.voltage == null ||
            b.voltage == null ||
            a.powerDirection == null ||
            b.powerDirection == null)
          issue('POWER_UNRESOLVED',
              'Declare voltage domains and independent power directions.');
        else {
          if (a.powerDirection == PortDirection.input ||
              b.powerDirection == PortDirection.output)
            issue('POWER_DIRECTION',
                'Power must flow from the declared source to the declared sink.');
          if (!a.voltage!.valid ||
              !b.voltage!.valid ||
              a.voltage!.currentKind != b.voltage!.currentKind ||
              a.voltage!.minimumV < b.voltage!.minimumV ||
              a.voltage!.maximumV > b.voltage!.maximumV)
            issue('VOLTAGE_DOMAIN',
                'Source voltage range must fit the sink acceptance range, with the same AC/DC kind.');
          if (a.powerLimitW != null &&
              b.powerDemandW != null &&
              b.powerDemandW! > a.powerLimitW!)
            issue('DECLARED_POWER_LIMIT',
                'Declared endpoint demand exceeds the source port rating.');
        }
      }
    }
    if (c.groupId != null) {
      final group = groups[c.groupId], top = topologyProfiles[group?.profileId];
      if (group == null ||
          group.systemId != c.systemId ||
          top == null ||
          profile == null ||
          !layerServes(profile.layer, top.layer))
        issue('GROUP_OWNERSHIP',
            'Connection group must belong to the same system and compatible semantic layer.');
    }
    return result;
  }

  List<TopologyFinding> internalFindings(InternalConnectivity link) {
    final a = ports[link.fromPortId], b = ports[link.toPortId];
    final result = <TopologyFinding>[];
    void issue(String code, String message) => result.add(TopologyFinding(
        code, message, [link.id, link.fromPortId, link.toPortId]));
    if (link.id.trim().isEmpty || link.evidence.trim().isEmpty)
      issue('INTERNAL_EVIDENCE',
          'Identify the passive mapping and its engineering evidence.');
    if (a == null || b == null || !componentIds.contains(link.componentId)) {
      issue('PORT_UNAVAILABLE', 'Resolve active internal endpoints.');
      return result;
    }
    if (a.id == b.id ||
        a.componentId != link.componentId ||
        b.componentId != link.componentId)
      issue('INTERNAL_OWNER',
          'Internal endpoints must be distinct ports of the same owning component.');
    if (a.validate().isNotEmpty || b.validate().isNotEmpty)
      issue('INVALID_PORT', 'Internal endpoint data is invalid.');
    if (a.kind != b.kind ||
        a.connector?.trim().isNotEmpty != true ||
        b.connector?.trim().isNotEmpty != true ||
        !_sameRef(a.protocol, b.protocol))
      issue('PASSIVE_COMPATIBILITY',
          'Passive mapping needs matching kinds/protocol editions and two declared connectors; connector adaptation is explicit.');
    if (carriesPower(link.layer) &&
        (a.voltage == null ||
            b.voltage == null ||
            !a.voltage!.valid ||
            !b.voltage!.valid ||
            a.voltage!.toMap().toString() != b.voltage!.toMap().toString()))
      issue('PASSIVE_POWER',
          'Passive power mapping cannot convert voltage or AC/DC kind. Model converters separately.');
    if (internalLinks.values.any((v) =>
        v.id != link.id &&
        {v.fromPortId, v.toPortId}
            .containsAll([link.fromPortId, link.toPortId])))
      issue('DUPLICATE_INTERNAL', 'The passive port pair is already mapped.');
    return result;
  }

  List<_Edge> _traceEdges(TraceLayer layer, {String? systemId}) => [
        for (final c in connections.values)
          if ((systemId == null || c.systemId == systemId) &&
              connectionFindings(c).isEmpty &&
              layerServes(connectionProfiles[c.profileId]!.layer, layer))
            _Edge(c.id, c.fromPortId, c.toPortId,
                bidirectional: layer != TraceLayer.power &&
                    connectionProfiles[c.profileId]!.flow ==
                        CompatibilityFlow.bidirectional),
        for (final link in internalLinks.values)
          if (internalFindings(link).isEmpty && layerServes(link.layer, layer))
            _Edge(link.id, link.fromPortId, link.toPortId,
                bidirectional: link.bidirectional, internal: true),
      ];
  TopologyTraceResult trace(String startPortId,
      {TraceLayer layer = TraceLayer.all,
      TopologyTraceDirection direction = TopologyTraceDirection.both,
      String? systemId}) {
    if (!ports.containsKey(startPortId) ||
        !componentIds.contains(ports[startPortId]!.componentId))
      return TopologyTraceResult(
          portIds: [], connectionIds: [], internalLinkIds: []);
    final reached = <String>{startPortId},
        external = <String>{},
        internal = <String>{},
        queue = <String>[startPortId];
    final edges = _traceEdges(layer, systemId: systemId)
      ..sort((a, b) => a.id.compareTo(b.id));
    for (var i = 0; i < queue.length; i++) {
      final port = queue[i];
      for (final e in edges) {
        String? next;
        if (e.from == port &&
            (direction != TopologyTraceDirection.upstream || e.bidirectional))
          next = e.to;
        if (e.to == port &&
            (direction != TopologyTraceDirection.downstream || e.bidirectional))
          next = e.from;
        if (next != null) {
          (e.internal ? internal : external).add(e.id);
          if (reached.add(next)) queue.add(next);
        }
      }
    }
    return TopologyTraceResult(
        portIds: reached, connectionIds: external, internalLinkIds: internal);
  }

  List<TopologyFinding> groupFindings(TopologyGroup group) {
    final result = <TopologyFinding>[];
    final profile = topologyProfiles[group.profileId],
        start = ports[group.startPortId],
        end = ports[group.endPortId];
    void issue(String code, String message, {bool draft = false}) =>
        result.add(TopologyFinding(code, message, [group.id],
            profile: profile?.identity, draft: draft));
    if ([
      group.id,
      group.code,
      group.systemId,
      group.profileId,
      group.startPortId
    ].any((s) => s.trim().isEmpty))
      issue('INVALID_GROUP',
          'Group identity, code, owner, profile and source port are required.');
    if (profile == null ||
        profile.identity.projectId != projectId ||
        profile.validate().isNotEmpty) {
      issue('PROFILE_UNRESOLVED', 'Resolve an exact topology profile.');
      return result;
    }
    final system = systems[group.systemId];
    if (system == null || system.projectId != projectId)
      issue('SYSTEM_UNAVAILABLE', 'Group system is unavailable.');
    if (start == null ||
        !componentIds.contains(start.componentId) ||
        !_participates(start.componentId, group.systemId))
      issue('GROUP_SOURCE',
          'Source port must belong to an active participant of this system.');
    if (groups.values.any((g) =>
        g.id != group.id &&
        g.systemId == group.systemId &&
        g.code.trim().toUpperCase() == group.code.trim().toUpperCase()))
      issue('DUPLICATE_GROUP_CODE', 'Group code must be unique in the system.');
    if ([TopologyShape.path, TopologyShape.loop].contains(profile.shape)) {
      if (end == null ||
          end.id == start?.id ||
          !_participates(end.componentId, group.systemId) ||
          !componentIds.contains(end.componentId))
        issue('GROUP_END',
            'Path/loop needs a distinct active end port in the same system.');
      if (profile.shape == TopologyShape.loop &&
          end?.componentId != start?.componentId)
        issue('LOOP_RETURN',
            'Loop source and return are distinct ports of the same controller component.');
    }
    final members =
        connections.values.where((c) => c.groupId == group.id).toList();
    if (members.isEmpty) {
      issue('GROUP_EMPTY', 'Assign external connections to the group.',
          draft: true);
      return result;
    }
    if (members.any((c) => connectionFindings(c).isNotEmpty)) {
      issue('GROUP_INVALID_CONNECTION', 'Resolve member connection findings.');
      return result;
    }
    final edges = [
      for (final c in members)
        _Edge(c.id, c.fromPortId, c.toPortId, bidirectional: true)
    ];
    final vertices = {
      for (final e in edges) ...[e.from, e.to]
    };
    if (profile.shape == TopologyShape.star) {
      if (start == null ||
          !vertices.contains(start.id) ||
          members.any((c) =>
              ports[c.fromPortId]!.componentId != start.componentId &&
              ports[c.toPortId]!.componentId != start.componentId))
        issue('STAR_CENTER',
            'Every star link must terminate at an explicit port of the source component.');
      return result;
    }
    // Include only internal mappings reached by this group's external ports. Controller return is not shorted internally.
    final added = <String>{};
    var changed = true;
    while (changed) {
      changed = false;
      for (final link in internalLinks.values) {
        if (added.contains(link.id) ||
            !layerServes(link.layer, profile.layer) ||
            internalFindings(link).isNotEmpty ||
            (profile.shape == TopologyShape.loop &&
                link.componentId == start?.componentId)) continue;
        if (vertices.contains(link.fromPortId) ||
            vertices.contains(link.toPortId)) {
          added.add(link.id);
          edges.add(_Edge(link.id, link.fromPortId, link.toPortId,
              bidirectional: true, internal: true));
          vertices.addAll([link.fromPortId, link.toPortId]);
          changed = true;
        }
      }
    }
    final adjacent = <String, Set<String>>{for (final v in vertices) v: {}};
    for (final edge in edges) {
      adjacent[edge.from]!.add(edge.to);
      adjacent[edge.to]!.add(edge.from);
    }
    final reached = <String>{}, queue = <String>[group.startPortId];
    for (var i = 0; i < queue.length; i++) {
      if (!reached.add(queue[i])) continue;
      queue.addAll(adjacent[queue[i]] ?? {});
    }
    if (!vertices.contains(group.startPortId) ||
        reached.intersection(vertices).length != vertices.length)
      issue('GROUP_INCOMPLETE', 'Group paths are disconnected from the source.',
          draft: true);
    final parent = {for (final v in vertices) v: v};
    String root(String v) {
      while (parent[v] != v) {
        v = parent[v]!;
      }
      return v;
    }

    for (final edge in edges) {
      final a = root(edge.from), b = root(edge.to);
      if (a == b) {
        issue('GROUP_CYCLE', 'Path/tree must not contain an unintended cycle.');
        break;
      }
      parent[a] = b;
    }
    if ([TopologyShape.path, TopologyShape.loop].contains(profile.shape)) {
      if (adjacent.values.any((s) => s.length > 2))
        issue('GROUP_BRANCH', 'This path/loop profile prohibits branching.');
      final ends = adjacent.entries
          .where((e) => e.value.length == 1)
          .map((e) => e.key)
          .toSet();
      if (ends.length != 2 ||
          !ends.contains(group.startPortId) ||
          !ends.contains(group.endPortId))
        issue('GROUP_INCOMPLETE',
            'Only the declared source and end/return may remain open.',
            draft: true);
    }
    return result;
  }

  List<TopologyFinding> assemblyFindings(ComponentAssembly assembly) {
    final result = <TopologyFinding>[],
        profile = assemblyProfiles[assembly.profileId];
    void issue(String code, String message, {bool draft = false}) =>
        result.add(TopologyFinding(code, message, [assembly.id],
            profile: profile?.identity, draft: draft));
    if (assembly.id.trim().isEmpty || assembly.code.trim().isEmpty)
      issue('INVALID_ASSEMBLY', 'Assembly identity and code are required.');
    if (profile == null ||
        profile.identity.projectId != projectId ||
        profile.validate().isNotEmpty) {
      issue('PROFILE_UNRESOLVED', 'Resolve an exact assembly profile.');
      return result;
    }
    if (assemblies.values.any((a) =>
        a.id != assembly.id &&
        a.code.trim().toUpperCase() == assembly.code.trim().toUpperCase()))
      issue('DUPLICATE_ASSEMBLY_CODE', 'Assembly code must be project-unique.');
    final seen = <String>{};
    for (final member in assembly.members) {
      if (!componentIds.contains(member.componentId))
        issue('COMPONENT_UNAVAILABLE',
            'Assembly member is unavailable in this project.');
      if (!seen.add('${member.componentId}\u0000${member.role}'))
        issue('DUPLICATE_ASSEMBLY_MEMBER',
            'A component-role pair can occur only once.');
      if (!profile.roles.any((r) => r.code == member.role))
        issue('ASSEMBLY_ROLE', 'Role is not allowed by this assembly profile.');
      for (final other in assemblies.values.where((a) =>
          a.id != assembly.id &&
          a.members.any((m) => m.componentId == member.componentId))) {
        if (!profile.allowSharedComponents ||
            assemblyProfiles[other.profileId]?.allowSharedComponents != true)
          issue('ASSEMBLY_SHARING',
              'Both assembly profiles must explicitly allow a shared component.');
      }
    }
    for (final role in profile.roles) {
      final count = assembly.members.where((m) => m.role == role.code).length;
      if (count < role.minimum)
        issue('ASSEMBLY_REQUIRED_ROLE',
            'Role ${role.code} needs at least ${role.minimum} participants.',
            draft: true);
      if (count > role.maximum)
        issue('ASSEMBLY_ROLE_CAPACITY',
            'Role ${role.code} exceeds its declared maximum.');
    }
    return result;
  }

  List<TopologyFinding> findings() => [
        for (final p in ports.values) ...portFindings(p),
        for (final c in connections.values) ...connectionFindings(c),
        for (final link in internalLinks.values) ...internalFindings(link),
        for (final group in groups.values) ...groupFindings(group),
        for (final assembly in assemblies.values) ...assemblyFindings(assembly),
      ];
}
