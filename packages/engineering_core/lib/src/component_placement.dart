import 'geometry.dart';
import 'spatial_geometry.dart';

/// A project-owned placement of a catalog component definition.
///
/// The catalog definition describes what the component is. This instance
/// describes where that component exists in one project. Persisted placement
/// coordinates remain integer millimetres in the host patch local frame.
final class ComponentInstance {
  const ComponentInstance({
    required this.id,
    required this.definitionId,
    required this.definitionVersion,
    required this.roomId,
    required this.hostSurfacePatchId,
    required this.localPosition,
    this.rotationRadians = 0,
    this.displayNameOverride,
    this.metadataOverrides = const {},
  });

  final String id;
  final String definitionId;
  final int definitionVersion;
  final String roomId;
  final String hostSurfacePatchId;
  final Point2Mm localPosition;
  final double rotationRadians;
  final String? displayNameOverride;
  final Map<String, Object?> metadataOverrides;
}

enum ComponentPlacementViolationCode {
  emptyInstanceId,
  emptyDefinitionId,
  invalidDefinitionVersion,
  missingHostPatch,
  roomMismatch,
  outsideHostPatch,
  nonFiniteRotation,
}

final class ComponentPlacementViolation {
  const ComponentPlacementViolation({
    required this.code,
    required this.message,
  });

  final ComponentPlacementViolationCode code;
  final String message;
}

final class ComponentPlacementValidator {
  const ComponentPlacementValidator._();

  static List<ComponentPlacementViolation> validate({
    required ComponentInstance instance,
    required Iterable<SurfacePatch> patches,
  }) {
    final violations = <ComponentPlacementViolation>[];

    if (instance.id.trim().isEmpty) {
      violations.add(
        const ComponentPlacementViolation(
          code: ComponentPlacementViolationCode.emptyInstanceId,
          message: 'Component instance id must not be empty.',
        ),
      );
    }
    if (instance.definitionId.trim().isEmpty) {
      violations.add(
        const ComponentPlacementViolation(
          code: ComponentPlacementViolationCode.emptyDefinitionId,
          message: 'Component definition id must not be empty.',
        ),
      );
    }
    if (instance.definitionVersion < 1) {
      violations.add(
        const ComponentPlacementViolation(
          code: ComponentPlacementViolationCode.invalidDefinitionVersion,
          message: 'Component definition version must be at least 1.',
        ),
      );
    }
    if (!instance.rotationRadians.isFinite) {
      violations.add(
        const ComponentPlacementViolation(
          code: ComponentPlacementViolationCode.nonFiniteRotation,
          message: 'Component rotation must be finite.',
        ),
      );
    }

    SurfacePatch? hostPatch;
    for (final patch in patches) {
      if (patch.id == instance.hostSurfacePatchId) {
        hostPatch = patch;
        break;
      }
    }
    if (hostPatch == null) {
      violations.add(
        ComponentPlacementViolation(
          code: ComponentPlacementViolationCode.missingHostPatch,
          message:
              'Host surface patch ${instance.hostSurfacePatchId} does not exist.',
        ),
      );
      return List.unmodifiable(violations);
    }

    if (hostPatch.roomId != instance.roomId) {
      violations.add(
        ComponentPlacementViolation(
          code: ComponentPlacementViolationCode.roomMismatch,
          message:
              'Component room ${instance.roomId} does not match host patch room ${hostPatch.roomId}.',
        ),
      );
    }

    if (!hostPatch.boundary.containsPointInclusive(instance.localPosition)) {
      violations.add(
        ComponentPlacementViolation(
          code: ComponentPlacementViolationCode.outsideHostPatch,
          message:
              'Component position ${instance.localPosition.xMm},${instance.localPosition.yMm} mm lies outside host patch ${hostPatch.id}.',
        ),
      );
    }

    return List.unmodifiable(violations);
  }
}
