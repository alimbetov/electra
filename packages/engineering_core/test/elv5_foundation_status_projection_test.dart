import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:test/test.dart';

void main() {
  test('legacy blocked evaluation projects to succeeded + blocked + unresolved',
      () {
    final projected = projectElv5FoundationStatus(
      execution: Elv5Execution.blocked,
      completion: Elv5Completion.incomplete,
      assessment: Elv5Assessment.unresolved,
      freshness: Elv5Freshness.current,
    );

    expect(projected.execution, Elv5FoundationExecution.succeeded);
    expect(projected.completion, Elv5FoundationCompletion.blocked);
    expect(projected.assessment, Elv5Assessment.unresolved);
    expect(projected.freshness, Elv5Freshness.current);
  });

  test('legacy succeeded incomplete evaluation projects to partial', () {
    final projected = projectElv5FoundationStatus(
      execution: Elv5Execution.succeeded,
      completion: Elv5Completion.incomplete,
      assessment: Elv5Assessment.notAssessed,
      freshness: Elv5Freshness.current,
    );

    expect(projected.execution, Elv5FoundationExecution.succeeded);
    expect(projected.completion, Elv5FoundationCompletion.partial);
  });

  test('legacy failed remains failed without inventing blocked completion', () {
    final projected = projectElv5FoundationStatus(
      execution: Elv5Execution.failed,
      completion: Elv5Completion.incomplete,
      assessment: Elv5Assessment.unresolved,
      freshness: Elv5Freshness.stale,
    );

    expect(projected.execution, Elv5FoundationExecution.failed);
    expect(projected.completion, Elv5FoundationCompletion.partial);
    expect(projected.freshness, Elv5Freshness.stale);
  });
}
