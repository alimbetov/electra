import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';
import '../../application/engineering_reference_repository.dart';
import '../../application/id_generator.dart';
import '../database/app_database.dart';
import 'drift_engineering_system_repository.dart';
import 'drift_engineering_topology_repository.dart';

class DriftEngineeringReferenceRepository
    implements EngineeringReferenceRepository {
  DriftEngineeringReferenceRepository(
    this.database, {
    required this.originDeviceId,
    required this.idGenerator,
  });
  final AppDatabase database;
  final String originDeviceId;
  final IdGenerator idGenerator;
  @override
  Stream<ProjectEngineeringReferences> watch(String projectId) => database
      .customSelect(
        'SELECT id FROM projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(projectId));
  @override
  Future<ProjectEngineeringReferences> load(String projectId) =>
      database.transaction(() async {
        final systems = await DriftEngineeringSystemRepository(
          database,
          originDeviceId: originDeviceId,
        ).load(projectId);
        final catalogs =
            await (database.select(database.engineeringReferenceCatalogs)
              ..where((r) => r.projectId.equals(projectId))).get();
        final bindings =
            await (database.select(database.componentReferenceBindings)..where(
              (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
            )).get();
        return ProjectEngineeringReferences(
          systems: systems,
          catalogs:
              catalogs
                  .map(
                    (r) => EngineeringReferenceCatalog.fromMap(
                      jsonDecode(r.payloadJson) as Map<String, dynamic>,
                    ),
                  )
                  .toList(),
          bindings:
              bindings
                  .map(
                    (r) => ComponentReferenceBinding.fromMap(
                      jsonDecode(r.payloadJson) as Map<String, dynamic>,
                    ),
                  )
                  .toList(),
        );
      });
  Future<ProjectEngineeringReferences> _active(String projectId) async {
    final s = await load(projectId);
    if (s.systems.project == null) throw StateError('Project unavailable.');
    return s;
  }

  @override
  Future<void> importCatalog(
    String projectId,
    EngineeringReferenceCatalog catalog,
  ) => database.transaction(() async {
    await _active(projectId);
    if (catalog.validate().isNotEmpty)
      throw ArgumentError(catalog.validate().join(' '));
    final payload = canonicalEngineeringJson(catalog.toMap());
    final old =
        await (database.select(database.engineeringReferenceCatalogs)
          ..where((r) => r.id.equals(catalog.id))).getSingleOrNull();
    if (old != null) {
      if (old.projectId != projectId || old.payloadJson != payload)
        throw StateError(
          'Catalog editions are immutable. Import a new identity and edition.',
        );
      return;
    }
    final topology = DriftEngineeringTopologyRepository(
      database,
      originDeviceId: originDeviceId,
    );
    for (final profile in catalog.connectionProfiles(projectId)) {
      await topology.saveConnectionProfile(profile);
    }
    final now = DateTime.now().toUtc();
    await database
        .into(database.engineeringReferenceCatalogs)
        .insert(
          EngineeringReferenceCatalogsCompanion.insert(
            id: catalog.id,
            projectId: projectId,
            code: catalog.code.trim().toUpperCase(),
            catalogVersion: catalog.version,
            payloadJson: payload,
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
  });
  @override
  Future<void> bind(
    String projectId,
    String componentId,
    String catalogId,
    String profileCode,
  ) => database.transaction(() async {
    final s = await _active(projectId);
    if (!s.systems.components.any((c) => c.id == componentId))
      throw StateError('Choose an active placed component in this project.');
    final catalog = s.catalogs.where((c) => c.id == catalogId).single;
    final profile = catalog.profile(profileCode);
    final familyCode = switch (profile.discipline) {
      ReferenceDiscipline.cctv => 'CCTV',
      ReferenceDiscipline.lan => 'LAN',
      ReferenceDiscipline.acs => 'ACS',
      ReferenceDiscipline.fire => 'FIRE',
    };
    final eligibleSystems =
        s.systems.systems
            .where(
              (sys) => s.systems.families.any(
                (f) =>
                    f.id == sys.familyId &&
                    f.version == sys.familyVersion &&
                    f.code == familyCode,
              ),
            )
            .map((sys) => sys.id)
            .toSet();
    if (!s.systems.memberships.any(
      (m) =>
          m.componentId == componentId && eligibleSystems.contains(m.systemId),
    ))
      throw StateError(
        'Assign the device to the profile discipline system first.',
      );
    final old =
        await (database.select(database.componentReferenceBindings)
          ..where((r) => r.componentId.equals(componentId))).getSingleOrNull();
    if (old != null && old.deletedAt == null) {
      if (old.projectId == projectId &&
          old.catalogId == catalogId &&
          old.profileCode == profileCode)
        return;
      throw StateError(
        'Explicitly release the old binding and resolve its ports before adopting another edition.',
      );
    }
    if (old != null && old.projectId != projectId)
      throw StateError('Binding identity cannot move between projects.');
    final existing =
        await (database.select(database.engineeringPortInstances)..where(
          (r) => r.componentId.equals(componentId) & r.deletedAt.isNull(),
        )).get();
    if (existing.isNotEmpty)
      throw StateError(
        'Resolve existing manually authored ports before profile instantiation.',
      );
    final retired =
        await (database.select(database.engineeringPortInstances)..where(
          (r) => r.componentId.equals(componentId) & r.deletedAt.isNotNull(),
        )).get();
    final retiredIds = {for (final r in retired) r.code: r.id};
    var templateIndex = 0;
    final ports = profile.instantiate(
      componentId: componentId,
      catalogId: catalog.id,
      version: catalog.version,
      vocabulary: catalog.vocabulary,
      nextId: () {
        final code =
            profile.portTemplates[templateIndex++].code.trim().toUpperCase();
        return retiredIds[code] ?? idGenerator.next();
      },
    );
    final topology = DriftEngineeringTopologyRepository(
      database,
      originDeviceId: originDeviceId,
    );
    for (final port in ports) {
      await topology.savePort(projectId, port);
    }
    final binding = ComponentReferenceBinding(
      componentId: componentId,
      catalogId: catalog.id,
      profileCode: profile.code,
      catalogVersion: catalog.version,
      profile: profile,
      portIds: ports.map((p) => p.id).toList(),
    );
    final now = DateTime.now().toUtc();
    await database
        .into(database.componentReferenceBindings)
        .insertOnConflictUpdate(
          ComponentReferenceBindingsCompanion(
            componentId: Value(componentId),
            projectId: Value(projectId),
            catalogId: Value(catalogId),
            profileCode: Value(profileCode),
            payloadJson: Value(canonicalEngineeringJson(binding.toMap())),
            createdAt: Value(old?.createdAt ?? now),
            updatedAt: Value(now),
            deletedAt: const Value(null),
            revision: Value((old?.revision ?? 0) + 1),
            originDeviceId: Value(originDeviceId),
          ),
        );
  });
  @override
  Future<void> unbind(
    String projectId,
    String componentId,
  ) => database.transaction(() async {
    await _active(projectId);
    final row =
        await (database.select(database.componentReferenceBindings)..where(
          (r) =>
              r.componentId.equals(componentId) &
              r.projectId.equals(projectId) &
              r.deletedAt.isNull(),
        )).getSingle();
    final ports =
        ComponentReferenceBinding.fromMap(
          jsonDecode(row.payloadJson) as Map<String, dynamic>,
        ).portIds;
    final activePorts =
        await (database.select(database.engineeringPortInstances)
          ..where((r) => r.id.isIn(ports) & r.deletedAt.isNull())).get();
    if (activePorts.isNotEmpty)
      throw StateError(
        'Resolve links and retire instantiated ports before releasing the binding.',
      );
    final now = DateTime.now().toUtc();
    await (database.update(database.componentReferenceBindings)
      ..where((r) => r.componentId.equals(componentId))).write(
      ComponentReferenceBindingsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        revision: Value(row.revision + 1),
        originDeviceId: Value(originDeviceId),
      ),
    );
  });
}
