import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/elv_physical_calculation_service.dart';
import '../database/app_database.dart';

final class DriftElvPhysicalCalculationResultStore
    implements ElvPhysicalCalculationResultStore {
  const DriftElvPhysicalCalculationResultStore(
    this.database, {
    required this.originDeviceId,
  });

  final AppDatabase database;
  final String originDeviceId;

  @override
  Future<void> put<T>(
    String projectId,
    String nodeKey,
    ElvPhysicalCalculationResult<T> result,
  ) async {
    final now = DateTime.now().toUtc();
    final payload = <String, Object?>{
      'processCode': result.processCode,
      'algorithmVersion': result.algorithmVersion,
      'projectId': result.projectId,
      'designRevisionId': result.designRevisionId,
      'subjectId': result.subjectId,
      'value': result.value,
      'unit': result.unit,
      'state': result.state.name,
      'inputFingerprint': result.inputFingerprint,
      'trace': result.trace,
      'blockingCodes': result.blockingCodes,
    };

    await database.into(database.projectDerivedResults).insertOnConflictUpdate(
          ProjectDerivedResultsCompanion.insert(
            projectId: projectId,
            nodeKey: nodeKey,
            fingerprint: result.inputFingerprint,
            inputsJson: jsonEncode({
              'designRevisionId': result.designRevisionId,
              'processCode': result.processCode,
              'algorithmVersion': result.algorithmVersion,
              'subjectId': result.subjectId,
            }),
            dependenciesJson: '[]',
            resultJson: jsonEncode(payload),
            state: result.state.name.toUpperCase(),
            revision: const Value(1),
            createdAt: now,
            updatedAt: now,
            originDeviceId: originDeviceId,
          ),
        );
  }

  @override
  Future<ElvPhysicalCalculationResult<Object?>?> find(
    String projectId,
    String nodeKey,
  ) async {
    final row = await (database.select(database.projectDerivedResults)
          ..where(
            (candidate) =>
                candidate.projectId.equals(projectId) &
                candidate.nodeKey.equals(nodeKey) &
                candidate.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (row == null) return null;

    final map = jsonDecode(row.resultJson) as Map<String, dynamic>;
    final persistedState = ElvCalculationState.values.byName(
      row.state.toLowerCase(),
    );

    return ElvPhysicalCalculationResult<Object?>(
      processCode: map['processCode'] as String,
      algorithmVersion: map['algorithmVersion'] as String,
      projectId: map['projectId'] as String,
      designRevisionId: map['designRevisionId'] as String,
      subjectId: map['subjectId'] as String,
      value: map['value'],
      unit: map['unit'] as String,
      state: persistedState,
      inputFingerprint: map['inputFingerprint'] as String,
      trace: (map['trace'] as Map).cast<String, Object?>(),
      blockingCodes: (map['blockingCodes'] as List).cast<String>(),
    );
  }

  @override
  Future<void> invalidate(String projectId, Iterable<String> nodeKeys) async {
    final keys = nodeKeys.toSet();
    if (keys.isEmpty) return;

    await (database.update(database.projectDerivedResults)
          ..where(
            (row) =>
                row.projectId.equals(projectId) &
                row.nodeKey.isIn(keys) &
                row.deletedAt.isNull(),
          ))
        .write(
          ProjectDerivedResultsCompanion(
            state: const Value('STALE'),
            updatedAt: Value(DateTime.now().toUtc()),
            originDeviceId: Value(originDeviceId),
          ),
        );
  }
}
