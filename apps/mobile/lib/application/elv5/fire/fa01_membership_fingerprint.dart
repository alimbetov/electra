import 'package:engineering_core/engineering_core_elv5.dart';

String fa01MembershipFingerprint({
  required String loopId,
  required Map<String, Object?> addressDomain,
  required List<Map<String, Object?>> deviceAssignments,
}) {
  const encoder = Elv5CanonicalJsonV1();
  final panelId = _text(addressDomain['panelId'], 'panelId');
  final domainLoopId = _text(addressDomain['loopId'], 'domain.loopId');
  if (domainLoopId != loopId) {
    throw StateError('FA01_MEMBERSHIP_DOMAIN_LOOP_MISMATCH:$domainLoopId:$loopId');
  }
  final reserved = _ints(addressDomain['reservedAddresses'], 'reservedAddresses')
    ..sort();
  final devices = <Map<String, Object?>>[];
  for (final assignment in deviceAssignments) {
    final addresses = _ints(assignment['expandedAddresses'], 'expandedAddresses')
      ..sort();
    devices.add(<String, Object?>{
      'deviceId': _text(assignment['deviceId'], 'deviceId'),
      'profileRef': _text(assignment['profileRef'], 'profileRef'),
      'expandedAddresses': addresses,
    });
  }
  devices.sort((a, b) =>
      (a['deviceId']! as String).compareTo(b['deviceId']! as String));
  return encoder.sha256(<String, Object?>{
    'schema': 'electra.elv5-fa01-address-membership.v1',
    'loopId': loopId,
    'domain': <String, Object?>{
      'panelId': panelId,
      'loopId': domainLoopId,
      'minAddress': addressDomain['minAddress'],
      'maxAddress': addressDomain['maxAddress'],
      'reservedAddresses': reserved,
    },
    'devices': devices,
  });
}

String _text(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be non-empty text.');
  }
  return value.trim();
}

List<int> _ints(Object? value, String field) {
  if (value is! List || value.any((item) => item is! int)) {
    throw FormatException('$field must be an integer array.');
  }
  return value.cast<int>().toList();
}
