import 'elv_command_result.dart';

/// RM08 history boundary used by the power workspace.
///
/// The older ELV3 project-only history contract remains for compatibility, but
/// ELV4 must never infer a design revision from project scope. Every read and
/// mutation therefore carries the explicit immutable revision identity.
abstract interface class ElvRevisionCommandHistoryService {
  Future<bool> canUndo({
    required String projectId,
    required String designRevisionId,
  });

  Future<bool> canRedo({
    required String projectId,
    required String designRevisionId,
  });

  Future<ElvCommandResult<Object?>> undo({
    required String projectId,
    required String designRevisionId,
  });

  Future<ElvCommandResult<Object?>> redo({
    required String projectId,
    required String designRevisionId,
  });
}
