import 'package:engineering_core/engineering_core.dart';

final class RoomGeometrySnapshot {
  const RoomGeometrySnapshot({
    required this.roomId,
    this.patches = const [],
    this.edges = const [],
    this.adjacencies = const [],
    this.openings = const [],
    this.features = const [],
  });

  final String roomId;
  final List<SurfacePatch> patches;
  final List<SurfaceEdge> edges;
  final List<SurfaceAdjacency> adjacencies;
  final List<Opening> openings;
  final List<SpatialFeature> features;

  List<GeometryInvariantViolation> validate() =>
      SpatialGeometryValidator.validatePatchTopology(
        patches: patches,
        edges: edges,
        adjacencies: adjacencies,
        openings: openings,
        features: features,
      );
}

abstract interface class GeometryRepository {
  Stream<RoomGeometrySnapshot> watchRoomGeometry(String roomId);

  Future<RoomGeometrySnapshot> loadRoomGeometry(String roomId);

  Future<void> replaceRoomGeometry(RoomGeometrySnapshot snapshot);
}
