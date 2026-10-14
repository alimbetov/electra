import 'package:engineering_core/engineering_core.dart';

import 'elv_command_result.dart';
import 'elv_design_revision_command.dart';

abstract interface class ElvDesignRevisionRepository {
  Future<PhysicalDesignContext> context(String projectId);

  Future<ElvCommandResult<ProjectDesignRevision>> bootstrap(
    BootstrapProjectDesignRevisionCommand command,
  );

  Future<ElvCommandResult<ProjectDesignRevision>> freeze(
    FreezeProjectDesignRevisionCommand command,
  );

  Future<ElvCommandResult<ProjectDesignRevision>> createNext(
    CreateNextWorkingDesignRevisionCommand command,
  );

  Future<ElvCommandResult<ProjectDesignRevision>> supersede(
    SupersedeProjectDesignRevisionCommand command,
  );

  Future<ElvCommandResult<ProjectDesignRevision>> archive(
    ArchiveProjectDesignRevisionCommand command,
  );
}
