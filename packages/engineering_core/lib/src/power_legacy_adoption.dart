enum LegacyPowerField {
  nominalVoltage,
  powerDirection,
  demand,
  limit,
}

enum LegacyAdoptionDisposition {
  preserved,
  resolved,
  unresolved,
  conflict,
}

final class PowerEvidenceValue {
  PowerEvidenceValue({
    required String value,
    required String provenance,
  })  : value = _text(value, 'value'),
        provenance = _text(provenance, 'provenance');

  final String value;
  final String provenance;

  Map<String, Object?> toMap() => {
        'value': value,
        'provenance': provenance,
      };
}

final class LegacyPowerFieldPreview {
  const LegacyPowerFieldPreview({
    required this.field,
    required this.disposition,
    this.legacy,
    this.typed,
  });

  final LegacyPowerField field;
  final LegacyAdoptionDisposition disposition;
  final PowerEvidenceValue? legacy;
  final PowerEvidenceValue? typed;

  Map<String, Object?> toMap() => {
        'field': field.name.toUpperCase(),
        'disposition': disposition.name.toUpperCase(),
        'legacy': legacy?.toMap(),
        'typed': typed?.toMap(),
      };
}

/// Reviewed migration preview. This intentionally performs no physical-unit
/// synthesis: callers must provide exact comparable evidence. In particular, a
/// legacy nominal voltage never invents min/max tolerance and legacy power
/// labels never invent PF, PoE class, peak duration or battery behavior.
final class PowerLegacyAdoptionPreview {
  PowerLegacyAdoptionPreview({
    required String subjectId,
    required Iterable<LegacyPowerFieldPreview> fields,
  })  : subjectId = _text(subjectId, 'subjectId'),
        fields = List.unmodifiable(_normalizeFields(fields));

  final String subjectId;
  final List<LegacyPowerFieldPreview> fields;

  bool get canCommit => fields.every(
        (field) => field.disposition != LegacyAdoptionDisposition.conflict,
      );

  bool get hasUnresolved => fields.any(
        (field) => field.disposition == LegacyAdoptionDisposition.unresolved,
      );

  Map<String, Object?> toMap() => {
        'subjectId': subjectId,
        'fields': fields.map((field) => field.toMap()).toList(growable: false),
      };

  static PowerLegacyAdoptionPreview compare({
    required String subjectId,
    Map<LegacyPowerField, PowerEvidenceValue> legacy = const {},
    Map<LegacyPowerField, PowerEvidenceValue> typed = const {},
  }) {
    final fields = <LegacyPowerFieldPreview>[];
    for (final field in LegacyPowerField.values) {
      final oldValue = legacy[field];
      final newValue = typed[field];
      if (oldValue == null && newValue == null) continue;

      late final LegacyAdoptionDisposition disposition;
      if (oldValue == null) {
        disposition = LegacyAdoptionDisposition.resolved;
      } else if (newValue == null) {
        disposition = LegacyAdoptionDisposition.unresolved;
      } else if (oldValue.value == newValue.value) {
        disposition = LegacyAdoptionDisposition.preserved;
      } else {
        disposition = LegacyAdoptionDisposition.conflict;
      }

      fields.add(
        LegacyPowerFieldPreview(
          field: field,
          disposition: disposition,
          legacy: oldValue,
          typed: newValue,
        ),
      );
    }
    return PowerLegacyAdoptionPreview(subjectId: subjectId, fields: fields);
  }

  static List<LegacyPowerFieldPreview> _normalizeFields(
    Iterable<LegacyPowerFieldPreview> input,
  ) {
    final result = input.toList()
      ..sort((a, b) => a.field.name.compareTo(b.field.name));
    if (result.map((field) => field.field).toSet().length != result.length) {
      throw ArgumentError('Legacy adoption fields must be unique.');
    }
    return result;
  }
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
