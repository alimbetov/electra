import 'package:engineering_core/engineering_core.dart';

import 'engineering_reference_repository.dart';
import 'engineering_topology_repository.dart';

enum BoundProfileRevisionDisposition { changed, removed }

class BoundProfileRevisionImpact {
  BoundProfileRevisionImpact({
    required this.componentId,
    required this.profileCode,
    required this.previousCatalogId,
    required this.previousVersion,
    required this.candidateCatalogId,
    required this.candidateVersion,
    required this.disposition,
    required this.profileImpact,
    required Iterable<String> portIds,
    required Iterable<String> connectionIds,
    required Iterable<String> topologyGroupIds,
    required this.graphFingerprint,
    this.placementResult,
    this.placementBlockerReason,
    Iterable<String> candidateProfileValidationErrors = const [],
  }) : portIds = List.unmodifiable(portIds),
       connectionIds = List.unmodifiable(connectionIds),
       topologyGroupIds = List.unmodifiable(topologyGroupIds),
       candidateProfileValidationErrors = List.unmodifiable(
         candidateProfileValidationErrors,
       );

  final String componentId;
  final String profileCode;
  final String previousCatalogId;
  final String previousVersion;
  final String candidateCatalogId;
  final String candidateVersion;
  final BoundProfileRevisionDisposition disposition;
  final ProfileRevisionImpact profileImpact;
  final List<String> portIds;
  final List<String> connectionIds;
  final List<String> topologyGroupIds;
  final String graphFingerprint;
  final PlacementCompatibilityResult? placementResult;
  final String? placementBlockerReason;
  final List<String> candidateProfileValidationErrors;

  bool get affectsProjectGraph =>
      connectionIds.isNotEmpty || topologyGroupIds.isNotEmpty;

  bool get adoptionBlocked {
    if (disposition == BoundProfileRevisionDisposition.removed ||
        candidateProfileValidationErrors.isNotEmpty) {
      return true;
    }
    if (!profileImpact.affectsPlacement) return false;
    if (placementBlockerReason != null || placementResult == null) return true;
    return placementResult!.status != PlacementCompatibilityStatus.compatible;
  }
}

class CatalogRevisionPreview {
  CatalogRevisionPreview({
    required this.catalogCode,
    required this.candidateCatalogId,
    required this.candidateVersion,
    required Iterable<BoundProfileRevisionImpact> bindingImpacts,
    required Iterable<String> removedProfileCodes,
    Iterable<String> candidateValidationErrors = const [],
  }) : bindingImpacts = List.unmodifiable(bindingImpacts),
       removedProfileCodes = List.unmodifiable(removedProfileCodes),
       candidateValidationErrors = List.unmodifiable(candidateValidationErrors);

  final String catalogCode;
  final String candidateCatalogId;
  final String candidateVersion;
  final List<BoundProfileRevisionImpact> bindingImpacts;
  final List<String> removedProfileCodes;
  final List<String> candidateValidationErrors;

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

  bool get adoptionBlocked =>
      candidateValidationErrors.isNotEmpty ||
      bindingImpacts.any((impact) => impact.adoptionBlocked);
}

CatalogRevisionPreview previewCatalogRevision({
  required ProjectEngineeringReferences references,
  required ProjectEngineeringTopologySnapshot topology,
  required EngineeringReferenceCatalog candidate,
}) {
  final sameCode =
      references.catalogs
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
    if (previousCatalog == null ||
        binding.catalogVersion != previousCatalog.version) {
      continue;
    }

    final candidateProfile = candidateProfiles[binding.profileCode];
    if (candidateProfile == null) {
      removed.add(binding.profileCode);
      final graph = _graphImpact(binding.portIds, topology);
      impacts.add(
        BoundProfileRevisionImpact(
          componentId: binding.componentId,
          profileCode: binding.profileCode,
          previousCatalogId: previousCatalog.id,
          previousVersion: binding.catalogVersion,
          candidateCatalogId: candidate.id,
          candidateVersion: candidate.version,
          disposition: BoundProfileRevisionDisposition.removed,
          profileImpact: removedEngineeringProfileImpact(binding.profileCode),
          portIds: binding.portIds,
          connectionIds: graph.connections,
          topologyGroupIds: graph.groups,
          graphFingerprint: graph.fingerprint,
          placementBlockerReason:
              'The bound profile is absent from the candidate catalog edition.',
        ),
      );
      continue;
    }

    final profileImpact = compareEngineeringProfileRevisions(
      previous: binding.profile,
      candidate: candidateProfile,
    );
    if (!profileImpact.changed) continue;

    final graph = _graphImpact(binding.portIds, topology);
    final profileErrors = candidateProfile.validateForPublication();
    PlacementCompatibilityResult? placementResult;
    String? placementBlockerReason;
    if (profileImpact.affectsPlacement) {
      final evidence = binding.placementCommand;
      if (profileErrors.isNotEmpty) {
        placementBlockerReason =
            'The candidate profile is not publication-valid and cannot be placement-revalidated.';
      } else if (evidence == null) {
        placementBlockerReason =
            'The historical binding has no reviewed placement evidence.';
      } else {
        placementResult = const PlacementCompatibilityEngine().evaluate(
          profile: candidateProfile,
          catalogId: candidate.id,
          catalogVersion: candidate.version,
          context: evidence.placementContext,
        );
      }
    }

    impacts.add(
      BoundProfileRevisionImpact(
        componentId: binding.componentId,
        profileCode: binding.profileCode,
        previousCatalogId: previousCatalog.id,
        previousVersion: binding.catalogVersion,
        candidateCatalogId: candidate.id,
        candidateVersion: candidate.version,
        disposition: BoundProfileRevisionDisposition.changed,
        profileImpact: profileImpact,
        portIds: binding.portIds,
        connectionIds: graph.connections,
        topologyGroupIds: graph.groups,
        graphFingerprint: graph.fingerprint,
        placementResult: placementResult,
        placementBlockerReason: placementBlockerReason,
        candidateProfileValidationErrors: profileErrors,
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
  final candidateErrors = candidate.validateForPublication();

  return CatalogRevisionPreview(
    catalogCode: candidate.code,
    candidateCatalogId: candidate.id,
    candidateVersion: candidate.version,
    bindingImpacts: impacts,
    removedProfileCodes: removedSorted,
    candidateValidationErrors: candidateErrors,
  );
}

({List<String> connections, List<String> groups, String fingerprint})
_graphImpact(
  Iterable<String> portIds,
  ProjectEngineeringTopologySnapshot topology,
) {
  final ports = portIds.toSet();
  final relevantConnections =
      topology.connections
          .where(
            (connection) =>
                ports.contains(connection.fromPortId) ||
                ports.contains(connection.toPortId),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final relevantGroups =
      topology.groups
          .where(
            (group) =>
                ports.contains(group.startPortId) ||
                (group.endPortId != null && ports.contains(group.endPortId)),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  final relevantInternal =
      topology.internalLinks
          .where(
            (mapping) =>
                ports.contains(mapping.fromPortId) ||
                ports.contains(mapping.toPortId),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));
  return (
    connections: relevantConnections.map((item) => item.id).toList(),
    groups: relevantGroups.map((item) => item.id).toList(),
    fingerprint: canonicalEngineeringJson({
      'connections': relevantConnections.map((item) => item.toMap()).toList(),
      'groups': relevantGroups.map((item) => item.toMap()).toList(),
      'internalLinks': relevantInternal.map((item) => item.toMap()).toList(),
    }),
  );
}
