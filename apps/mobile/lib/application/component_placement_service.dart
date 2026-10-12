import 'package:engineering_core/engineering_core.dart';

import 'component_instance_repository.dart';
import 'geometry_repository.dart';
import 'id_generator.dart';

final class ComponentPlacementService {
  const ComponentPlacementService({
    required this.components,
    required this.geometry,
    required this.idGenerator,
  });

  final ComponentInstanceRepository components;
  final GeometryRepository geometry;
  final IdGenerator idGenerator;

  Future<ComponentInstance> place({
    required String roomId,
    required ComponentDefinition definition,
    required String hostSurfacePatchId,
    required Point2Mm localPosition,
    double rotationRadians = 0,
  }) async {
    final geometrySnapshot = await geometry.loadRoomGeometry(roomId);
    final instance = ComponentInstance(
      id: idGenerator.next(),
      definitionId: definition.id,
      definitionVersion: definition.version,
      roomId: roomId,
      hostSurfacePatchId: hostSurfacePatchId,
      localPosition: localPosition,
      rotationRadians: rotationRadians,
    );

    final violations = ComponentPlacementValidator.validate(
      instance: instance,
      patches: geometrySnapshot.patches,
    );
    if (violations.isNotEmpty) {
      throw StateError(
        'Invalid component placement: '
        '${violations.map((item) => item.code.name).join(', ')}',
      );
    }

    await components.saveComponent(instance);
    return instance;
  }
}
