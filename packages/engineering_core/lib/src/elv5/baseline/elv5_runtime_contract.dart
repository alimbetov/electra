import '../numeric/rational.dart';

/// Frozen P0 implementation-entry facts inherited from the accepted ELV4 baseline.
abstract final class Elv5RuntimeContract {
  static const acceptedElv4MergedSha =
      'd2b059d4c11a284cdd32965140f6df3c40020c8d';
  static const acceptedElv4DesignSha =
      '31581aa6c396d5ebd6cdf1985c53719d9d05e12a';
  static const inheritedDatabaseSchema = 23;
  static const databaseSchema = 24;
  static const processCount = 27;
  static const commandCount = 16;
  static const wireSchema = 'electra.elv5-discipline-command.v1';
  static const wirePayloadSchemaVersion = 1;
  static const canonicalEncoderVersion = 'electra.canonical-json.v1';
  static const numericBackendVersion = 'electra.elv5.exact-bounded-rational.v1';
  static const engineeringNodeSchema = 'engineering-node-v3';
  static const engineeringNodeOwner = 'ELV5';

  static void validateDatabaseEntry({
    required int inheritedSchema,
    required int targetSchema,
  }) {
    if (inheritedSchema != inheritedDatabaseSchema ||
        targetSchema != databaseSchema) {
      throw StateError(
        'ELV5 database entry must be schema '
        '$inheritedDatabaseSchema -> $databaseSchema.',
      );
    }
  }

  static Elv5Rational validateReserveMultiplier(Elv5Rational value) {
    if (value < Elv5Rational.one) {
      throw ArgumentError.value(
        value,
        'reserveMultiplier',
        'Reserve multiplier must be >= 1.',
      );
    }
    return value;
  }
}
