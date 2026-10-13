import 'package:engineering_core/engineering_core.dart';

import 'engineering_reference_repository.dart';

enum EngineeringPortMigrationAction {
  preserve,
  add,
  retire,
  explicitRemap,
}

class EngineeringPortMigrationStep {
  const EngineeringPortMigrationStep({
    required this.action,
    this.currentPortId,
    this.currentCode,
    this.candidateCode,
    required this.hasLiveDependencies,
    required this.requiresConnectionRevalidation,
  });

  final EngineeringPortMigrationAction action;
  final String? currentPortId;
  final String? currentCode;
  final String? candidateCode;
  final bool hasLiveDependencies;
  final bool requiresConnectionRevalidation;
}

class EngineeringReferenceAdoptionPlan {
  EngineeringReferenceAdoptionPlan({
    required this.componentId,
    required this.currentCatalogId,
    required this.currentCatalogVersion,
    required this.candidateCatalogId,
    required this.candidateCatalogVersion,
    required this.profileCode,
    required Iterable<EngineeringPortMigrationStep> steps,
    required Iterable<String> blockers,
  }) : steps = List.unmodifiable(steps),
       blockers = List.unmodifiable(blockers);

  final String componentId;
  final String currentCatalogId;
  final String currentCatalogVersion;
  final String candidateCatalogId;
  final String candidateCatalogVersion;
  final String profileCode;
  final List<EngineeringPortMigrationStep> steps;
  final List<String> blockers;

  bool get canApply => blockers.isEmpty;
  bool get requiresConnectionRevalidation =>
      steps.any((step) => step.requiresConnectionRevalidation);
}

