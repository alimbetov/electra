import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_cable_repository.dart';
import '../database/app_database.dart';

final class DriftElvCableRepository implements ElvCableRepository {
  const DriftElvCableRepository(this.database);

  final AppDatabase database;

  @override
  Future<List<Cable>> loadProjectCables(String projectId) async {
    final rows =
        await (database.select(database.elvCables)..where(
              (row) => row.projectId.equals(projectId) & row.deletedAt.isNull(),
            ))
            .get();
    return rows.map(_cableFromRow).toList(growable: false);
  }

  @override
  Future<Cable?> findCable(String projectId, String cableId) async {
    final row =
        await (database.select(database.elvCables)..where(
              (candidate) =>
                  candidate.projectId.equals(projectId) &
                  candidate.id.equals(cableId) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    return row == null ? null : _cableFromRow(row);
  }

  @override
  Stream<List<Cable>> watchProjectCables(String projectId) =>
      (database.select(database.elvCables)..where(
            (row) => row.projectId.equals(projectId) & row.deletedAt.isNull(),
          ))
          .watch()
          .map((rows) => rows.map(_cableFromRow).toList(growable: false));

  @override
  Future<CableDefinition> resolveDefinition(
    String projectId,
    CableDefinitionRef ref,
  ) async {
    final normalized = ref.normalized();
    final row =
        await (database.select(database.engineeringReferenceCatalogs)..where(
              (candidate) =>
                  candidate.projectId.equals(projectId) &
                  candidate.id.equals(normalized.catalogId) &
                  candidate.catalogVersion.equals(normalized.catalogVersion) &
                  candidate.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (row == null) {
      throw StateError('Cable definition catalog edition not found.');
    }
    final catalog = EngineeringReferenceCatalog.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    final definition = catalog.cableDefinition(normalized.definitionCode);
    final actualHash = cableDefinitionContentHashV1(definition);
    if (actualHash != normalized.definitionContentHash) {
      throw StateError('Cable definition content hash mismatch.');
    }
    return definition;
  }

  Cable _cableFromRow(ElvCableRow row) => Cable(
    id: row.id,
    projectId: row.projectId,
    label: row.label,
    name: row.name,
    definitionRef: CableDefinitionRef(
      catalogId: row.definitionCatalogId,
      catalogVersion: row.definitionCatalogVersion,
      definitionCode: row.definitionCode,
      definitionContentHash: row.definitionContentHash,
    ),
    lifecycleState: CableLifecycleState.values.byName(
      row.lifecycleState.toLowerCase(),
    ),
    revision: row.revision,
  );
}
