import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/engineering_placement_command.dart';
import '../../application/engineering_placement_repository.dart';
import '../../application/id_generator.dart';
import '../../domain/system_component_catalog.dart';
import '../database/app_database.dart';
import '../database/geometry_codec.dart';

final class DriftEngineeringPlacementRepository
    implements EngineeringPlacementRepository {
  DriftEngineeringPlacementRepository(
    this.database, {
    required this.originDeviceId,
    IdGenerator? idGenerator,
    DateTime Function()? clock,
    ComponentDefinition canonicalDefinition = canonicalElvComponentDefinition,
  }) : _componentWriter = DriftEngineeringPlacementComponentWriter(
         database,
         originDeviceId: originDeviceId,
         idGenerator: idGenerator ?? UuidV7IdGenerator(),
         clock: clock,
         canonicalDefinition: canonicalDefinition,
       );

  final AppDatabase database;
  final String originDeviceId;
  final DriftEngineeringPlacementComponentWriter _componentWriter;

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
  ) {
    final validation = command.validate();
    if (validation.isNotEmpty) {
      throw validation.first;
    }
    final fingerprint = engineeringPlacementFingerprintV1(command);

    return database.transaction(() async {
      final existing =
          await (database.select(database.engineeringPlacementOperations)
            ..where(
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

      final component = await _componentWriter.insertCanonicalComponent(command);

      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.transactionFailed,
        message:
            'Canonical component created inside the placement transaction, but aggregate writes remain incomplete until P4.4-P4.7.',
        details: {
          'operationId': command.operationId,
          'componentId': component.id,
          'phase': 'P4.3',
          'transactionOwner': 'DriftEngineeringPlacementRepository',
        },
      );
    });
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
              row.id.equals(command.hostSurfacePatchId) & row.deletedAt.isNull(),
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

    final componentId = idGenerator.next();
    if (componentId.trim().isEmpty) {
      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.componentConflict,
        message: 'Generated component identity must not be empty.',
      );
    }

    final existing =
        await (database.select(database.componentInstances)..where(
          (row) => row.id.equals(componentId),
        )).getSingleOrNull();
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
      patches: [_patchFromRow(patch)],
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

    final now = _clock().toUtc();
    await database.into(database.componentInstances).insert(
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
