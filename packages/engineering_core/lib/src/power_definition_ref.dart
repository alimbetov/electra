/// Exact edition provenance for the ELV4 extension of a root catalog.
enum PowerDefinitionKind {
  port,
  component,
  transfer,
  poe,
  battery,
  policy,
  interface,
  protocol,
  compatibility,
}

final class PowerDefinitionRef {
  factory PowerDefinitionRef({
    required String catalogId,
    required String catalogVersion,
    required PowerDefinitionKind definitionKind,
    required String definitionCode,
    required String definitionVersion,
    required String definitionSchema,
    required String contentSha256,
    required String sourceRef,
  }) {
    final code = definitionCode.trim().toUpperCase();
    final hash = contentSha256.trim().toLowerCase();
    final rootVersion = _text(catalogVersion);
    final version = _text(definitionVersion);
    if (rootVersion != version) {
      throw ArgumentError(
          'Power v1 definitions must use their exact root edition.');
    }
    if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,63}$').hasMatch(code) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw ArgumentError('Invalid power definition code or content SHA-256.');
    }
    return PowerDefinitionRef._(
      _text(catalogId),
      rootVersion,
      definitionKind,
      code,
      version,
      _text(definitionSchema),
      hash,
      _text(sourceRef),
    );
  }

  const PowerDefinitionRef._(
      this.catalogId,
      this.catalogVersion,
      this.definitionKind,
      this.definitionCode,
      this.definitionVersion,
      this.definitionSchema,
      this.contentSha256,
      this.sourceRef);

  factory PowerDefinitionRef.fromMap(Map<String, Object?> map) {
    const keys = {
      'catalogId',
      'catalogVersion',
      'definitionKind',
      'definitionCode',
      'definitionVersion',
      'definitionSchema',
      'contentSha256',
      'sourceRef'
    };
    if (map.length != keys.length ||
        !keys.every(map.containsKey) ||
        map.values.any((value) => value is! String)) {
      throw const FormatException('Invalid power definition reference shape.');
    }
    final kind = PowerDefinitionKind.values
        .where((k) => k.name.toUpperCase() == map['definitionKind']);
    if (kind.isEmpty)
      throw const FormatException('Unknown power definition kind.');
    // Wire technical codes/hashes are strict; constructor normalization is for
    // explicitly authored domain input, not acceptance of a different schema.
    final code = map['definitionCode'] as String;
    final hash = map['contentSha256'] as String;
    if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,63}$').hasMatch(code) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid reference wire code or hash.');
    }
    return PowerDefinitionRef(
      catalogId: map['catalogId'] as String,
      catalogVersion: map['catalogVersion'] as String,
      definitionKind: kind.single,
      definitionCode: code,
      definitionVersion: map['definitionVersion'] as String,
      definitionSchema: map['definitionSchema'] as String,
      contentSha256: hash,
      sourceRef: map['sourceRef'] as String,
    );
  }

  final String catalogId;
  final String catalogVersion;
  final PowerDefinitionKind definitionKind;
  final String definitionCode;
  final String definitionVersion;
  final String definitionSchema;
  final String contentSha256;
  final String sourceRef;

  Map<String, Object?> toMap() => {
        'catalogId': catalogId,
        'catalogVersion': catalogVersion,
        'definitionKind': definitionKind.name.toUpperCase(),
        'definitionCode': definitionCode,
        'definitionVersion': definitionVersion,
        'definitionSchema': definitionSchema,
        'contentSha256': contentSha256,
        'sourceRef': sourceRef,
      };

  static String _text(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.length > 512) {
      throw ArgumentError('Reference fields require 1–512 characters.');
    }
    return normalized;
  }
}
