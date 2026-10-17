import 'package:engineering_core/engineering_core_elv5.dart';

import 'environment_profile_persistence.dart';

final class Elv5ResolvedEnvironment {
  const Elv5ResolvedEnvironment({
    required this.routeSectionId,
    required this.roomId,
    required this.binding,
    required this.usedSectionOverride,
  });

  final String routeSectionId;
  final String roomId;
  final Elv5EnvironmentProfileSnapshot binding;
  final bool usedSectionOverride;

  Elv5EnvironmentScopeBinding toCoreBinding() => Elv5EnvironmentScopeBinding(
        bindingId: binding.bindingId,
        scopeKind: binding.scopeKind,
        scopeId: binding.scopeId,
        profile: binding.profile,
        priority: usedSectionOverride ? 200 : 100,
      );
}

abstract interface class Elv5EnvironmentScopeResolver {
  /// Resolves environment with strict precedence:
  /// ROUTE_SECTION explicit override > ROOM explicit profile > missing.
  ///
  /// roomType/roomCategory are never engineering fallbacks.
  Future<Elv5ResolvedEnvironment?> resolveForRouteSection({
    required String projectId,
    required String designRevisionId,
    required String routeSectionId,
  });
}
