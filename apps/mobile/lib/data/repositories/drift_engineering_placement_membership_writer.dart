import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/engineering_placement_command.dart';
import '../database/app_database.dart';

final class DriftEngineeringPlacementMembershipWriter {
  DriftEngineeringPlacementMembershipWriter(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? clock,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _clock;

  Future<ComponentSystemMembership> insertCanonicalMembership(
    PlaceEngineeringProfileCommand command, {
    required String componentId,
    DateTime? committedAt,
  }) async {
    await resolve(command);

    await _validateComponentProjectOwnership(command, componentId);

    final existing =
        await (database.select(database.componentEngineeringMemberships)..where(
          (row) =>
              row.systemId.equals(command.systemId) &
              row.componentId.equals(componentId),
        )).getSingleOrNull();
    if (existing != null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.membershipConflict,
        message:
            'Canonical placement cannot reuse, restore or overwrite an existing membership identity.',
        details: {
          'systemId': command.systemId,
          'componentId': componentId,
          'existingRole': existing.role,
          'existingDeleted': existing.deletedAt != null,
        },
      );
    }

    final now = committedAt ?? _clock().toUtc();
    await database
        .into(database.componentEngineeringMemberships)
        .insert(
          ComponentEngineeringMembershipsCompanion.insert(
            systemId: command.systemId,
            componentId: componentId,
            role: command.normalizedMembershipRole,
            revision: const Value(1),
            createdAt: now,
            updatedAt: now,
            deletedAt: const Value(null),
            originDeviceId: originDeviceId,
          ),
        );

    return ComponentSystemMembership(
      systemId: command.systemId,
      componentId: componentId,
      role: command.normalizedMembershipRole,
    );
  }

