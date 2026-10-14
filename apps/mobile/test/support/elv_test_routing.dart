import 'elv_test_ids.dart';

final class ElvTestRoutingFixture {
  const ElvTestRoutingFixture({
    required this.runId,
    required this.routeId,
    required this.traversalIds,
    required this.contextId,
    required this.carrierId,
    required this.installedLengthMm,
  });

  final String runId;
  final String routeId;
  final List<String> traversalIds;
  final String contextId;
  final String carrierId;
  final int installedLengthMm;
}

ElvTestRoutingFixture buildElvTestRouting(
  FixedSequenceIdGenerator ids, {
  int traversalCount = 3,
  int installedLengthMm = 12000,
}) => ElvTestRoutingFixture(
  runId: ids.next(ElvFixturePrefixes.run),
  routeId: ids.next(ElvFixturePrefixes.route),
  traversalIds: [
    for (var index = 0; index < traversalCount; index++)
      ids.next(ElvFixturePrefixes.traversal),
  ],
  contextId: ids.next(ElvFixturePrefixes.context),
  carrierId: ids.next(ElvFixturePrefixes.carrier),
  installedLengthMm: installedLengthMm,
);
