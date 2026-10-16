import 'package:engineering_core/engineering_core_elv5.dart';

/// Code-owned v1 operation inventory and strict payload validation.
abstract final class Elv5WireCommandRegistry {
  static const payloadKeys = <String, Set<String>>{
    'BIND_DISCIPLINE_POLICY': {
      'bindingId', 'subject', 'processCodes', 'definitionRef', 'applicability'
    },
    'ADOPT_DISCIPLINE_POLICY': {
      'bindingId', 'newDefinitionRef', 'applicability'
    },
    'RELEASE_DISCIPLINE_POLICY': {'bindingId', 'releasePolicy'},
    'REPLACE_CAMERA_STREAMS': {
      'cameraId', 'streams', 'subscriptions', 'transportOverheadModelRef'
    },
    'REPLACE_RECORDING_ASSIGNMENTS': {
      'poolId', 'horizon', 'temporalPolicy', 'assignments', 'scheduleSegments',
      'sizingBasis', 'reserveMultiplier', 'redundancyModel', 'policyRef'
    },
    'REPLACE_RECORDER_ASSIGNMENTS': {
      'recorderId', 'accountingBasis', 'assignments'
    },
    'REPLACE_LINK_COMPOSITION': {
      'linkId', 'orderedSections', 'policyBindingId'
    },
    'REPLACE_PORT_CAPACITY_ASSIGNMENTS': {
      'switchId', 'assignments', 'sparePolicyRef'
    },
    'REPLACE_OPTICAL_LINK_ASSIGNMENTS': {
      'linkId', 'forwardOptics', 'reverseOptics', 'connectorEvents', 'spliceEvents'
    },
    'REPLACE_RACK_CAPACITY_BASIS': {
      'rackId', 'capacityBasis', 'equipmentIds', 'excludedCapacity', 'policyRef'
    },
    'REPLACE_PATCH_PANEL_ASSIGNMENTS': {
      'panelId', 'assignments', 'sparePolicyRef'
    },
    'REPLACE_DOOR_ROLE_ASSIGNMENTS': {
      'doorAssemblyId', 'topologyProfileRef', 'safetyMode', 'roleAssignments',
      'releaseTruthTable'
    },
    'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS': {
      'controllerId', 'resourceAssignments', 'reservePolicyRef'
    },
    'REPLACE_FIRE_LOOP_ASSIGNMENTS': {
      'loopId', 'deviceAssignments', 'addressDomain', 'topologyProfileRef'
    },
    'REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS': {
      'circuitId', 'deviceAssignments', 'outputRef', 'policyRef'
    },
    'CALCULATE_DISCIPLINE_PROCESS': {
      'scope', 'processCodes', 'subjects', 'expectedPointerGenerations'
    },
  };

  static void requireOperation(String operation) {
    if (!payloadKeys.containsKey(operation)) {
      throw FormatException('Unsupported ELV5 operation: $operation.');
    }
  }

