import 'dart:convert';

import 'drift_engineering_placement_aggregate.dart';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/engineering_placement_command.dart';
import '../../application/engineering_placement_repository.dart';
import '../../application/id_generator.dart';
import '../../domain/system_component_catalog.dart';
import '../database/app_database.dart';
import '../database/geometry_codec.dart';
import 'drift_engineering_placement_membership_writer.dart';

final class DriftEngineeringPlacementRepository
    implements EngineeringPlacementRepository {
  DriftEngineeringPlacementRepository(
    this.database, {
    required this.originDeviceId,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
    ComponentDefinition canonicalDefinition = canonicalElvComponentDefinition,
    EngineeringPlacementFault? fault,
  }) : _clock = clock ?? (() => DateTime.now().toUtc()),
       _aggregate = DriftEngineeringPlacementAggregate(
         database,
         originDeviceId: originDeviceId,
         idGenerator: idGenerator ?? UuidV7IdGenerator(),
         fault: fault,
       ),
       _componentWriter = DriftEngineeringPlacementComponentWriter(
         database,
         originDeviceId: originDeviceId,
         idGenerator: idGenerator ?? UuidV7IdGenerator(),
         clock: clock,
         canonicalDefinition: canonicalDefinition,
       ),
       _membershipWriter = DriftEngineeringPlacementMembershipWriter(
         database,
         originDeviceId: originDeviceId,
         clock: clock,
       );

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() _clock;
  final DriftEngineeringPlacementAggregate _aggregate;
  final DriftEngineeringPlacementComponentWriter _componentWriter;
  final DriftEngineeringPlacementMembershipWriter _membershipWriter;

  @override
  Future<EngineeringPlacementOperationRecord?> findOperation(
    String operationId,
  ) async {
    final row =
        await (database.select(database.engineeringPlacementOperations)..where(
          (candidate) => candidate.operationId.equals(operationId),
        )).getSingleOrNull();
    return row == null ? null : _operationFromRow(row);
  }

  @override
  Future<EngineeringPlacementResult> place(
    PlaceEngineeringProfileCommand command,
  ) async {
    final validation = command.validate();
    if (validation.isNotEmpty) {
      throw validation.first;
    }
    final fingerprint = engineeringPlacementFingerprintV1(command);

    try {
      return await database.transaction(() async {
        final existing =
            await (database.select(
              database.engineeringPlacementOperations,
            )..where(
              (candidate) => candidate.operationId.equals(command.operationId),
            )).getSingleOrNull();

        if (existing != null) {
          if (existing.fingerprintVersion !=
                  engineeringPlacementFingerprintVersion ||
              existing.commandFingerprint != fingerprint) {
            throw EngineeringPlacementFailure(
              code: EngineeringPlacementFailureCode.idempotencyConflict,
              message:
                  'operationId is already bound to different placement semantics.',
              details: {
                'operationId': command.operationId,
                'storedFingerprintVersion': existing.fingerprintVersion,
                'requestedFingerprintVersion':
                    engineeringPlacementFingerprintVersion,
                'storedFingerprint': existing.commandFingerprint,
                'requestedFingerprint': fingerprint,
              },
            );
          }

          final operation = _operationFromRow(existing);
          switch (operation.status) {
            case EngineeringPlacementOperationStatus.completed:
              return operation.result;
            case EngineeringPlacementOperationStatus.undone:
              throw EngineeringPlacementFailure(
                code: EngineeringPlacementFailureCode.operationUndone,
                message:
                    'The completed placement was undone. Normal retry cannot reactivate it.',
                details: {'operationId': command.operationId},
              );
          }
        }

        await _aggregate.hit(
          EngineeringPlacementFailurePoint.afterOperationCheck,
        );
        await _componentWriter.validateLocation(command);
        final resolved = await _membershipWriter.resolve(command);
        final context = await _aggregate.revalidate(command, resolved);
        final now = _clock().toUtc();
        final component = await _componentWriter.insertCanonicalComponent(
          command,
          committedAt: now,
        );
        await _aggregate.hit(EngineeringPlacementFailurePoint.afterComponent);
        await _membershipWriter.insertCanonicalMembership(
          command,
          componentId: component.id,
          committedAt: now,
        );
        await _aggregate.hit(EngineeringPlacementFailurePoint.afterMembership);
        final ports = await _aggregate.insertPortsAndBinding(
          command,
          component.id,
          resolved,
          context,
          now,
        );
        await _aggregate.assertAggregate(
          command,
          component.id,
          resolved,
          ports,
        );
        final result = EngineeringPlacementResult(
          operationId: command.operationId,
          componentId: component.id,
          systemId: command.systemId,
          membershipRole: command.normalizedMembershipRole,
          catalogId: command.catalogId,
          catalogVersion: command.catalogVersion,
          profileCode: command.profileCode,
          bindingComponentId: component.id,
          portIds: ports.map((p) => p.id),
          placementStatus: PlacementCompatibilityStatus.compatible,
          committedAt: now,
        );
        final snapshot = await _aggregate.snapshot(
          component.id,
          retired: false,
        );
        await _aggregate.hit(
          EngineeringPlacementFailurePoint.beforeOperationComplete,
        );
        await database
            .into(database.engineeringPlacementOperations)
            .insert(
              EngineeringPlacementOperationsCompanion.insert(
                operationId: command.operationId,
                projectId: command.projectId,
                fingerprintVersion: engineeringPlacementFingerprintVersion,
                commandFingerprint: fingerprint,
                status: 'COMPLETED',
                componentId: component.id,
                resultJson: jsonEncode({
                  ...jsonDecode(engineeringPlacementResultJson(result))
                      as Map<String, dynamic>,
                  'command': command.toMap(),
                  'aggregateSnapshot': snapshot,
                }),
                createdAt: now,
                updatedAt: now,
                originDeviceId: originDeviceId,
              ),
            );
        await _aggregate.hit(EngineeringPlacementFailurePoint.beforeCommit);
        return result;
      });
    } on EngineeringPlacementFailure {
      rethrow;
    } catch (error) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.transactionFailed,
        message: 'Atomic placement rolled back.',
        details: {'cause': error.toString()},
      );
    }
  }

  @override
  Future<void> undo(String operationId) =>
      _historyTransition(operationId, retire: true);

  @override
  Future<void> redo(EngineeringPlacementHistoryEntry entry) =>
      _historyTransition(entry.result.operationId, retire: false, entry: entry);

  Future<void> _historyTransition(
    String operationId, {
    required bool retire,
    EngineeringPlacementHistoryEntry? entry,
  }) async {
    try {
      await database.transaction(() async {
        final row =
            await (database.select(database.engineeringPlacementOperations)
              ..where(
                (r) => r.operationId.equals(operationId),
              )).getSingleOrNull();
        if (row == null || row.status != (retire ? 'COMPLETED' : 'UNDONE')) {
          throw EngineeringPlacementFailure(
            code: EngineeringPlacementFailureCode.historyConflict,
            message: 'Operation is unavailable in the required history state.',
          );
        }
        final stored = jsonDecode(row.resultJson) as Map<String, dynamic>;
        if (stored['command'] == null || stored['aggregateSnapshot'] == null) {
          throw EngineeringPlacementFailure(
            code: EngineeringPlacementFailureCode.historyConflict,
            message: 'Exact aggregate evidence is unavailable.',
          );
        }
        final command = PlaceEngineeringProfileCommand.fromMap(
          stored['command'] as Map<String, dynamic>,
        );
        final result = _resultFromJson(row.resultJson);
        if (row.commandFingerprint !=
                engineeringPlacementFingerprintV1(command) ||
            (entry != null &&
                (engineeringPlacementFingerprintV1(entry.command) !=
                        row.commandFingerprint ||
                    engineeringPlacementResultJson(entry.result) !=
                        engineeringPlacementResultJson(result)))) {
          throw EngineeringPlacementFailure(
            code: EngineeringPlacementFailureCode.historyConflict,
            message: 'History identity does not match the durable operation.',
          );
        }
        final current = await _aggregate.snapshot(
          result.componentId,
          retired: !retire,
        );
        if (canonicalEngineeringJson(current) !=
            canonicalEngineeringJson(stored['aggregateSnapshot'])) {
          throw EngineeringPlacementFailure(
            code: EngineeringPlacementFailureCode.historyConflict,
            message: 'The placed aggregate changed after this history entry.',
          );
        }
        await _aggregate.guardHistory(result);
        if (!retire) {
          await _componentWriter.validateLocation(command);
          final resolved = await _membershipWriter.resolve(command);
          await _aggregate.revalidate(command, resolved);
          final active = await _aggregate.snapshot(
            result.componentId,
            retired: false,
          );
          if (active.values.any((v) => (v as List).isNotEmpty)) {
            throw EngineeringPlacementFailure(
              code: EngineeringPlacementFailureCode.historyConflict,
              message: 'Aggregate identities were reactivated elsewhere.',
            );
          }
        }
        final now = _clock().toUtc();
        await _aggregate.transition(result, retire: retire, now: now);
        await (database.update(database.engineeringPlacementOperations)
          ..where((r) => r.operationId.equals(operationId))).write(
          EngineeringPlacementOperationsCompanion(
            status: Value(retire ? 'UNDONE' : 'COMPLETED'),
            updatedAt: Value(now),
            originDeviceId: Value(originDeviceId),
          ),
        );
        await _aggregate.hit(EngineeringPlacementFailurePoint.beforeCommit);
      });
    } on EngineeringPlacementFailure catch (error) {
      if (error.code == EngineeringPlacementFailureCode.historyConflict)
        rethrow;
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.historyConflict,
        message: error.message,
        findings: error.findings,
        details: error.details,
      );
    } catch (error) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.historyConflict,
        message: 'History transition rolled back.',
        details: {'cause': error.toString()},
      );
    }
  }

  EngineeringPlacementOperationRecord _operationFromRow(
    EngineeringPlacementOperationRow row,
  ) {
    final status = switch (row.status) {
      'COMPLETED' => EngineeringPlacementOperationStatus.completed,
      'UNDONE' => EngineeringPlacementOperationStatus.undone,
      _ =>
        throw StateError(
          'Unsupported engineering placement operation status: ${row.status}',
        ),
    };
    return EngineeringPlacementOperationRecord(
      operationId: row.operationId,
      projectId: row.projectId,
      fingerprintVersion: row.fingerprintVersion,
      commandFingerprint: row.commandFingerprint,
      status: status,
      componentId: row.componentId,
      result: _resultFromJson(row.resultJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      originDeviceId: row.originDeviceId,
    );
  }
}

