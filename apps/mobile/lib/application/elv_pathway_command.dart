import 'package:engineering_core/engineering_core.dart';

final class CreatePathwayContextCommand {
  const CreatePathwayContextCommand({
    required this.commandId,
    required this.context,
  });
  final String commandId;
  final PathwayContext context;
}

final class UpdatePathwayContextCommand {
  const UpdatePathwayContextCommand({
    required this.commandId,
    required this.context,
    required this.expectedRevision,
    required this.expectedImpactFingerprint,
  });
  final String commandId;
  final PathwayContext context;
  final int expectedRevision;
  final String expectedImpactFingerprint;
}

final class ArchivePathwayContextCommand {
  const ArchivePathwayContextCommand({
    required this.commandId,
    required this.projectId,
    required this.contextId,
    required this.expectedRevision,
  });
  final String commandId;
  final String projectId;
  final String contextId;
  final int expectedRevision;
}
