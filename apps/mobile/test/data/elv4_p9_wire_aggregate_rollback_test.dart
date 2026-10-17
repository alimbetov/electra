import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/elv4_wire_command_dispatcher.dart';
import 'package:electra_mobile/application/elv4_wire_power_payload.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv4_wire_aggregate_service.dart';
import 'package:electra_mobile/data/repositories/drift_power_runtime_store.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';

void main() {
  test(
    'aggregate wire load replacement rolls back all state on bad member',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();

      const protocol = EngineeringProfileReference(id: 'POWER', version: '1');
      final validPort = EngineeringPort(
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
      await builder.addComponent('node', ports: [validPort]);

      final service = DriftElv4WireAggregateService(
        db,
        originDeviceId: 'wire-rollback-test',
        now: () => builder.instant,
      );
      final original = Elv4WireLoadEntry(
        loadId: 'load-original',
        inputPortId: validPort.id,
        stateCode: 'ON',
        accountingKind: 'CONSUMER_INPUT',
        originId: 'origin-original',
        demand: DcConstantPowerDemand(PowerRational.integer(10)),
      );
      await service.replaceLoadProfile(
        envelope: _envelope(
          builder,
          commandId: 'seed-load',
          expectedRevision: 1,
          loads: [original.toMap()],
        ),
        changedDependencyRefs: const [],
        componentId: 'node',
        loads: [original],
      );
      expect(await _revisionToken(db), 2);

      final validReplacement = Elv4WireLoadEntry(
        loadId: 'load-valid',
        inputPortId: validPort.id,
        stateCode: 'ON',
        accountingKind: 'CONSUMER_INPUT',
        originId: 'origin-valid',
        demand: DcConstantPowerDemand(PowerRational.integer(11)),
      );
      final invalidReplacement = Elv4WireLoadEntry(
        loadId: 'load-invalid',
        inputPortId: 'missing-port',
        stateCode: 'ON',
        accountingKind: 'CONSUMER_INPUT',
        originId: 'origin-invalid',
        demand: DcConstantPowerDemand(PowerRational.integer(12)),
      );
      final failingEnvelope = _envelope(
        builder,
        commandId: 'replace-with-invalid-member',
        expectedRevision: 2,
        loads: [validReplacement.toMap(), invalidReplacement.toMap()],
      );

      await expectLater(
        service.replaceLoadProfile(
          envelope: failingEnvelope,
          changedDependencyRefs: const [],
          componentId: 'node',
          loads: [validReplacement, invalidReplacement],
        ),
        throwsA(
          isA<PowerRuntimeStorageException>().having(
            (error) => error.code,
            'code',
            'ELV4_PORT_OWNER_MISMATCH',
          ),
        ),
      );

      expect(await _revisionToken(db), 2);
      final active = await db
          .customSelect(
            'SELECT id, origin_id FROM power_load_bindings '
            'WHERE design_revision_id = ? AND deleted_at IS NULL ORDER BY id',
            variables: [Variable.withString(builder.revisionId)],
          )
          .get();
      expect(active, hasLength(1));
      expect(active.single.read<String>('id'), 'load-original');
      expect(active.single.read<String>('origin_id'), 'origin-original');

      final failedLedgerRow = await db
          .customSelect(
            'SELECT status FROM power_operation_records '
            'WHERE project_id = ? AND design_revision_id = ? AND operation_id = ?',
            variables: [
              Variable.withString(builder.projectId),
              Variable.withString(builder.revisionId),
              Variable.withString(failingEnvelope.commandId),
            ],
          )
          .getSingleOrNull();
      expect(failedLedgerRow, null);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}

Elv4WireCommandEnvelope _envelope(
  Elv4QualificationBuilder builder, {
  required String commandId,
  required int expectedRevision,
  required List<Map<String, Object?>> loads,
}) => Elv4WireCommandEnvelope(
  schema: Elv4WireCommandEnvelope.powerCommandSchema,
  operation: 'SET_POWER_LOAD_PROFILE',
  payloadSchemaVersion: 1,
  projectId: builder.projectId,
  designRevisionId: builder.revisionId,
  commandId: commandId,
  expectedDesignRowRevision: expectedRevision,
  expectedRows: const {},
  reviewedImpactFingerprint: sha256HexUtf8('review-$commandId'),
  payload: {'componentId': 'node', 'loads': loads},
);

Future<int> _revisionToken(AppDatabase db) async =>
    (await db.select(db.projectDesignRevisions).getSingle()).revision;
