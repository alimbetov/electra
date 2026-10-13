import 'dart:convert';

import 'package:engineering_core/engineering_core.dart';

import '../../application/engineering_placement_command.dart';
import '../../application/engineering_placement_repository.dart';
import '../database/app_database.dart';

final class DriftEngineeringPlacementRepository
    implements EngineeringPlacementRepository {
  DriftEngineeringPlacementRepository(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<EngineeringPlacementOperationRecord?> findOperation(
    String operationId,
  ) async {
    final row =
        await (database.select(database.engineeringPlacementOperations)
              ..where((candidate) => candidate.operationId.equals(operationId)))
            .getSingleOrNull();
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
                  (candidate) =>
                      candidate.operationId.equals(command.operationId),
                ))
              .getSingleOrNull();

      if (existing != null) {
        if (existing.fingerprintVersion !=
                engineeringPlacementFingerprintVersion ||
            existing.commandFingerprint != fingerprint) {
          throw EngineeringPlacementFailure(
            code: EngineeringPlacementFailureCode.idempotencyConflict,
            message: 'operationId is already bound to different placement semantics.',
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
              message: 'The completed placement was undone. Normal retry cannot reactivate it.',
              details: {'operationId': command.operationId},
            );
        }
      }

      throw EngineeringPlacementFailure(
        code: EngineeringPlacementFailureCode.transactionFailed,
        message: 'Atomic placement aggregate writes are not enabled until P4.3-P4.7 are installed.',
        details: {
          'operationId': command.operationId,
          'phase': 'P4.2',
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
      _ => throw StateError(
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
