import 'package:drift/drift.dart';
import 'package:engineering_core/engineering_core.dart';

import '../../application/power_mutation_command.dart';
import '../database/app_database.dart';
import 'drift_power_canonical_projection_write_store.dart';
import 'drift_power_command_service.dart';
import 'drift_power_runtime_store.dart';

/// RM03 single-UoW entry point for a power profile that owns static canonical
/// port projection fields.
///
/// The caller cannot choose invalidation dependencies: they are replaced by the
/// exact old/new closure from the reviewed projection. Canonical projection,
/// binding mutation, design-token CAS, invalidation and operation receipt are
/// committed by one outer Drift transaction. The underlying command service
/// remains replay-first and owns the durable ledger format.
final class DriftReviewedPowerPortBindingCoordinator {
  DriftReviewedPowerPortBindingCoordinator(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now,
       projectionStore = DriftPowerCanonicalProjectionWriteStore(
         database,
         originDeviceId: originDeviceId,
         now: now,
       ),
       commandService = DriftPowerCommandService(
         database,
         originDeviceId: originDeviceId,
         now: now,
       );

  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() now;
  final DriftPowerCanonicalProjectionWriteStore projectionStore;
  final DriftPowerCommandService commandService;

  Future<PowerMutationReceipt> execute({
    required BindPowerPortCommand command,
    required EngineeringPort candidate,
    required PowerCanonicalProjectionReview review,
  }) async {
    if (command.projectId != review.projectId ||
        command.designRevisionId != review.designRevisionId ||
        command.binding.portId != review.portId ||
        candidate.id != review.portId ||
        command.expectedRevision != review.expectedDesignRevision) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_SCOPE_MISMATCH',
      );
    }

    final existing = await _operationExists(command);
    if (existing) {
      await _requirePersistedCandidate(review.projectId, candidate);
      final normalized = _withReviewedDependencies(command, review);
      return commandService.execute(normalized);
    }

    return database.transaction(() async {
      final fresh = await projectionStore.preview(
        projectId: review.projectId,
        designRevisionId: review.designRevisionId,
        candidate: candidate,
        binding: command.binding,
      );
      _requireSameReview(review, fresh);
      final normalized = _withReviewedDependencies(command, fresh);

      if (canonicalEngineeringJson(review.beforePayload) !=
          canonicalEngineeringJson(review.candidatePayload)) {
        final changed = await database.customUpdate(
          'UPDATE engineering_port_instances '
          'SET payload_json = ?, revision = revision + 1, updated_at = ?, '
          'origin_device_id = ? '
          'WHERE project_id = ? AND id = ? AND deleted_at IS NULL '
          'AND revision = ?',
          variables: [
            Variable.withString(canonicalEngineeringJson(candidate.toMap())),
            Variable<DateTime>(now().toUtc()),
            Variable.withString(originDeviceId),
            Variable.withString(review.projectId),
            Variable.withString(review.portId),
            Variable.withInt(review.expectedPortRevision),
          ],
        );
        if (changed != 1) {
          throw const PowerRuntimeStorageException(
            'ELV4_POWER_PROJECTION_PORT_CAS_FAILED',
          );
        }
      }

      final receipt = await commandService.execute(normalized);
      if (receipt.previousRevision != review.expectedDesignRevision ||
          receipt.currentRevision != review.expectedDesignRevision + 1) {
        throw const PowerRuntimeStorageException(
          'ELV4_POWER_PROJECTION_DESIGN_CAS_FAILED',
        );
      }
      return receipt;
    });
  }

  BindPowerPortCommand _withReviewedDependencies(
    BindPowerPortCommand command,
    PowerCanonicalProjectionReview review,
  ) {
    final dependencies = <PowerDependencyKey>{
      ...review.oldClosure,
      ...review.newClosure,
    }.toList()..sort();
    return BindPowerPortCommand(
      operationId: command.operationId,
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      expectedRevision: command.expectedRevision,
      changedDependencies: dependencies,
      bindingId: command.bindingId,
      binding: command.binding,
    );
  }

  void _requireSameReview(
    PowerCanonicalProjectionReview expected,
    PowerCanonicalProjectionReview actual,
  ) {
    if (expected.reviewedImpactFingerprint !=
            actual.reviewedImpactFingerprint ||
        expected.expectedDesignRevision != actual.expectedDesignRevision ||
        expected.expectedPortRevision != actual.expectedPortRevision) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_STALE_REVIEW',
      );
    }
  }

  Future<bool> _operationExists(BindPowerPortCommand command) async {
    final row = await database
        .customSelect(
          'SELECT 1 FROM power_operation_records '
          'WHERE project_id = ? AND design_revision_id = ? AND operation_id = ?',
          variables: [
            Variable.withString(command.projectId),
            Variable.withString(command.designRevisionId),
            Variable.withString(command.operationId),
          ],
        )
        .getSingleOrNull();
    return row != null;
  }

  Future<void> _requirePersistedCandidate(
    String projectId,
    EngineeringPort candidate,
  ) async {
    final row = await database
        .customSelect(
          'SELECT payload_json FROM engineering_port_instances '
          'WHERE project_id = ? AND id = ? AND deleted_at IS NULL',
          variables: [
            Variable.withString(projectId),
            Variable.withString(candidate.id),
          ],
        )
        .getSingleOrNull();
    if (row == null ||
        row.read<String>('payload_json') !=
            canonicalEngineeringJson(candidate.toMap())) {
      throw const PowerRuntimeStorageException(
        'ELV4_POWER_PROJECTION_REPLAY_STATE_MISMATCH',
      );
    }
  }
}
