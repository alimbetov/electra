from pathlib import Path

path = Path('apps/mobile/lib/data/repositories/drift_engineering_reference_adoption_repository.dart')
text = path.read_text()

old = """    final topologyBeforeCommit = await DriftEngineeringTopologyRepository(
      database,
      originDeviceId: originDeviceId,
    ).load(command.projectId);

    return database.transaction(() async {"""
new = """    return database.transaction(() async {"""
assert old in text
text = text.replace(old, new, 1)

needle = """      if (currentGraphFingerprint != command.reviewedGraphFingerprint) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.staleReview,
          'The reviewed ELV1 graph payload changed after P5 preview.',
        );
      }

      final dependentPortIds = <String>{};"""
replacement = """      if (currentGraphFingerprint != command.reviewedGraphFingerprint) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.staleReview,
          'The reviewed ELV1 graph payload changed after P5 preview.',
        );
      }

      final topologyAtCommit = await DriftEngineeringTopologyRepository(
        database,
        originDeviceId: originDeviceId,
      ).load(command.projectId);

      final dependentPortIds = <String>{};"""
assert needle in text
text = text.replace(needle, replacement, 1)
text = text.replace("        topologyBeforeCommit,", "        topologyAtCommit,", 1)
path.write_text(text)
