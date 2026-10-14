enum RouteHandoffKind { surface, floor, vertical, explicit }

final class RouteHandoff {
  const RouteHandoff({
    required this.id,
    required this.projectId,
    required this.fromRouteNodeId,
    required this.toRouteNodeId,
    required this.kind,
    this.adjacencyRef,
  });

  final String id;
  final String projectId;
  final String fromRouteNodeId;
  final String toRouteNodeId;
  final RouteHandoffKind kind;
  final String? adjacencyRef;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Route handoff id is required.',
        if (projectId.trim().isEmpty) 'Route handoff projectId is required.',
        if (fromRouteNodeId.trim().isEmpty || toRouteNodeId.trim().isEmpty)
          'Route handoff endpoints are required.',
        if (fromRouteNodeId == toRouteNodeId)
          'Route handoff endpoints must be distinct route nodes.',
      ];

  double get designLengthMm => 0;
}
