import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';
import '../../application/manufacturer_repository.dart';
import '../database/app_database.dart';
import 'drift_protection_repository.dart';
import 'drift_dependency_recalculation_repository.dart';
import 'drift_project_hierarchy_repository.dart';

class DriftManufacturerRepository implements ManufacturerRepository {
  DriftManufacturerRepository(this.database, {required this.originDeviceId});
  final AppDatabase database;
  final String originDeviceId;
  DriftDependencyRecalculationRepository get engine =>
      DriftDependencyRecalculationRepository(
        database,
        originDeviceId: originDeviceId,
      );
  @override
  Stream<ProjectManufacturerSnapshot> watch(String projectId) => database
      .customSelect(
        'SELECT id, revision FROM projects WHERE id = ?',
        variables: [Variable.withString(projectId)],
        readsFrom: database.allTables.toSet(),
      )
      .watch()
      .asyncMap((_) => load(projectId));
  @override
  Future<ProjectManufacturerSnapshot> load(String projectId) =>
      database.transaction(() async {
        final protection = await DriftProtectionRepository(
          database,
          originDeviceId: originDeviceId,
        ).load(projectId);
        final catalogs =
            await (database.select(database.manufacturerCatalogs)
                  ..where((r) => r.deletedAt.isNull())
                  ..orderBy([
                    (r) => OrderingTerm.asc(r.manufacturer),
                    (r) => OrderingTerm.asc(r.catalogVersion),
                    (r) => OrderingTerm.asc(r.id),
                  ]))
                .get();
        final row =
            await (database.select(database.manufacturerPolicies)..where(
              (r) => r.projectId.equals(projectId) & r.deletedAt.isNull(),
            )).getSingleOrNull();
        final ids = protection.circuits.map((c) => c.circuitId).toList();
        final selections =
            await (database.select(database.circuitProductSelections)..where(
              (r) => r.circuitId.isIn(ids) & r.deletedAt.isNull(),
            )).get();
        return ProjectManufacturerSnapshot(
          protection: protection,
          catalogs: catalogs
              .map(
                (c) => ManufacturerCatalogCodec.decodeCatalog(
                  jsonDecode(c.payloadJson) as Map<String, dynamic>,
                ),
              )
              .toList(growable: false),
          policy:
              row == null
                  ? const ProjectManufacturerPolicy()
                  : ManufacturerCatalogCodec.decodePolicy(
                    jsonDecode(row.payloadJson) as Map<String, dynamic>,
                  ),
          selections: {
            for (final s in selections)
              s.circuitId: ManufacturerSelection(
                circuitId: s.circuitId,
                productId: s.productId,
                snapshot: jsonDecode(s.snapshotJson) as Map<String, dynamic>,
                requirementFingerprint: s.requirementFingerprint,
                policyJson: s.policyJson,
              ),
          },
        );
      });
  @override
  Future<void> importCatalog(
    ManufacturerCatalog catalog,
  ) => database.transaction(() async {
    if ([
          catalog.id ?? '',
          catalog.manufacturer,
          catalog.catalogVersion,
          catalog.sourceReference ?? '',
        ].any((v) => v.trim().isEmpty) ||
        catalog.products.isEmpty)
      throw ArgumentError(
        'Catalog ID, manufacturer, version, source and products are required.',
      );
    final ids = <String>{}, skus = <String>{};
    for (final p in catalog.products) {
      final errors = ManufacturerProductMatcher.validateProduct(p);
      if (errors.isNotEmpty) throw ArgumentError(errors.join(' '));
      if (ManufacturerProductMatcher.normalize(p.manufacturer) !=
          ManufacturerProductMatcher.normalize(catalog.manufacturer))
        throw ArgumentError(
          'All products must match the catalog manufacturer.',
        );
      if (!ids.add(p.id) || !skus.add(p.sku))
        throw ArgumentError(
          'Product IDs and SKUs must be unique within the catalog.',
        );
    }
    final payload = canonicalEngineeringJson(
      ManufacturerCatalogCodec.catalog(catalog),
    );
    final old =
        await (database.select(database.manufacturerCatalogs)
          ..where((r) => r.id.equals(catalog.id!))).getSingleOrNull();
    if (old != null) {
      if (old.deletedAt != null)
        throw StateError('Catalog is archived; import a new version.');
      if (canonicalEngineeringJson(jsonDecode(old.payloadJson)) != payload)
        throw StateError(
          'Catalog versions are immutable. Import a new version.',
        );
      return;
    }
    final all = await database.select(database.manufacturerCatalogs).get();
    if (all.any(
      (c) =>
          ManufacturerProductMatcher.normalize(c.manufacturer) ==
              ManufacturerProductMatcher.normalize(catalog.manufacturer) &&
          c.catalogVersion == catalog.catalogVersion &&
          ManufacturerProductMatcher.normalize(c.region ?? '') ==
              ManufacturerProductMatcher.normalize(catalog.region ?? ''),
    )) {
      throw StateError('This manufacturer/version/region already exists.');
    }
    final borrowed =
        await (database.select(database.manufacturerProducts)
          ..where((p) => p.id.isIn(ids))).get();
    if (borrowed.isNotEmpty)
      throw StateError(
        'Product IDs cannot be reused from another catalog version.',
      );
    final now = DateTime.now().toUtc();
    await database
        .into(database.manufacturerCatalogs)
        .insert(
          ManufacturerCatalogsCompanion.insert(
            id: catalog.id!,
            manufacturer: catalog.manufacturer,
            catalogVersion: catalog.catalogVersion,
            region: Value(catalog.region),
            sourceReference: catalog.sourceReference!,
            payloadJson: payload,
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
    for (final product in catalog.products) {
      await database
          .into(database.manufacturerProducts)
          .insert(
            ManufacturerProductsCompanion.insert(
              id: product.id,
              catalogId: catalog.id!,
              sku: product.sku,
              payloadJson: canonicalEngineeringJson(
                ManufacturerCatalogCodec.product(product),
              ),
              createdAt: now,
              updatedAt: now,
              originDeviceId: originDeviceId,
            ),
          );
    }
  });
  @override
  Future<void> archiveCatalog(
    String catalogId,
  ) => database.transaction(() async {
    final row =
        await (database.select(database.manufacturerCatalogs)
          ..where((r) => r.id.equals(catalogId))).getSingleOrNull();
    if (row == null || row.deletedAt != null) return;
    final now = DateTime.now().toUtc();
    await (database.update(database.manufacturerCatalogs)
      ..where((r) => r.id.equals(catalogId))).write(
      ManufacturerCatalogsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
        revision: Value(row.revision + 1),
        originDeviceId: Value(originDeviceId),
      ),
    );
    // Preserve original selection snapshots. Freshness and catalog availability are checked on read.
  });
  @override
  Future<void> savePolicy(String projectId, ProjectManufacturerPolicy policy) =>
      database.transaction(() async {
        final project = await DriftProjectHierarchyRepository(
          database,
        ).findProject(projectId);
        if (project == null) throw StateError('Project is unavailable.');
        for (final list in [
          policy.allowedManufacturers,
          policy.preferredManufacturers,
        ]) {
          if (list.any((v) => v.trim().isEmpty) ||
              list.map(ManufacturerProductMatcher.normalize).toSet().length !=
                  list.length)
            throw ArgumentError(
              'Manufacturer lists must be nonempty strings with no duplicates.',
            );
        }
        if (policy.preferredSeriesByRole.values.any((v) => v.trim().isEmpty))
          throw ArgumentError('Preferred series must be nonempty.');
        final old =
            await (database.select(database.manufacturerPolicies)
              ..where((r) => r.projectId.equals(projectId))).getSingleOrNull();
        final payload = canonicalEngineeringJson(
          ManufacturerCatalogCodec.policy(policy),
        );
        if (old != null &&
            old.deletedAt == null &&
            canonicalEngineeringJson(jsonDecode(old.payloadJson)) == payload)
          return;
        final now = DateTime.now().toUtc();
        await database
            .into(database.manufacturerPolicies)
            .insertOnConflictUpdate(
              ManufacturerPoliciesCompanion(
                projectId: Value(projectId),
                payloadJson: Value(payload),
                createdAt: Value(old?.createdAt ?? now),
                updatedAt: Value(now),
                revision: Value((old?.revision ?? 0) + 1),
                deletedAt: const Value(null),
                originDeviceId: Value(originDeviceId),
              ),
            );
        await engine.recalculate(projectId);
      });
  @override
  Future<void> selectProduct({
    required String projectId,
    required String circuitId,
    required String productId,
    required String expectedRequirementFingerprint,
  }) => database.transaction(() async {
    final snapshot = await load(projectId);
    final circuit =
        snapshot.protection.circuits
            .where((c) => c.circuitId == circuitId)
            .firstOrNull;
    if (snapshot.protection.recalculation.project == null ||
        circuit == null ||
        circuit.fingerprint != expectedRequirementFingerprint ||
        circuit.stale)
      throw StateError(
        'Requirement changed. Recalculate and review the current proposal.',
      );
    final candidate =
        snapshot
            .candidates(circuit)
            .where((c) => c.product.id == productId)
            .firstOrNull;
    if (candidate == null)
      throw StateError(
        'Choose an active product with all required technical characteristics and project policy compatibility.',
      );
    final now = DateTime.now().toUtc();
    final old =
        await (database.select(database.circuitProductSelections)
          ..where((r) => r.circuitId.equals(circuitId))).getSingleOrNull();
    final productSnapshot = <String, Object?>{
      'catalogId': candidate.catalog.id,
      'manufacturer': candidate.catalog.manufacturer,
      'catalogVersion': candidate.catalog.catalogVersion,
      'region': candidate.catalog.region,
      'sourceReference': candidate.catalog.sourceReference,
      'product': ManufacturerCatalogCodec.product(candidate.product),
    };
    await database
        .into(database.circuitProductSelections)
        .insertOnConflictUpdate(
          CircuitProductSelectionsCompanion(
            circuitId: Value(circuitId),
            productId: Value(productId),
            requirementFingerprint: Value(circuit.fingerprint),
            policyJson: Value(
              canonicalEngineeringJson(
                ManufacturerCatalogCodec.policy(snapshot.policy),
              ),
            ),
            snapshotJson: Value(canonicalEngineeringJson(productSnapshot)),
            createdAt: Value(old?.createdAt ?? now),
            updatedAt: Value(now),
            revision: Value((old?.revision ?? 0) + 1),
            deletedAt: const Value(null),
            originDeviceId: Value(originDeviceId),
          ),
        );
    await engine.recalculate(projectId);
  });
  @override
  Future<void> clearSelection(String projectId, String circuitId) =>
      database.transaction(() async {
        final snapshot = await load(projectId);
        if (snapshot.protection.recalculation.project == null ||
            !snapshot.protection.circuits.any((c) => c.circuitId == circuitId))
          throw StateError('Circuit is unavailable.');
        final row =
            await (database.select(database.circuitProductSelections)
              ..where((r) => r.circuitId.equals(circuitId))).getSingleOrNull();
        if (row == null || row.deletedAt != null) return;
        final now = DateTime.now().toUtc();
        await (database.update(database.circuitProductSelections)
          ..where((r) => r.circuitId.equals(circuitId))).write(
          CircuitProductSelectionsCompanion(
            deletedAt: Value(now),
            updatedAt: Value(now),
            revision: Value(row.revision + 1),
            originDeviceId: Value(originDeviceId),
          ),
        );
        await engine.recalculate(projectId);
      });
}
