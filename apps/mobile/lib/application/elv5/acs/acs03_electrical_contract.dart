import 'package:engineering_core/engineering_core_elv5.dart';

final class Acs03ElectricalEventContract {
  Acs03ElectricalEventContract({
    required String eventId,
    required this.state,
    required this.durationMicroseconds,
    required String scenarioId,
    required String segmentId,
    required String domainId,
    required String lockLoadOriginId,
    required String sharedTrunkSectionId,
    required this.lockCurrent,
  }) : eventId = _text(eventId, 'eventId'),
       scenarioId = _text(scenarioId, 'scenarioId'),
       segmentId = _text(segmentId, 'segmentId'),
       domainId = _text(domainId, 'domainId'),
       lockLoadOriginId = _text(lockLoadOriginId, 'lockLoadOriginId'),
       sharedTrunkSectionId = _text(
         sharedTrunkSectionId,
         'sharedTrunkSectionId',
       ) {
    if (durationMicroseconds <= BigInt.zero) {
      throw ArgumentError('ACS03 event duration must be positive.');
    }
    if (lockCurrent.value < Elv5Rational.zero) {
      throw ArgumentError('ACS03 lock current must be nonnegative.');
    }
  }

  final String eventId;
  final Acs03StateCode state;
  final BigInt durationMicroseconds;
  final String scenarioId;
  final String segmentId;
  final String domainId;
  final String lockLoadOriginId;
  final String sharedTrunkSectionId;
  final Current lockCurrent;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'eventId': eventId,
    'state': _stateWire(state),
    'durationMicroseconds': durationMicroseconds.toString(),
    'scenarioId': scenarioId,
    'segmentId': segmentId,
    'domainId': domainId,
    'lockLoadOriginId': lockLoadOriginId,
    'sharedTrunkSectionId': sharedTrunkSectionId,
    'lockCurrentA': lockCurrent.value.toMap(),
  };

  factory Acs03ElectricalEventContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'eventId',
      'state',
      'durationMicroseconds',
      'scenarioId',
      'segmentId',
      'domainId',
      'lockLoadOriginId',
      'sharedTrunkSectionId',
      'lockCurrentA',
    }, 'ACS03 event');
    final duration = map['durationMicroseconds'];
    if (duration is! String) {
      throw const FormatException('ACS03 durationMicroseconds must be text.');
    }
    return Acs03ElectricalEventContract(
      eventId: _mapText(map, 'eventId'),
      state: _stateFromWire(_mapText(map, 'state')),
      durationMicroseconds: BigInt.parse(duration),
      scenarioId: _mapText(map, 'scenarioId'),
      segmentId: _mapText(map, 'segmentId'),
      domainId: _mapText(map, 'domainId'),
      lockLoadOriginId: _mapText(map, 'lockLoadOriginId'),
      sharedTrunkSectionId: _mapText(map, 'sharedTrunkSectionId'),
      lockCurrent: Current(_rational(map['lockCurrentA'], 'lockCurrentA')),
    );
  }
}

final class Acs03ElectricalContract {
  Acs03ElectricalContract({
    required String doorId,
    required String lockId,
    required String conductiveFeedPathId,
    required String controlPathId,
    required Iterable<Acs03ElectricalEventContract> events,
    this.minimumTerminalVoltage,
    this.maximumTerminalVoltage,
  }) : doorId = _text(doorId, 'doorId'),
       lockId = _text(lockId, 'lockId'),
       conductiveFeedPathId = _text(
         conductiveFeedPathId,
         'conductiveFeedPathId',
       ),
       controlPathId = _text(controlPathId, 'controlPathId'),
       events = List.unmodifiable(_normalizeEvents(events)) {
    if (minimumTerminalVoltage != null &&
        maximumTerminalVoltage != null &&
        minimumTerminalVoltage! > maximumTerminalVoltage!) {
      throw ArgumentError('ACS03 voltage requirements are reversed.');
    }
    final states = this.events.map((value) => value.state).toSet();
    for (final requiredState in const <Acs03StateCode>{
      Acs03StateCode.holding,
      Acs03StateCode.activeRelease,
      Acs03StateCode.startupInrush,
    }) {
      if (!states.contains(requiredState)) {
        throw ArgumentError(
          'ACS03 missing mandatory state: ${requiredState.name}.',
        );
      }
    }
  }

  static const schema = 'electra.elv5-acs03-electrical-contract.v1';

  final String doorId;
  final String lockId;
  final String conductiveFeedPathId;
  final String controlPathId;
  final List<Acs03ElectricalEventContract> events;
  final Voltage? minimumTerminalVoltage;
  final Voltage? maximumTerminalVoltage;

