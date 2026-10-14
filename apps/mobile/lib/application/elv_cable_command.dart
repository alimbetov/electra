import 'package:engineering_core/engineering_core.dart';

final class CreateCableCommand {
  const CreateCableCommand({
    required this.commandId,
    required this.projectId,
    required this.cableId,
    required this.label,
    required this.name,
    required this.definitionRef,
  });

  final String commandId;
  final String projectId;
  final String cableId;
  final String label;
  final String name;
  final CableDefinitionRef definitionRef;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'cableId': cableId.trim(),
    'label': label.trim(),
    'name': name.trim(),
    'definitionRef': definitionRef.normalized().toMap(),
  };
}

final class ChangeCableDefinitionRefCommand {
  const ChangeCableDefinitionRefCommand({
    required this.commandId,
    required this.projectId,
    required this.cableId,
    required this.expectedRevision,
    required this.definitionRef,
  });

  final String commandId;
  final String projectId;
  final String cableId;
  final int expectedRevision;
  final CableDefinitionRef definitionRef;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'cableId': cableId.trim(),
    'expectedRevision': expectedRevision,
    'definitionRef': definitionRef.normalized().toMap(),
  };
}

final class ArchiveCableCommand {
  const ArchiveCableCommand({
    required this.commandId,
    required this.projectId,
    required this.cableId,
    required this.expectedRevision,
  });

  final String commandId;
  final String projectId;
  final String cableId;
  final int expectedRevision;

  Map<String, Object?> normalizedPayload() => {
    'projectId': projectId.trim(),
    'cableId': cableId.trim(),
    'expectedRevision': expectedRevision,
  };
}
