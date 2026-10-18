import 'package:engineering_core/engineering_core_elv5.dart';

import 'elv5_blocked_capture.dart';
import 'elv5_calculation_runtime.dart';

abstract interface class Elv5CaptureRevisionSource {
  Future<int> requireWorkingRevision({
    required String projectId,
    required String designRevisionId,
  });
}

/// Converts a domain resolver capture into a publication-safe capture token.
///
/// A capture is accepted only when the global design revision is identical
/// before and after all domain reads. This prevents a mixed snapshot from being
/// stamped with a newer revision and later passing publication CAS. One retry is
/// allowed for a concurrent mutation; continued churn fails the command rather
/// than publishing evidence assembled across two design states.
final class Elv5RevisionGuardedInputResolver<I>
    implements Elv5ProcessInputResolver<I> {
  Elv5RevisionGuardedInputResolver({
    required this.inner,
    required this.revisions,
  });

  final Elv5ProcessInputResolver<I> inner;
  final Elv5CaptureRevisionSource revisions;

  @override
  Elv5ProcessCode get processCode => inner.processCode;

  @override
  Future<Elv5CapturedInput<I>> capture(Elv5CalculationRequest request) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final before = await revisions.requireWorkingRevision(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
      );

      Elv5CapturedInput<I>? captured;
      Elv5CaptureBlockedException? blocked;
      try {
        captured = await inner.capture(request);
      } on Elv5CaptureBlockedException catch (value) {
        blocked = value;
      }

      final after = await revisions.requireWorkingRevision(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
      );
      if (before != after) {
        if (attempt == 0) continue;
        throw StateError('ELV5_CAPTURE_CHANGED_DURING_READ:$before:$after');
      }

      if (blocked != null) {
        throw blocked.withCaptureRevision(after);
      }
      final stable = captured!;
      return Elv5CapturedInput<I>(
        request: stable.request,
        value: stable.value,
        inputFingerprint: stable.inputFingerprint,
        policyFingerprint: stable.policyFingerprint,
        dependencies: stable.dependencies,
        upstreamPointerGenerations: stable.upstreamPointerGenerations,
        captureRevision: after,
      );
    }

    throw StateError('ELV5_CAPTURE_STABILITY_RETRY_EXHAUSTED');
  }
}
