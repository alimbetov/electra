import 'package:engineering_core/engineering_core.dart';

abstract interface class ElvPhysicalCalculationSource {
  Future<CanonicalCableRun> loadRun(String projectId, String runId);
  Future<List<CableRunTraversalGeometry>> loadTraversalGeometry(
    String projectId,
    String runId,
  );
  Future<String> installedLengthInputFingerprint(
    String projectId,
    String runId,
  );
}

abstract interface class ElvPhysicalCalculationResultStore {
  Future<void> put<T>(
    String projectId,
    String nodeKey,
    ElvPhysicalCalculationResult<T> result,
  );

  Future<ElvPhysicalCalculationResult<Object?>?> find(
    String projectId,
    String nodeKey,
  );

  Future<void> invalidate(String projectId, Iterable<String> nodeKeys);
}

final class ElvPhysicalCalculationService {
  const ElvPhysicalCalculationService({
    required this.source,
    required this.results,
  });

  final ElvPhysicalCalculationSource source;
  final ElvPhysicalCalculationResultStore results;

  Future<ElvPhysicalCalculationResult<double>> recomputeInstalledLength({
    required String projectId,
    required String cableRunId,
  }) async {
    final run = await source.loadRun(projectId, cableRunId);
    final geometry = await source.loadTraversalGeometry(projectId, cableRunId);
    final fingerprint = await source.installedLengthInputFingerprint(
      projectId,
      cableRunId,
    );
    final result = calculateInstalledLength(
      run: run,
      traversals: geometry,
      inputFingerprint: fingerprint,
    );
    final nodeKey =
        'elv3:${run.designRevisionId}:${ElvPhysicalProcessCodes.installedLength}:cable-run:${run.id}';
    await results.put(projectId, nodeKey, result);
    return result;
  }
}
