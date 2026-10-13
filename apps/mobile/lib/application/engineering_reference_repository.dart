import 'package:engineering_core/engineering_core.dart';
import 'engineering_system_repository.dart';

class ComponentReferenceBinding {
  const ComponentReferenceBinding({
    required this.componentId,
    required this.catalogId,
    required this.profileCode,
    required this.catalogVersion,
    required this.profile,
    required this.portIds,
  });
  final String componentId, catalogId, profileCode, catalogVersion;
  final ComponentEngineeringProfile profile;
  final List<String> portIds;
  Map<String, Object?> toMap() => {
    'componentId': componentId,
    'catalogId': catalogId,
    'profileCode': profileCode,
    'catalogVersion': catalogVersion,
    'profile': profile.toMap(),
    'portIds': portIds,
  };
  factory ComponentReferenceBinding.fromMap(Map<String, dynamic> m) =>
      ComponentReferenceBinding(
        componentId: m['componentId'] as String,
        catalogId: m['catalogId'] as String,
        profileCode: m['profileCode'] as String,
        catalogVersion: m['catalogVersion'] as String,
        profile: ComponentEngineeringProfile.fromMap(
          m['profile'] as Map<String, dynamic>,
        ),
        portIds: (m['portIds'] as List).cast<String>(),
      );
}

class ProjectEngineeringReferences {
  const ProjectEngineeringReferences({
    required this.systems,
    required this.catalogs,
    required this.bindings,
  });
  final ProjectEngineeringSystemsSnapshot systems;
  final List<EngineeringReferenceCatalog> catalogs;
  final List<ComponentReferenceBinding> bindings;
}

abstract interface class EngineeringReferenceRepository {
  Future<ProjectEngineeringReferences> load(String projectId);
  Stream<ProjectEngineeringReferences> watch(String projectId);
  Future<void> importCatalog(
    String projectId,
    EngineeringReferenceCatalog catalog,
  );
  Future<void> bind(
    String projectId,
    String componentId,
    String catalogId,
    String profileCode,
  );
  Future<void> unbind(String projectId, String componentId);
}