  static void validatePayload(String operation, Map<String, Object?> payload) {
    final expected = payloadKeys[operation];
    if (expected == null) {
      throw FormatException('Unsupported ELV5 operation: $operation.');
    }
    _exact(payload, expected, '$operation payload');
    switch (operation) {
      case 'BIND_DISCIPLINE_POLICY':
        _text(payload['bindingId'], 'bindingId');
        _subject(payload['subject'], 'subject');
        _processCodes(payload['processCodes']);
        _definitionRef(payload['definitionRef'], 'definitionRef');
        _applicability(payload['applicability']);
      case 'ADOPT_DISCIPLINE_POLICY':
        _text(payload['bindingId'], 'bindingId');
        _definitionRef(payload['newDefinitionRef'], 'newDefinitionRef');
        _applicability(payload['applicability']);
      case 'RELEASE_DISCIPLINE_POLICY':
        _text(payload['bindingId'], 'bindingId');
        _text(payload['releasePolicy'], 'releasePolicy');
      case 'REPLACE_CAMERA_STREAMS':
        _cameraStreams(payload);
      case 'REPLACE_RECORDING_ASSIGNMENTS':
        _recordingAssignments(payload);
      case 'REPLACE_RECORDER_ASSIGNMENTS':
        _recorderAssignments(payload);
      case 'REPLACE_LINK_COMPOSITION':
        _linkComposition(payload);
      case 'REPLACE_PORT_CAPACITY_ASSIGNMENTS':
        _portCapacity(payload);
      case 'REPLACE_OPTICAL_LINK_ASSIGNMENTS':
        _opticalLink(payload);
      case 'REPLACE_RACK_CAPACITY_BASIS':
        _rackCapacity(payload);
      case 'REPLACE_PATCH_PANEL_ASSIGNMENTS':
        _patchPanel(payload);
      case 'REPLACE_DOOR_ROLE_ASSIGNMENTS':
        _doorRoles(payload);
      case 'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS':
        _controllerResources(payload);
      case 'REPLACE_FIRE_LOOP_ASSIGNMENTS':
        _fireLoop(payload);
      case 'REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS':
        _notificationCircuit(payload);
      case 'CALCULATE_DISCIPLINE_PROCESS':
        _calculate(payload);
    }
  }
}

void _cameraStreams(Map<String, Object?> payload) {
  _text(payload['cameraId'], 'cameraId');
  final streams = _objectList(payload['streams'], 'streams');
  final streamIds = <String>{};
  for (final stream in streams) {
    _exact(stream, const {
      'encodedStreamId', 'codecProfileRef', 'expectedBitrateBps',
      'peakBitrateBps', 'expectedRateEvidence', 'peakRateEvidence'
    }, 'stream');
    final id = _text(stream['encodedStreamId'], 'encodedStreamId');
    if (!streamIds.add(id)) {
      throw const FormatException('Duplicate encodedStreamId.');
    }
    _text(stream['codecProfileRef'], 'codecProfileRef');
    _decimal(stream['expectedBitrateBps'], 'expectedBitrateBps', nonnegative: true);
    _nullableDecimal(stream['peakBitrateBps'], 'peakBitrateBps', nonnegative: true);
    _rateEvidence(stream['expectedRateEvidence'], 'expectedRateEvidence');
    if (stream['peakRateEvidence'] != null) {
      _rateEvidence(stream['peakRateEvidence'], 'peakRateEvidence');
    }
  }

  final subscriptions = _objectList(payload['subscriptions'], 'subscriptions');
  final subscriptionIds = <String>{};
  final multicastHashes = <String, String>{};
  const encoder = Elv5CanonicalJsonV1();
  for (final subscription in subscriptions) {
    _exact(subscription, const {
      'subscriptionId', 'encodedStreamId', 'receiverId', 'deliveryMode',
      'orderedNetworkEdgeIds', 'multicastGroupId', 'multicastTree'
    }, 'subscription');
    final subscriptionId = _text(subscription['subscriptionId'], 'subscriptionId');
    if (!subscriptionIds.add(subscriptionId)) {
      throw const FormatException('Duplicate subscriptionId.');
    }
    final streamId = _text(subscription['encodedStreamId'], 'encodedStreamId');
    if (!streamIds.contains(streamId)) {
      throw const FormatException('Subscription references unknown stream.');
    }
    _text(subscription['receiverId'], 'receiverId');
    final mode = _text(subscription['deliveryMode'], 'deliveryMode');
    final path = _stringList(subscription['orderedNetworkEdgeIds'], 'orderedNetworkEdgeIds');
    if (path.isEmpty || path.toSet().length != path.length) {
      throw const FormatException('Network path must be non-empty with unique edges.');
    }
    if (mode == 'UNICAST') {
      if (subscription['multicastGroupId'] != null ||
          subscription['multicastTree'] != null) {
        throw const FormatException('UNICAST cannot carry multicast identity.');
      }
    } else if (mode == 'MULTICAST') {
      final group = _text(subscription['multicastGroupId'], 'multicastGroupId');
      final tree = _object(subscription['multicastTree'], 'multicastTree');
      _exact(tree, const {'treeId', 'edgeIds'}, 'multicastTree');
      _text(tree['treeId'], 'treeId');
      final treeEdges = _stringList(tree['edgeIds'], 'edgeIds');
      if (treeEdges.isEmpty || treeEdges.toSet().length != treeEdges.length) {
        throw const FormatException('Multicast tree edges must be non-empty/unique.');
      }
      if (path.any((edge) => !treeEdges.contains(edge))) {
        throw const FormatException('Subscription path must be contained in multicast tree.');
      }
      final key = '$streamId\u0000$group';
      final hash = encoder.sha256(tree);
      final previous = multicastHashes[key];
      if (previous != null && previous != hash) {
        throw const FormatException('Same stream/multicast group has different tree.');
      }
      multicastHashes[key] = hash;
    } else {
      throw const FormatException('deliveryMode must be UNICAST or MULTICAST.');
    }
  }

  final overhead = payload['transportOverheadModelRef'];
  if (overhead != null) _modelRef(overhead, 'transportOverheadModelRef');
}

