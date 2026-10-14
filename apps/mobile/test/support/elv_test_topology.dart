import 'elv_test_ids.dart';

final class ElvTestConnectionFixture {
  const ElvTestConnectionFixture({
    required this.connectionId,
    required this.fromPortId,
    required this.toPortId,
    required this.role,
  });

  final String connectionId;
  final String fromPortId;
  final String toPortId;
  final String role;
}

ElvTestConnectionFixture buildElvTestConnection(
  FixedSequenceIdGenerator ids, {
  required String role,
}) => ElvTestConnectionFixture(
  connectionId: ids.next(ElvFixturePrefixes.connection),
  fromPortId: ids.next(ElvFixturePrefixes.port),
  toPortId: ids.next(ElvFixturePrefixes.port),
  role: role,
);
