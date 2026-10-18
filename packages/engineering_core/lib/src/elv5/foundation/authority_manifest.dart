import '../baseline/elv5_runtime_contract.dart';
import '../canonical/canonical_json_v1.dart';
import '../processes/process_code.dart';
import '../processes/process_registry.dart';

/// Code-owned authority manifest for ELV5 qualification.
///
/// The authority fingerprint is derived only from versioned process/runtime
/// contracts. Source identity is deliberately excluded and is supplied by the
/// build so the manifest can remain stable across rebuilds of the same ruleset.
final class Elv5FoundationAuthorityManifest implements Elv5CanonicalValue {
  const Elv5FoundationAuthorityManifest._();

  static const instance = Elv5FoundationAuthorityManifest._();
  static const schema = 'electra.elv5-foundation-authority-manifest.v1';
  static const rulesetVersion = 'electra.elv5.ruleset.v1';

  @override
  Map<String, Object?> toCanonicalValue() => <String, Object?>{
        'schema': schema,
        'rulesetVersion': rulesetVersion,
        'canonicalEncoderVersion': Elv5RuntimeContract.canonicalEncoderVersion,
        'processes': <Object?>[
          for (final code in Elv5ProcessCode.values)
            _processEntry(Elv5ProcessCatalog.require(code)),
        ],
      };

  String fingerprint({
    Elv5CanonicalEncoder encoder = const Elv5CanonicalJsonV1(),
  }) =>
      encoder.sha256(toCanonicalValue());

  Map<String, Object?> _processEntry(Elv5ProcessDescriptor descriptor) {
    final versions = descriptor.versions;
    return <String, Object?>{
      'processCode': descriptor.code.wireCode,
      'processVersion': versions.processVersion,
      'algorithmVersion': versions.algorithmVersion,
      'inputSchemaVersion': versions.inputSchemaVersion,
      'outputSchemaVersion': versions.outputSchemaVersion,
      'numericBackendVersion': versions.numericBackendVersion,
      'traceVersion': versions.traceVersion,
    };
  }
}
