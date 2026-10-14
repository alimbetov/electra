import 'package:engineering_core/engineering_core.dart';

abstract final class ElvPhysicalCalculationNodes {
  static String installedLength({
    required String designRevisionId,
    required String cableRunId,
  }) =>
      'elv3:$designRevisionId:${ElvPhysicalProcessCodes.installedLength}:cable-run:$cableRunId';

  static String carrierUsage({
    required String designRevisionId,
    required CarrierUsageKey key,
  }) =>
      'elv3:$designRevisionId:${ElvPhysicalProcessCodes.carrierFillBasis}:carrier-usage:${key.stableKey}';

  static String bendRadius({
    required String designRevisionId,
    required String routeNodeId,
    required String cableId,
  }) =>
      'elv3:$designRevisionId:${ElvPhysicalProcessCodes.bendRadiusBasis}:route-node:$routeNodeId:cable:$cableId';

  static String segregation({
    required String designRevisionId,
    required String subjectAId,
    required String subjectBId,
  }) {
    final ids = [subjectAId, subjectBId]..sort();
    return 'elv3:$designRevisionId:${ElvPhysicalProcessCodes.segregationEvidence}:subjects:${ids[0]}/${ids[1]}';
  }
}