void _rateEvidence(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {
    'kind', 'averagingWindowMs', 'rateBoundary', 'evidenceRef', 'applicabilityHash'
  }, field);
  final kind = _text(map['kind'], '$field.kind');
  const kinds = {
    'EXPECTED_ESTIMATE',
    'CONFIGURED_TARGET',
    'MEASURED_WINDOW',
    'GUARANTEED_WINDOW_UPPER_BOUND',
    'GUARANTEED_POINTWISE_UPPER_BOUND',
  };
  if (!kinds.contains(kind)) throw FormatException('Unsupported $field.kind.');
  final window = map['averagingWindowMs'];
  if (window != null && (window is! int || window <= 0)) {
    throw FormatException('$field.averagingWindowMs must be positive or null.');
  }
  if (kind == 'GUARANTEED_WINDOW_UPPER_BOUND' && window == null) {
    throw FormatException('$field window-bound evidence requires a window.');
  }
  if (kind == 'GUARANTEED_POINTWISE_UPPER_BOUND' && window != null) {
    throw FormatException('$field pointwise evidence must have null window.');
  }
  final boundary = _text(map['rateBoundary'], '$field.rateBoundary');
  if (boundary != 'PAYLOAD' && boundary != 'WIRE') {
    throw FormatException('$field.rateBoundary must be PAYLOAD or WIRE.');
  }
  _evidenceRef(map['evidenceRef'], '$field.evidenceRef');
  _sha(map['applicabilityHash'], '$field.applicabilityHash');
}

