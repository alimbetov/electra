import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/elv5/wire/elv5_wire_command.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command_codec.dart';
import 'package:electra_mobile/application/elv5/wire/elv5_wire_command_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = Elv5WireCommandCodec();

  Map<String, Object?> envelope(
    String operation,
    Map<String, Object?> payload,
  ) => <String, Object?>{
    'schema': 'electra.elv5-discipline-command.v1',
    'operation': operation,
    'payloadSchemaVersion': 1,
    'projectId': 'project-fixture-01',
    'designRevisionId': 'revision-r1',
    'commandId': 'command-$operation',
    'expectedDesignRowRevision': 1,
    'expectedRows': <String, Object?>{},
    'reviewedImpactFingerprint':
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    'payload': payload,
  };

  test('registry is a closed 16-operation public surface', () {
    expect(Elv5WireCommandRegistry.payloadKeys, hasLength(16));
    expect(Elv5WireCommandEnvelope.topLevelKeys, hasLength(10));
  });

  test('all 16 authoritative canonical examples pass the runtime codec', () {
    final file = File(
      '../../docs/product/elv5-implementation/command-examples.json',
    );
    expect(file.existsSync(), isTrue);
    final root =
        (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
    final rows =
        (root['examples'] as List<Object?>).cast<Map<String, Object?>>();
    expect(rows, hasLength(16));
    for (final row in rows) {
      final operation = row['operation']! as String;
      final payload = (row['validPayload']! as Map).cast<String, Object?>();
      final decoded = codec.decodeMap(envelope(operation, payload));
      expect(decoded.operation, operation);
      expect(decoded.normalizedRequestSha256, hasLength(64));
      expect(codec.decodeJson(codec.encode(decoded)).toMap(), decoded.toMap());
    }
  });

  test('unknown nested field fails closed', () {
    final payload = <String, Object?>{
      'bindingId': 'binding-1',
      'subject': <String, Object?>{
        'kind': 'CAMERA',
        'id': 'camera-1',
        'label': 'not-authoritative',
      },
      'processCodes': <Object?>['CCTV-01'],
      'definitionRef': <String, Object?>{
        'policyCode': 'CCTV-DESIGN',
        'editionId': 'v1',
        'contentHash':
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      },
      'applicability': <String, Object?>{
        'scopeKinds': <Object?>['DESIGN'],
        'scenarioIds': <Object?>[],
      },
    };
    expect(
      () => codec.decodeMap(envelope('BIND_DISCIPLINE_POLICY', payload)),
      throwsFormatException,
    );
  });

  test('storage reserve below one is rejected', () {
    final examples = _examples();
    final payload = Map<String, Object?>.from(
      examples['REPLACE_RECORDING_ASSIGNMENTS']!,
    )..['reserveMultiplier'] = '0.99';
    expect(
      () => codec.decodeMap(envelope('REPLACE_RECORDING_ASSIGNMENTS', payload)),
      throwsA(anyOf(isA<FormatException>(), isA<ArgumentError>())),
    );
  });

  test('multicast group cannot change tree for the same stream', () {
    final examples = _examples();
    final payload = _deepCopy(examples['REPLACE_CAMERA_STREAMS']!);
    final subscriptions =
        (payload['subscriptions']! as List).cast<Map<String, Object?>>();
    final multicast = subscriptions.last;
    subscriptions.add(<String, Object?>{
      ...multicast,
      'subscriptionId': 'sub-wall-main-2',
      'receiverId': 'video-wall-02',
      'multicastTree': <String, Object?>{
        'treeId': 'tree-main-v2',
        'edgeIds': <Object?>['edge-access-01', 'edge-core-01'],
      },
      'orderedNetworkEdgeIds': <Object?>['edge-access-01', 'edge-core-01'],
    });
    expect(
      () => codec.decodeMap(envelope('REPLACE_CAMERA_STREAMS', payload)),
      throwsFormatException,
    );
  });

  test('recording assignment requires an existing schedule profile', () {
    final examples = _examples();
    final payload = _deepCopy(examples['REPLACE_RECORDING_ASSIGNMENTS']!);
    final assignments =
        (payload['assignments']! as List).cast<Map<String, Object?>>();
    assignments.first['scheduleProfileId'] = 'missing-profile';
    expect(
      () => codec.decodeMap(envelope('REPLACE_RECORDING_ASSIGNMENTS', payload)),
      throwsFormatException,
    );
  });
}

Map<String, Map<String, Object?>> _examples() {
  final file = File(
    '../../docs/product/elv5-implementation/command-examples.json',
  );
  final root =
      (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
  return <String, Map<String, Object?>>{
    for (final row
        in (root['examples']! as List<Object?>).cast<Map<String, Object?>>())
      row['operation']! as String:
          (row['validPayload']! as Map).cast<String, Object?>(),
  };
}

Map<String, Object?> _deepCopy(Map<String, Object?> value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, Object?>();
