import 'engineering_hash.dart';

final class DesignRevisionPhysicalSnapshot {
  DesignRevisionPhysicalSnapshot({
    required this.designRevisionId,
    required this.projectId,
    required this.schemaVersion,
    required Map<String, Object?> payload,
  }) : payload = Map.unmodifiable(payload);

  final String designRevisionId;
  final String projectId;
  final int schemaVersion;
  final Map<String, Object?> payload;

  String get contentSha256 => sha256HexUtf8(
        canonicalEngineeringJsonV1({
          'schema': 'electra.elv3-physical-snapshot.v$schemaVersion',
          'designRevisionId': designRevisionId,
          'projectId': projectId,
          'payload': payload,
        }),
      );

  List<String> validate() => [
        if (designRevisionId.trim().isEmpty)
          'Snapshot designRevisionId is required.',
        if (projectId.trim().isEmpty) 'Snapshot projectId is required.',
        if (schemaVersion < 1) 'Snapshot schemaVersion must be >= 1.',
      ];
}
