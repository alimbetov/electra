import 'elv_physical_compatibility_profile.dart';

enum PhysicalCompatibilityProfileSetState { active, archived }

final class ProjectPhysicalCompatibilityProfileSet {
  ProjectPhysicalCompatibilityProfileSet({
    required this.id,
    required this.projectId,
    required Iterable<PhysicalCompatibilityProfileRef> refs,
    required this.state,
    required this.revision,
  }) : refs = List.unmodifiable(refs);

  final String id;
  final String projectId;
  final List<PhysicalCompatibilityProfileRef> refs;
  final PhysicalCompatibilityProfileSetState state;
  final int revision;

  bool get active => state == PhysicalCompatibilityProfileSetState.active;

  List<String> validate() => [
        if (id.trim().isEmpty)
          'Physical compatibility profile set id is required.',
        if (projectId.trim().isEmpty)
          'Physical compatibility profile set projectId is required.',
        if (refs.isEmpty)
          'Physical compatibility profile set must not be empty.',
        if (revision < 1)
          'Physical compatibility profile set revision must be >= 1.',
      ];
}
