import 'package:flutter_test/flutter_test.dart';

/// Process-neutral observation of the durable ELV5 publication state.
///
/// Process fixtures own their engineering facts. The harness owns the common
/// qualification semantics: production publication, restart-safe replay,
/// stale-writer rejection and frozen historical replay.
final class Elv5F2PublicationSnapshot {
  const Elv5F2PublicationSnapshot({
    required this.generation,
    required this.evaluationId,
    required this.freshness,
    required this.execution,
    required this.completion,
    required this.inputFingerprint,
    required this.logicalResultJson,
  });

  final int generation;
  final String evaluationId;
  final String freshness;
  final String execution;
  final String completion;
  final String inputFingerprint;
  final String logicalResultJson;
}

/// A process fixture supplies only process-specific setup/mutation commands.
/// All lifecycle assertions are centralized here so the 27-process matrix
/// cannot silently drift into different definitions of Q6/Q7/Q8.
abstract interface class Elv5F2QualificationScenario {
  String get processCode;

  /// Seeds authoritative persisted facts and returns the first production
  /// publication. This must traverse the real process registry/runtime.
  Future<Elv5F2PublicationSnapshot> publishInitial();

  /// Optional Q6 invalidation/recalculation phase. Return null only when the
  /// process has no mutable authoritative dependency in this fixture.
  Future<Elv5F2PublicationSnapshot?> invalidateAndRepublish();

  /// Reopens durable persistence and replays the latest committed command.
  Future<Elv5F2PublicationSnapshot> restartAndReplay();

  /// Must fail with ELV5_POINTER_GENERATION_CONFLICT.
  Future<void> attemptStaleWriter();

  /// Freezes the design revision and replays the already committed command.
  Future<Elv5F2PublicationSnapshot> freezeAndReplayCommitted();

  /// Must fail closed for a new calculation after freeze.
  Future<void> attemptNewCalculationAfterFreeze();

  /// Optional authoritative mutation attempted after freeze. A scenario with
  /// a public mutation path must implement this and reject it fail-closed.
  Future<void> attemptMutationAfterFreeze() async {}
}

final class Elv5F2QualificationHarness {
  const Elv5F2QualificationHarness();

  Future<void> qualify(Elv5F2QualificationScenario scenario) async {
    final initial = await scenario.publishInitial();
    assertQ6Initial(scenario.processCode, initial);

    final republished = await scenario.invalidateAndRepublish();
    final committed = republished ?? initial;
    if (republished != null) {
      assertQ6Republished(scenario.processCode, initial, republished);
    }

    final restarted = await scenario.restartAndReplay();
    assertQ7Replay(scenario.processCode, committed, restarted);

    await expectQ7StaleWriter(
      scenario.processCode,
      scenario.attemptStaleWriter,
    );

    final frozenReplay = await scenario.freezeAndReplayCommitted();
    assertQ8Replay(scenario.processCode, committed, frozenReplay);

    await expectQ8ReadOnly(
      scenario.processCode,
      scenario.attemptNewCalculationAfterFreeze,
      operation: 'new calculation',
    );
  }

  /// Shared Q6 assertion used both by scenario-driven qualification and by
  /// mature production E2E tests that retain richer process-specific checks.
  void assertQ6Initial(String processCode, Elv5F2PublicationSnapshot snapshot) {
    _assertCurrentPublication(snapshot, minimumGeneration: 1);
    expect(
      snapshot.evaluationId,
      isNotEmpty,
      reason: '$processCode Q6 must persist an evaluation identity',
    );
  }

  /// Shared Q6 invalidation/republication contract.
  void assertQ6Republished(
    String processCode,
    Elv5F2PublicationSnapshot initial,
    Elv5F2PublicationSnapshot republished,
  ) {
    _assertCurrentPublication(
      republished,
      minimumGeneration: initial.generation + 1,
    );
    expect(
      republished.evaluationId,
      isNot(initial.evaluationId),
      reason: '$processCode Q6 must publish a new evaluation',
    );
    expect(
      republished.inputFingerprint,
      isNot(initial.inputFingerprint),
      reason: '$processCode Q6 mutation must change captured input',
    );
  }

  /// Shared Q7 durable restart/replay contract.
  void assertQ7Replay(
    String processCode,
    Elv5F2PublicationSnapshot committed,
    Elv5F2PublicationSnapshot restarted,
  ) {
    _assertSameCommittedResult(processCode, committed, restarted, gate: 'Q7');
  }

  /// Shared Q7 stale-writer CAS contract.
  Future<void> expectQ7StaleWriter(
    String processCode,
    Future<void> Function() action,
  ) => _expectFailureCode(
    action,
    'ELV5_POINTER_GENERATION_CONFLICT',
    '$processCode Q7 stale writer',
  );

  /// Shared Q8 frozen historical replay contract.
  void assertQ8Replay(
    String processCode,
    Elv5F2PublicationSnapshot committed,
    Elv5F2PublicationSnapshot frozenReplay,
  ) {
    _assertSameCommittedResult(
      processCode,
      committed,
      frozenReplay,
      gate: 'Q8',
    );
  }

  /// Shared Q8 fail-closed read-only contract for new work after freeze.
  Future<void> expectQ8ReadOnly(
    String processCode,
    Future<void> Function() action, {
    String operation = 'operation',
  }) => _expectFailureCode(
    action,
    'ELV5_DESIGN_REVISION_READ_ONLY',
    '$processCode Q8 $operation after freeze',
  );

  void _assertCurrentPublication(
    Elv5F2PublicationSnapshot snapshot, {
    required int minimumGeneration,
  }) {
    expect(snapshot.freshness, 'CURRENT');
    expect(snapshot.generation, greaterThanOrEqualTo(minimumGeneration));
    expect(snapshot.evaluationId, isNotEmpty);
    expect(snapshot.execution, anyOf('SUCCEEDED', 'BLOCKED'));
    expect(snapshot.completion, anyOf('COMPLETE', 'INCOMPLETE'));
    expect(snapshot.inputFingerprint, hasLength(64));
    expect(snapshot.logicalResultJson, isNotEmpty);
  }

  void _assertSameCommittedResult(
    String processCode,
    Elv5F2PublicationSnapshot expected,
    Elv5F2PublicationSnapshot actual, {
    required String gate,
  }) {
    expect(actual.freshness, 'CURRENT');
    expect(
      actual.generation,
      expected.generation,
      reason: '$processCode $gate replay must not republish CURRENT',
    );
    expect(
      actual.evaluationId,
      expected.evaluationId,
      reason: '$processCode $gate replay must preserve evaluation identity',
    );
    expect(
      actual.logicalResultJson,
      expected.logicalResultJson,
      reason: '$processCode $gate replay must be byte-logically identical',
    );
  }

  Future<void> _expectFailureCode(
    Future<void> Function() action,
    String code,
    String reason,
  ) async {
    Object? failure;
    try {
      await action();
    } catch (error) {
      failure = error;
    }
    expect(failure, isNotNull, reason: '$reason must fail closed');
    expect(
      failure.toString(),
      contains(code),
      reason: '$reason must expose $code',
    );
  }
}
