import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_elv_cable_allocation_write_unit_of_work.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';
import '../support/elv4_power_qualification_topology.dart';

void main() {
  test(
    'ELV2 allocation writer cannot release an active PoE path member',
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
          .into(db.engineeringReferenceCatalogs)
          .insert(
            EngineeringReferenceCatalogsCompanion.insert(
              id: 'catalog-poe-allocation',
              projectId: builder.projectId,
              code: 'POE-CABLE',
              catalogVersion: '1',
              payloadJson: '{}',
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'allocation-guard-test',
            ),
          );
      await db
          .into(db.elvCables)
          .insert(
            ElvCablesCompanion.insert(
              id: 'cable-poe',
              projectId: builder.projectId,
              label: 'POE-CABLE',
              normalizedLabel: 'POE-CABLE',
              name: 'PoE cable',
              definitionCatalogId: 'catalog-poe-allocation',
              definitionCatalogVersion: '1',
              definitionCode: 'CAT6',
              definitionContentHash: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
              lifecycleState: 'ACTIVE',
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'allocation-guard-test',
            ),
          );
      await db
          .into(db.cableAllocations)
          .insert(
            CableAllocationsCompanion.insert(
              id: 'allocation-poe',
              projectId: builder.projectId,
              engineeringConnectionId: 'poe-link',
              cableId: 'cable-poe',
              lifecycleState: 'ACTIVE',
              revision: const Value(4),
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'allocation-guard-test',
            ),
          );
      await db
          .into(db.poeDeliveryBindings)
          .insert(
            PoeDeliveryBindingsCompanion.insert(
              projectId: builder.projectId,
              designRevisionId: builder.revisionId,
              id: 'delivery-1',
              createdAt: now,
              updatedAt: now,
              originDeviceId: 'allocation-guard-test',
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
              allocationId: const Value('allocation-poe'),
              evidenceJson: '{}',
            ),
          );

      const allocation = CableAllocation(
        id: 'allocation-poe',
        projectId: 'elv4-qualification',
        engineeringConnectionId: 'poe-link',
        cableId: 'cable-poe',
        state: CableAllocationState.active,
        revision: 4,
      );
      final unitOfWork = DriftElvCableAllocationWriteUnitOfWork(
        db,
        originDeviceId: 'allocation-guard-test',
      );
      await expectLater(
        unitOfWork.run(
          (session) => session.allocations.release(
            allocation: allocation,
            expectedRevision: 4,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('ELV4_POWER_ALLOCATION_OWNED'),
          ),
        ),
      );

      final durable = await (db.select(
        db.cableAllocations,
      )..where((row) => row.id.equals('allocation-poe'))).getSingle();
      expect(durable.lifecycleState, 'ACTIVE');
      expect(durable.revision, 4);
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}
