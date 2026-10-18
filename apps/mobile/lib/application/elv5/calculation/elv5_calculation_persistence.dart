import '../../elv_write_unit_of_work.dart';
import '../persistence/elv5_runtime_persistence.dart';

final class Elv5CalculationRevisionGuard {
  const Elv5CalculationRevisionGuard({
    required this.projectId,
    required this.designRevisionId,
    required this.state,
    required this.rowRevision,
  });

  final String projectId;
  final String designRevisionId;
  final String state;
  final int rowRevision;

  bool get working => state == 'WORKING';
}

abstract interface class Elv5CalculationPublicationGuardStore {
  Future<bool> upstreamStillCurrent({
    required String projectId,
    required String designRevisionId,
    required Map<String, int> generations,
  });

  Future<Elv5CalculationRevisionGuard?> loadRevision({
    required String projectId,
    required String designRevisionId,
  });
}

abstract interface class Elv5CalculationWriteSession
    implements Elv5RuntimeWriteSession {
  Elv5CalculationPublicationGuardStore get publicationGuards;
}

typedef Elv5CalculationWriteUnitOfWork =
    ElvWriteUnitOfWork<Elv5CalculationWriteSession>;
