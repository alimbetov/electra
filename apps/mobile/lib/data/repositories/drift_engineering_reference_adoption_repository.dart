import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/engineering_reference_adoption.dart';
import '../../application/engineering_reference_adoption_repository.dart';
import '../../application/engineering_reference_repository.dart';
import '../../application/engineering_topology_repository.dart';
import '../../application/id_generator.dart';
import '../database/app_database.dart';
import 'drift_engineering_topology_repository.dart';

enum EngineeringReferenceAdoptionFailurePoint {
  afterReviewCheck,
  afterFirstPreservedPortUpdate,
  afterNewPortInsert,
  afterOldPortRetirement,
  afterBindingReplacement,
  beforeOperationComplete,
  beforeCommit,
}

final class DriftEngineeringReferenceAdoptionRepository
    implements EngineeringReferenceAdoptionRepository {
  DriftEngineeringReferenceAdoptionRepository(
    this.database, {
    required this.originDeviceId,
    required this.idGenerator,
    this.failurePoint,
  });

  final AppDatabase database;
  final String originDeviceId;
  final IdGenerator idGenerator;
  final EngineeringReferenceAdoptionFailurePoint? failurePoint;

  @override
  Future<EngineeringReferenceAdoptionResult> adopt(
    EngineeringReferenceAdoptionCommand command,
  ) async {
    final validation = command.validate();
    if (validation.isNotEmpty) {
      throw EngineeringReferenceAdoptionFailure(
        EngineeringReferenceAdoptionFailureCode.invalidCommand,
        validation.join(' '),
      );
    }

    return database.transaction(() async {
      final ledgerKey = command.ledgerOperationId;
      final existingOperation = await (database.select(
        database.engineeringPlacementOperations,
      )..where((row) => row.operationId.equals(ledgerKey))).getSingleOrNull();
      if (existingOperation != null) {
        if (existingOperation.commandFingerprint != command.fingerprint ||
            existingOperation.fingerprintVersion !=
                engineeringReferenceAdoptionFingerprintVersion ||
            existingOperation.status !=
                engineeringReferenceAdoptionCompletedStatus) {
          throw const EngineeringReferenceAdoptionFailure(
            EngineeringReferenceAdoptionFailureCode.idempotencyConflict,
            'The adoption operation id is already reserved by different semantics.',
          );
        }
        return engineeringReferenceAdoptionResultFromJson(
          existingOperation.resultJson,
        );
      }

      final componentProject = await database
          .customSelect(
            '''SELECT ci.id FROM component_instances ci
JOIN rooms r ON r.id = ci.room_id
JOIN floors f ON f.id = r.floor_id
WHERE ci.id = ? AND ci.deleted_at IS NULL
  AND r.deleted_at IS NULL AND f.deleted_at IS NULL
  AND f.project_id = ?''',
            variables: [
              Variable.withString(command.componentId),
              Variable.withString(command.projectId),
            ],
            readsFrom: database.allTables.toSet(),
          )
          .getSingleOrNull();
      if (componentProject == null) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
          'The component is not active in the requested project.',
        );
      }

      final bindingRow =
          await (database.select(database.componentReferenceBindings)..where(
                (row) =>
                    row.componentId.equals(command.componentId) &
                    row.projectId.equals(command.projectId) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (bindingRow == null) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.currentBindingUnavailable,
          'The component has no active frozen reference binding.',
        );
      }
      final binding = ComponentReferenceBinding.fromMap(
        jsonDecode(bindingRow.payloadJson) as Map<String, dynamic>,
      );
      if (binding.catalogId != command.expectedCatalogId ||
          binding.catalogVersion != command.expectedCatalogVersion ||
          binding.profileCode != command.profileCode ||
          canonicalEngineeringJson(binding.toMap()) !=
              command.reviewedBindingFingerprint) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.staleReview,
          'The frozen binding changed after P5 review.',
        );
      }

      final currentCatalogRow =
          await (database.select(database.engineeringReferenceCatalogs)..where(
                (row) =>
                    row.id.equals(binding.catalogId) &
                    row.projectId.equals(command.projectId) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      final candidateRow =
          await (database.select(database.engineeringReferenceCatalogs)..where(
                (row) =>
                    row.id.equals(command.candidateCatalogId) &
                    row.projectId.equals(command.projectId) &
                    row.catalogVersion.equals(command.candidateCatalogVersion) &
                    row.deletedAt.isNull(),
              ))
              .getSingleOrNull();
      if (currentCatalogRow == null) {
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
      }
      final catalogErrors = candidateCatalog.validateForPublication();
      if (catalogErrors.isNotEmpty) {
        throw EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateInvalid,
          catalogErrors.join(' '),
        );
      }

      ComponentEngineeringProfile candidateProfile;
      try {
        candidateProfile = candidateCatalog.profile(command.profileCode);
      } catch (_) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateInvalid,
          'The candidate edition no longer contains the reviewed profile.',
        );
      }
      if (candidateProfile.deprecated) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.candidateInvalid,
          'A deprecated candidate profile cannot be adopted.',
        );
      }

      final placementEvidence = binding.placementCommand;
      if (placementEvidence == null) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.placementBlocked,
          'Historical bindings without reviewed P4 placement evidence cannot be adopted automatically.',
        );
      }
      final placement = const PlacementCompatibilityEngine().evaluate(
        profile: candidateProfile,
        catalogId: candidateCatalog.id,
        catalogVersion: candidateCatalog.version,
        context: placementEvidence.placementContext,
      );
      if (placement.status != PlacementCompatibilityStatus.compatible) {
        throw EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.placementBlocked,
          'Candidate placement revalidation is ${placement.status.name}.',
        );
      }

      await _verifyDisciplineMembership(
        projectId: command.projectId,
        componentId: command.componentId,
        systemId: placementEvidence.systemId,
        discipline: candidateProfile.discipline,
      );

      final boundIds = binding.portIds.toSet();
      final portRows =
          await (database.select(database.engineeringPortInstances)..where(
                (row) =>
                    row.projectId.equals(command.projectId) &
                    row.id.isIn(boundIds) &
                    row.deletedAt.isNull(),
              ))
              .get();
      if (portRows.length != boundIds.length) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.staleReview,
          'The active port set no longer matches the frozen binding.',
        );
      }
      final currentPorts = [
        for (final row in portRows)
          EngineeringPort.fromMap(
            jsonDecode(row.payloadJson) as Map<String, dynamic>,
          ),
      ];

      final connections =
          await (database.select(database.engineeringPortConnections)..where(
                (row) =>
                    row.deletedAt.isNull() &
                    (row.fromPortId.isIn(boundIds) |
                        row.toPortId.isIn(boundIds)),
              ))
              .get();
      final groups =
          await (database.select(database.engineeringTopologyGroups)..where(
                (row) =>
                    row.deletedAt.isNull() &
                    (row.startPortId.isIn(boundIds) |
                        row.endPortId.isIn(boundIds)),
              ))
              .get();
      final internal =
          await (database.select(database.engineeringInternalMappings)..where(
                (row) =>
                    row.deletedAt.isNull() &
                    (row.fromPortId.isIn(boundIds) |
                        row.toPortId.isIn(boundIds)),
              ))
              .get();

      final currentConnectionIds = connections.map((row) => row.id).toList()
        ..sort();
      final currentGroupIds = groups.map((row) => row.id).toList()..sort();
      if (!_sameStrings(currentConnectionIds, command.reviewedConnectionIds) ||
          !_sameStrings(currentGroupIds, command.reviewedTopologyGroupIds)) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.staleReview,
          'Connection or topology-group membership changed after P5 review.',
        );
      }
      final currentGraphFingerprint = _graphFingerprint(
        connections: connections,
        groups: groups,
        internal: internal,
      );
      if (currentGraphFingerprint != command.reviewedGraphFingerprint) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.staleReview,
          'The reviewed ELV1 graph payload changed after P5 preview.',
        );
      }

      final topologyAtCommit = await DriftEngineeringTopologyRepository(
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

      final dependentPortIds = <String>{};
      for (final row in connections) {
        dependentPortIds.add(row.fromPortId);
        dependentPortIds.add(row.toPortId);
      }
      for (final row in groups) {
        dependentPortIds.add(row.startPortId);
        if (row.endPortId != null) dependentPortIds.add(row.endPortId!);
      }
      for (final row in internal) {
        dependentPortIds.add(row.fromPortId);
        dependentPortIds.add(row.toPortId);
      }
      dependentPortIds.removeWhere((id) => !boundIds.contains(id));

      final plan = planEngineeringReferenceAdoption(
        binding: binding,
        currentPorts: currentPorts,
        candidateCatalog: candidateCatalog,
        explicitPortMappings: command.explicitPortMappings,
        dependentPortIds: dependentPortIds,
      );
      if (!plan.canApply) {
        throw EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.dependencyConflict,
          plan.blockers.join(' '),
        );
      }
      _inject(EngineeringReferenceAdoptionFailurePoint.afterReviewCheck);

      final reusableIdByCandidateCode = <String, String>{};
      for (final step in plan.steps) {
        if ((step.action == EngineeringPortMigrationAction.preserve ||
                step.action == EngineeringPortMigrationAction.explicitRemap) &&
            step.currentPortId != null &&
            step.candidateCode != null) {
          reusableIdByCandidateCode[step.candidateCode!] = step.currentPortId!;
        }
      }
      final generatedIds = <String, String>{};
      final candidatePorts = candidateProfile.instantiate(
        componentId: command.componentId,
        catalogId: candidateCatalog.id,
        version: candidateCatalog.version,
        vocabulary: candidateCatalog.vocabulary,
        nextId: idGenerator.next,
        idForTemplate: (templateCode) {
          final code = templateCode.trim().toUpperCase();
          return reusableIdByCandidateCode[code] ??
              generatedIds.putIfAbsent(code, idGenerator.next);
        },
      );
      final candidateIds = candidatePorts.map((port) => port.id).toSet();
      if (candidateIds.length != candidatePorts.length) {
        throw const EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.dependencyConflict,
          'Candidate migration produced duplicate port identities.',
        );
      }

      _validateCandidateGraph(
        topologyAtCommit,
        currentBindingPortIds: boundIds,
        candidatePorts: candidatePorts,
        relevantConnectionIds: currentConnectionIds.toSet(),
        relevantGroupIds: currentGroupIds.toSet(),
        relevantInternalIds: internal.map((row) => row.id).toSet(),
      );

      final rowsById = {for (final row in portRows) row.id: row};
      final now = DateTime.now().toUtc();
      var preservedUpdated = false;
      var newInserted = false;
      for (final port in candidatePorts) {
        final old = rowsById[port.id];
        if (old != null) {
          await (database.update(
            database.engineeringPortInstances,
          )..where((row) => row.id.equals(port.id))).write(
            EngineeringPortInstancesCompanion(
              code: Value(port.code.trim().toUpperCase()),
              payloadJson: Value(canonicalEngineeringJson(port.toMap())),
              revision: Value(old.revision + 1),
              updatedAt: Value(now),
              deletedAt: const Value(null),
              originDeviceId: Value(originDeviceId),
            ),
          );
          if (!preservedUpdated) {
            preservedUpdated = true;
            _inject(
              EngineeringReferenceAdoptionFailurePoint
                  .afterFirstPreservedPortUpdate,
            );
          }
        } else {
          await database
              .into(database.engineeringPortInstances)
              .insert(
                EngineeringPortInstancesCompanion.insert(
                  id: port.id,
                  projectId: command.projectId,
                  componentId: command.componentId,
                  code: port.code.trim().toUpperCase(),
                  payloadJson: canonicalEngineeringJson(port.toMap()),
                  createdAt: now,
                  updatedAt: now,
                  originDeviceId: originDeviceId,
                ),
              );
          if (!newInserted) {
            newInserted = true;
            _inject(
              EngineeringReferenceAdoptionFailurePoint.afterNewPortInsert,
            );
          }
        }
      }

      var retired = false;
      for (final row in portRows) {
        if (candidateIds.contains(row.id)) continue;
        await (database.update(
          database.engineeringPortInstances,
        )..where((candidate) => candidate.id.equals(row.id))).write(
          EngineeringPortInstancesCompanion(
            revision: Value(row.revision + 1),
            updatedAt: Value(now),
            deletedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
        if (!retired) {
          retired = true;
          _inject(
            EngineeringReferenceAdoptionFailurePoint.afterOldPortRetirement,
          );
        }
      }

      final adoptedBinding = ComponentReferenceBinding(
        componentId: command.componentId,
        catalogId: candidateCatalog.id,
        profileCode: candidateProfile.code,
        catalogVersion: candidateCatalog.version,
        profile: candidateProfile,
        portIds: candidatePorts.map((port) => port.id).toList(),
        placementCommand: placementEvidence,
      );
      await (database.update(
        database.componentReferenceBindings,
      )..where((row) => row.componentId.equals(command.componentId))).write(
        ComponentReferenceBindingsCompanion(
          catalogId: Value(candidateCatalog.id),
          profileCode: Value(candidateProfile.code),
          payloadJson: Value(canonicalEngineeringJson(adoptedBinding.toMap())),
          revision: Value(bindingRow.revision + 1),
          updatedAt: Value(now),
          deletedAt: const Value(null),
          originDeviceId: Value(originDeviceId),
        ),
      );
      _inject(EngineeringReferenceAdoptionFailurePoint.afterBindingReplacement);

      await _assertPostconditions(
        command: command,
        binding: adoptedBinding,
        candidatePorts: candidatePorts,
      );

      final result = EngineeringReferenceAdoptionResult(
        operationId: command.operationId,
        projectId: command.projectId,
        componentId: command.componentId,
        catalogId: candidateCatalog.id,
        catalogVersion: candidateCatalog.version,
        profileCode: candidateProfile.code,
        portIds: candidatePorts.map((port) => port.id).toList(),
        committedAt: now,
      );
      _inject(EngineeringReferenceAdoptionFailurePoint.beforeOperationComplete);
      await database
          .into(database.engineeringPlacementOperations)
          .insert(
            EngineeringPlacementOperationsCompanion.insert(
              operationId: ledgerKey,
              projectId: command.projectId,
              fingerprintVersion:
                  engineeringReferenceAdoptionFingerprintVersion,
              commandFingerprint: command.fingerprint,
              status: engineeringReferenceAdoptionCompletedStatus,
              componentId: command.componentId,
              resultJson: engineeringReferenceAdoptionResultJson(result),
              createdAt: now,
              updatedAt: now,
              originDeviceId: originDeviceId,
            ),
          );
      _inject(EngineeringReferenceAdoptionFailurePoint.beforeCommit);
      return result;
    });
  }

  Future<void> _verifyDisciplineMembership({
    required String projectId,
    required String componentId,
    required String systemId,
    required ReferenceDiscipline discipline,
  }) async {
    final membership =
        await (database.select(database.componentEngineeringMemberships)..where(
              (row) =>
                  row.systemId.equals(systemId) &
                  row.componentId.equals(componentId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final system =
        await (database.select(database.projectEngineeringSystems)..where(
              (row) =>
                  row.id.equals(systemId) &
                  row.projectId.equals(projectId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    if (membership == null || system == null) {
      throw const EngineeringReferenceAdoptionFailure(
        EngineeringReferenceAdoptionFailureCode.staleReview,
        'The reviewed engineering-system membership is no longer active.',
      );
    }
    final family =
        await (database.select(database.engineeringFamilyDefinitions)..where(
              (row) => row.id.equals(system.familyId) & row.deletedAt.isNull(),
            ))
            .getSingleOrNull();
    final expectedCode = switch (discipline) {
      ReferenceDiscipline.cctv => 'CCTV',
      ReferenceDiscipline.lan => 'LAN',
      ReferenceDiscipline.acs => 'ACS',
      ReferenceDiscipline.fire => 'FIRE',
    };
    if (family == null || family.code != expectedCode) {
      throw const EngineeringReferenceAdoptionFailure(
        EngineeringReferenceAdoptionFailureCode.staleReview,
        'The candidate discipline no longer matches the component system.',
      );
    }
  }

  void _assertExactSameEditionAggregate({
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

  void _validateCandidateGraph(
    ProjectEngineeringTopologySnapshot snapshot, {
    required Set<String> currentBindingPortIds,
    required List<EngineeringPort> candidatePorts,
    required Set<String> relevantConnectionIds,
    required Set<String> relevantGroupIds,
    required Set<String> relevantInternalIds,
  }) {
    final graph = EngineeringTopologyGraph(
      projectId: snapshot.systems.project?.id ?? '',
      componentIds: snapshot.systems.components.map(
        (component) => component.id,
      ),
      systems: snapshot.systems.systems,
      families: snapshot.systems.families,
      memberships: snapshot.systems.memberships,
      ports: [
        ...snapshot.ports.where(
          (port) => !currentBindingPortIds.contains(port.id),
        ),
        ...candidatePorts,
      ],
      connectionProfiles: snapshot.connectionProfiles,
      connections: snapshot.connections,
      internalLinks: snapshot.internalLinks,
      topologyProfiles: snapshot.topologyProfiles,
      groups: snapshot.groups,
      assemblyProfiles: snapshot.assemblyProfiles,
      assemblies: snapshot.assemblies,
    );

    for (final port in candidatePorts) {
      final findings = graph.portFindings(port);
      if (findings.isNotEmpty) {
        throw EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.graphIncompatible,
          findings.map((finding) => finding.message).join(' '),
        );
      }
    }
    for (final connection in snapshot.connections.where(
      (item) => relevantConnectionIds.contains(item.id),
    )) {
      final findings = graph.connectionFindings(connection);
      if (findings.isNotEmpty) {
        throw EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.graphIncompatible,
          findings.map((finding) => finding.message).join(' '),
        );
      }
    }
    for (final mapping in snapshot.internalLinks.where(
      (item) => relevantInternalIds.contains(item.id),
    )) {
      final findings = graph.internalFindings(mapping);
      if (findings.isNotEmpty) {
        throw EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.graphIncompatible,
          findings.map((finding) => finding.message).join(' '),
        );
      }
    }
    for (final group in snapshot.groups.where(
      (item) => relevantGroupIds.contains(item.id),
    )) {
      final findings = graph
          .groupFindings(group)
          .where((finding) => !finding.draft);
      if (findings.isNotEmpty) {
        throw EngineeringReferenceAdoptionFailure(
          EngineeringReferenceAdoptionFailureCode.graphIncompatible,
          findings.map((finding) => finding.message).join(' '),
        );
      }
    }
  }

  Future<void> _assertPostconditions({
    required EngineeringReferenceAdoptionCommand command,
    required ComponentReferenceBinding binding,
    required List<EngineeringPort> candidatePorts,
  }) async {
    final bindingRow =
        await (database.select(database.componentReferenceBindings)..where(
              (row) =>
                  row.componentId.equals(command.componentId) &
                  row.deletedAt.isNull(),
            ))
            .getSingle();
    final durableBinding = ComponentReferenceBinding.fromMap(
      jsonDecode(bindingRow.payloadJson) as Map<String, dynamic>,
    );
    final activePorts =
        await (database.select(database.engineeringPortInstances)..where(
              (row) =>
                  row.componentId.equals(command.componentId) &
                  row.deletedAt.isNull(),
            ))
            .get();
    final expectedIds = candidatePorts.map((port) => port.id).toSet();
    final durableIds = activePorts.map((row) => row.id).toSet();
    if (durableBinding.catalogId != command.candidateCatalogId ||
        durableBinding.catalogVersion != command.candidateCatalogVersion ||
        durableBinding.profileCode != command.profileCode ||
        durableBinding.portIds.toSet().length !=
            durableBinding.portIds.length ||
        !_sameSets(durableBinding.portIds.toSet(), expectedIds) ||
        !_sameSets(durableIds, expectedIds) ||
        activePorts.map((row) => row.code).toSet().length !=
            activePorts.length) {
      throw const EngineeringReferenceAdoptionFailure(
        EngineeringReferenceAdoptionFailureCode.transactionFailed,
        'Adoption aggregate postconditions failed.',
      );
    }
  }

  String _graphFingerprint({
    required List<EngineeringPortConnectionRow> connections,
    required List<EngineeringTopologyGroupRow> groups,
    required List<EngineeringInternalMappingRow> internal,
  }) {
    final connectionPayloads = [
      for (final row in connections)
        jsonDecode(row.payloadJson) as Map<String, dynamic>,
    ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final groupPayloads = [
      for (final row in groups)
        jsonDecode(row.payloadJson) as Map<String, dynamic>,
    ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    final internalPayloads = [
      for (final row in internal)
        jsonDecode(row.payloadJson) as Map<String, dynamic>,
    ]..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    return canonicalEngineeringJson({
      'connections': connectionPayloads,
      'groups': groupPayloads,
      'internalLinks': internalPayloads,
    });
  }

  void _inject(EngineeringReferenceAdoptionFailurePoint point) {
    if (failurePoint == point) {
      throw StateError('Injected P6 failure at ${point.name}.');
    }
  }
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameSets(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);
