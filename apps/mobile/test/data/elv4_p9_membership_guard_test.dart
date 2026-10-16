import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/drift_engineering_system_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/elv4_power_qualification_builder.dart';
import '../support/elv4_power_qualification_topology.dart';

void main() {
  test('system detach rejects active ELV4 power ownership', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final builder = Elv4QualificationBuilder(db);
    await builder.createStructuralBaseline();
    await builder.addComponent('owned');
    await builder.addComponent('plain');

    final systemId = await builder.ensureSystem('CCTV');
    final systems = DriftEngineeringSystemRepository(
      db,
      originDeviceId: 'qualification',
    );
    for (final componentId in ['owned', 'plain']) {
      await systems.assign(
        builder.projectId,
        ComponentSystemMembership(
          systemId: systemId,
          componentId: componentId,
          role: 'DEVICE',
        ),
      );
    }

    await builder.bindComponent('owned', const [
      PowerComponentCapability.consumer,
    ], expectedRevision: 1);

    await expectLater(
      systems.detach(builder.projectId, systemId, 'owned'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('ELV4_POWER_MEMBERSHIP_OWNED'),
        ),
      ),
    );

    final afterRejectedDetach = await systems.load(builder.projectId);
    expect(
      afterRejectedDetach.memberships.any(
        (membership) =>
            membership.systemId == systemId &&
            membership.componentId == 'owned',
      ),
      isTrue,
    );

    await systems.detach(builder.projectId, systemId, 'plain');
    final afterPlainDetach = await systems.load(builder.projectId);
    expect(
      afterPlainDetach.memberships.any(
        (membership) =>
            membership.systemId == systemId &&
            membership.componentId == 'plain',
      ),
      isFalse,
    );
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
}
