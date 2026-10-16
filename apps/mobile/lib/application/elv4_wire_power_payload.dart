import 'package:engineering_core/engineering_core.dart';

final class Elv4WireLoadEntry {
  Elv4WireLoadEntry({
    required String loadId,
    required String inputPortId,
    required String stateCode,
    required String accountingKind,
    required String originId,
    required this.demand,
  }) : loadId = _text(loadId, 'loadId'),
       inputPortId = _text(inputPortId, 'inputPortId'),
       stateCode = _code(stateCode, 'stateCode'),
       accountingKind = _accountingKind(accountingKind),
       originId = _text(originId, 'originId');

  factory Elv4WireLoadEntry.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {
      'loadId',
      'inputPortId',
      'stateCode',
      'accountingKind',
      'originId',
      'demand',
    });
    final demand = map['demand'];
    if (demand is! Map) {
      throw const FormatException('demand must be an object.');
    }
    return Elv4WireLoadEntry(
      loadId: _string(map['loadId'], 'loadId'),
      inputPortId: _string(map['inputPortId'], 'inputPortId'),
      stateCode: _string(map['stateCode'], 'stateCode'),
      accountingKind: _string(map['accountingKind'], 'accountingKind'),
      originId: _string(map['originId'], 'originId'),
      demand: PowerDemand.fromMap(demand.cast<String, Object?>()),
    );
  }

  final String loadId;
  final String inputPortId;
  final String stateCode;
  final String accountingKind;
  final String originId;
  final PowerDemand demand;

  Map<String, Object?> toMap() => {
    'loadId': loadId,
    'inputPortId': inputPortId,
    'stateCode': stateCode,
    'accountingKind': accountingKind,
    'originId': originId,
    'demand': demand.toMap(),
  };
}

final class Elv4WireTransferEntry {
  Elv4WireTransferEntry({
    required String id,
    required String componentId,
    required String inputPortId,
    required Iterable<String> outputPortIds,
    required String kind,
    required Iterable<String> activeStates,
    required this.loss,
    required Iterable<String> capacityGroupIds,
  }) : id = _text(id, 'id'),
       componentId = _text(componentId, 'componentId'),
       inputPortId = _text(inputPortId, 'inputPortId'),
       outputPortIds = List.unmodifiable(
         _uniqueTexts(outputPortIds, 'outputPortIds'),
       ),
       kind = _transferKind(kind),
       activeStates = List.unmodifiable(
         _uniqueCodes(activeStates, 'activeStates'),
       ),
       capacityGroupIds = List.unmodifiable(
         _uniqueTexts(capacityGroupIds, 'capacityGroupIds'),
       ) {
    if (this.outputPortIds.isEmpty) {
      throw ArgumentError('outputPortIds must not be empty.');
    }
    if (this.activeStates.isEmpty) {
      throw ArgumentError('activeStates must not be empty.');
    }
    if (this.outputPortIds.contains(this.inputPortId)) {
      throw ArgumentError('Transfer input and output ports must be distinct.');
    }
  }

  factory Elv4WireTransferEntry.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {
      'id',
      'componentId',
      'inputPortId',
      'outputPortIds',
      'kind',
      'activeStates',
      'loss',
      'capacityGroupIds',
    });
    final loss = map['loss'];
    if (loss is! Map) {
      throw const FormatException('loss must be an object.');
    }
    return Elv4WireTransferEntry(
      id: _string(map['id'], 'id'),
      componentId: _string(map['componentId'], 'componentId'),
      inputPortId: _string(map['inputPortId'], 'inputPortId'),
      outputPortIds: _stringList(map['outputPortIds'], 'outputPortIds'),
      kind: _string(map['kind'], 'kind'),
      activeStates: _stringList(map['activeStates'], 'activeStates'),
      loss: PowerLossDefinition.fromMap(loss.cast<String, Object?>()),
      capacityGroupIds: _stringList(
        map['capacityGroupIds'],
        'capacityGroupIds',
      ),
    );
  }

  final String id;
  final String componentId;
  final String inputPortId;
  final List<String> outputPortIds;
  final String kind;
  final List<String> activeStates;
  final PowerLossDefinition loss;
  final List<String> capacityGroupIds;

  Map<String, Object?> toMap() => {
    'id': id,
    'componentId': componentId,
    'inputPortId': inputPortId,
    'outputPortIds': outputPortIds,
    'kind': kind,
    'activeStates': activeStates,
    'loss': loss.toMap(),
    'capacityGroupIds': capacityGroupIds,
  };
}

String _accountingKind(String value) {
  final normalized = value.trim().toUpperCase();
  if (normalized != 'CONSUMER_INPUT' && normalized != 'TRANSFER_IDLE') {
    throw FormatException('Unsupported accountingKind: $value.');
  }
  return normalized;
}

String _transferKind(String value) {
  final normalized = value.trim().toUpperCase();
  const allowed = {
    'AC_DC',
    'DC_DC',
    'TRANSFORMER',
    'UPS',
    'CHARGER',
    'DISTRIBUTOR',
    'POE_PSE',
    'SELECTOR',
  };
  if (!allowed.contains(normalized)) {
    throw FormatException('Unsupported transfer kind: $value.');
  }
  return normalized;
}

void _exactKeys(Map<String, Object?> value, Set<String> expected) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      !actual.containsAll(expected) ||
      !expected.containsAll(actual)) {
    throw const FormatException('ELV4 wire payload fields do not match.');
  }
}

String _string(Object? value, String field) {
  if (value is! String) throw FormatException('$field must be a string.');
  return value;
}

List<String> _stringList(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field must be a string array.');
  }
  return value.cast<String>();
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 512) {
    throw ArgumentError.value(value, field, 'Must contain 1..512 characters.');
  }
  return normalized;
}

String _code(String value, String field) {
  final normalized = value.trim().toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,63}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Invalid ELV4 code.');
  }
  return normalized;
}

List<String> _uniqueTexts(Iterable<String> values, String field) {
  final result = values.map((value) => _text(value, field)).toList();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must contain unique values.');
  }
  return result;
}

List<String> _uniqueCodes(Iterable<String> values, String field) {
  final result = values.map((value) => _code(value, field)).toList();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must contain unique values.');
  }
  return result;
}