  Map<String, Object?> toCanonicalValue() => <String, Object?>{
    'schema': schema,
    'doorId': doorId,
    'lockId': lockId,
    'conductiveFeedPathId': conductiveFeedPathId,
    'controlPathId': controlPathId,
    'minimumTerminalVoltageV': minimumTerminalVoltage?.value.toMap(),
    'maximumTerminalVoltageV': maximumTerminalVoltage?.value.toMap(),
    'events': [for (final event in events) event.toCanonicalValue()],
  };

  factory Acs03ElectricalContract.fromMap(Map<String, Object?> map) {
    _exact(map, const <String>{
      'schema',
      'doorId',
      'lockId',
      'conductiveFeedPathId',
      'controlPathId',
      'minimumTerminalVoltageV',
      'maximumTerminalVoltageV',
      'events',
    }, 'ACS03 electrical contract');
    if (map['schema'] != schema) {
      throw const FormatException(
        'Unsupported ACS03 electrical contract schema.',
      );
    }
    final rawEvents = map['events'];
    if (rawEvents is! List) {
      throw const FormatException('ACS03 events must be an array.');
    }
    return Acs03ElectricalContract(
      doorId: _mapText(map, 'doorId'),
      lockId: _mapText(map, 'lockId'),
      conductiveFeedPathId: _mapText(map, 'conductiveFeedPathId'),
      controlPathId: _mapText(map, 'controlPathId'),
      minimumTerminalVoltage: map['minimumTerminalVoltageV'] == null
          ? null
          : Voltage(
              _rational(
                map['minimumTerminalVoltageV'],
                'minimumTerminalVoltageV',
              ),
            ),
      maximumTerminalVoltage: map['maximumTerminalVoltageV'] == null
          ? null
          : Voltage(
              _rational(
                map['maximumTerminalVoltageV'],
                'maximumTerminalVoltageV',
              ),
            ),
      events: <Acs03ElectricalEventContract>[
        for (final raw in rawEvents)
          Acs03ElectricalEventContract.fromMap(_object(raw, 'ACS03 event')),
      ],
    );
  }
}

final class Acs03ElectricalContractSnapshot {
  const Acs03ElectricalContractSnapshot({
    required this.bindingId,
    required this.bindingRevision,
    required this.evidenceRef,
    required this.contentHash,
    required this.contract,
  });

  final String bindingId;
  final int bindingRevision;
  final String evidenceRef;
  final String contentHash;
  final Acs03ElectricalContract contract;
}

abstract interface class Acs03ElectricalContractSource {
  Future<Acs03ElectricalContractSnapshot?> loadActiveForDoor({
    required String projectId,
    required String designRevisionId,
    required String doorId,
  });
}

List<Acs03ElectricalEventContract> _normalizeEvents(
  Iterable<Acs03ElectricalEventContract> values,
) {
  final result = values.toList()
    ..sort((a, b) => a.eventId.compareTo(b.eventId));
  if (result.isEmpty) throw ArgumentError('ACS03 requires operating events.');
  final ids = <String>{};
  for (final event in result) {
    if (!ids.add(event.eventId)) {
      throw ArgumentError('ACS03 duplicate eventId: ${event.eventId}');
    }
  }
  return result;
}

String _stateWire(Acs03StateCode value) => switch (value) {
  Acs03StateCode.holding => 'HOLDING',
  Acs03StateCode.activeRelease => 'ACTIVE_RELEASE',
  Acs03StateCode.startupInrush => 'STARTUP_INRUSH',
  Acs03StateCode.fireRelease => 'FIRE_RELEASE',
  Acs03StateCode.powerFailure => 'POWER_FAILURE',
};

Acs03StateCode _stateFromWire(String value) => switch (value) {
  'HOLDING' => Acs03StateCode.holding,
  'ACTIVE_RELEASE' => Acs03StateCode.activeRelease,
  'STARTUP_INRUSH' => Acs03StateCode.startupInrush,
  'FIRE_RELEASE' => Acs03StateCode.fireRelease,
  'POWER_FAILURE' => Acs03StateCode.powerFailure,
  _ => throw FormatException('Unsupported ACS03 state: $value'),
};

Elv5Rational _rational(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be a rational map.');
  return Elv5Rational.fromMap(Map<String, Object?>.from(value));
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  return Map<String, Object?>.from(value);
}

String _mapText(Map<String, Object?> map, String field) {
  final value = map[field];
  if (value is! String) throw FormatException('$field must be text.');
  return _text(value, field);
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

void _exact(Map<String, Object?> value, Set<String> expected, String field) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
