import 'dart:convert';
import 'package:engineering_core/engineering_core.dart';
import 'protection_repository.dart';

class ManufacturerCandidate {
  const ManufacturerCandidate({
    required this.catalog,
    required this.product,
    required this.match,
  });
  final ManufacturerCatalog catalog;
  final ManufacturerProductVariant product;
  final ManufacturerMatch match;
}

class ManufacturerSelection {
  const ManufacturerSelection({
    required this.circuitId,
    required this.productId,
    required this.snapshot,
    required this.requirementFingerprint,
    required this.policyJson,
  });
  final String circuitId, productId, requirementFingerprint, policyJson;
  final Map<String, dynamic> snapshot;
}

class ProjectManufacturerSnapshot {
  const ProjectManufacturerSnapshot({
    required this.protection,
    required this.catalogs,
    required this.policy,
    required this.selections,
  });
  final ProjectProtectionSnapshot protection;
  final List<ManufacturerCatalog> catalogs;
  final ProjectManufacturerPolicy policy;
  final Map<String, ManufacturerSelection> selections;
  List<ManufacturerCandidate> candidates(
    CircuitProtectionView circuit, {
    bool includeRejected = false,
  }) {
    if (circuit.stale ||
        circuit.checkpoint == null ||
        protection.recalculation.session.state(
              'protection:${circuit.circuitId}',
            ) !=
            EngineeringDerivedState.current)
      return [];
    final requirement = ManufacturerCatalogCodec.protectionRequirement(
      circuit.checkpoint!.proposal.values,
    );
    if (requirement == null) return [];
    final list = <ManufacturerCandidate>[
      for (final catalog in catalogs)
        for (final p in catalog.products)
          ManufacturerCandidate(
            catalog: catalog,
            product: p,
            match: ManufacturerProductMatcher.match(
              requirement,
              p,
              policy: policy,
              catalogRegion: catalog.region,
            ),
          ),
    ];
    list.sort((a, b) {
      final n = (a.match.compatible ? 0 : 1).compareTo(
        b.match.compatible ? 0 : 1,
      );
      if (n != 0) return n;
      final preferred = ManufacturerProductMatcher.compare(
        a.product,
        b.product,
        policy,
      );
      return preferred != 0
          ? preferred
          : (a.catalog.id ?? '').compareTo(b.catalog.id ?? '');
    });
    return includeRejected
        ? list
        : list.where((c) => c.match.compatible).toList();
  }

  String selectionStatus(CircuitProtectionView circuit) {
    final selected = selections[circuit.circuitId];
    if (selected == null) return 'Not selected';
    if (circuit.stale ||
        selected.requirementFingerprint != circuit.fingerprint ||
        canonicalEngineeringJson(jsonDecode(selected.policyJson)) !=
            canonicalEngineeringJson(ManufacturerCatalogCodec.policy(policy)))
      return 'Review required';
    final node = 'product:${circuit.circuitId}',
        entry = protection.recalculation.session.cache[node];
    if (entry == null ||
        protection.recalculation.session.state(node) !=
            EngineeringDerivedState.current)
      return 'Review required';
    return 'Selected';
  }
}

abstract interface class ManufacturerRepository {
  Future<ProjectManufacturerSnapshot> load(String projectId);
  Stream<ProjectManufacturerSnapshot> watch(String projectId);
  Future<void> importCatalog(ManufacturerCatalog catalog);
  Future<void> archiveCatalog(String catalogId);
  Future<void> savePolicy(String projectId, ProjectManufacturerPolicy policy);
  Future<void> selectProduct({
    required String projectId,
    required String circuitId,
    required String productId,
    required String expectedRequirementFingerprint,
  });
  Future<void> clearSelection(String projectId, String circuitId);
}
