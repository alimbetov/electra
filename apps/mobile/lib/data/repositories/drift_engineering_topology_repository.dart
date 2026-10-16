import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/engineering_topology_repository.dart';
import '../database/app_database.dart';
import '../elv_deletion_guards.dart';
import 'drift_engineering_system_repository.dart';

class DriftEngineeringTopologyRepository
    implements EngineeringTopologyRepository {
  DriftEngineeringTopologyRepository(
    this.database, {
    required this.originDeviceId,
  });
  final AppDatabase database;
  final String originDeviceId;
  @override
  Stream<ProjectEngineeringTopologySnapshot> watch(String projectId) => database
      .customSelect(
        'SELECT id FROM projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(projectId));
  @override
  Future<ProjectEngineeringTopologySnapshot> load(
    String projectId,
  ) => database.transaction(() async {
    final systems = await DriftEngineeringSystemRepository(
      database,
      originDeviceId: originDeviceId,
    ).load(projectId);
    Future<List<Map<String, dynamic>>> rows(String table) async =>
        systems.project == null
            ? []
            : (await database
                    .customSelect(
                      'SELECT payload_json FROM $table WHERE project_id = ? AND deleted_at IS NULL ORDER BY id',
                      variables: [Variable.withString(projectId)],
                      readsFrom: database.allTables.toSet(),
                    )
                    .get())
                .map(
                  (r) =>
                      jsonDecode(r.read<String>('payload_json'))
                          as Map<String, dynamic>,
                )
                .toList();
    return ProjectEngineeringTopologySnapshot(
      systems: systems,
      ports:
          (await rows(
            'engineering_port_instances',
          )).map(EngineeringPort.fromMap).toList(),
      connectionProfiles:
          (await rows(
            'engineering_compatibility_profiles',
          )).map(ConnectionCompatibilityProfile.fromMap).toList(),
      topologyProfiles:
          (await rows(
            'engineering_topology_profiles',
          )).map(TopologyProfile.fromMap).toList(),
      assemblyProfiles:
          (await rows(
            'engineering_assembly_profiles',
          )).map(AssemblyProfile.fromMap).toList(),
      connections:
          (await rows(
            'engineering_port_connections',
          )).map(EngineeringConnection.fromMap).toList(),
      groups:
          (await rows(
            'engineering_topology_groups',
          )).map(TopologyGroup.fromMap).toList(),
      internalLinks:
          (await rows(
            'engineering_internal_mappings',
          )).map(InternalConnectivity.fromMap).toList(),
      assemblies:
          (await rows(
            'engineering_component_assemblies',
          )).map(ComponentAssembly.fromMap).toList(),
    );
  });
  Future<ProjectEngineeringTopologySnapshot> _active(String projectId) async {
    final snapshot = await load(projectId);
    if (snapshot.systems.project == null)
      throw StateError('Project is unavailable.');
    return snapshot;
  }

  Future<QueryRow?> _old(String table, String id, String projectId) async {
    final old =
        await database
            .customSelect(
              'SELECT * FROM $table WHERE id = ?',
              variables: [Variable.withString(id)],
              readsFrom: database.allTables.toSet(),
            )
            .getSingleOrNull();
    if (old != null && old.read<String>('project_id') != projectId)
      throw StateError('Topology identity cannot move between projects.');
    return old;
  }

  Map<String, dynamic> _payload(QueryRow row) =>
      jsonDecode(row.read<String>('payload_json')) as Map<String, dynamic>;
  DateTime _created(QueryRow? row, DateTime now) =>
      row?.read<DateTime>('created_at') ?? now;
  int _revision(QueryRow? row) => (row?.read<int>('revision') ?? 0) + 1;
  void _check(Iterable<TopologyFinding> findings, {bool draft = false}) {
    final invalid = findings.where((f) => !draft || !f.draft).toList();
    if (invalid.isNotEmpty)
      throw StateError(
        invalid.map((f) => '${f.code}: ${f.message}').join('\n'),
      );
  }

  bool _same(QueryRow? old, Map<String, Object?> payload) =>
      old != null &&
      old.readNullable<DateTime>('deleted_at') == null &&
      canonicalEngineeringJson(_payload(old)) ==
          canonicalEngineeringJson(payload);
  Future<void> _uniqueCode(
    String table,
    String scopeColumn,
    String scope,
    String code,
    String id,
  ) async {
    final rows =
        await database
            .customSelect(
              'SELECT id FROM $table WHERE $scopeColumn = ? AND code = ?',
              variables: [
                Variable.withString(scope),
                Variable.withString(code),
              ],
              readsFrom: database.allTables.toSet(),
            )
            .get();
    if (rows.any((r) => r.read<String>('id') != id))
      throw StateError(
        'Code is reserved by another identity. Restore its original record or use a new code.',
      );
  }

  Future<bool> _newProfile(
    String table,
    ProfileIdentity identity,
    Map<String, Object?> payload,
  ) async {
    await _active(identity.projectId);
    final old = await _old(table, identity.id, identity.projectId);
    if (old != null) {
      if (!_same(old, payload))
        throw StateError(
          'Profile editions are immutable. Create a new edition.',
        );
      return false;
    }
    final duplicate =
        await database
            .customSelect(
              'SELECT id FROM $table WHERE project_id = ? AND code = ? AND profile_version = ?',
              variables: [
                Variable.withString(identity.projectId),
                Variable.withString(identity.code),
                Variable.withString(identity.version),
              ],
              readsFrom: database.allTables.toSet(),
            )
            .get();
    if (duplicate.isNotEmpty)
      throw StateError('Profile code and edition already exist.');
    return true;
  }

  ProfileIdentity _identity(ProfileIdentity id) => ProfileIdentity(
    id: id.id,
    projectId: id.projectId,
    code: id.code.trim().toUpperCase(),
    version: id.version,
    source: id.source,
  );
  @override
  Future<void> saveConnectionProfile(ConnectionCompatibilityProfile profile) =>
      database.transaction(() async {
        final p = ConnectionCompatibilityProfile.fromMap({
          ...profile.toMap(),
          'identity': _identity(profile.identity).toMap(),
          'familyCodes':
              profile.familyCodes.map((s) => s.trim().toUpperCase()).toList(),
        });
        if (p.validate().isNotEmpty)
          throw ArgumentError(p.validate().join(' '));
        final s = await _active(p.identity.projectId);
        if (p.familyCodes.any(
          (code) => !s.systems.families.any((f) => f.code == code),
        ))
          throw StateError(
            'Compatibility family codes must resolve in the family catalog.',
          );
        if (!await _newProfile(
          'engineering_compatibility_profiles',
          p.identity,
          p.toMap(),
        ))
          return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringCompatibilityProfiles)
            .insert(
              EngineeringCompatibilityProfilesCompanion.insert(
                id: p.id,
                projectId: p.identity.projectId,
                code: p.identity.code,
                profileVersion: p.identity.version,
                payloadJson: canonicalEngineeringJson(p.toMap()),
                createdAt: now,
                updatedAt: now,
                originDeviceId: originDeviceId,
              ),
            );
      });
  @override
  Future<void> saveTopologyProfile(TopologyProfile profile) =>
      database.transaction(() async {
        final p = TopologyProfile(
          identity: _identity(profile.identity),
          shape: profile.shape,
          layer: profile.layer,
        );
        if (p.validate().isNotEmpty)
          throw ArgumentError(p.validate().join(' '));
        if (!await _newProfile(
          'engineering_topology_profiles',
          p.identity,
          p.toMap(),
        ))
          return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringTopologyProfiles)
            .insert(
              EngineeringTopologyProfilesCompanion.insert(
                id: p.id,
                projectId: p.identity.projectId,
                code: p.identity.code,
                profileVersion: p.identity.version,
                payloadJson: canonicalEngineeringJson(p.toMap()),
                createdAt: now,
                updatedAt: now,
                originDeviceId: originDeviceId,
              ),
            );
      });
  @override
  Future<void> saveAssemblyProfile(AssemblyProfile profile) =>
      database.transaction(() async {
        final p = AssemblyProfile(
          identity: _identity(profile.identity),
          roles: profile.roles,
          allowSharedComponents: profile.allowSharedComponents,
        );
        if (p.validate().isNotEmpty)
          throw ArgumentError(p.validate().join(' '));
        if (!await _newProfile(
          'engineering_assembly_profiles',
          p.identity,
          p.toMap(),
        ))
          return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringAssemblyProfiles)
            .insert(
              EngineeringAssemblyProfilesCompanion.insert(
                id: p.id,
                projectId: p.identity.projectId,
                code: p.identity.code,
                profileVersion: p.identity.version,
                payloadJson: canonicalEngineeringJson(p.toMap()),
                createdAt: now,
                updatedAt: now,
                originDeviceId: originDeviceId,
              ),
            );
      });
  @override
  Future<void> savePort(
    String projectId,
    EngineeringPort port,
  ) => database.transaction(() async {
    final snapshot = await _active(projectId);
    final p = EngineeringPort.fromMap({
      ...port.toMap(),
      'code': port.code.trim().toUpperCase(),
    });
    final old = await _old('engineering_port_instances', p.id, projectId);
    if (old != null && _payload(old)['componentId'] != p.componentId)
      throw StateError('Port identity cannot move between components.');
    if (_same(old, p.toMap())) return;
    await guardMutableEngineeringPortAgainstPowerOwnership(
      database,
      projectId,
      p.id,
    );
    final binding =
        await (database.select(database.componentReferenceBindings)..where(
          (r) => r.componentId.equals(p.componentId) & r.deletedAt.isNull(),
        )).getSingleOrNull();
    if (binding != null &&
        old != null &&
        canonicalEngineeringJson(_payload(old)) !=
            canonicalEngineeringJson(p.toMap()))
      throw StateError(
        'Profile-instantiated ports are frozen. Release the binding before changing their characteristics.',
      );

    if (snapshot.connections.any(
          (c) => c.fromPortId == p.id || c.toPortId == p.id,
        ) ||
        snapshot.internalLinks.any(
          (m) => m.fromPortId == p.id || m.toPortId == p.id,
        ) ||
        snapshot.groups.any(
          (g) => g.startPortId == p.id || g.endPortId == p.id,
        ))
      throw StateError(
        'Resolve external/internal links and group attachments before changing a port.',
      );
    _check(snapshot.graph(port: p).portFindings(p));
    await _uniqueCode(
      'engineering_port_instances',
      'component_id',
      p.componentId,
      p.code,
      p.id,
    );
    final now = DateTime.now().toUtc();
    await database
        .into(database.engineeringPortInstances)
        .insertOnConflictUpdate(
          EngineeringPortInstancesCompanion(
            id: Value(p.id),
            projectId: Value(projectId),
            componentId: Value(p.componentId),
            code: Value(p.code),
            payloadJson: Value(canonicalEngineeringJson(p.toMap())),
            revision: Value(_revision(old)),
            createdAt: Value(_created(old, now)),
            updatedAt: Value(now),
            deletedAt: const Value(null),
            originDeviceId: Value(originDeviceId),
          ),
        );
  });
  @override
  Future<void> saveConnection(String projectId, EngineeringConnection c) =>
      database.transaction(() async {
        final snapshot = await _active(projectId),
            graph = snapshot.graph(connection: c);
        final old = await _old('engineering_port_connections', c.id, projectId);
        _check(graph.connectionFindings(c));
        if (c.groupId != null)
          _check(graph.groupFindings(graph.groups[c.groupId]!), draft: true);
        if (_same(old, c.toMap())) return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringPortConnections)
            .insertOnConflictUpdate(
              EngineeringPortConnectionsCompanion(
                id: Value(c.id),
                projectId: Value(projectId),
                systemId: Value(c.systemId),
                fromPortId: Value(c.fromPortId),
                toPortId: Value(c.toPortId),
                profileId: Value(c.profileId),
                groupId: Value(c.groupId),
                payloadJson: Value(canonicalEngineeringJson(c.toMap())),
                revision: Value(_revision(old)),
                createdAt: Value(_created(old, now)),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      });
  @override
  Future<void> saveInternal(String projectId, InternalConnectivity mapping) =>
      database.transaction(() async {
        final snapshot = await _active(projectId),
            graph = snapshot.graph(internal: mapping);
        final old = await _old(
          'engineering_internal_mappings',
          mapping.id,
          projectId,
        );
        if (old != null && _payload(old)['componentId'] != mapping.componentId)
          throw StateError('Internal identity cannot move between components.');
        _check(graph.internalFindings(mapping));
        for (final g in graph.groups.values) {
          if (graph.ports[g.startPortId]?.componentId == mapping.componentId ||
              graph.ports[g.endPortId]?.componentId == mapping.componentId ||
              graph.connections.values.any(
                (c) =>
                    c.groupId == g.id &&
                    (graph.ports[c.fromPortId]?.componentId ==
                            mapping.componentId ||
                        graph.ports[c.toPortId]?.componentId ==
                            mapping.componentId),
              ))
            _check(graph.groupFindings(g), draft: true);
        }
        if (_same(old, mapping.toMap())) return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringInternalMappings)
            .insertOnConflictUpdate(
              EngineeringInternalMappingsCompanion(
                id: Value(mapping.id),
                projectId: Value(projectId),
                componentId: Value(mapping.componentId),
                fromPortId: Value(mapping.fromPortId),
                toPortId: Value(mapping.toPortId),
                payloadJson: Value(canonicalEngineeringJson(mapping.toMap())),
                revision: Value(_revision(old)),
                createdAt: Value(_created(old, now)),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      });
  @override
  Future<void> saveGroup(String projectId, TopologyGroup group) =>
      database.transaction(() async {
        final snapshot = await _active(projectId);
        final g = TopologyGroup.fromMap({
          ...group.toMap(),
          'code': group.code.trim().toUpperCase(),
        });
        final old = await _old('engineering_topology_groups', g.id, projectId);
        if (old != null && _payload(old)['systemId'] != g.systemId)
          throw StateError('Group identity cannot move between systems.');
        _check(snapshot.graph(group: g).groupFindings(g), draft: true);
        await _uniqueCode(
          'engineering_topology_groups',
          'system_id',
          g.systemId,
          g.code,
          g.id,
        );
        if (_same(old, g.toMap())) return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringTopologyGroups)
            .insertOnConflictUpdate(
              EngineeringTopologyGroupsCompanion(
                id: Value(g.id),
                projectId: Value(projectId),
                systemId: Value(g.systemId),
                code: Value(g.code),
                profileId: Value(g.profileId),
                startPortId: Value(g.startPortId),
                endPortId: Value(g.endPortId),
                payloadJson: Value(canonicalEngineeringJson(g.toMap())),
                revision: Value(_revision(old)),
                createdAt: Value(_created(old, now)),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      });
  @override
  Future<void> saveAssembly(String projectId, ComponentAssembly assembly) =>
      database.transaction(() async {
        final snapshot = await _active(projectId);
        final a = ComponentAssembly.fromMap({
          ...assembly.toMap(),
          'code': assembly.code.trim().toUpperCase(),
        });
        final old = await _old(
          'engineering_component_assemblies',
          a.id,
          projectId,
        );
        _check(snapshot.graph(assembly: a).assemblyFindings(a), draft: true);
        await _uniqueCode(
          'engineering_component_assemblies',
          'project_id',
          projectId,
          a.code,
          a.id,
        );
        if (_same(old, a.toMap())) return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringComponentAssemblies)
            .insertOnConflictUpdate(
              EngineeringComponentAssembliesCompanion(
                id: Value(a.id),
                projectId: Value(projectId),
                code: Value(a.code),
                profileId: Value(a.profileId),
                payloadJson: Value(canonicalEngineeringJson(a.toMap())),
                revision: Value(_revision(old)),
                createdAt: Value(_created(old, now)),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      });

  @override
  Future<void> archive(
    String projectId,
    TopologyObjectKind kind,
    String id,
  ) => database.transaction(() async {
    final s = await _active(projectId);
    final table = switch (kind) {
      TopologyObjectKind.port => 'engineering_port_instances',
      TopologyObjectKind.connection => 'engineering_port_connections',
      TopologyObjectKind.internalMapping => 'engineering_internal_mappings',
      TopologyObjectKind.group => 'engineering_topology_groups',
      TopologyObjectKind.assembly => 'engineering_component_assemblies',
    };
    final old = await _old(table, id, projectId);
    if (old == null || old.readNullable<DateTime>('deleted_at') != null)
      throw StateError('Topology object is unavailable.');
    if (kind == TopologyObjectKind.port) {
      await guardMutableEngineeringPortAgainstPowerOwnership(
        database,
        projectId,
        id,
      );
    }
    if (kind == TopologyObjectKind.port &&
        (s.connections.any((c) => c.fromPortId == id || c.toPortId == id) ||
            s.internalLinks.any(
              (m) => m.fromPortId == id || m.toPortId == id,
            ) ||
            s.groups.any((g) => g.startPortId == id || g.endPortId == id)))
      throw StateError(
        'Resolve port links and group attachments before retirement.',
      );
    if (kind == TopologyObjectKind.group &&
        s.connections.any((c) => c.groupId == id))
      throw StateError('Detach group connections before retirement.');
    final now = DateTime.now().toUtc();
    // Each typed write notifies Drift observers; no anonymous raw SQL mutation.
    switch (kind) {
      case TopologyObjectKind.port:
        await (database.update(database.engineeringPortInstances)
          ..where((r) => r.id.equals(id))).write(
          EngineeringPortInstancesCompanion(
            revision: Value(_revision(old)),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
      case TopologyObjectKind.connection:
        await (database.update(database.engineeringPortConnections)
          ..where((r) => r.id.equals(id))).write(
          EngineeringPortConnectionsCompanion(
            revision: Value(_revision(old)),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
      case TopologyObjectKind.internalMapping:
        await (database.update(database.engineeringInternalMappings)
          ..where((r) => r.id.equals(id))).write(
          EngineeringInternalMappingsCompanion(
            revision: Value(_revision(old)),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
      case TopologyObjectKind.group:
        await (database.update(database.engineeringTopologyGroups)
          ..where((r) => r.id.equals(id))).write(
          EngineeringTopologyGroupsCompanion(
            revision: Value(_revision(old)),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
      case TopologyObjectKind.assembly:
        await (database.update(database.engineeringComponentAssemblies)
          ..where((r) => r.id.equals(id))).write(
          EngineeringComponentAssembliesCompanion(
            revision: Value(_revision(old)),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
    }
  });
}
