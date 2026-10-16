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
/// Domain resolvers may naturally expose their aggregate revision in evidence,
/// but `Elv5CalculationService` guards publication against the global design
/// revision row. This wrapper snapshots that row revision after all domain reads
/// and makes it the sole `captureRevision` consumed by the publication CAS.
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
    try {
      final captured = await inner.capture(request);
      final designRowRevision = await revisions.requireWorkingRevision(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
      );
      return Elv5CapturedInput<I>(
        request: captured.request,
        value: captured.value,
        inputFingerprint: captured.inputFingerprint,
        policyFingerprint: captured.policyFingerprint,
        dependencies: captured.dependencies,
        upstreamPointerGenerations: captured.upstreamPointerGenerations,
        captureRevision: designRowRevision,
      );
    } on Elv5CaptureBlockedException catch (blocked) {
      final designRowRevision = await revisions.requireWorkingRevision(
        projectId: request.projectId,
        designRevisionId: request.designRevisionId,
      );
      throw blocked.withCaptureRevision(designRowRevision);
    }
  }
}
