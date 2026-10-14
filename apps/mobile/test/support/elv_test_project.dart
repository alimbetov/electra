import 'elv_test_ids.dart';

final class ElvTestProjectFixture {
  const ElvTestProjectFixture({
    required this.projectId,
    required this.workingRevisionId,
  });

  final String projectId;
  final String workingRevisionId;
}

ElvTestProjectFixture buildElvTestProject(FixedSequenceIdGenerator ids) =>
    ElvTestProjectFixture(
      projectId: ids.next(ElvFixturePrefixes.project),
      workingRevisionId: ids.next(ElvFixturePrefixes.revision),
    );
