enum PathwayContextKind {
  roomLocal,
  floorCommon,
  ceilingVoid,
  underfloor,
  riser,
  shaft,
  projectShared,
}

enum PathwayContextLifecycleState { active, archived }

sealed class PathwayContextHost {
  const PathwayContextHost();
}

final class RoomHost extends PathwayContextHost {
  const RoomHost(this.roomId);
  final String roomId;
}

final class FloorHost extends PathwayContextHost {
  const FloorHost(this.floorId);
  final String floorId;
}

final class SurfaceVoidHost extends PathwayContextHost {
  const SurfaceVoidHost(
      {required this.floorId, required this.spatialFeatureId});
  final String floorId;
  final String spatialFeatureId;
}

final class VerticalHost extends PathwayContextHost {
  const VerticalHost({
    required this.fromFloorId,
    required this.toFloorId,
    this.spatialFeatureId,
  });
  final String fromFloorId;
  final String toFloorId;
  final String? spatialFeatureId;
}

final class ProjectHost extends PathwayContextHost {
  const ProjectHost(this.projectId);
  final String projectId;
}

final class PathwayContext {
  const PathwayContext({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.host,
    required this.lifecycleState,
    required this.revision,
    this.parentContextId,
    this.provenance,
  });

  final String id;
  final String projectId;
  final PathwayContextKind kind;
  final PathwayContextHost host;
  final String? parentContextId;
  final String? provenance;
  final PathwayContextLifecycleState lifecycleState;
  final int revision;
}

abstract final class PathwayContextValidator {
  static List<String> validate({
    required PathwayContext context,
    required Map<String, PathwayContext> projectContexts,
  }) {
    final errors = <String>[];
    if (context.id.trim().isEmpty || context.projectId.trim().isEmpty) {
      errors.add('Pathway context identity and project are required.');
    }
    if (context.revision < 1)
      errors.add('Pathway context revision must be >= 1.');
    final validHost = switch (context.kind) {
      PathwayContextKind.roomLocal => context.host is RoomHost,
      PathwayContextKind.floorCommon => context.host is FloorHost,
      PathwayContextKind.ceilingVoid ||
      PathwayContextKind.underfloor =>
        context.host is SurfaceVoidHost,
      PathwayContextKind.riser ||
      PathwayContextKind.shaft =>
        context.host is VerticalHost,
      PathwayContextKind.projectShared => context.host is ProjectHost,
    };
    if (!validHost)
      errors.add('Pathway context kind/host combination is invalid.');

    if (context.host case final VerticalHost host) {
      if (host.fromFloorId == host.toFloorId) {
        errors.add('Vertical pathway must span distinct floors.');
      }
    }

    final parentId = context.parentContextId;
    if (parentId != null) {
      if (parentId == context.id) {
        errors.add('Pathway context cannot parent itself.');
      } else {
        final parent = projectContexts[parentId];
        if (parent == null) {
          errors.add('Pathway parent context does not exist in the project.');
        } else if (parent.projectId != context.projectId) {
          errors.add('Pathway parent context must belong to the same project.');
        }
      }
      final visited = <String>{context.id};
      var cursor = parentId;
      while (cursor != null) {
        if (!visited.add(cursor)) {
          errors.add('Pathway context hierarchy must be acyclic.');
          break;
        }
        cursor = projectContexts[cursor]?.parentContextId;
      }
    }
    return errors;
  }
}
