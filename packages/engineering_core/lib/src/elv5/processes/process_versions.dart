import 'process_code.dart';

final class Elv5ProcessVersions {
  const Elv5ProcessVersions({
    required this.processVersion,
    required this.algorithmVersion,
    required this.inputSchemaVersion,
    required this.outputSchemaVersion,
    required this.numericBackendVersion,
    required this.traceVersion,
  });

  factory Elv5ProcessVersions.v1(Elv5ProcessCode code) {
    final normalized = code.wireCode.toLowerCase();
    return Elv5ProcessVersions(
      processVersion: 'electra.elv5.$normalized.process.v1',
      algorithmVersion: 'electra.elv5.$normalized.algorithm.v1',
      inputSchemaVersion: '1',
      outputSchemaVersion: '1',
      numericBackendVersion: 'electra.elv5.exact-bounded-rational.v1',
      traceVersion: 'electra.elv5.$normalized.trace.v1',
    );
  }

  /// Public process-contract edition. This is intentionally distinct from the
  /// implementation algorithm version so a ruleset/contract edition can be
  /// pinned independently from an internal algorithm revision.
  final String processVersion;
  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String numericBackendVersion;
  final String traceVersion;
}