EngineeringReferenceAdoptionPlan planEngineeringReferenceAdoption({
  required ComponentReferenceBinding binding,
  required Iterable<EngineeringPort> currentPorts,
  required EngineeringReferenceCatalog candidateCatalog,
  Map<String, String> explicitPortMappings = const {},
  Set<String> dependentPortIds = const {},
}) {
  final blockers = <String>[];
  final candidateErrors = candidateCatalog.validateForPublication();
  if (candidateErrors.isNotEmpty) {
    blockers.addAll(
      candidateErrors.map((error) => 'Candidate catalog invalid: $error'),
    );
  }

  ComponentEngineeringProfile? candidateProfile;
  try {
    candidateProfile = candidateCatalog.profile(binding.profileCode);
  } catch (_) {
    blockers.add(
      'Candidate catalog does not contain bound profile ${binding.profileCode}.',
    );
  }
  if (candidateProfile?.deprecated == true) {
    blockers.add('Candidate profile ${binding.profileCode} is deprecated.');
  }

  final normalizedMappings = <String, String>{};
  for (final entry in explicitPortMappings.entries) {
    final oldCode = _code(entry.key);
    final newCode = _code(entry.value);
    if (oldCode.isEmpty || newCode.isEmpty) {
      blockers.add('Explicit port mappings require non-empty codes.');
      continue;
    }
    if (normalizedMappings.containsKey(oldCode)) {
      blockers.add('Duplicate explicit mapping for old port $oldCode.');
      continue;
    }
    normalizedMappings[oldCode] = newCode;
  }
  if (normalizedMappings.values.toSet().length != normalizedMappings.length) {
    blockers.add('Explicit port mappings must be one-to-one.');
  }

  final boundIds = binding.portIds.toSet();
  final activePorts = currentPorts.where((port) => boundIds.contains(port.id)).toList();
  if (activePorts.length != boundIds.length) {
    blockers.add('Current active ports do not match the frozen binding port set.');
  }
  if (activePorts.map((port) => port.id).toSet().length != activePorts.length) {
    blockers.add('Current bound port identities are not unique.');
  }

  final oldByCode = <String, EngineeringPort>{};
  for (final port in activePorts) {
    final code = _code(port.code);
    if (oldByCode.containsKey(code)) {
      blockers.add('Current bound port code $code is duplicated.');
    } else {
      oldByCode[code] = port;
    }
  }

  final candidateTemplates = <String, EngineeringPort>{};
  if (candidateProfile != null) {
    for (final port in candidateProfile.portTemplates) {
      final code = _code(port.code);
      if (candidateTemplates.containsKey(code)) {
        blockers.add('Candidate port template code $code is duplicated.');
      } else {
        candidateTemplates[code] = port;
      }
    }
  }

  for (final entry in normalizedMappings.entries) {
    if (!oldByCode.containsKey(entry.key)) {
      blockers.add('Explicit mapping references unknown old port ${entry.key}.');
    }
    if (!candidateTemplates.containsKey(entry.value)) {
      blockers.add('Explicit mapping references unknown candidate port ${entry.value}.');
    }
    if (entry.key == entry.value) {
      blockers.add(
        'Same-code port ${entry.key} is preserved automatically; explicit mapping is not allowed.',
      );
    }
  }

  final mappedCandidateCodes = normalizedMappings.values.toSet();
  final steps = <EngineeringPortMigrationStep>[];

  for (final entry in oldByCode.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final oldCode = entry.key;
    final currentPort = entry.value;
    final hasDependencies = dependentPortIds.contains(currentPort.id);
    final explicitTarget = normalizedMappings[oldCode];

    if (explicitTarget != null) {
      final candidateTemplate = candidateTemplates[explicitTarget];
      steps.add(
        EngineeringPortMigrationStep(
          action: EngineeringPortMigrationAction.explicitRemap,
          currentPortId: currentPort.id,
          currentCode: oldCode,
          candidateCode: explicitTarget,
          hasLiveDependencies: hasDependencies,
          requiresConnectionRevalidation:
              hasDependencies &&
              candidateTemplate != null &&
              _connectionRelevantPortChange(currentPort, candidateTemplate),
        ),
      );
      continue;
    }

    final sameCode = candidateTemplates[oldCode];
    if (sameCode != null && !mappedCandidateCodes.contains(oldCode)) {
      steps.add(
        EngineeringPortMigrationStep(
          action: EngineeringPortMigrationAction.preserve,
          currentPortId: currentPort.id,
          currentCode: oldCode,
          candidateCode: oldCode,
          hasLiveDependencies: hasDependencies,
          requiresConnectionRevalidation:
              hasDependencies &&
              _connectionRelevantPortChange(currentPort, sameCode),
        ),
      );
      continue;
    }

    steps.add(
      EngineeringPortMigrationStep(
        action: EngineeringPortMigrationAction.retire,
        currentPortId: currentPort.id,
        currentCode: oldCode,
        hasLiveDependencies: hasDependencies,
        requiresConnectionRevalidation: false,
      ),
    );
    if (hasDependencies) {
      blockers.add(
        'Port $oldCode (${currentPort.id}) cannot be retired while live graph dependencies remain.',
      );
    }
  }

  final consumedCandidateCodes = <String>{
    for (final step in steps)
      if (step.candidateCode != null) step.candidateCode!,
  };
  for (final code in candidateTemplates.keys.toList()..sort()) {
    if (consumedCandidateCodes.contains(code)) continue;
    steps.add(
      EngineeringPortMigrationStep(
        action: EngineeringPortMigrationAction.add,
        candidateCode: code,
        hasLiveDependencies: false,
        requiresConnectionRevalidation: false,
      ),
    );
  }

  steps.sort((a, b) {
    final left = '${a.currentCode ?? ''}|${a.candidateCode ?? ''}|${a.action.name}';
    final right = '${b.currentCode ?? ''}|${b.candidateCode ?? ''}|${b.action.name}';
    return left.compareTo(right);
  });

  return EngineeringReferenceAdoptionPlan(
    componentId: binding.componentId,
    currentCatalogId: binding.catalogId,
    currentCatalogVersion: binding.catalogVersion,
    candidateCatalogId: candidateCatalog.id,
    candidateCatalogVersion: candidateCatalog.version,
    profileCode: binding.profileCode,
    steps: steps,
    blockers: blockers,
  );
}

String _code(String value) => value.trim().toUpperCase();

bool _connectionRelevantPortChange(
  EngineeringPort current,
  EngineeringPort candidateTemplate,
) =>
    current.kind != candidateTemplate.kind ||
    current.direction != candidateTemplate.direction ||
    current.capacity != candidateTemplate.capacity ||
    current.connector != candidateTemplate.connector ||
    current.protocol?.id != candidateTemplate.protocol?.id ||
    current.protocol?.version != candidateTemplate.protocol?.version ||
    current.interfaceProvenance?.id != candidateTemplate.interfaceProvenance?.id ||
    current.interfaceProvenance?.version != candidateTemplate.interfaceProvenance?.version ||
    current.voltage?.currentKind != candidateTemplate.voltage?.currentKind ||
    current.voltage?.minimumV != candidateTemplate.voltage?.minimumV ||
    current.voltage?.maximumV != candidateTemplate.voltage?.maximumV ||
    current.powerDirection != candidateTemplate.powerDirection ||
    current.powerLimitW != candidateTemplate.powerLimitW ||
    current.powerDemandW != candidateTemplate.powerDemandW;
