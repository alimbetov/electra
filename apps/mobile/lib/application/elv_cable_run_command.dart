import 'package:engineering_core/engineering_core.dart';

final class CreateCableRunCommand {
  const CreateCableRunCommand({
    required this.commandId,
    required this.projectId,
    required this.cableRunId,
    required this.cableId,
    required this.designRevisionId,
    required this.reservePercent,
    required this.terminationAllowanceMm,
    required this.traversals,
  });

  final String commandId;
  final String projectId;
  final String cableRunId;
  final String cableId;
  final String designRevisionId;
  final double reservePercent;
  final int terminationAllowanceMm;
  final List<CableRunTraversal> traversals;
}

final class RerouteCableRunCommand {
  const RerouteCableRunCommand({
    required this.commandId,
    required this.projectId,
    required this.cableRunId,
    required this.expectedRevision,
    required this.traversals,
  });

  final String commandId;
  final String projectId;
  final String cableRunId;
  final int expectedRevision;
  final List<CableRunTraversal> traversals;
}

final class SupersedeCableRunCommand {
  const SupersedeCableRunCommand({
    required this.commandId,
    required this.projectId,
    required this.cableRunId,
    required this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String cableRunId;
  final int expectedRevision;
}

final class ArchiveCableRunCommand {
  const ArchiveCableRunCommand({
    required this.commandId,
    required this.projectId,
    required this.cableRunId,
    required this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String cableRunId;
  final int expectedRevision;
}
