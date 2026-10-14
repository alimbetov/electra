import 'package:engineering_core/engineering_core.dart';

final class CreatePhysicalCompatibilityProfileSetCommand {
  const CreatePhysicalCompatibilityProfileSetCommand({
    required this.commandId,
    required this.projectId,
    required this.profileSetId,
    required this.refs,
  });

  final String commandId;
  final String projectId;
  final String profileSetId;
  final List<PhysicalCompatibilityProfileRef> refs;
}

final class ReplaceActivePhysicalCompatibilityProfileSetCommand {
  const ReplaceActivePhysicalCompatibilityProfileSetCommand({
    required this.commandId,
    required this.projectId,
    required this.profileSetId,
    required this.refs,
  });

  final String commandId;
  final String projectId;
  final String profileSetId;
  final List<PhysicalCompatibilityProfileRef> refs;
}

final class ArchivePhysicalCompatibilityProfileSetCommand {
  const ArchivePhysicalCompatibilityProfileSetCommand({
    required this.commandId,
    required this.projectId,
    required this.profileSetId,
    required this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String profileSetId;
  final int expectedRevision;
}
