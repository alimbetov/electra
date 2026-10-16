import 'process_code.dart';

final class Elv5ProcessVersions {
  const Elv5ProcessVersions({
    required this.algorithmVersion,
    required this.inputSchemaVersion,
    required this.outputSchemaVersion,
    required this.numericBackendVersion,
    required this.traceVersion,
  });

  factory Elv5ProcessVersions.v1(Elv5ProcessCode code) {
    final normalized = code.wireCode.toLowerCase();
    return Elv5ProcessVersions(
      algorithmVersion: 'electra.elv5.$normalized.algorithm.v1',
      inputSchemaVersion: '1',
      outputSchemaVersion: '1',
      numericBackendVersion: 'electra.elv5.exact-bounded-rational.v1',
      traceVersion: 'electra.elv5.$normalized.trace.v1',
    );
  }

  final String algorithmVersion;
  final String inputSchemaVersion;
  final String outputSchemaVersion;
  final String numericBackendVersion;
  final String traceVersion;
}
