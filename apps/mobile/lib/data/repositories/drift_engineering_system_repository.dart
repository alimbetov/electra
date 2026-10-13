import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';
import '../../application/engineering_system_repository.dart';
import '../database/app_database.dart';
import 'drift_project_hierarchy_repository.dart';

class DriftEngineeringSystemRepository implements EngineeringSystemRepository {
  DriftEngineeringSystemRepository(
    this.database, {
    required this.originDeviceId,
  });
  final AppDatabase database;
  final String originDeviceId;
  @override
  Stream<ProjectEngineeringSystemsSnapshot> watch(String projectId) => database
      .customSelect(
        'SELECT id FROM projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(projectId));
  @override
  Future<ProjectEngineeringSystemsSnapshot> load(
    String projectId,
  ) => database.transaction(() async {
    final project = await DriftProjectHierarchyRepository(
      database,
    ).findProject(projectId);
    final families =
        await (database.select(database.engineeringFamilyDefinitions)
              ..where((r) => r.deletedAt.isNull())
              ..orderBy([
                (r) => OrderingTerm.asc(r.code),
                (r) => OrderingTerm.asc(r.familyVersion),
              ]))
            .get();
    final allRows =
        project == null
            ? <ProjectEngineeringSystemRow>[]
            : await (database.select(database.projectEngineeringSystems)
                  ..where((r) => r.projectId.equals(projectId))
                  ..orderBy([(r) => OrderingTerm.asc(r.code)]))
                .get();
    final rows = allRows.where((r) => r.deletedAt == null).toList();
    final memberships =
        await (database.select(database.componentEngineeringMemberships)
              ..where(
                (r) =>
                    r.systemId.isIn(rows.map((r) => r.id)) &
                    r.deletedAt.isNull(),
              )
              ..orderBy([
                (r) => OrderingTerm.asc(r.systemId),
                (r) => OrderingTerm.asc(r.componentId),
              ]))
            .get();
    final components =
        project == null
            ? <QueryRow>[]
            : await database
                .customSelect(
                  '''SELECT ci.id, ci.definition_id, ci.display_name_override, r.name AS room_name
      FROM component_instances ci JOIN rooms r ON r.id = ci.room_id JOIN floors f ON f.id = r.floor_id
      WHERE f.project_id = ? AND f.deleted_at IS NULL AND r.deleted_at IS NULL AND ci.deleted_at IS NULL ORDER BY ci.id''',
                  variables: [Variable.withString(projectId)],
                  readsFrom: database.allTables.toSet(),
                )
                .get();
    return ProjectEngineeringSystemsSnapshot(
      project: project,
      archivedSystems: [
        for (final row in allRows.where((r) => r.deletedAt != null))
          EngineeringSystem.fromMap(
            jsonDecode(row.payloadJson) as Map<String, dynamic>,
          ),
      ],
      families:
          families
              .map(
                (r) => EngineeringSystemFamily.fromMap(
                  jsonDecode(r.payloadJson) as Map<String, dynamic>,
                ),
              )
              .toList(),
      systems:
          rows
              .map(
                (r) => EngineeringSystem.fromMap(
                  jsonDecode(r.payloadJson) as Map<String, dynamic>,
                ),
              )
              .toList(),
      memberships:
          memberships
              .map(
                (r) => ComponentSystemMembership(
                  systemId: r.systemId,
                  componentId: r.componentId,
                  role: r.role,
                ),
              )
              .toList(),
      components:
          components
              .map(
                (r) => EngineeringComponentView(
                  id: r.read<String>('id'),
                  name:
                      r.readNullable<String>('display_name_override') ??
                      r.read<String>('definition_id'),
                  roomName: r.read<String>('room_name'),
                ),
              )
              .toList(),
    );
  });
  @override
  Future<void> saveFamily(EngineeringSystemFamily family) =>
      database.transaction(() async {
        if (family.validate().isNotEmpty)
          throw ArgumentError(family.validate().join(' '));
        final normalized = EngineeringSystemFamily.fromMap({
          ...family.toMap(),
          'code': family.code.trim().toUpperCase(),
        });
        final old =
            await (database.select(database.engineeringFamilyDefinitions)
              ..where((r) => r.id.equals(family.id))).getSingleOrNull();
        final payload = canonicalEngineeringJson(normalized.toMap());
        if (old != null) {
          if (canonicalEngineeringJson(jsonDecode(old.payloadJson)) !=
                  payload ||
              old.deletedAt != null)
            throw StateError(
              'Family editions are immutable. Create a new edition.',
            );
          return;
        }
        final duplicates =
            await (database.select(database.engineeringFamilyDefinitions)
              ..where(
                (r) =>
                    r.code.equals(normalized.code) &
                    r.familyVersion.equals(family.version),
              )).get();
        if (duplicates.isNotEmpty)
          throw StateError('Family code and edition already exist.');
        final now = DateTime.now().toUtc();
        await database
            .into(database.engineeringFamilyDefinitions)
            .insert(
              EngineeringFamilyDefinitionsCompanion.insert(
                id: family.id,
                code: normalized.code,
                familyVersion: family.version,
                payloadJson: payload,
                createdAt: now,
                updatedAt: now,
                originDeviceId: originDeviceId,
              ),
            );
      });
  @override
  Future<void> saveSystem(EngineeringSystem system) =>
      database.transaction(() async {
        if (system.validate().isNotEmpty)
          throw ArgumentError(system.validate().join(' '));
        final snapshot = await load(system.projectId);
        final family =
            snapshot.families.where((f) => f.id == system.familyId).firstOrNull;
        if (snapshot.project == null ||
            family == null ||
            family.version != system.familyVersion)
          throw StateError(
            'Active project and exact family edition are required.',
          );
        final old =
            await (database.select(database.projectEngineeringSystems)
              ..where((r) => r.id.equals(system.id))).getSingleOrNull();
        if (old != null && old.projectId != system.projectId)
          throw StateError('System identity cannot move between projects.');
        final existingMemberships =
            await (database.select(database.componentEngineeringMemberships)
              ..where(
                (r) => r.systemId.equals(system.id) & r.deletedAt.isNull(),
              )).get();
        if (old != null &&
            old.familyId != system.familyId &&
            existingMemberships.isNotEmpty)
          throw StateError(
            'Detach participants before changing the family edition.',
          );
        final normalized = EngineeringSystem.fromMap({
          ...system.toMap(),
          'code': system.code.trim().toUpperCase(),
          'name': system.name.trim(),
        });
        final duplicates =
            await (database.select(database.projectEngineeringSystems)..where(
              (r) =>
                  r.projectId.equals(system.projectId) &
                  r.code.equals(normalized.code),
            )).get();
        if (duplicates.any((r) => r.id != system.id))
          throw StateError('System code is already used in this project.');
        final payload = canonicalEngineeringJson(normalized.toMap());
        if (old != null &&
            old.deletedAt == null &&
            canonicalEngineeringJson(jsonDecode(old.payloadJson)) == payload)
          return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.projectEngineeringSystems)
            .insertOnConflictUpdate(
              ProjectEngineeringSystemsCompanion(
                id: Value(system.id),
                projectId: Value(system.projectId),
                code: Value(normalized.code),
                familyId: Value(system.familyId),
                payloadJson: Value(payload),
                revision: Value((old?.revision ?? 0) + 1),
                createdAt: Value(old?.createdAt ?? now),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      });
  Future<ProjectEngineeringSystemsSnapshot> _activeSystem(
    String projectId,
    String systemId,
  ) async {
    final snapshot = await load(projectId);
    if (snapshot.project == null ||
        !snapshot.systems.any((s) => s.id == systemId))
      throw StateError('System is unavailable in this project.');
    return snapshot;
  }

  @override
  Future<void> assign(String projectId, ComponentSystemMembership membership) =>
      database.transaction(() async {
        if (membership.validate().isNotEmpty)
          throw ArgumentError(membership.validate().join(' '));
        final snapshot = await _activeSystem(projectId, membership.systemId);
        if (!snapshot.components.any((c) => c.id == membership.componentId))
          throw StateError(
            'Component must be active and belong to the same project.',
          );
        final old =
            await (database.select(database.componentEngineeringMemberships)
              ..where(
                (r) =>
                    r.systemId.equals(membership.systemId) &
                    r.componentId.equals(membership.componentId),
              )).getSingleOrNull();
        final role = membership.role.trim();
        if (old != null && old.deletedAt == null && old.role == role) return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.componentEngineeringMemberships)
            .insertOnConflictUpdate(
              ComponentEngineeringMembershipsCompanion(
                systemId: Value(membership.systemId),
                componentId: Value(membership.componentId),
                role: Value(role),
                revision: Value((old?.revision ?? 0) + 1),
                createdAt: Value(old?.createdAt ?? now),
                updatedAt: Value(now),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
      });
  @override
  Future<void> detach(String projectId, String systemId, String componentId) =>
      database.transaction(() async {
        await _activeSystem(projectId, systemId);
        final old =
            await (database.select(database.componentEngineeringMemberships)
              ..where(
                (r) =>
                    r.systemId.equals(systemId) &
                    r.componentId.equals(componentId) &
                    r.deletedAt.isNull(),
              )).getSingleOrNull();
        if (old == null) return;
        final now = DateTime.now().toUtc();
        await (database.update(database.componentEngineeringMemberships)..where(
          (r) =>
              r.systemId.equals(systemId) & r.componentId.equals(componentId),
        )).write(
          ComponentEngineeringMembershipsCompanion(
            revision: Value(old.revision + 1),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
      });
  @override
  Future<void> archiveSystem(String projectId, String systemId) =>
      database.transaction(() async {
        final snapshot = await _activeSystem(projectId, systemId);
        if (snapshot.memberships.any((m) => m.systemId == systemId))
          throw StateError('Detach participants before archiving the system.');
        final row =
            await (database.select(database.projectEngineeringSystems)
              ..where((r) => r.id.equals(systemId))).getSingle();
        final now = DateTime.now().toUtc();
        await (database.update(database.projectEngineeringSystems)
          ..where((r) => r.id.equals(systemId))).write(
          ProjectEngineeringSystemsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            revision: Value(row.revision + 1),
            originDeviceId: Value(originDeviceId),
          ),
        );
      });
}
