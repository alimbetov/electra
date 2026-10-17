import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';

import '../../../application/elv5/fire/fa08_route_facts.dart';
import '../../../application/elv_cable_run_repository.dart';
import '../../database/app_database.dart';

final class DriftFa08RouteCableFactSource implements Fa08RouteCableFactSource {
  const DriftFa08RouteCableFactSource({
    required this.database,
    required this.cableRuns,
  });

  final AppDatabase database;
  final ElvCableRunRepository cableRuns;

  @override
  Future<List<Fa08RouteCableFact>> loadForCableRun({
    required String projectId,
    required String designRevisionId,
    required String cableRunId,
  }) async {
    final run = await cableRuns.findRun(
      projectId,
      designRevisionId,
      cableRunId,
    );
    if (run == null || run.state != CanonicalCableRunState.active)
      return const [];
    final cable =
        await (database.select(database.elvCables)..where(
          (row) =>
              row.projectId.equals(projectId) &
              row.id.equals(run.cableId) &
              row.lifecycleState.equals('ACTIVE') &
              row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (cable == null) return const [];

    final ref =
        CableDefinitionRef(
          catalogId: cable.definitionCatalogId,
          catalogVersion: cable.definitionCatalogVersion,
          definitionCode: cable.definitionCode,
          definitionContentHash: cable.definitionContentHash,
        ).normalized();
    final catalogRow =
        await (database.select(database.engineeringReferenceCatalogs)..where(
          (row) =>
              row.projectId.equals(projectId) &
              row.id.equals(ref.catalogId) &
              row.catalogVersion.equals(ref.catalogVersion) &
              row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (catalogRow == null) {
      throw StateError('FA08_CABLE_CATALOG_EDITION_MISSING:${ref.catalogId}');
    }
    final decoded = jsonDecode(catalogRow.payloadJson);
    if (decoded is! Map) throw StateError('FA08_CABLE_CATALOG_PAYLOAD_INVALID');
    final catalog = EngineeringReferenceCatalog.fromMap(
      Map<String, dynamic>.from(decoded),
    );
    final definition = catalog.cableDefinition(ref.definitionCode);
    if (cableDefinitionContentHashV1(definition) != ref.definitionContentHash) {
      throw StateError(
        'FA08_CABLE_DEFINITION_HASH_MISMATCH:${ref.definitionCode}',
      );
    }

    final editionId = <String>[
      ref.catalogId,
      ref.catalogVersion,
      ref.definitionCode,
      ref.definitionContentHash,
    ].join(':');
    final traversals = await cableRuns.loadTraversals(cableRunId);
    final ordered = [...traversals]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return <Fa08RouteCableFact>[
      for (final traversal in ordered)
        Fa08RouteCableFact(
          sectionId: traversal.routeSegmentId,
          cableId: cable.id,
          cableEditionId: editionId,
          cableClass: definition.firePerformanceCode,
          numericFacts: const [],
        ),
    ];
  }
}