void _recordingAssignments(Map<String, Object?> payload) {
  _text(payload['poolId'], 'poolId');
  _utcWindow(payload['horizon'], 'horizon');
  final temporal = _object(payload['temporalPolicy'], 'temporalPolicy');
  _exact(temporal, const {'timeZoneId', 'tzdbVersion', 'gapRule', 'overlapRule'}, 'temporalPolicy');
  for (final key in temporal.keys) {
    _text(temporal[key], 'temporalPolicy.$key');
  }
  final basis = _text(payload['sizingBasis'], 'sizingBasis');
  if (basis != 'EXPECTED_ESTIMATE' && basis != 'GUARANTEED_UPPER_BOUND') {
    throw const FormatException('Unsupported storage sizingBasis.');
  }
  final reserve = _decimal(payload['reserveMultiplier'], 'reserveMultiplier', nonnegative: true);
  Elv5RuntimeContract.validateReserveMultiplier(reserve);

  final segments = _objectList(payload['scheduleSegments'], 'scheduleSegments');
  final scheduleProfiles = <String>{};
  final segmentIds = <String>{};
  for (final segment in segments) {
    _exact(segment, const {'scheduleProfileId', 'segmentId', 'absoluteWindow', 'recurrence'}, 'scheduleSegment');
    final profile = _text(segment['scheduleProfileId'], 'scheduleProfileId');
    final segmentId = _text(segment['segmentId'], 'segmentId');
    if (!segmentIds.add('$profile\u0000$segmentId')) {
      throw const FormatException('Duplicate recording schedule segment identity.');
    }
    scheduleProfiles.add(profile);
    final absolute = segment['absoluteWindow'];
    final recurrence = segment['recurrence'];
    if ((absolute == null) == (recurrence == null)) {
      throw const FormatException('Schedule segment requires exactly one time model.');
    }
    if (absolute != null) _utcWindow(absolute, 'absoluteWindow');
    if (recurrence != null) {
      final recur = _object(recurrence, 'recurrence');
      _exact(recur, const {'rule', 'timeZoneLocal'}, 'recurrence');
      _text(recur['rule'], 'recurrence.rule');
      if (recur['timeZoneLocal'] is! bool) {
        throw const FormatException('recurrence.timeZoneLocal must be boolean.');
      }
    }
  }

  final assignments = _objectList(payload['assignments'], 'assignments');
  final assignmentIds = <String>{};
  for (final assignment in assignments) {
    _exact(assignment, const {
      'encodedStreamId', 'copyRole', 'scheduleProfileId', 'expectedBitrateBps',
      'upperBoundBitrateBps', 'evidenceBasis'
    }, 'recordingAssignment');
    final stream = _text(assignment['encodedStreamId'], 'encodedStreamId');
    final role = _text(assignment['copyRole'], 'copyRole');
    final profile = _text(assignment['scheduleProfileId'], 'scheduleProfileId');
    if (!assignmentIds.add('$stream\u0000$role')) {
      throw const FormatException('Duplicate recording stream/copyRole identity.');
    }
    if (!scheduleProfiles.contains(profile)) {
      throw const FormatException('Recording assignment references missing schedule profile.');
    }
    _decimal(assignment['expectedBitrateBps'], 'expectedBitrateBps', nonnegative: true);
    _nullableDecimal(assignment['upperBoundBitrateBps'], 'upperBoundBitrateBps', nonnegative: true);
    _text(assignment['evidenceBasis'], 'evidenceBasis');
  }

  final redundancy = payload['redundancyModel'];
  if (redundancy != null) {
    final model = _object(redundancy, 'redundancyModel');
    _exact(model, const {'modelCode', 'usableFraction', 'contentHash'}, 'redundancyModel');
    _text(model['modelCode'], 'redundancyModel.modelCode');
    final usable = _decimal(model['usableFraction'], 'usableFraction', nonnegative: true);
    if (usable <= Elv5Rational.zero || usable > Elv5Rational.one) {
      throw const FormatException('usableFraction must be in (0,1].');
    }
    _sha(model['contentHash'], 'redundancyModel.contentHash');
  }
  final policy = payload['policyRef'];
  if (policy != null) _policyRef(policy, 'policyRef');
}

void _recorderAssignments(Map<String, Object?> payload) {
  _text(payload['recorderId'], 'recorderId');
  final accounting = _text(payload['accountingBasis'], 'accountingBasis');
  if (!const {'DEVICE', 'ENCODED_STREAM', 'LICENSE_CHANNEL'}.contains(accounting)) {
    throw const FormatException('Unsupported recorder accountingBasis.');
  }
  final ids = <String>{};
  for (final row in _objectList(payload['assignments'], 'assignments')) {
    _exact(row, const {'assignmentId', 'cameraId', 'encodedStreamId', 'licenseChannelId', 'storagePoolId'}, 'recorderAssignment');
    final id = _text(row['assignmentId'], 'assignmentId');
    if (!ids.add(id)) throw const FormatException('Duplicate recorder assignmentId.');
    _text(row['cameraId'], 'cameraId');
    _text(row['encodedStreamId'], 'encodedStreamId');
    _text(row['licenseChannelId'], 'licenseChannelId');
    _text(row['storagePoolId'], 'storagePoolId');
  }
}