  Future<ResolvedEngineeringPlacement> resolve(
    PlaceEngineeringProfileCommand command,
  ) async {
    if (command.normalizedMembershipRole != canonicalElvMembershipRole) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.invalidCommand,
        message:
            'Canonical engineering placement membership role must be DEVICE.',
        details: {
          'expectedRole': canonicalElvMembershipRole,
          'actualRole': command.membershipRole,
        },
      );
    }

    final systemRow =
        await (database.select(database.projectEngineeringSystems)..where(
          (row) => row.id.equals(command.systemId) & row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (systemRow == null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.systemNotFound,
        message: 'Engineering system does not exist or is archived.',
        details: {'systemId': command.systemId},
      );
    }
    if (systemRow.projectId != command.projectId) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.systemProjectMismatch,
        message: 'Engineering system belongs to another project.',
        details: {
          'systemId': command.systemId,
          'expectedProjectId': command.projectId,
          'actualProjectId': systemRow.projectId,
        },
      );
    }

    final system = _decodeSystem(systemRow);
    final familyRow =
        await (database.select(database.engineeringFamilyDefinitions)..where(
          (row) =>
              row.id.equals(system.familyId) &
              row.familyVersion.equals(system.familyVersion) &
              row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (familyRow == null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.systemNotFound,
        message: 'Exact engineering-system family edition is unavailable.',
        details: {
          'systemId': system.id,
          'familyId': system.familyId,
          'familyVersion': system.familyVersion,
        },
      );
    }
    final family = _decodeFamily(familyRow);
    final (catalog, profile) = await resolveProfile(command);
    final profileDiscipline = profile.discipline;
    final expectedFamilyCode = switch (profileDiscipline) {
      ReferenceDiscipline.cctv => 'CCTV',
      ReferenceDiscipline.lan => 'LAN',
      ReferenceDiscipline.acs => 'ACS',
      ReferenceDiscipline.fire => 'FIRE',
    };
    if (family.code.trim().toUpperCase() != expectedFamilyCode) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.systemDisciplineMismatch,
        message:
            'Engineering-system family discipline does not match the exact profile discipline.',
        details: {
          'systemId': system.id,
          'familyId': family.id,
          'familyVersion': family.version,
          'familyCode': family.code,
          'expectedFamilyCode': expectedFamilyCode,
          'profileDiscipline': profileDiscipline.name,
          'catalogId': command.catalogId,
          'catalogVersion': command.catalogVersion,
          'profileCode': command.profileCode,
        },
      );
    }

    return ResolvedEngineeringPlacement(
      system: system,
      family: family,
      catalog: catalog,
      profile: profile,
    );
  }

  EngineeringSystem _decodeSystem(ProjectEngineeringSystemRow row) {
    final system = EngineeringSystem.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    final coherent =
        system.id == row.id &&
        system.projectId == row.projectId &&
        system.familyId == row.familyId;
    if (!coherent || system.validate().isNotEmpty) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.systemNotFound,
        message: 'Persisted engineering-system identity is inconsistent.',
        details: {'systemId': row.id},
      );
    }
    return system;
  }

  EngineeringSystemFamily _decodeFamily(EngineeringFamilyDefinitionRow row) {
    final family = EngineeringSystemFamily.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    final coherent = family.id == row.id && family.version == row.familyVersion;
    if (!coherent || family.validate().isNotEmpty) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.systemNotFound,
        message: 'Persisted engineering-system family edition is inconsistent.',
        details: {'familyId': row.id, 'familyVersion': row.familyVersion},
      );
    }
    return family;
  }

  Future<(EngineeringReferenceCatalog, ComponentEngineeringProfile)>
  resolveProfile(PlaceEngineeringProfileCommand command) async {
    final row =
        await (database.select(database.engineeringReferenceCatalogs)..where(
          (candidate) =>
              candidate.id.equals(command.catalogId) &
              candidate.projectId.equals(command.projectId),
        )).getSingleOrNull();
    if (row == null || row.catalogVersion != command.catalogVersion) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.catalogEditionNotFound,
        message: 'Exact engineering reference catalog edition is unavailable.',
        details: {
          'catalogId': command.catalogId,
          'catalogVersion': command.catalogVersion,
          if (row != null) 'actualCatalogVersion': row.catalogVersion,
        },
      );
    }

    final catalog = EngineeringReferenceCatalog.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    if (catalog.id != row.id ||
        catalog.version != row.catalogVersion ||
        catalog.id != command.catalogId ||
        catalog.version != command.catalogVersion) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.catalogEditionNotFound,
        message: 'Persisted catalog edition identity is inconsistent.',
        details: {
          'catalogId': command.catalogId,
          'catalogVersion': command.catalogVersion,
        },
      );
    }

    ComponentEngineeringProfile? profile;
    for (final candidate in catalog.profiles) {
      if (candidate.code == command.profileCode) {
        profile = candidate;
        break;
      }
    }
    if (profile == null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.profileNotFound,
        message:
            'Exact engineering profile is unavailable in the pinned edition.',
        details: {
          'catalogId': command.catalogId,
          'catalogVersion': command.catalogVersion,
          'profileCode': command.profileCode,
        },
      );
    }
    return (catalog, profile);
  }

  Future<void> _validateComponentProjectOwnership(
    PlaceEngineeringProfileCommand command,
    String componentId,
  ) async {
    final component =
        await (database.select(database.componentInstances)..where(
          (row) => row.id.equals(componentId) & row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (component == null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.membershipConflict,
        message: 'Membership requires the active transaction-scoped component.',
        details: {'componentId': componentId},
      );
    }

    final room =
        await (database.select(database.rooms)..where(
          (row) => row.id.equals(component.roomId) & row.deletedAt.isNull(),
        )).getSingleOrNull();
    final floor =
        room == null
            ? null
            : await (database.select(database.floors)..where(
              (row) => row.id.equals(room.floorId) & row.deletedAt.isNull(),
            )).getSingleOrNull();
    if (room == null ||
        floor == null ||
        floor.projectId != command.projectId ||
        component.roomId != command.roomId) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.membershipConflict,
        message:
            'Component and engineering system must belong to the same project.',
        details: {
          'componentId': componentId,
          'expectedProjectId': command.projectId,
          'expectedRoomId': command.roomId,
          'actualRoomId': component.roomId,
          if (floor != null) 'actualProjectId': floor.projectId,
        },
      );
    }
  }
}

final class ResolvedEngineeringPlacement {
  const ResolvedEngineeringPlacement({
    required this.system,
    required this.family,
    required this.catalog,
    required this.profile,
  });
  final EngineeringSystem system;
  final EngineeringSystemFamily family;
  final EngineeringReferenceCatalog catalog;
  final ComponentEngineeringProfile profile;
}
