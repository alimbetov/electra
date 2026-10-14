import 'elv_physical_routing_workspace_service.dart';

enum ElvCommandHistoryRecordState { applied, undone, redoAbandoned }

final class ElvCommandHistoryRecord {
  const ElvCommandHistoryRecord({
    required this.projectId,
    required this.sequence,
    required this.commandId,
    required this.forwardCommandType,
    required this.forwardPayloadSha256,
    required this.undoClass,
    required this.preconditionFingerprint,
    required this.state,
    this.inverseCommandType,
    this.inversePayloadJson,
  });

  final String projectId;
  final int sequence;
  final String commandId;
  final String forwardCommandType;
  final String forwardPayloadSha256;
  final ElvCommandUndoClass undoClass;
  final String preconditionFingerprint;
  final ElvCommandHistoryRecordState state;
  final String? inverseCommandType;
  final String? inversePayloadJson;

  bool get undoEligible =>
      undoClass == ElvCommandUndoClass.reversible &&
      state == ElvCommandHistoryRecordState.applied;

  bool get redoEligible =>
      undoClass == ElvCommandUndoClass.reversible &&
      state == ElvCommandHistoryRecordState.undone;

  List<String> validate() => [
        if (projectId.trim().isEmpty) 'History projectId is required.',
        if (sequence < 1) 'History sequence must be >= 1.',
        if (commandId.trim().isEmpty) 'History commandId is required.',
        if (forwardCommandType.trim().isEmpty)
          'Forward command type is required.',
        if (forwardPayloadSha256.trim().isEmpty)
          'Forward payload hash is required.',
        if (preconditionFingerprint.trim().isEmpty)
          'Precondition fingerprint is required.',
        if (undoClass == ElvCommandUndoClass.reversible &&
            (inverseCommandType == null || inverseCommandType!.trim().isEmpty))
          'Reversible history requires inverse command type.',
        if (undoClass == ElvCommandUndoClass.reversible &&
            (inversePayloadJson == null || inversePayloadJson!.trim().isEmpty))
          'Reversible history requires inverse payload.',
      ];
}

abstract interface class ElvCommandHistoryRepository {
  Future<ElvCommandHistoryRecord?> findUndoCandidate(String projectId);
  Future<ElvCommandHistoryRecord?> findRedoCandidate(String projectId);
}

abstract interface class ElvCommandHistoryWriteStore
    implements ElvCommandHistoryRepository {
  Future<void> appendCommitted(ElvCommandHistoryRecord record);

  Future<bool> markUndone({
    required String projectId,
    required int sequence,
    required String expectedPreconditionFingerprint,
  });

  Future<bool> markReapplied({
    required String projectId,
    required int sequence,
    required String expectedPreconditionFingerprint,
  });

  Future<void> abandonRedoBranch({
    required String projectId,
    required int afterSequence,
  });
}
