import 'engineering_hash.dart';
import 'power_definition_ref.dart';
import 'power_numeric.dart';

enum PowerScenarioRole {
  normal,
  standby,
  alarm,
  startup,
  backup,
  restoreRecharge,
  custom,
}

enum PowerDeviceState {
  off,
  standby,
  normal,
  alarm,
  startup,
  charging,
  discharging,
}

final class PowerPolicyRef {
  PowerPolicyRef({required this.definitionRef, required String purpose})
      : purpose = _code(purpose, 'purpose') {
    if (definitionRef.definitionKind != PowerDefinitionKind.policy) {
      throw ArgumentError(
          'Power policy reference requires a policy definition.');
    }
  }

  final PowerDefinitionRef definitionRef;
  final String purpose;

  Map<String, Object?> toMap() => {
        'definitionRef': definitionRef.toMap(),
        'purpose': purpose,
      };

  factory PowerPolicyRef.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {'definitionRef', 'purpose'});
    return PowerPolicyRef(
      definitionRef: PowerDefinitionRef.fromMap(
        (map['definitionRef'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      purpose: map['purpose'] as String,
    );
  }
}

/// One immutable operating interval. Scenario role labels do not imply state or
/// source changes: all relevant state and source selections are explicit here.
final class PowerScenarioSegment {
  PowerScenarioSegment({
    required String segmentId,
    required this.ordinal,
    this.durationSeconds,
    Map<String, PowerDeviceState> componentStates = const {},
    Map<String, String> selectedSourceBySupplySet = const {},
    Iterable<String> unavailableSourceIds = const [],
    Iterable<String> chargingBankIds = const [],
    Iterable<String> dischargingBankIds = const [],
  })  : segmentId = _code(segmentId, 'segmentId'),
        componentStates = Map.unmodifiable(_sortedStateMap(componentStates)),
        selectedSourceBySupplySet =
            Map.unmodifiable(_sortedTextMap(selectedSourceBySupplySet)),
        unavailableSourceIds = List.unmodifiable(_sortedUniqueTexts(
          unavailableSourceIds,
          field: 'unavailableSourceIds',
        )),
        chargingBankIds = List.unmodifiable(_sortedUniqueTexts(
          chargingBankIds,
          field: 'chargingBankIds',
        )),
        dischargingBankIds = List.unmodifiable(_sortedUniqueTexts(
          dischargingBankIds,
          field: 'dischargingBankIds',
        )) {
    if (ordinal < 1) {
      throw ArgumentError.value(ordinal, 'ordinal', 'Must be 1-based.');
    }
    if (durationSeconds != null && durationSeconds! <= PowerRational.zero) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'Must be positive when present.',
      );
    }
    final unavailable = this.unavailableSourceIds.toSet();
    for (final sourceId in this.selectedSourceBySupplySet.values) {
      if (unavailable.contains(sourceId)) {
        throw ArgumentError(
          'A selected source cannot be unavailable in the same segment.',
        );
      }
    }
    final charging = this.chargingBankIds.toSet();
    final discharging = this.dischargingBankIds.toSet();
    if (charging.intersection(discharging).isNotEmpty) {
      throw ArgumentError(
        'A battery bank cannot charge and discharge in the same segment.',
      );
    }
    for (final entry in this.componentStates.entries) {
      if (entry.value == PowerDeviceState.charging &&
          this.dischargingBankIds.contains(entry.key)) {
        throw ArgumentError('Component state conflicts with bank discharge.');
      }
      if (entry.value == PowerDeviceState.discharging &&
          this.chargingBankIds.contains(entry.key)) {
        throw ArgumentError('Component state conflicts with bank charge.');
      }
    }
  }

  final String segmentId;
  final int ordinal;
  final PowerRational? durationSeconds;
  final Map<String, PowerDeviceState> componentStates;
  final Map<String, String> selectedSourceBySupplySet;
  final List<String> unavailableSourceIds;
  final List<String> chargingBankIds;
  final List<String> dischargingBankIds;

  PowerDeviceState? stateOf(String componentId) =>
      componentStates[componentId.trim()];

  String? sourceFor(String supplySetId) =>
      selectedSourceBySupplySet[supplySetId.trim().toUpperCase()];

  bool sourceAvailable(String sourceId) =>
      !unavailableSourceIds.contains(sourceId.trim());

  Map<String, Object?> toMap() => {
        'segmentId': segmentId,
        'ordinal': ordinal,
        'durationSeconds': durationSeconds?.toWireDecimal(),
        'componentStates': {
          for (final entry in componentStates.entries)
            entry.key: entry.value.name.toUpperCase(),
        },
        'selectedSourceBySupplySet': selectedSourceBySupplySet,
        'unavailableSourceIds': unavailableSourceIds,
        'chargingBankIds': chargingBankIds,
        'dischargingBankIds': dischargingBankIds,
      };

  factory PowerScenarioSegment.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {
      'segmentId',
      'ordinal',
      'durationSeconds',
      'componentStates',
      'selectedSourceBySupplySet',
      'unavailableSourceIds',
      'chargingBankIds',
      'dischargingBankIds',
    });
    final rawStates = (map['componentStates'] as Map<Object?, Object?>)
        .cast<String, String>();
    return PowerScenarioSegment(
      segmentId: map['segmentId'] as String,
      ordinal: map['ordinal'] as int,
      durationSeconds: map['durationSeconds'] == null
          ? null
          : PowerRational.fromWireDecimal(map['durationSeconds']),
      componentStates: {
        for (final entry in rawStates.entries)
          entry.key: PowerDeviceState.values.singleWhere(
            (value) => value.name.toUpperCase() == entry.value,
          ),
      },
      selectedSourceBySupplySet:
          (map['selectedSourceBySupplySet'] as Map<Object?, Object?>)
              .cast<String, String>(),
      unavailableSourceIds:
          (map['unavailableSourceIds'] as List<Object?>).cast<String>(),
      chargingBankIds: (map['chargingBankIds'] as List<Object?>).cast<String>(),
      dischargingBankIds:
          (map['dischargingBankIds'] as List<Object?>).cast<String>(),
    );
  }
}

