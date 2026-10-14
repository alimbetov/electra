import 'package:engineering_core/engineering_core.dart';

import 'elv_command_result.dart';
import 'elv_physical_profile_set_command.dart';

abstract interface class ElvPhysicalCompatibilityRepository {
  Future<ProjectPhysicalCompatibilityProfileSet?> activeProfileSet(
    String projectId,
  );

  Future<ElvCommandResult<ProjectPhysicalCompatibilityProfileSet>>
  createProfileSet(CreatePhysicalCompatibilityProfileSetCommand command);

  Future<ElvCommandResult<ProjectPhysicalCompatibilityProfileSet>>
  replaceActiveProfileSet(
    ReplaceActivePhysicalCompatibilityProfileSetCommand command,
  );

  Future<ElvCommandResult<void>> archiveProfileSet(
    ArchivePhysicalCompatibilityProfileSetCommand command,
  );

  Future<List<PhysicalCompatibilityProfile>> resolveProfiles(
    String projectId,
    Iterable<PhysicalCompatibilityProfileRef> refs,
  );
}
