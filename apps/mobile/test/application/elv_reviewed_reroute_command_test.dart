import 'package:electra_mobile/application/elv_reviewed_reroute_command.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review fingerprint ignores execution command id and input order', () {
    final forward = ReviewedRerouteCableRunWorkspaceCommand(
      commandId: 'cmd-a',
      projectId: 'project',
      designRevisionId: 'rev-1',
      cableRunId: 'run-1',
      expectedRevision: 7,
      traversals: _traversals.reversed,
    );
    final retryEnvelope = ReviewedRerouteCableRunWorkspaceCommand(
      commandId: 'cmd-b',
      projectId: 'project',
      designRevisionId: 'rev-1',
      cableRunId: 'run-1',
      expectedRevision: 7,
      traversals: _traversals,
    );

    expect(forward.reviewedFingerprint, retryEnvelope.reviewedFingerprint);
    expect(forward.traversals.map((item) => item.sequence), [1, 2]);
    expect(forward.reviewedPayload.containsKey('commandId'), isFalse);
  });

  test('review fingerprint binds row precondition and engineering payload', () {
    final baseline = ReviewedRerouteCableRunWorkspaceCommand(
      commandId: 'cmd-a',
      projectId: 'project',
      designRevisionId: 'rev-1',
      cableRunId: 'run-1',
      expectedRevision: 7,
      traversals: _traversals,
    );
    final staleRevision = ReviewedRerouteCableRunWorkspaceCommand(
      commandId: 'cmd-a',
      projectId: 'project',
      designRevisionId: 'rev-1',
      cableRunId: 'run-1',
      expectedRevision: 8,
      traversals: _traversals,
    );
    final changedRoute = ReviewedRerouteCableRunWorkspaceCommand(
      commandId: 'cmd-a',
      projectId: 'project',
      designRevisionId: 'rev-1',
      cableRunId: 'run-1',
      expectedRevision: 7,
      traversals: [
        _traversals.first,
        CableRunTraversal(
          id: 'tr-2',
          cableRunId: 'run-1',
          sequence: 2,
          routeSegmentId: 'seg-c',
          direction: CableTraversalDirection.forward,
        ),
      ],
    );

    expect(staleRevision.reviewedFingerprint, isNot(baseline.reviewedFingerprint));
    expect(changedRoute.reviewedFingerprint, isNot(baseline.reviewedFingerprint));
  });
}

const _traversals = [
  CableRunTraversal(
    id: 'tr-1',
    cableRunId: 'run-1',
    sequence: 1,
    routeSegmentId: 'seg-a',
    direction: CableTraversalDirection.forward,
  ),
  CableRunTraversal(
    id: 'tr-2',
    cableRunId: 'run-1',
    sequence: 2,
    routeSegmentId: 'seg-b',
    direction: CableTraversalDirection.reverse,
  ),
];