void _linkComposition(Map<String, Object?> payload) {
  _text(payload['linkId'], 'linkId');
  _text(payload['policyBindingId'], 'policyBindingId');
  final ordinals = <int>{};
  final sections = <String>{};
  for (final row in _objectList(payload['orderedSections'], 'orderedSections')) {
    _exact(row, const {'ordinal', 'realizedSectionId', 'classification'}, 'linkSection');
    final ordinal = _nonnegativeInt(row['ordinal'], 'ordinal');
    final section = _text(row['realizedSectionId'], 'realizedSectionId');
    _text(row['classification'], 'classification');
    if (!ordinals.add(ordinal) || !sections.add(section)) {
      throw const FormatException('Duplicate link section ordinal/identity.');
    }
  }
}

void _portCapacity(Map<String, Object?> payload) {
  _text(payload['switchId'], 'switchId');
  _policyRef(payload['sparePolicyRef'], 'sparePolicyRef');
  final ports = <String>{};
  for (final row in _objectList(payload['assignments'], 'assignments')) {
    _exact(row, const {'portId', 'endpointId', 'media', 'speedBps'}, 'portAssignment');
    final port = _text(row['portId'], 'portId');
    if (!ports.add(port)) throw const FormatException('Duplicate port assignment.');
    _text(row['endpointId'], 'endpointId');
    _text(row['media'], 'media');
    final speed = _decimal(row['speedBps'], 'speedBps', nonnegative: true);
    if (speed <= Elv5Rational.zero) throw const FormatException('speedBps must be positive.');
  }
}

void _opticalLink(Map<String, Object?> payload) {
  _text(payload['linkId'], 'linkId');
  _optics(payload['forwardOptics'], 'forwardOptics');
  _optics(payload['reverseOptics'], 'reverseOptics');
  final ids = <String>{};
  for (final field in const ['connectorEvents', 'spliceEvents']) {
    for (final row in _objectList(payload[field], field)) {
      _exact(row, const {'eventId', 'lossMinDb', 'lossMaxDb'}, 'opticalLossEvent');
      final id = _text(row['eventId'], 'eventId');
      if (!ids.add(id)) throw const FormatException('Duplicate optical loss eventId.');
      final min = _decimal(row['lossMinDb'], 'lossMinDb', nonnegative: true);
      final max = _decimal(row['lossMaxDb'], 'lossMaxDb', nonnegative: true);
      if (min > max) throw const FormatException('Optical loss interval is reversed.');
    }
  }
}

void _optics(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {
    'txPortId', 'rxPortId', 'wavelengthNm', 'txMinDbm', 'txMaxDbm',
    'receiverSensitivityDbm', 'receiverOverloadDbm', 'requiredSensitivityMarginDb'
  }, field);
  _text(map['txPortId'], '$field.txPortId');
  _text(map['rxPortId'], '$field.rxPortId');
  _decimal(map['wavelengthNm'], '$field.wavelengthNm', nonnegative: true);
  _decimal(map['txMinDbm'], '$field.txMinDbm');
  _decimal(map['txMaxDbm'], '$field.txMaxDbm');
  _decimal(map['receiverSensitivityDbm'], '$field.receiverSensitivityDbm');
  _decimal(map['receiverOverloadDbm'], '$field.receiverOverloadDbm');
  _decimal(map['requiredSensitivityMarginDb'], '$field.requiredSensitivityMarginDb', nonnegative: true);
}

void _rackCapacity(Map<String, Object?> payload) {
  _text(payload['rackId'], 'rackId');
  final basis = _text(payload['capacityBasis'], 'capacityBasis');
  if (!const {'GROSS_WITH_EXCLUSIONS', 'NET_USABLE'}.contains(basis)) {
    throw const FormatException('Unsupported rack capacityBasis.');
  }
  final equipment = _stringList(payload['equipmentIds'], 'equipmentIds');
  if (equipment.toSet().length != equipment.length) {
    throw const FormatException('Duplicate equipmentIds.');
  }
  final excluded = _object(payload['excludedCapacity'], 'excludedCapacity');
  _exact(excluded, const {'reservedRu', 'unavailableRu', 'provenance'}, 'excludedCapacity');
  _decimal(excluded['reservedRu'], 'reservedRu', nonnegative: true);
  _decimal(excluded['unavailableRu'], 'unavailableRu', nonnegative: true);
  _text(excluded['provenance'], 'provenance');
  _policyRef(payload['policyRef'], 'policyRef');
}