final class PowerOperatingScenario {
  PowerOperatingScenario({
    required String scenarioId,
    required this.role,
    required this.rowRevision,
    required Iterable<PowerScenarioSegment> segments,
    Iterable<PowerPolicyRef> policyRefs = const [],
  })  : scenarioId = _code(scenarioId, 'scenarioId'),
        segments = List.unmodifiable(segments),
        policyRefs = List.unmodifiable(_sortedPolicies(policyRefs)) {
    if (rowRevision < 1) {
      throw ArgumentError.value(
          rowRevision, 'rowRevision', 'Must be positive.');
    }
    if (this.segments.isEmpty) {
      throw ArgumentError('Power scenario requires at least one segment.');
    }
    if (this.segments.map((segment) => segment.segmentId).toSet().length !=
        this.segments.length) {
      throw ArgumentError('Scenario segment identities must be unique.');
    }
    final ordinals = this.segments.map((segment) => segment.ordinal).toList();
    final expected =
        List<int>.generate(this.segments.length, (index) => index + 1);
    if (!_sameInts(ordinals, expected)) {
      throw ArgumentError('Scenario ordinals must be gap-free and ordered.');
    }
    final policyPurposes =
        this.policyRefs.map((policy) => policy.purpose).toList();
    if (policyPurposes.toSet().length != policyPurposes.length) {
      throw ArgumentError('Scenario policy purposes must be unique.');
    }
  }

  final String scenarioId;
  final PowerScenarioRole role;
  final int rowRevision;
  final List<PowerScenarioSegment> segments;
  final List<PowerPolicyRef> policyRefs;

  Map<String, Object?> toMap() => {
        'scenarioId': scenarioId,
        'role': role.name.toUpperCase(),
        'rowRevision': rowRevision,
        'segments':
            segments.map((segment) => segment.toMap()).toList(growable: false),
        'policyRefs':
            policyRefs.map((policy) => policy.toMap()).toList(growable: false),
      };

  String get fingerprintSha256 => sha256HexUtf8(
        canonicalEngineeringJsonV1({
          'schema': 'electra.power-operating-scenario.v1',
          'scenario': toMap(),
        }),
      );

  factory PowerOperatingScenario.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {
      'scenarioId',
      'role',
      'rowRevision',
      'segments',
      'policyRefs',
    });
    return PowerOperatingScenario(
      scenarioId: map['scenarioId'] as String,
      role: PowerScenarioRole.values.singleWhere(
        (value) => value.name.toUpperCase() == map['role'],
      ),
      rowRevision: map['rowRevision'] as int,
      segments: (map['segments'] as List<Object?>).map(
        (value) => PowerScenarioSegment.fromMap(
          (value as Map<Object?, Object?>).cast<String, Object?>(),
        ),
      ),
      policyRefs: (map['policyRefs'] as List<Object?>).map(
        (value) => PowerPolicyRef.fromMap(
          (value as Map<Object?, Object?>).cast<String, Object?>(),
        ),
      ),
    );
  }
}

Map<String, PowerDeviceState> _sortedStateMap(
  Map<String, PowerDeviceState> input,
) {
  final entries = input.entries
      .map(
        (entry) => MapEntry(
          _text(entry.key, 'componentId'),
          entry.value,
        ),
      )
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (entries.map((entry) => entry.key).toSet().length != entries.length) {
    throw ArgumentError('Component state identities must be unique.');
  }
  return Map.fromEntries(entries);
}

Map<String, String> _sortedTextMap(Map<String, String> input) {
  final entries = input.entries
      .map(
        (entry) => MapEntry(
          _code(entry.key, 'supplySetId'),
          _text(entry.value, 'sourceId'),
        ),
      )
      .toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  if (entries.map((entry) => entry.key).toSet().length != entries.length) {
    throw ArgumentError('Supply-set selections must be unique.');
  }
  return Map.fromEntries(entries);
}

List<String> _sortedUniqueTexts(
  Iterable<String> input, {
  required String field,
}) {
  final result = input.map((value) => _text(value, field)).toList()..sort();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  return result;
}

List<PowerPolicyRef> _sortedPolicies(Iterable<PowerPolicyRef> input) {
  final result = input.toList()..sort((a, b) => a.purpose.compareTo(b.purpose));
  return result;
}

bool _sameInts(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) return false;
  }
  return true;
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _code(String value, String field) {
  final normalized = _text(value, field).toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Invalid canonical code.');
  }
  return normalized;
}

void _exactKeys(Map<String, Object?> map, Set<String> expected) {
  if (map.length != expected.length || !expected.every(map.containsKey)) {
    throw FormatException('Expected exactly: ${expected.join(', ')}.');
  }
}
