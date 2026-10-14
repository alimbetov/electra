import 'package:engineering_core/engineering_core.dart';

import 'elv_cable_run_command.dart';
import 'elv_command_result.dart';

abstract interface class ElvCableRunRepository {
  Future<List<CanonicalCableRun>> loadRuns(
    String projectId,
    String designRevisionId,
  );

  Future<CanonicalCableRun?> findRun(
    String projectId,
    String designRevisionId,
    String cableRunId,
  );

  Future<List<CableRunTraversal>> loadTraversals(String cableRunId);

  Future<ElvCommandResult<CanonicalCableRun>> create(
    CreateCableRunCommand command,
  );

  Future<ElvCommandResult<CanonicalCableRun>> reroute(
    RerouteCableRunCommand command,
  );

  Future<ElvCommandResult<CanonicalCableRun>> supersede(
    SupersedeCableRunCommand command,
  );

  Future<ElvCommandResult<CanonicalCableRun>> archive(
    ArchiveCableRunCommand command,
  );
}
