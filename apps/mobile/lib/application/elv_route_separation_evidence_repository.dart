import 'package:engineering_core/engineering_core.dart';

import 'elv_command_result.dart';
import 'elv_route_separation_evidence_command.dart';

abstract interface class ElvRouteSeparationEvidenceRepository {
  Future<RouteSeparationEvidence?> findActive({
    required String projectId,
    required String designRevisionId,
    required String subjectAId,
    required String subjectBId,
  });

  Future<ElvCommandResult<RouteSeparationEvidence>> persist(
    PersistRouteSeparationEvidenceCommand command,
  );
}
