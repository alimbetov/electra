import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv4_wire_command_dispatcher.dart';
import 'package:electra_mobile/application/elv4_wire_runtime_registry.dart';
import 'package:electra_mobile/application/elv4_wire_semantic_adapter.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv4_wire_runtime_backend.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';

void main() {
  test(
    'public wire load profile reaches durable aggregate runtime and replays',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();

      const protocol = EngineeringProfileReference(id: 'POWER', version: '1');
      final port = EngineeringPort(
        id: 'load-in',
        componentId: 'node',
        code: 'LOAD_IN',
        kind: EngineeringPortKind.dataPower,
        direction: PortDirection.input,
        capacity: 1,
        connector: 'WIRE',
        protocol: protocol,
        voltage: const PortVoltageDomain(
          currentKind: PortCurrentKind.dc,
          minimumV: 20,
          maximumV: 60,
        ),
        powerDirection: PortDirection.input,
      );
      await builder.addComponent('node', ports: [port]);

      final backend = DriftElv4WireRuntimeBackend(
        db,
        originDeviceId: 'wire-public-test',
        delegate: _UnusedDelegate(),
        now: () => builder.instant,
      );
      const fingerprint =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final adapter = Elv4WireSemanticAdapter<Object?>(
        codecs: createElv4WireRuntimeCodecs(backend),
        resolveImpact:
            (_) async => Elv4ResolvedWireImpact(
              verifiedRows: const {},
              changedDependencyRefs: const [],
              reviewedImpactFingerprint: fingerprint,
            ),
      );
      final demand = DcConstantPowerDemand(PowerRational.integer(12)).toMap();
      final envelope = <String, Object?>{
        'schema': Elv4WireCommandEnvelope.powerCommandSchema,
        'operation': 'SET_POWER_LOAD_PROFILE',
        'payloadSchemaVersion': 1,
        'projectId': builder.projectId,
        'designRevisionId': builder.revisionId,
        'commandId': 'public-load-1',
        'expectedDesignRowRevision': 1,
        'expectedRows': <String, Object?>{},
        'reviewedImpactFingerprint': fingerprint,
        'payload': <String, Object?>{
          'componentId': 'node',
          'loads': <Object?>[
            <String, Object?>{
              'loadId': 'public-load',
              'inputPortId': port.id,
              'stateCode': 'ON',
              'accountingKind': 'CONSUMER_INPUT',
              'originId': 'canonical-origin',
              'demand': demand,
            },
          ],
        },
      };

      final first = await adapter.dispatchMap(envelope);
      expect(first, isA<Object?>());
      final persisted =
          await db
              .customSelect(
                'SELECT id, origin_id, typed_demand_json FROM power_load_bindings '
                'WHERE design_revision_id = ? AND deleted_at IS NULL',
                variables: [Variable.withString(builder.revisionId)],
              )
              .getSingle();
      expect(persisted.read<String>('id'), 'public-load');
      expect(persisted.read<String>('origin_id'), 'canonical-origin');
      expect(
        (await db.select(db.projectDesignRevisions).getSingle()).revision,
        2,
      );

      final replay = await adapter.dispatchMap(envelope);
      expect(replay, isA<Object?>());
      expect(
        (await db.select(db.projectDesignRevisions).getSingle()).revision,
        2,
      );
      final ledger =
          await db
              .customSelect(
                'SELECT command_type, payload_schema, status FROM power_operation_records '
                'WHERE project_id = ? AND design_revision_id = ? AND operation_id = ?',
                variables: [
                  Variable.withString(builder.projectId),
                  Variable.withString(builder.revisionId),
                  Variable.withString('public-load-1'),
                ],
              )
              .getSingle();
      expect(ledger.read<String>('command_type'), 'SET_POWER_LOAD_PROFILE');
      expect(
        ledger.read<String>('payload_schema'),
        'electra.elv4-command.v1/SET_POWER_LOAD_PROFILE@1',
      );
      expect(ledger.read<String>('status'), 'COMMITTED');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}

final class _UnusedDelegate implements Elv4WireRuntimeBackend<Object?> {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError(
        'Unexpected delegated wire operation: ${invocation.memberName}',
      );
}
