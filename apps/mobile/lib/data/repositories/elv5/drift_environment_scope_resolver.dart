import '../../../application/elv5/environment/environment_profile_persistence.dart';
import '../../../application/elv5/environment/environment_scope_resolver.dart';
import '../../database/app_database.dart';

final class DriftElv5EnvironmentScopeResolver
    implements Elv5EnvironmentScopeResolver {
  const DriftElv5EnvironmentScopeResolver({
    required this.database,
    required this.profileSource,
  });

  final AppDatabase database;
  final Elv5EnvironmentProfileSource profileSource;

  @override
  Future<Elv5ResolvedEnvironment?> resolveForRouteSection({
    required String projectId,
    required String designRevisionId,
    required String routeSectionId,
  }) async {
    final section = await (database.select(database.cableRouteSegments)
          ..where(
            (row) =>
                row.id.equals(routeSectionId) & row.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (section == null) {
      throw StateError('ELV5_ENVIRONMENT_ROUTE_SECTION_NOT_FOUND:$routeSectionId');
    }

    final route = await (database.select(database.cableRoutes)
          ..where(
            (row) => row.id.equals(section.routeId) & row.deletedAt.isNull(),
          ))
        .getSingleOrNull();
    if (route == null) {
      throw StateError(
        'ELV5_ENVIRONMENT_ROUTE_NOT_FOUND:${section.routeId}:$routeSectionId',
      );
    }

    final room = await (database.select(database.rooms)
          ..where((row) => row.id.equals(route.roomId) & row.deletedAt.isNull()))
        .getSingleOrNull();
    if (room == null) {
      throw StateError('ELV5_ENVIRONMENT_ROOM_NOT_FOUND:${route.roomId}');
    }

    final sectionProfile = await profileSource.loadActiveForScope(
      projectId: projectId,
      designRevisionId: designRevisionId,
      scopeKind: 'ROUTE_SECTION',
      scopeId: routeSectionId,
    );
    if (sectionProfile != null) {
      return Elv5ResolvedEnvironment(
        routeSectionId: routeSectionId,
        roomId: room.id,
        binding: sectionProfile,
        usedSectionOverride: true,
      );
    }

    final roomProfile = await profileSource.loadActiveForScope(
      projectId: projectId,
      designRevisionId: designRevisionId,
      scopeKind: 'ROOM',
      scopeId: room.id,
    );
    if (roomProfile == null) return null;

    return Elv5ResolvedEnvironment(
      routeSectionId: routeSectionId,
      roomId: room.id,
      binding: roomProfile,
      usedSectionOverride: false,
    );
  }
}