void _patchPanel(Map<String, Object?> payload) {
  _text(payload['panelId'], 'panelId');
  _policyRef(payload['sparePolicyRef'], 'sparePolicyRef');
  final ports = <String>{};
  for (final row in _objectList(payload['assignments'], 'assignments')) {
    _exact(row, const {'panelPortId', 'terminationId', 'linkId'}, 'patchAssignment');
    final port = _text(row['panelPortId'], 'panelPortId');
    if (!ports.add(port)) throw const FormatException('Duplicate patch panel port.');
    _text(row['terminationId'], 'terminationId');
    _text(row['linkId'], 'linkId');
  }
}

void _doorRoles(Map<String, Object?> payload) {
  _text(payload['doorAssemblyId'], 'doorAssemblyId');
  _topologyRef(payload['topologyProfileRef'], 'topologyProfileRef');
  final safety = _text(payload['safetyMode'], 'safetyMode');
  if (!const {'FAIL_SAFE', 'FAIL_SECURE', 'PROJECT_DEFINED'}.contains(safety)) {
    throw const FormatException('Unsupported safetyMode.');
  }
  final roleSlots = <String>{};
  for (final row in _objectList(payload['roleAssignments'], 'roleAssignments')) {
    _exact(row, const {'roleCode', 'slot', 'componentId'}, 'doorRoleAssignment');
    final role = _text(row['roleCode'], 'roleCode');
    final slot = _nonnegativeInt(row['slot'], 'slot');
    _text(row['componentId'], 'componentId');
    if (!roleSlots.add('$role\u0000$slot')) {
      throw const FormatException('Duplicate door role/slot.');
    }
  }
  final causes = <String>{};
  for (final row in _objectList(payload['releaseTruthTable'], 'releaseTruthTable')) {
    _exact(row, const {'causeCode', 'expectedOutcomeCode', 'requiredEvidenceRoles'}, 'releaseTruthRow');
    final cause = _text(row['causeCode'], 'causeCode');
    if (!causes.add(cause)) throw const FormatException('Duplicate release cause.');
    _text(row['expectedOutcomeCode'], 'expectedOutcomeCode');
    _stringList(row['requiredEvidenceRoles'], 'requiredEvidenceRoles');
  }
  const requiredCauses = {
    'NORMAL_ACCESS', 'REQUEST_TO_EXIT', 'FIRE_RELEASE',
    'EMERGENCY_BREAK_GLASS', 'POWER_FAILURE'
  };
  if (!causes.containsAll(requiredCauses)) {
    throw const FormatException('Door release truth table misses required cause.');
  }
}

void _controllerResources(Map<String, Object?> payload) {
  _text(payload['controllerId'], 'controllerId');
  _policyRef(payload['reservePolicyRef'], 'reservePolicyRef');
  final resources = <String>{};
  for (final row in _objectList(payload['resourceAssignments'], 'resourceAssignments')) {
    _exact(row, const {'resourceId', 'resourceKind', 'assignmentRole', 'subjectId'}, 'controllerResourceAssignment');
    final resource = _text(row['resourceId'], 'resourceId');
    if (!resources.add(resource)) throw const FormatException('Duplicate controller resource assignment.');
    _text(row['resourceKind'], 'resourceKind');
    _text(row['assignmentRole'], 'assignmentRole');
    _text(row['subjectId'], 'subjectId');
  }
}

