import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';
import '../../application/engineering_placement_command.dart';
import '../../application/engineering_reference_repository.dart';
import '../../application/id_generator.dart';
import '../database/app_database.dart';
import 'drift_engineering_placement_membership_writer.dart';

enum EngineeringPlacementFailurePoint {
  afterOperationCheck,
  afterComponent,
  afterMembership,
  beforePort,
  afterPort,
  afterBinding,
  beforeOperationComplete,
  beforeCommit,
}

typedef EngineeringPlacementFault =
    FutureOr<void> Function(
      EngineeringPlacementFailurePoint point,
      String? portCode,
    );

/// All methods run inside the placement owner's transaction. No public save/bind
/// repositories are composed, and this helper never opens a transaction.
final class DriftEngineeringPlacementAggregate {
  DriftEngineeringPlacementAggregate(
    this.database, {
    required this.originDeviceId,
    required this.idGenerator,
    this.fault,
  });
  final AppDatabase database;
  final String originDeviceId;
  final IdGenerator idGenerator;
  final EngineeringPlacementFault? fault;
  Future<void> hit(
    EngineeringPlacementFailurePoint point, [
    String? code,
  ]) async {
    await fault?.call(point, code);
  }

  Future<PlacementCandidateContext> revalidate(
    PlaceEngineeringProfileCommand command,
    ResolvedEngineeringPlacement resolved,
  ) async {
    final profile = resolved.profile;
    if (profile.deprecated)
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.profileDeprecated,
        message: 'Deprecated profiles cannot be placed.',
      );
    final codes =
        profile.portTemplates.map((p) => p.code.trim().toUpperCase()).toList();
    if (codes.toSet().length != codes.length)
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.portConflict,
        message: 'Duplicate normalized port template code.',
      );
    final ref = resolved.system.topologyProfile;
    var context = command.placementContext;
    if (ref != null) {
      final row =
          await (database.select(database.engineeringTopologyProfiles)..where(
            (r) =>
                r.id.equals(ref.id) &
                r.projectId.equals(command.projectId) &
                r.profileVersion.equals(ref.version) &
                r.deletedAt.isNull(),
          )).getSingleOrNull();
      TopologyShape? shape;
      if (row != null) {
        final topology = TopologyProfile.fromMap(
          jsonDecode(row.payloadJson) as Map<String, dynamic>,
        );
        if (topology.id == ref.id &&
            topology.identity.version == ref.version &&
            topology.identity.projectId == command.projectId &&
            topology.validate().isEmpty) {
          shape = topology.shape;
        }
      }
      context = PlacementCandidateContext.fromMap({
        ...context.toMap(),
        'topologyShape': shape?.name,
      });
      if (shape == null)
        throw EngineeringPlacementFailure(
          code: EngineeringPlacementFailureCode.placementUnresolved,
          message: 'The pinned topology edition is unavailable.',
        );
    }
    final result = const PlacementCompatibilityEngine().evaluate(
      profile: profile,
      catalogId: resolved.catalog.id,
      catalogVersion: resolved.catalog.version,
      context: context,
    );
    if (!result.compatible)
      throw EngineeringPlacementFailure(
        code:
            result.status == PlacementCompatibilityStatus.forbidden
                ? EngineeringPlacementFailureCode.placementForbidden
                : EngineeringPlacementFailureCode.placementUnresolved,
        message: 'Current placement evidence is ${result.status.name}.',
        findings: result.findings,
      );
    final errors = resolved.catalog.validateForPublication();
    if (errors.isNotEmpty)
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.profileNotFound,
        message: 'The exact catalog edition is not publication-valid.',
        details: {'errors': errors},
      );
    return context;
  }

  Future<List<EngineeringPort>> insertPortsAndBinding(
    PlaceEngineeringProfileCommand command,
    String componentId,
    ResolvedEngineeringPlacement resolved,
    PlacementCandidateContext context,
    DateTime now,
  ) async {
    if ((await (database.select(database.componentReferenceBindings)
          ..where((r) => r.componentId.equals(componentId))).get())
        .isNotEmpty)
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.bindingConflict,
        message: 'Binding identity already exists.',
      );
    if ((await (database.select(database.engineeringPortInstances)
          ..where((r) => r.componentId.equals(componentId))).get())
        .isNotEmpty)
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.portConflict,
        message: 'Manual or retired port identities already exist.',
      );
    final codes =
        resolved.profile.portTemplates
            .map((p) => p.code.trim().toUpperCase())
            .toList()
          ..sort();
    final ids = {for (final code in codes) code: idGenerator.next()};
    if (ids.values.any((id) => id.trim().isEmpty) ||
        ids.values.toSet().length != ids.length) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.portConflict,
        message: 'Generated port identities must be unique and non-empty.',
      );
    }
    final ports =
        resolved.profile
            .instantiate(
              componentId: componentId,
              catalogId: resolved.catalog.id,
              version: resolved.catalog.version,
              vocabulary: resolved.catalog.vocabulary,
              nextId: idGenerator.next,
              idForTemplate: (code) => ids[code]!,
            )
            .map(
              (p) => EngineeringPort.fromMap({
                ...p.toMap(),
                'code': p.code.trim().toUpperCase(),
              }),
            )
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));
    for (final port in ports) {
      await hit(EngineeringPlacementFailurePoint.beforePort, port.code);
      final old =
          await (database.select(database.engineeringPortInstances)
            ..where((r) => r.id.equals(port.id))).getSingleOrNull();
      if (old != null || port.validate().isNotEmpty)
        throw EngineeringPlacementFailure(
          code: EngineeringPlacementFailureCode.portConflict,
          message: 'Invalid or occupied persisted port identity.',
          details: {'portId': port.id},
        );
      await database
          .into(database.engineeringPortInstances)
          .insert(
            EngineeringPortInstancesCompanion.insert(
              id: port.id,
              projectId: command.projectId,
              componentId: componentId,
              code: port.code,
              payloadJson: canonicalEngineeringJson(port.toMap()),
              createdAt: now,
              updatedAt: now,
              originDeviceId: originDeviceId,
            ),
          );
      await hit(EngineeringPlacementFailurePoint.afterPort, port.code);
    }
    final evidence = PlaceEngineeringProfileCommand.fromMap({
      ...command.toMap(),
      'placementContext': context.toMap(),
    });
    final binding = ComponentReferenceBinding(
      componentId: componentId,
      catalogId: resolved.catalog.id,
      catalogVersion: resolved.catalog.version,
      profileCode: resolved.profile.code,
      profile: resolved.profile,
      portIds: ports.map((p) => p.id).toList(),
      placementCommand: evidence,
    );
    await database
        .into(database.componentReferenceBindings)
        .insert(
          ComponentReferenceBindingsCompanion.insert(
            componentId: componentId,
            projectId: command.projectId,
            catalogId: resolved.catalog.id,
            profileCode: resolved.profile.code,
            payloadJson: canonicalEngineeringJson(binding.toMap()),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
    await hit(EngineeringPlacementFailurePoint.afterBinding);
    return ports;
  }

  Future<void> assertAggregate(
    PlaceEngineeringProfileCommand command,
    String componentId,
    ResolvedEngineeringPlacement resolved,
    List<EngineeringPort> ports,
  ) async {
    final component =
        await (database.select(database.componentInstances)..where(
          (r) => r.id.equals(componentId) & r.deletedAt.isNull(),
        )).getSingle();
    final members =
        await (database.select(database.componentEngineeringMemberships)..where(
          (r) => r.componentId.equals(componentId) & r.deletedAt.isNull(),
        )).get();
    final rows =
        await (database.select(database.engineeringPortInstances)..where(
          (r) => r.componentId.equals(componentId) & r.deletedAt.isNull(),
        )).get();
    final row =
        await (database.select(database.componentReferenceBindings)..where(
          (r) => r.componentId.equals(componentId) & r.deletedAt.isNull(),
        )).getSingle();
    final binding = ComponentReferenceBinding.fromMap(
      jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
    final expected = ports.map((p) => p.id).toSet();
    final actual = rows.map((p) => p.id).toSet();
    if (component.localXmm != command.localPosition.xMm ||
        component.localYmm != command.localPosition.yMm ||
        component.rotationRadians != command.rotationRadians ||
        component.displayNameOverride !=
            command.normalizedDisplayNameOverride ||
        row.projectId != command.projectId ||
        row.catalogId != command.catalogId ||
        row.profileCode != command.profileCode ||
        rows.any(
          (r) =>
              r.projectId != command.projectId ||
              r.componentId != componentId ||
              r.code != ports.singleWhere((p) => p.id == r.id).code,
        ) ||
        component.roomId != command.roomId ||
        component.hostSurfacePatchId != command.hostSurfacePatchId ||
        component.definitionId != canonicalElvComponentDefinitionId ||
        component.definitionVersion != canonicalElvComponentDefinitionVersion ||
        members.length != 1 ||
        members.single.systemId != command.systemId ||
        members.single.role != canonicalElvMembershipRole ||
        rows.length != resolved.profile.portTemplates.length ||
        !actual.containsAll(expected) ||
        actual.length != expected.length ||
        binding.portIds.length != expected.length ||
        !expected.containsAll(binding.portIds) ||
        binding.catalogId != command.catalogId ||
        binding.catalogVersion != command.catalogVersion ||
        binding.profileCode != command.profileCode ||
        canonicalEngineeringJson(binding.profile.toMap()) !=
            canonicalEngineeringJson(resolved.profile.toMap()) ||
        rows.any(
          (r) =>
              canonicalEngineeringJson(jsonDecode(r.payloadJson)) !=
              canonicalEngineeringJson(
                ports.singleWhere((p) => p.id == r.id).toMap(),
              ),
        )) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.transactionFailed,
        message: 'Canonical aggregate postconditions failed.',
      );
    }
  }

  static const aggregateTables = {
    'component_instances': 'id',
    'component_engineering_memberships': 'component_id',
    'engineering_port_instances': 'component_id',
    'component_reference_bindings': 'component_id',
  };
  Future<Map<String, Object?>> snapshot(
    String componentId, {
    required bool retired,
  }) async {
    final result = <String, Object?>{};
    for (final e in aggregateTables.entries) {
      final rows =
          await database
              .customSelect(
                'SELECT * FROM ${e.key} WHERE ${e.value} = ? AND deleted_at IS ${retired ? 'NOT ' : ''}NULL',
                variables: [Variable.withString(componentId)],
                readsFrom: database.allTables.toSet(),
              )
              .get();
      final values =
          rows
              .map(
                (r) => Map<String, Object?>.from(r.data)..removeWhere(
                  (k, _) => [
                    'revision',
                    'created_at',
                    'updated_at',
                    'deleted_at',
                    'origin_device_id',
                  ].contains(k),
                ),
              )
              .toList()
            ..sort(
              (a, b) => canonicalEngineeringJson(
                a,
              ).compareTo(canonicalEngineeringJson(b)),
            );
      result[e.key] = values;
    }
    return result;
  }

  Future<void> guardHistory(EngineeringPlacementResult result) async {
    final ids = result.portIds;
    final connections =
        await (database.select(database.engineeringPortConnections)..where(
          (r) =>
              r.deletedAt.isNull() &
              (r.fromPortId.isIn(ids) | r.toPortId.isIn(ids)),
        )).get();
    final mappings =
        await (database.select(database.engineeringInternalMappings)..where(
          (r) =>
              r.deletedAt.isNull() &
              (r.fromPortId.isIn(ids) | r.toPortId.isIn(ids)),
        )).get();
    final groups =
        await (database.select(database.engineeringTopologyGroups)..where(
          (r) =>
              r.deletedAt.isNull() &
              (r.startPortId.isIn(ids) | r.endPortId.isIn(ids)),
        )).get();
    final assemblies =
        await (database.select(database.engineeringComponentAssemblies)
          ..where((r) => r.deletedAt.isNull())).get();
    if (connections.isNotEmpty ||
        mappings.isNotEmpty ||
        groups.isNotEmpty ||
        assemblies.any(
          (r) => ComponentAssembly.fromMap(
            jsonDecode(r.payloadJson) as Map<String, dynamic>,
          ).members.any((m) => m.componentId == result.componentId),
        )) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.historyConflict,
        message:
            'Resolve later connections, mappings, groups or assemblies before undo/redo.',
      );
    }
    // Also guard later physical/electrical ownership through declared component FKs.
    for (final table in database.allTables) {
      if (aggregateTables.containsKey(table.actualTableName) ||
          table.actualTableName == 'engineering_placement_operations')
        continue;
      final fks =
          await database
              .customSelect(
                'PRAGMA foreign_key_list("${table.actualTableName}")',
              )
              .get();
      for (final fk in fks.where(
        (r) => r.read<String>('table') == 'component_instances',
      )) {
        final column = fk.read<String>('from');
        final hasDeleted = table.$columns.any((c) => c.$name == 'deleted_at');
        final refs =
            await database
                .customSelect(
                  'SELECT 1 FROM "${table.actualTableName}" WHERE "$column" = ?${hasDeleted ? ' AND deleted_at IS NULL' : ''} LIMIT 1',
                  variables: [Variable.withString(result.componentId)],
                )
                .get();
        if (refs.isNotEmpty)
          throw EngineeringPlacementFailure(
            code: EngineeringPlacementFailureCode.historyConflict,
            message: 'Later component ownership prevents history transition.',
            details: {'table': table.actualTableName},
          );
      }
    }
  }

  Future<void> transition(
    EngineeringPlacementResult result, {
    required bool retire,
    required DateTime now,
  }) async {
    for (final e in aggregateTables.entries.toList().reversed) {
      final portFilter =
          e.key == 'engineering_port_instances'
              ? ' AND id IN (${List.filled(result.portIds.length, '?').join(',')})'
              : '';
      final memberFilter =
          e.key == 'component_engineering_memberships'
              ? ' AND system_id = ?'
              : '';
      await database.customUpdate(
        'UPDATE ${e.key} SET deleted_at = ?, updated_at = ?, revision = revision + 1, origin_device_id = ? WHERE ${e.value} = ?$portFilter$memberFilter',
        variables: [
          Variable<DateTime>(retire ? now : null),
          Variable<DateTime>(now),
          Variable.withString(originDeviceId),
          Variable.withString(result.componentId),
          if (portFilter.isNotEmpty) ...result.portIds.map(Variable.withString),
          if (memberFilter.isNotEmpty) Variable.withString(result.systemId),
        ],
        updates: database.allTables.toSet(),
      );
    }
  }
}
