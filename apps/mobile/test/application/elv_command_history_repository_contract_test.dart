import 'package:electra_mobile/application/elv_command_history_repository.dart';
import 'package:electra_mobile/application/elv_physical_routing_workspace_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ELV3 P7 command history foundation', () {
    test('reversible entry requires inverse command evidence', () {
      const record = ElvCommandHistoryRecord(
        projectId: 'PRJ-001',
        sequence: 1,
        commandId: 'CMD-001',
        forwardCommandType: 'RerouteCableRun',
        forwardPayloadSha256: 'sha-forward',
        undoClass: ElvCommandUndoClass.reversible,
        preconditionFingerprint: 'fp-1',
        state: ElvCommandHistoryRecordState.applied,
      );

      expect(record.validate(), hasLength(2));
      expect(record.undoEligible, isTrue);
    });

    test('reversible applied and undone states expose one direction only', () {
      const applied = ElvCommandHistoryRecord(
        projectId: 'PRJ-001',
        sequence: 1,
        commandId: 'CMD-001',
        forwardCommandType: 'RerouteCableRun',
        forwardPayloadSha256: 'sha-forward',
        undoClass: ElvCommandUndoClass.reversible,
        preconditionFingerprint: 'fp-1',
        state: ElvCommandHistoryRecordState.applied,
        inverseCommandType: 'RerouteCableRun',
        inversePayloadJson: '{"route":"old"}',
      );
      const undone = ElvCommandHistoryRecord(
        projectId: 'PRJ-001',
        sequence: 1,
        commandId: 'CMD-001',
        forwardCommandType: 'RerouteCableRun',
        forwardPayloadSha256: 'sha-forward',
        undoClass: ElvCommandUndoClass.reversible,
        preconditionFingerprint: 'fp-1',
        state: ElvCommandHistoryRecordState.undone,
        inverseCommandType: 'RerouteCableRun',
        inversePayloadJson: '{"route":"old"}',
      );

      expect(applied.validate(), isEmpty);
      expect(applied.undoEligible, isTrue);
      expect(applied.redoEligible, isFalse);
      expect(undone.undoEligible, isFalse);
      expect(undone.redoEligible, isTrue);
    });

    test('irreversible history is never exposed as normal undo', () {
      const record = ElvCommandHistoryRecord(
        projectId: 'PRJ-001',
        sequence: 2,
        commandId: 'CMD-002',
        forwardCommandType: 'FreezeProjectDesignRevision',
        forwardPayloadSha256: 'sha-freeze',
        undoClass: ElvCommandUndoClass.irreversibleHistory,
        preconditionFingerprint: 'fp-2',
        state: ElvCommandHistoryRecordState.applied,
      );

      expect(record.validate(), isEmpty);
      expect(record.undoEligible, isFalse);
      expect(record.redoEligible, isFalse);
    });
  });
}