void _fireLoop(Map<String, Object?> payload) {
  _text(payload['loopId'], 'loopId');
  _topologyRef(payload['topologyProfileRef'], 'topologyProfileRef');
  final domain = _object(payload['addressDomain'], 'addressDomain');
  _exact(domain, const {'panelId', 'loopId', 'minAddress', 'maxAddress', 'reservedAddresses'}, 'addressDomain');
  _text(domain['panelId'], 'addressDomain.panelId');
  _text(domain['loopId'], 'addressDomain.loopId');
  final min = _nonnegativeInt(domain['minAddress'], 'minAddress');
  final max = _nonnegativeInt(domain['maxAddress'], 'maxAddress');
  if (min > max) throw const FormatException('Address domain is reversed.');
  final reserved = _integerList(domain['reservedAddresses'], 'reservedAddresses');
  if (reserved.toSet().length != reserved.length ||
      reserved.any((value) => value < min || value > max)) {
    throw const FormatException('Invalid reserved address set.');
  }
  final claimed = <int>{};
  final devices = <String>{};
  for (final row in _objectList(payload['deviceAssignments'], 'deviceAssignments')) {
    _exact(row, const {'deviceId', 'profileRef', 'expandedAddresses'}, 'fireDeviceAssignment');
    final device = _text(row['deviceId'], 'deviceId');
    if (!devices.add(device)) throw const FormatException('Duplicate fire device assignment.');
    _text(row['profileRef'], 'profileRef');
    final addresses = _integerList(row['expandedAddresses'], 'expandedAddresses');
    if (addresses.isEmpty || addresses.toSet().length != addresses.length) {
      throw const FormatException('Expanded fire addresses must be non-empty/unique.');
    }
    for (final address in addresses) {
      if (address < min || address > max || reserved.contains(address)) {
        throw const FormatException('Fire address is outside allowed domain.');
      }
      if (!claimed.add(address)) {
        throw const FormatException('Fire address collision in replacement set.');
      }
    }
  }
}

void _notificationCircuit(Map<String, Object?> payload) {
  _text(payload['circuitId'], 'circuitId');
  _outputRef(payload['outputRef'], 'outputRef');
  _policyRef(payload['policyRef'], 'policyRef');
  final devices = <String>{};
  for (final row in _objectList(payload['deviceAssignments'], 'deviceAssignments')) {
    _exact(row, const {'deviceId', 'stateCurrentMa'}, 'notificationDeviceAssignment');
    final device = _text(row['deviceId'], 'deviceId');
    if (!devices.add(device)) throw const FormatException('Duplicate notification device.');
    final currents = _object(row['stateCurrentMa'], 'stateCurrentMa');
    if (currents.isEmpty) throw const FormatException('stateCurrentMa cannot be empty.');
    for (final entry in currents.entries) {
      _text(entry.key, 'state code');
      _decimal(entry.value, 'state current', nonnegative: true);
    }
  }
}

void _calculate(Map<String, Object?> payload) {
  final scope = _object(payload['scope'], 'scope');
  _exact(scope, const {'kind', 'scopeId', 'scenarioKey'}, 'scope');
  final kind = _text(scope['kind'], 'scope.kind');
  _text(scope['scopeId'], 'scope.scopeId');
  final scenario = _text(scope['scenarioKey'], 'scope.scenarioKey');
  if (kind == 'DESIGN' && scenario != 'NONE') {
    throw const FormatException('DESIGN scope requires scenarioKey NONE.');
  }
  _processCodes(payload['processCodes']);
  for (final subject in _objectList(payload['subjects'], 'subjects')) {
    _subject(subject, 'subject');
  }
  final generations = _object(payload['expectedPointerGenerations'], 'expectedPointerGenerations');
  for (final entry in generations.entries) {
    _text(entry.key, 'pointer key');
    _nonnegativeInt(entry.value, 'pointer generation');
  }
}

void _processCodes(Object? value) {
  final values = _stringList(value, 'processCodes');
  if (values.isEmpty || values.toSet().length != values.length) {
    throw const FormatException('processCodes must be non-empty and unique.');
  }
  for (final code in values) {
    Elv5ProcessCode.parse(code);
  }
}

void _subject(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {'kind', 'id'}, field);
  _text(map['kind'], '$field.kind');
  _text(map['id'], '$field.id');
}

void _definitionRef(Object? value, String field) => _policyLikeRef(value, field);
void _policyRef(Object? value, String field) => _policyLikeRef(value, field);

