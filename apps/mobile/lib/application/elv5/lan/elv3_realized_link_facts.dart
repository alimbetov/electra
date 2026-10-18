import 'package:engineering_core/engineering_core_elv5.dart';

final class Elv3RealizedSectionLengthFact {
  Elv3RealizedSectionLengthFact({
    required this.realizedSectionId,
    required this.routeSegmentId,
    required this.cableRunId,
    required this.cableRunRevision,
    required this.installedLength,
    required this.includesRunReserve,
    required this.includesTerminationAllowance,
    required this.sourceFingerprint,
  });

  final String realizedSectionId;
  final String routeSegmentId;
  final String cableRunId;
  final int cableRunRevision;
  final Lan01LengthInterval installedLength;
  final bool includesRunReserve;
  final bool includesTerminationAllowance;
  final String sourceFingerprint;
}

/// Exact/conservative ELV3 projection used by LAN-01/LAN-05.
///
/// Implementations must not promote legacy floating derived lengths into exact
/// engineering facts. When persisted facts cannot provide a conservative bound,
/// they must fail closed.
abstract interface class Elv3RealizedLinkFactSource {
  Future<Elv3RealizedSectionLengthFact> requireSectionLength({
    required String projectId,
    required String designRevisionId,
    required String realizedSectionId,
  });
}
