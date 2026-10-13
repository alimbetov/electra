import 'package:engineering_core/engineering_core.dart';

import 'engineering_reference_repository.dart';
import 'engineering_topology_repository.dart';

class BoundProfileRevisionImpact {
  const BoundProfileRevisionImpact({
    required this.componentId,
    required this.profileCode,
    required this.previousCatalogId,
    required this.previousVersion,
    required this.candidateCatalogId,
    required this.candidateVersion,
    required this.profileImpact,
    required this.portIds,
    required this.connectionIds,
    required this.topologyGroupIds,
  });

  final String componentId;
  final String profileCode;
  final String previousCatalogId;
  final String previousVersion;
  final String candidateCatalogId;
  final String candidateVersion;
  final ProfileRevisionImpact profileImpact;
  final List<String> portIds;
  final List<String> connectionIds;
  final List<String> topologyGroupIds;

  bool get affectsProjectGraph =>
      connectionIds.isNotEmpty || topologyGroupIds.isNotEmpty;
}

class CatalogRevisionPreview {
  CatalogRevisionPreview({
    required this.catalogCode,
    required this.candidateCatalogId,
    required this.candidateVersion,
    required Iterable<BoundProfileRevisionImpact> bindingImpacts,
    required Iterable<String> removedProfileCodes,
  }) : bindingImpacts = List.unmodifiable(bindingImpacts),
       removedProfileCodes = List.unmodifiable(removedProfileCodes);

  final String catalogCode;
  final String candidateCatalogId;
  final String candidateVersion;
  final List<BoundProfileRevisionImpact> bindingImpacts;
  final List<String> removedProfileCodes;

  int get affectedBindingCount => bindingImpacts.length;

  Set<String> get affectedConnectionIds => {
    for (final impact in bindingImpacts) ...impact.connectionIds,
  };

  Set<String> get affectedTopologyGroupIds => {
    for (final impact in bindingImpacts) ...impact.topologyGroupIds,
  };

  bool get affectsPlacement =>
      bindingImpacts.any((impact) => impact.profileImpact.affectsPlacement);

  bool get affectsConnections =>
      bindingImpacts.any((impact) => impact.profileImpact.affectsConnections);
}

CatalogRevisionPreview previewCatalogRevision({
  required ProjectEngineeringReferences references,
  required ProjectEngineeringTopologySnapshot topology,
  required EngineeringReferenceCatalog candidate,
}) {
  final sameCode = references.catalogs
      .where(
        (catalog) =>
            catalog.code == candidate.code && catalog.id != candidate.id,
      )
      .toList();
  final byId = {for (final catalog in sameCode) catalog.id: catalog};
  final candidateProfiles = {
    for (final profile in candidate.profiles) profile.code: profile,
  };
  final impacts = <BoundProfileRevisionImpact>[];
  final removed = <String>{};

  for (final binding in references.bindings) {
    final previousCatalog = byId[binding.catalogId];
    if (previousCatalog == null) continue;

    final candidateProfile = candidateProfiles[binding.profileCode];
    if (candidateProfile == null) {
      removed.add(binding.profileCode);
      continue;
    }

    final previousProfile = previousCatalog.profile(binding.profileCode);
    final profileImpact = compareEngineeringProfileRevisions(
      previous: previousProfile,
      candidate: candidateProfile,
    );
    if (!profileImpact.changed) continue;

    final ports = binding.portIds.toSet();
    final connections =
        topology.connections
            .where(
              (connection) =>
                  ports.contains(connection.fromPortId) ||
                  ports.contains(connection.toPortId),
            )
            .map((connection) => connection.id)
            .toSet()
            .toList()
          ..sort();
    final groups =
        topology.groups
            .where(
              (group) =>
                  ports.contains(group.startPortId) ||
                  (group.endPortId != null && ports.contains(group.endPortId)),
            )
            .map((group) => group.id)
            .toSet()
            .toList()
          ..sort();

    impacts.add(
      BoundProfileRevisionImpact(
        componentId: binding.componentId,
        profileCode: binding.profileCode,
        previousCatalogId: previousCatalog.id,
        previousVersion: binding.catalogVersion,
        candidateCatalogId: candidate.id,
        candidateVersion: candidate.version,
        profileImpact: profileImpact,
        portIds: List.unmodifiable(binding.portIds),
        connectionIds: List.unmodifiable(connections),
        topologyGroupIds: List.unmodifiable(groups),
      ),
    );
  }

  impacts.sort((a, b) {
    final byComponent = a.componentId.compareTo(b.componentId);
    return byComponent != 0
        ? byComponent
        : a.profileCode.compareTo(b.profileCode);
  });
  final removedSorted = removed.toList()..sort();

  return CatalogRevisionPreview(
    catalogCode: candidate.code,
    candidateCatalogId: candidate.id,
    candidateVersion: candidate.version,
    bindingImpacts: impacts,
    removedProfileCodes: removedSorted,
  );
}
