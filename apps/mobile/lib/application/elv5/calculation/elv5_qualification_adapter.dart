import 'package:engineering_core/engineering_core_elv5.dart';

import 'elv5_calculation_runtime.dart';
import 'elv5_qualification_identity_source.dart';

/// Adds qualification identity after the pure executor has produced the normal
/// runtime candidate. Capture and engineering semantics remain unchanged.
final class Elv5QualificationBoundCalculationAdapter
    implements Elv5ProcessCalculationAdapter {
  Elv5QualificationBoundCalculationAdapter({
    required this.inner,
    required this.identitySource,
  });

  final Elv5ProcessCalculationAdapter inner;
  final Elv5QualificationIdentitySource identitySource;

  @override
  Elv5ProcessCode get processCode => inner.processCode;

  @override
  Elv5WorkloadClass get workloadClass => inner.workloadClass;

  @override
  Future<Elv5CapturedProcess> capture(Elv5CalculationRequest request) =>
      inner.capture(request);

  @override
  Future<Elv5ProcessEvaluationCandidate> execute(
    Elv5CapturedProcess input,
  ) async {
    final candidate = await inner.execute(input);
    final identity = identitySource.forProcess(processCode);
    return identity == null
        ? candidate
        : candidate.withQualificationIdentity(identity);
  }
}
