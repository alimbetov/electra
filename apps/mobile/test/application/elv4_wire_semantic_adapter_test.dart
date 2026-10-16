import 'package:electra_mobile/application/elv4_wire_command_dispatcher.dart';
import 'package:electra_mobile/application/elv4_wire_semantic_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fingerprint =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  Map<String, Object?> command({
    String operation = 'SET_POWER_LOAD_PROFILE',
    Map<String, Object?>? payload,
    String? reviewed = fingerprint,
  }) => {
    'schema': Elv4WireCommandEnvelope.powerCommandSchema,
    'operation': operation,
    'payloadSchemaVersion': 1,
    'projectId': 'project-1',
    'designRevisionId': 'revision-1',
    'commandId': 'command-1',
    'expectedDesignRowRevision': 7,
    'expectedRows': <String, Object?>{'aggregate': 3},
    'reviewedImpactFingerprint': reviewed,
    'payload':
        payload ??
        <String, Object?>{
          'componentId': 'component-1',
          'loads': <Object?>[
            <String, Object?>{'id': 'load-a'},
            <String, Object?>{'id': 'load-b'},
          ],
        },
  };

  test('semantic registry must cover every registered wire operation', () {
    expect(
      () => Elv4WireSemanticAdapter<int>(
        codecs: const [],
        resolveImpact: (_) async => Elv4ResolvedWireImpact(
          verifiedRows: const {'aggregate': 3},
          changedDependencyRefs: const ['dep'],
          reviewedImpactFingerprint: fingerprint,
        ),
      ),
      throwsArgumentError,
    );
  });

  test('aggregate payload reaches handler whole and impact is server-resolved', () async {
    late List<Map<String, Object?>> handledMembers;
    late Elv4ResolvedWireImpact handledImpact;
    final adapter = Elv4WireSemanticAdapter<int>(
      codecs: _completeCodecs(
        loadHandler: (envelope, payload, impact) async {
          handledMembers = payload.members;
          handledImpact = impact;
          return payload.members.length;
        },
      ),
      resolveImpact: (envelope) async {
        expect(envelope.payload.containsKey('changedDependencies'), isFalse);
        return Elv4ResolvedWireImpact(
          verifiedRows: const {'aggregate': 3},
          changedDependencyRefs: const ['dep-new', 'dep-old'],
          reviewedImpactFingerprint: fingerprint,
        );
      },
    );

    expect(await adapter.dispatchMap(command()), 2);
    expect(handledMembers.map((value) => value['id']), ['load-a', 'load-b']);
    expect(handledImpact.changedDependencyRefs, ['dep-new', 'dep-old']);
  });

  test('stale review and expected-row drift reject before semantic handler', () async {
    var handled = false;
    final codecs = _completeCodecs(
      loadHandler: (envelope, payload, impact) async {
        handled = true;
        return 1;
      },
    );
    final stale = Elv4WireSemanticAdapter<int>(
      codecs: codecs,
      resolveImpact: (_) async => Elv4ResolvedWireImpact(
        verifiedRows: const {'aggregate': 3},
        changedDependencyRefs: const ['dep'],
        reviewedImpactFingerprint:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      ),
    );
    await expectLater(stale.dispatchMap(command()), throwsStateError);
    expect(handled, isFalse);

    final rowDrift = Elv4WireSemanticAdapter<int>(
      codecs: codecs,
      resolveImpact: (_) async => Elv4ResolvedWireImpact(
        verifiedRows: const {'aggregate': 4},
        changedDependencyRefs: const ['dep'],
        reviewedImpactFingerprint: fingerprint,
      ),
    );
    await expectLater(rowDrift.dispatchMap(command()), throwsStateError);
    expect(handled, isFalse);
  });

  test('aggregate payload shape and missing review fail closed', () async {
    final adapter = Elv4WireSemanticAdapter<int>(
      codecs: _completeCodecs(),
      resolveImpact: (_) async => Elv4ResolvedWireImpact(
        verifiedRows: const {'aggregate': 3},
        changedDependencyRefs: const ['dep'],
        reviewedImpactFingerprint: fingerprint,
      ),
    );
    await expectLater(
      adapter.dispatchMap(
        command(payload: <String, Object?>{'componentId': 'component-1'}),
      ),
      throwsFormatException,
    );
    await expectLater(
      adapter.dispatchMap(command(reviewed: null)),
      throwsFormatException,
    );
  });
}

typedef _LoadHandler = Future<int> Function(
  Elv4WireCommandEnvelope envelope,
  Elv4WireAggregatePayload payload,
  Elv4ResolvedWireImpact impact,
);

List<Elv4WireSemanticCodec<int>> _completeCodecs({
  _LoadHandler? loadHandler,
}) {
  Elv4WireSemanticCodec<int> generic(
    String schema,
    String operation,
    int version,
  ) => Elv4WireTypedSemanticCodec<Map<String, Object?>, int>(
    key: Elv4WireCommandKey(
      schema: schema,
      operation: operation,
      payloadSchemaVersion: version,
    ),
    decodePayload: (payload) => payload,
    handler: (envelope, payload, impact) async => 0,
  );

  return [
    for (final operation in Elv4WireCommandEnvelope.powerV1Operations)
      if (operation == 'SET_POWER_LOAD_PROFILE')
        Elv4WireTypedSemanticCodec<Elv4WireAggregatePayload, int>(
          key: const Elv4WireCommandKey(
            schema: Elv4WireCommandEnvelope.powerCommandSchema,
            operation: 'SET_POWER_LOAD_PROFILE',
            payloadSchemaVersion: 1,
          ),
          decodePayload: (payload) => decodeElv4AggregatePayload(
            payload,
            ownerField: 'componentId',
            memberField: 'loads',
            exactKeys: const {'componentId', 'loads'},
          ),
          handler:
              loadHandler ??
              (envelope, payload, impact) async => payload.members.length,
        )
      else
        generic(
          Elv4WireCommandEnvelope.powerCommandSchema,
          operation,
          1,
        ),
    for (final operation in Elv4WireCommandEnvelope.revisionV2Operations)
      generic(
        Elv4WireCommandEnvelope.revisionCommandSchema,
        operation,
        2,
      ),
  ];
}
