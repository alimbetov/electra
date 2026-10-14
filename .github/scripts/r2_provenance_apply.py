from pathlib import Path

# Round-2 remediation patcher replayed on the clean canonical-identity head.
path = Path('apps/mobile/lib/data/repositories/drift_engineering_reference_adoption_repository.dart')
text = path.read_text()

needle = """      if (currentCatalogRow == null || candidateRow == null) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateUnavailable,
          'The exact current and candidate catalog editions must both exist.',
        );
      }
      if (currentCatalogRow.code != candidateRow.code) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateUnavailable,
          'Catalog adoption cannot switch to an unrelated catalog code.',
        );
      }
      final candidateCatalog = EngineeringReferenceCatalog.fromMap(
        jsonDecode(candidateRow.payloadJson) as Map<String, dynamic>,
      );
      if (candidateCatalog.id != command.candidateCatalogId ||
          candidateCatalog.version != command.candidateCatalogVersion) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateUnavailable,
          'Candidate catalog payload provenance does not match its durable edition.',
        );
      }"""
replacement = """      if (currentCatalogRow == null) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
          'The exact current catalog edition is unavailable.',
        );
      }
      if (candidateRow == null) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateUnavailable,
          'The exact candidate catalog edition is unavailable.',
        );
      }
      final currentCatalog = EngineeringReferenceCatalog.fromMap(
        jsonDecode(currentCatalogRow.payloadJson) as Map<String, dynamic>,
      );
      if (currentCatalogRow.catalogVersion != binding.catalogVersion ||
          currentCatalog.id != binding.catalogId ||
          currentCatalog.version != binding.catalogVersion ||
          currentCatalog.code != currentCatalogRow.code) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
          'Current catalog row, payload and frozen binding provenance disagree.',
        );
      }
      ComponentEngineeringProfile currentCatalogProfile;
      try {
        currentCatalogProfile = currentCatalog.profile(binding.profileCode);
      } catch (_) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
          'The frozen profile is unavailable in its exact current catalog edition.',
        );
      }
      if (canonicalEngineeringJson(currentCatalogProfile.toMap()) !=
          canonicalEngineeringJson(binding.profile.toMap())) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
          'Frozen binding profile disagrees with the exact immutable catalog payload.',
        );
      }
      if (currentCatalogRow.code != candidateRow.code) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateUnavailable,
          'Catalog adoption cannot switch to an unrelated catalog code.',
        );
      }
      final candidateCatalog = EngineeringReferenceCatalog.fromMap(
        jsonDecode(candidateRow.payloadJson) as Map<String, dynamic>,
      );
      if (candidateCatalog.id != command.candidateCatalogId ||
          candidateCatalog.version != command.candidateCatalogVersion ||
          candidateCatalog.code != candidateRow.code) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateUnavailable,
          'Candidate catalog row and payload provenance do not match exactly.',
        );
      }"""
assert needle in text
text = text.replace(needle, replacement, 1)

needle = """      final topologyAtCommit = await DriftEngineeringTopologyRepository(
        database,
        originDeviceId: originDeviceId,
      ).load(command.projectId);

      final dependentPortIds = <String>{};"""
replacement = """      final topologyAtCommit = await DriftEngineeringTopologyRepository(
        database,
        originDeviceId: originDeviceId,
      ).load(command.projectId);

      final sameExactEdition =
          command.candidateCatalogId == binding.catalogId &&
          command.candidateCatalogVersion == binding.catalogVersion;
      if (sameExactEdition) {
        _assertExactSameEditionAggregate(
          command: command,
          bindingRow: bindingRow,
          binding: binding,
          currentPorts: currentPorts,
          candidateCatalog: candidateCatalog,
          candidateProfile: candidateProfile,
        );
        return EngineeringReferenceAdoptionResult(
          operationId: command.operationId,
          projectId: command.projectId,
          componentId: command.componentId,
          catalogId: binding.catalogId,
          catalogVersion: binding.catalogVersion,
          profileCode: binding.profileCode,
          portIds: binding.portIds,
          committedAt: bindingRow.updatedAt.toUtc(),
        );
      }

      final dependentPortIds = <String>{};"""
assert needle in text
text = text.replace(needle, replacement, 1)

insert_before = """  void _validateCandidateGraph(
"""
helper = """  void _assertExactSameEditionAggregate({
    required EngineeringReferenceAdoptionCommand command,
    required ComponentReferenceBindingRow bindingRow,
    required ComponentReferenceBinding binding,
    required List<EngineeringPort> currentPorts,
    required EngineeringReferenceCatalog candidateCatalog,
    required ComponentEngineeringProfile candidateProfile,
  }) {
    final currentPortIds = currentPorts.map((port) => port.id).toSet();
    final bindingPortIds = binding.portIds.toSet();
    if (bindingRow.catalogId != candidateCatalog.id ||
        bindingRow.profileCode != binding.profileCode ||
        canonicalEngineeringJson(binding.profile.toMap()) !=
            canonicalEngineeringJson(candidateProfile.toMap()) ||
        bindingPortIds.length != binding.portIds.length ||
        currentPorts.length != binding.portIds.length ||
        currentPortIds.length != bindingPortIds.length ||
        !currentPortIds.containsAll(bindingPortIds)) {
      throw const EngineeringReferenceAdoptionFailure(
        EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
        'Same-edition no-op requires an exact current frozen aggregate.',
      );
    }

    final currentByCode = {
      for (final port in currentPorts)
        normalizeEngineeringReferenceCode(port.code): port,
    };
    var generated = 0;
    final expectedPorts = candidateProfile.instantiate(
      componentId: command.componentId,
      catalogId: candidateCatalog.id,
      version: candidateCatalog.version,
      vocabulary: candidateCatalog.vocabulary,
      nextId: () => 'unexpected-same-edition-${generated++}',
      idForTemplate: (code) {
        final port = currentByCode[normalizeEngineeringReferenceCode(code)];
        if (port == null) {
          throw const EngineeringReferenceAdoptionFailure(
            EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
            'Same-edition aggregate is missing a canonical profile port.',
          );
        }
        return port.id;
      },
    );
    if (expectedPorts.length != currentPorts.length) {
      throw const EngineeringReferenceAdoptionFailure(
        EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
        'Same-edition aggregate port cardinality disagrees with the profile.',
      );
    }
    final expectedById = {for (final port in expectedPorts) port.id: port};
    for (final current in currentPorts) {
      final expected = expectedById[current.id];
      if (expected == null ||
          canonicalEngineeringJson(current.toMap()) !=
              canonicalEngineeringJson(expected.toMap())) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
          'Same-edition port provenance or engineering payload has drifted.',
        );
      }
    }
  }

"""
assert insert_before in text
text = text.replace(insert_before, helper + insert_before, 1)

path.write_text(text)