void _policyLikeRef(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {'policyCode', 'editionId', 'contentHash'}, field);
  _text(map['policyCode'], '$field.policyCode');
  _text(map['editionId'], '$field.editionId');
  _sha(map['contentHash'], '$field.contentHash');
}

void _topologyRef(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {'profileCode', 'editionId', 'contentHash'}, field);
  _text(map['profileCode'], '$field.profileCode');
  _text(map['editionId'], '$field.editionId');
  _sha(map['contentHash'], '$field.contentHash');
}

void _modelRef(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {'modelCode', 'editionId', 'contentHash'}, field);
  _text(map['modelCode'], '$field.modelCode');
  _text(map['editionId'], '$field.editionId');
  _sha(map['contentHash'], '$field.contentHash');
}

void _evidenceRef(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {'sourceKind', 'sourceId', 'contentHash'}, field);
  _text(map['sourceKind'], '$field.sourceKind');
  _text(map['sourceId'], '$field.sourceId');
  _sha(map['contentHash'], '$field.contentHash');
}

void _applicability(Object? value) {
  final map = _object(value, 'applicability');
  _exact(map, const {'scopeKinds', 'scenarioIds'}, 'applicability');
  _stringList(map['scopeKinds'], 'scopeKinds');
  _stringList(map['scenarioIds'], 'scenarioIds');
}

void _utcWindow(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {'startUtc', 'endUtc'}, field);
  final start = _utc(map['startUtc'], '$field.startUtc');
  final end = _utc(map['endUtc'], '$field.endUtc');
  if (!start.isBefore(end)) throw FormatException('$field start must precede end.');
}

void _outputRef(Object? value, String field) {
  final map = _object(value, field);
  _exact(map, const {'componentId', 'portId'}, field);
  _text(map['componentId'], '$field.componentId');
  _text(map['portId'], '$field.portId');
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is! Map) throw FormatException('$field must be an object.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw FormatException('$field keys must be strings.');
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Map<String, Object?>> _objectList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an array.');
  return <Map<String, Object?>>[
    for (var i = 0; i < value.length; i++) _object(value[i], '$field[$i]'),
  ];
}

List<String> _stringList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be a string array.');
  return <String>[
    for (var i = 0; i < value.length; i++) _text(value[i], '$field[$i]'),
  ];
}

List<int> _integerList(Object? value, String field) {
  if (value is! List) throw FormatException('$field must be an integer array.');
  return <int>[
    for (var i = 0; i < value.length; i++) _nonnegativeInt(value[i], '$field[$i]'),
  ];
}

String _text(Object? value, String field) {
  if (value is! String || value.isEmpty || value.length > 512) {
    throw FormatException('$field must contain 1..512 characters.');
  }
  return value;
}

int _nonnegativeInt(Object? value, String field) {
  if (value is! int || value < 0) throw FormatException('$field must be a non-negative integer.');
  return value;
}

Elv5Rational _decimal(Object? value, String field, {bool nonnegative = false}) {
  if (value is! String) throw FormatException('$field must be a decimal string.');
  final parsed = Elv5Rational.parseDecimal(value);
  if (nonnegative && parsed < Elv5Rational.zero) {
    throw FormatException('$field must be non-negative.');
  }
  return parsed;
}

void _nullableDecimal(Object? value, String field, {bool nonnegative = false}) {
  if (value != null) _decimal(value, field, nonnegative: nonnegative);
}

void _sha(Object? value, String field) {
  final text = _text(value, field);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw FormatException('$field must be lowercase SHA-256.');
  }
}

DateTime _utc(Object? value, String field) {
  final text = _text(value, field);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !text.endsWith('Z') || !parsed.isUtc) {
    throw FormatException('$field must be an explicit UTC timestamp.');
  }
  return parsed;
}

void _exact(Map<String, Object?> value, Set<String> expected, String field) {
  final actual = value.keys.toSet();
  if (actual.length != expected.length ||
      actual.difference(expected).isNotEmpty ||
      expected.difference(actual).isNotEmpty) {
    throw FormatException('$field has missing or unknown fields.');
  }
}
