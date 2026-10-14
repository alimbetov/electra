final class BootstrapProjectDesignRevisionCommand {
  const BootstrapProjectDesignRevisionCommand({
    required this.commandId,
    required this.projectId,
    required this.revisionId,
    required this.code,
  });
  final String commandId;
  final String projectId;
  final String revisionId;
  final String code;
}

final class FreezeProjectDesignRevisionCommand {
  const FreezeProjectDesignRevisionCommand({
    required this.commandId,
    required this.projectId,
    required this.designRevisionId,
    required this.expectedRevision,
  });
  final String commandId;
  final String projectId;
  final String designRevisionId;
  final int expectedRevision;
}

final class CreateNextWorkingDesignRevisionCommand {
  const CreateNextWorkingDesignRevisionCommand({
    required this.commandId,
    required this.projectId,
    required this.newRevisionId,
    required this.code,
    required this.basedOnRevisionId,
  });
  final String commandId;
  final String projectId;
  final String newRevisionId;
  final String code;
  final String basedOnRevisionId;
}

final class SupersedeProjectDesignRevisionCommand {
  const SupersedeProjectDesignRevisionCommand({
    required this.commandId,
    required this.projectId,
    required this.designRevisionId,
    required this.expectedRevision,
  });
  final String commandId;
  final String projectId;
  final String designRevisionId;
  final int expectedRevision;
}

final class ArchiveProjectDesignRevisionCommand {
  const ArchiveProjectDesignRevisionCommand({
    required this.commandId,
    required this.projectId,
    required this.designRevisionId,
    required this.expectedRevision,
  });
  final String commandId;
  final String projectId;
  final String designRevisionId;
  final int expectedRevision;
}