final class DriftEngineeringPlacementComponentWriter {
  DriftEngineeringPlacementComponentWriter(
    this.database, {
    required this.originDeviceId,
    required this.idGenerator,
    DateTime Function()? clock,
    this.canonicalDefinition = canonicalElvComponentDefinition,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final String originDeviceId;
  final IdGenerator idGenerator;
  final DateTime Function() _clock;
  final ComponentDefinition canonicalDefinition;

  Future<ComponentInstance> insertCanonicalComponent(
    PlaceEngineeringProfileCommand command, {
    DateTime? committedAt,
  }) async {
    _validateCanonicalDefinition();

    final patch = await validateLocation(command);

    final componentId = idGenerator.next();
    if (componentId.trim().isEmpty) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.componentConflict,
        message: 'Generated component identity must not be empty.',
      );
    }

    final existing =
        await (database.select(database.componentInstances)
          ..where((row) => row.id.equals(componentId))).getSingleOrNull();
    if (existing != null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.componentConflict,
        message: 'Generated component identity already exists.',
        details: {'componentId': componentId},
      );
    }

    final instance = ComponentInstance(
      id: componentId,
      definitionId: canonicalDefinition.id,
      definitionVersion: canonicalDefinition.version,
      roomId: command.roomId,
      hostSurfacePatchId: command.hostSurfacePatchId,
      localPosition: command.localPosition,
      rotationRadians: command.rotationRadians,
      displayNameOverride: command.normalizedDisplayNameOverride,
    );
    final violations = ComponentPlacementValidator.validate(
      instance: instance,
      patches: [patch],
    );
    if (violations.isNotEmpty) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.placementForbidden,
        message: 'Canonical component violates physical surface geometry.',
        details: {
          'componentId': componentId,
          'violationCodes': violations
              .map((item) => item.code.name)
              .toList(growable: false),
        },
      );
    }

    final now = committedAt ?? _clock().toUtc();
    await database
        .into(database.componentInstances)
        .insert(
          ComponentInstancesCompanion.insert(
            id: componentId,
            definitionId: canonicalDefinition.id,
            definitionVersion: canonicalDefinition.version,
            roomId: command.roomId,
            hostSurfacePatchId: command.hostSurfacePatchId,
            localXmm: command.localPosition.xMm,
            localYmm: command.localPosition.yMm,
            rotationRadians: Value(command.rotationRadians),
            displayNameOverride: Value(command.normalizedDisplayNameOverride),
            metadataOverridesJson: const Value('{}'),
            revision: const Value(1),
            createdAt: now,
            updatedAt: now,
            deletedAt: const Value(null),
            originDeviceId: originDeviceId,
          ),
        );
    return instance;
  }

  Future<SurfacePatch> validateLocation(
    PlaceEngineeringProfileCommand command,
  ) async {
    _validateCanonicalDefinition();
    final project =
        await (database.select(database.projects)..where(
          (row) => row.id.equals(command.projectId) & row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (project == null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.projectNotFound,
        message: 'Placement project does not exist or is deleted.',
        details: {'projectId': command.projectId},
      );
    }

    final room =
        await (database.select(database.rooms)..where(
          (row) => row.id.equals(command.roomId) & row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (room == null) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.roomNotFound,
        message: 'Placement room does not exist or is deleted.',
        details: {'roomId': command.roomId},
      );
    }

    final floor =
        await (database.select(database.floors)..where(
          (row) => row.id.equals(room.floorId) & row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (floor == null || floor.projectId != project.id) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.roomNotFound,
        message: 'Placement room does not belong to the requested project.',
        details: {
          'projectId': command.projectId,
          'roomId': command.roomId,
          'floorId': room.floorId,
          if (floor != null) 'actualProjectId': floor.projectId,
        },
      );
    }

    final patch =
        await (database.select(database.surfacePatches)..where(
          (row) =>
              row.id.equals(command.hostSurfacePatchId) &
              row.deletedAt.isNull(),
        )).getSingleOrNull();
    if (patch == null || patch.roomId != command.roomId) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.surfacePatchNotFound,
        message:
            'Placement surface patch does not exist in the requested room.',
        details: {
          'roomId': command.roomId,
          'hostSurfacePatchId': command.hostSurfacePatchId,
          if (patch != null) 'actualRoomId': patch.roomId,
        },
      );
    }

    final resolved = _patchFromRow(patch);
    final candidate = ComponentInstance(
      id: 'validation-only',
      definitionId: canonicalDefinition.id,
      definitionVersion: canonicalDefinition.version,
      roomId: command.roomId,
      hostSurfacePatchId: command.hostSurfacePatchId,
      localPosition: command.localPosition,
      rotationRadians: command.rotationRadians,
    );
    final violations = ComponentPlacementValidator.validate(
      instance: candidate,
      patches: [resolved],
    );
    if (violations.isNotEmpty)
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.placementForbidden,
        message: 'Physical placement is outside the current surface.',
        details: {'violations': violations.map((v) => v.code.name).toList()},
      );
    return resolved;
  }

  void _validateCanonicalDefinition() {
    final valid =
        canonicalDefinition.id == canonicalElvComponentDefinitionId &&
        canonicalDefinition.code == canonicalElvComponentDefinitionCode &&
        canonicalDefinition.version == canonicalElvComponentDefinitionVersion &&
        canonicalDefinition.source == ComponentDefinitionSource.system;
    if (!valid) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.componentDefinitionNotFound,
        message: 'Canonical ELV physical component definition is unavailable.',
        details: {
          'expectedId': canonicalElvComponentDefinitionId,
          'expectedCode': canonicalElvComponentDefinitionCode,
          'expectedVersion': canonicalElvComponentDefinitionVersion,
          'actualId': canonicalDefinition.id,
          'actualCode': canonicalDefinition.code,
          'actualVersion': canonicalDefinition.version,
          'actualSource': canonicalDefinition.source.name,
        },
      );
    }
  }

  SurfacePatch _patchFromRow(SurfacePatchRow row) => SurfacePatch(
    id: row.id,
    roomId: row.roomId,
    surfaceId: row.surfaceId,
    frame: LocalCoordinateFrame(
      origin: Point3Mm(row.originXmm, row.originYmm, row.originZmm),
      uAxis: Vector3D(row.uAxisX, row.uAxisY, row.uAxisZ),
      vAxis: Vector3D(row.vAxisX, row.vAxisY, row.vAxisZ),
    ),
    boundary: GeometryCodec.decodePolygon(row.boundaryJson),
    orientation: SurfaceOrientation.values.byName(row.orientation),
  );
}

