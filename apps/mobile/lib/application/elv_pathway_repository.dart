import 'package:engineering_core/engineering_core.dart';

import 'elv_command_result.dart';
import 'elv_pathway_command.dart';

abstract interface class ElvPathwayRepository {
  Future<List<PathwayContext>> loadContexts(String projectId);
  Future<PathwayContext?> findContext(String projectId, String contextId);

  Future<ElvCommandResult<PathwayContext>> create(
    CreatePathwayContextCommand command,
  );

  Future<ElvCommandResult<PathwayContext>> update(
    UpdatePathwayContextCommand command,
  );

  Future<ElvCommandResult<void>> archive(
    ArchivePathwayContextCommand command,
  );
}
