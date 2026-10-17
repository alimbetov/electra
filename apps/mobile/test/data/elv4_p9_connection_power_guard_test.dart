import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/application/engineering_topology_repository.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';
import '../support/elv4_power_qualification_topology.dart';

void main() {
  test(
    'ELV1 connection writer cannot edit or retire an active PoE path member',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final builder = Elv4QualificationBuilder(db);
      await builder.createStructuralBaseline();

      const protocol = EngineeringProfileReference(id: 'POE', version: '1');
      final source = EngineeringPort(
        id: 'pse-out',
        componentId: 'pse',
        code: 'OUT',
        kind: EngineeringPortKind.dataPower,
        direction: PortDirection.output,
        capacity: 1,
        connector: 'RJ45',
        protocol: protocol,
        voltage: const PortVoltageDomain(
          currentKind: PortCurrentKind.dc,
          minimumV: 44,
          maximumV: 54,
        ),
        powerDirection: PortDirection.output,
      );
      final sink = EngineeringPort(
        id: 'pd-in',
        componentId: 'pd',
        code: 'IN',
        kind: EngineeringPortKind.dataPower,
        direction: PortDirection.input,
        capacity: 1,
        connector: 'RJ45',
        protocol: protocol,
        voltage: const PortVoltageDomain(
          currentKind: PortCurrentKind.dc,
          minimumV: 44,
          maximumV: 54,
        ),
        powerDirection: PortDirection.input,
      );
      await builder.addComponent('pse', ports: [source]);
      await builder.addComponent('pd', xMm: 1500, ports: [sink]);
      await builder.connectDataPower(
        familyCode: 'CCTV',
        connectionId: 'poe-link',
        fromPortId: source.id,
        toPortId: sink.id,
      );

      final now = builder.instant;
      await db
          .into(db.poeDeliveryBindings)
          .insert(
            PoeDeliveryBindingsCompanion.insert(
              projectId: builder.projectId,
              designRevisionId: builder.revisionId,
              id: 'delivery-1',
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'connection-guard-test',
              psePortId: source.id,
              pdPortId: sink.id,
              accountingMode: 'GUARANTEED_PD',
              definitionRefJson: '{}',
              payloadJson: '{}',
            ),
          );
      await db
          .into(db.poeDeliveryPathMembers)
          .insert(
            PoeDeliveryPathMembersCompanion.insert(
              projectId: builder.projectId,
              designRevisionId: builder.revisionId,
              deliveryId: 'delivery-1',
              ordinal: 0,
              connectionId: const Value('poe-link'),
              evidenceJson: '{}',
            ),
          );

      final original = (await builder.topology.load(builder.projectId))
          .connections
          .singleWhere((value) => value.id == 'poe-link');
      await builder.topology.saveConnection(builder.projectId, original);

      const alternateProfileId = 'qualification-profile-cctv-alt';
      await builder.topology.saveConnectionProfile(
        ConnectionCompatibilityProfile(
          identity: ProfileIdentity(
            id: alternateProfileId,
            projectId: builder.projectId,
            code: 'CCTV_DATA_POWER_ALT',
            version: '1',
            source: 'ELV4 P9 power ownership regression',
          ),
          familyCodes: const ['CCTV'],
          media: const [ConnectionMedium.wired],
          semanticCode: 'DATA_POWER',
          layer: ConnectionLayer.dataPower,
          flow: CompatibilityFlow.directed,
          kindA: EngineeringPortKind.dataPower,
          kindB: EngineeringPortKind.dataPower,
          connectorA: 'RJ45',
          connectorB: 'RJ45',
          protocolA: protocol,
          protocolB: protocol,
        ),
      );
      final changed = EngineeringConnection(
        id: original.id,
        systemId: original.systemId,
        fromPortId: original.fromPortId,
        toPortId: original.toPortId,
        profileId: alternateProfileId,
        medium: original.medium,
        groupId: original.groupId,
      );
      final owned = throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ELV4_POWER_CONNECTION_OWNED'),
        ),
      );
      await expectLater(
        builder.topology.saveConnection(builder.projectId, changed),
        owned,
      );
      await expectLater(
        builder.topology.archive(
          builder.projectId,
          TopologyObjectKind.connection,
          'poe-link',
        ),
        owned,
      );

      final durable = (await builder.topology.load(builder.projectId))
          .connections
          .singleWhere((value) => value.id == 'poe-link');
      expect(durable.toMap(), original.toMap());
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}
