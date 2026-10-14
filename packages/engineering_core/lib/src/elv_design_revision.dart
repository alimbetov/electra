enum ProjectDesignRevisionState { working, frozen, superseded, archived }

final class ProjectDesignRevision {
  const ProjectDesignRevision({
    required this.id,
    required this.projectId,
    required this.code,
    required this.sequence,
    required this.state,
    required this.revision,
    this.basedOnRevisionId,
  });

  final String id;
  final String projectId;
  final String code;
  final int sequence;
  final ProjectDesignRevisionState state;
  final String? basedOnRevisionId;
  final int revision;

  bool get editable => state == ProjectDesignRevisionState.working;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Design revision id is required.',
        if (projectId.trim().isEmpty) 'Design revision projectId is required.',
        if (code.trim().isEmpty) 'Design revision code is required.',
        if (sequence < 1) 'Design revision sequence must be >= 1.',
        if (revision < 1) 'Design revision optimistic revision must be >= 1.',
        if (basedOnRevisionId != null && basedOnRevisionId == id)
          'Design revision cannot be based on itself.',
      ];

  ProjectDesignRevision copyWith({
    ProjectDesignRevisionState? state,
    int? revision,
  }) =>
      ProjectDesignRevision(
        id: id,
        projectId: projectId,
        code: code,
        sequence: sequence,
        state: state ?? this.state,
        revision: revision ?? this.revision,
        basedOnRevisionId: basedOnRevisionId,
      );
}

final class PhysicalDesignContext {
  const PhysicalDesignContext({
    required this.projectId,
    required this.workingDesignRevisionId,
    required this.latestFrozenRevisionId,
    required this.editingAllowed,
  });

  final String projectId;
  final String? workingDesignRevisionId;
  final String? latestFrozenRevisionId;
  final bool editingAllowed;
}

abstract final class ProjectDesignRevisionStateMachine {
  static bool canTransition(
    ProjectDesignRevisionState from,
    ProjectDesignRevisionState to,
  ) =>
      switch ((from, to)) {
        (ProjectDesignRevisionState.working, ProjectDesignRevisionState.frozen) => true,
        (ProjectDesignRevisionState.frozen, ProjectDesignRevisionState.superseded) => true,
        (ProjectDesignRevisionState.superseded, ProjectDesignRevisionState.archived) => true,
        _ => false,
      };
}
