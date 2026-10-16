import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/elv4_wire_command_dispatcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> command({
    String schema = Elv4WireCommandEnvelope.powerCommandSchema,
    String operation = 'SET_POWER_LOAD_PROFILE',
    int version = 1,
  }) => {
    'schema': schema,
    'operation': operation,
    'payloadSchemaVersion': version,
    'projectId': 'project-1',
    'designRevisionId': 'revision-1',
    'commandId': 'command-1',
    'expectedDesignRowRevision': 7,
    'expectedRows': <String, Object?>{'LOAD-1': 3},
    'reviewedImpactFingerprint': null,
    'payload': <String, Object?>{
      'componentId': 'component-1',
      'loads': <Object?>[],
    },
  };

  test('runtime registry exactly matches authoritative command schema', () {
    final file = File(
      '../../docs/product/elv4-implementation/schemas/power-command.schema.json',
    );
    expect(file.existsSync(), isTrue);
    final root =
        (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
    final oneOf = (root['oneOf'] as List<Object?>)
        .cast<Map<String, Object?>>();
    final schemaKeys = <String>{};
    for (final branch in oneOf) {
      final properties = (branch['properties'] as Map).cast<String, Object?>();
      String constant(String field) =>
          ((properties[field] as Map).cast<String, Object?>()['const']) as String;
      final version =
          ((properties['payloadSchemaVersion'] as Map)
              .cast<String, Object?>()['const']) as int;
      schemaKeys.add(
        '${constant('schema')}|${constant('operation')}|$version',
      );
    }

    final runtimeKeys = <String>{
      for (final operation in Elv4WireCommandEnvelope.powerV1Operations)
        '${Elv4WireCommandEnvelope.powerCommandSchema}|$operation|1',
      for (final operation in Elv4WireCommandEnvelope.revisionV2Operations)
        '${Elv4WireCommandEnvelope.revisionCommandSchema}|$operation|2',
    };
    expect(runtimeKeys, schemaKeys);
  });

  test('registered v1 envelope round-trips without version inference', () {
    final decoded = Elv4WireCommandEnvelope.fromMap(command());

    expect(decoded.schema, Elv4WireCommandEnvelope.powerCommandSchema);
    expect(decoded.operation, 'SET_POWER_LOAD_PROFILE');
    expect(decoded.payloadSchemaVersion, 1);
    expect(decoded.expectedRows, {'LOAD-1': 3});

    final replay = Elv4WireCommandEnvelope.fromJson(decoded.toJson());
    expect(replay.toMap(), decoded.toMap());
  });

  test('revision v2 dispatch is isolated from power command v1', () async {
    final powerKey = const Elv4WireCommandKey(
      schema: Elv4WireCommandEnvelope.powerCommandSchema,
      operation: 'SET_POWER_LOAD_PROFILE',
      payloadSchemaVersion: 1,
    );
    final revisionKey = const Elv4WireCommandKey(
      schema: Elv4WireCommandEnvelope.revisionCommandSchema,
      operation: 'FREEZE_DESIGN_REVISION',
      payloadSchemaVersion: 2,
    );
    final dispatcher = Elv4WireCommandDispatcher<String>({
      powerKey: (envelope) async => 'power:${envelope.commandId}',
      revisionKey: (envelope) async => 'revision:${envelope.commandId}',
    });

    expect(await dispatcher.dispatchMap(command()), 'power:command-1');
    expect(
      await dispatcher.dispatchMap(
        command(
            schema: Elv4WireCommandEnvelope.revisionCommandSchema,
            operation: 'FREEZE_DESIGN_REVISION',
            version: 2,
          )
          ..['payload'] = <String, Object?>{
            'powerSectionIntent': 'CAPTURE_CURRENT',
          },
      ),
      'revision:command-1',
    );
  });

  test('unknown operation and unknown version fail closed', () {
    expect(
      () => Elv4WireCommandEnvelope.fromMap(
        command(operation: 'SET_POWER_LOAD_PROFILE_V2'),
      ),
      throwsFormatException,
    );
    expect(
      () => Elv4WireCommandEnvelope.fromMap(command(version: 2)),
      throwsFormatException,
    );
    expect(
      () => Elv4WireCommandEnvelope.fromMap(
        command(
          schema: Elv4WireCommandEnvelope.revisionCommandSchema,
          operation: 'FREEZE_DESIGN_REVISION',
          version: 1,
        ),
      ),
      throwsFormatException,
    );
  });

  test('missing, extra and malformed envelope fields are rejected', () {
    final missing = command()..remove('commandId');
    final extra = command()..['unexpected'] = true;
    final badRows =
        command()..['expectedRows'] = <String, Object?>{'LOAD-1': -1};
    final badFingerprint =
        command()..['reviewedImpactFingerprint'] = 'NOT-A-SHA';

    expect(
      () => Elv4WireCommandEnvelope.fromMap(missing),
      throwsFormatException,
    );
    expect(() => Elv4WireCommandEnvelope.fromMap(extra), throwsFormatException);
    expect(
      () => Elv4WireCommandEnvelope.fromMap(badRows),
      throwsFormatException,
    );
    expect(
      () => Elv4WireCommandEnvelope.fromMap(badFingerprint),
      throwsFormatException,
    );
  });

  test('registered envelope without installed runtime codec fails closed', () {
    final dispatcher = Elv4WireCommandDispatcher<String>(const {});
    final envelope = Elv4WireCommandEnvelope.fromMap(command());

    expect(() => dispatcher.dispatch(envelope), throwsStateError);
  });
}