EngineeringPlacementResult _resultFromJson(String encoded) {
  final map = jsonDecode(encoded) as Map<String, dynamic>;
  return EngineeringPlacementResult(
    operationId: map['operationId'] as String,
    componentId: map['componentId'] as String,
    systemId: map['systemId'] as String,
    membershipRole: map['membershipRole'] as String,
    catalogId: map['catalogId'] as String,
    catalogVersion: map['catalogVersion'] as String,
    profileCode: map['profileCode'] as String,
    bindingComponentId: map['bindingComponentId'] as String,
    portIds: (map['portIds'] as List).cast<String>(),
    placementStatus: PlacementCompatibilityStatus.values.byName(
      map['placementStatus'] as String,
    ),
    committedAt: DateTime.parse(map['committedAt'] as String).toUtc(),
  );
}

String engineeringPlacementResultJson(EngineeringPlacementResult result) =>
    jsonEncode({
      'operationId': result.operationId,
      'componentId': result.componentId,
      'systemId': result.systemId,
      'membershipRole': result.membershipRole,
      'catalogId': result.catalogId,
      'catalogVersion': result.catalogVersion,
      'profileCode': result.profileCode,
      'bindingComponentId': result.bindingComponentId,
      'portIds': result.portIds,
      'placementStatus': result.placementStatus.name,
      'committedAt': result.committedAt.toUtc().toIso8601String(),
    });
