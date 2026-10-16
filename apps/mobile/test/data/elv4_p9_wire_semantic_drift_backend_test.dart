import 'package:drift/drift.dart' hide isNotNull;
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
    'semantic wire dispatch persists reviewed aggregate through Drift',
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

      final dependency = PowerDependencyKey(
        projectId: builder.projectId,
        revisionId: builder.revisionId,
        kind: PowerDependencyKind.definition,
        entityId: 'node',
        purpose: 'LOAD_PROFILE',
      );
      final reviewedFingerprint = sha256HexUtf8('semantic-drift-review');
      final backend = DriftElv4WireRuntimeBackend(
        db,
        originDeviceId: 'wire-semantic-test',
        delegate: _UnexpectedDelegate(),
        now: () => builder.instant,
      );
      final adapter = Elv4WireSemanticAdapter<Object?>(
        codecs: createElv4WireRuntimeCodecs<Object?>(backend),
        resolveImpact:
            (envelope) async => Elv4ResolvedWireImpact(
              verifiedRows: envelope.expectedRows,
              changedDependencyRefs: [dependency.encode()],
              reviewedImpactFingerprint: reviewedFingerprint,
            ),
      );

      final result = await adapter.dispatchMap({
        'schema': Elv4WireCommandEnvelope.powerCommandSchema,
        'operation': 'SET_POWER_LOAD_PROFILE',
        'payloadSchemaVersion': 1,
        'projectId': builder.projectId,
        'designRevisionId': builder.revisionId,
        'commandId': 'wire-set-loads',
        'expectedDesignRowRevision': 1,
        'expectedRows': <String, int>{},
        'reviewedImpactFingerprint': reviewedFingerprint,
        'payload': {
          'componentId': 'node',
          'loads': [
            {
              'loadId': 'load-1',
              'inputPortId': port.id,
              'stateCode': 'ON',
              'accountingKind': 'CONSUMER_INPUT',
              'originId': 'wire-origin',
              'demand': {'kind': 'DC_CONSTANT_POWER', 'powerW': '12'},
            },
          ],
        },
      });

      expect(result, isNotNull);
      final load =
          await db
              .customSelect(
                'SELECT id, origin_id FROM power_load_bindings '
                'WHERE design_revision_id = ? AND deleted_at IS NULL',
                variables: [Variable.withString(builder.revisionId)],
              )
              .getSingle();
      expect(load.read<String>('id'), 'load-1');
      expect(load.read<String>('origin_id'), 'wire-origin');

      final revision = await db.select(db.projectDesignRevisions).getSingle();
      expect(revision.revision, 2);
      final ledger =
          await db
              .customSelect(
                'SELECT command_type, payload_schema, status FROM power_operation_records '
                'WHERE project_id = ? AND design_revision_id = ? AND operation_id = ?',
                variables: [
                  Variable.withString(builder.projectId),
                  Variable.withString(builder.revisionId),
                  Variable.withString('wire-set-loads'),
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

final class _UnexpectedDelegate implements Elv4WireRuntimeBackend<Object?> {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw StateError(
      'Unexpected delegated ELV4 operation: ${invocation.memberName}',
    );
  }
}
