import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production calculation runtime registers the persisted-fact vertical', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final runtime = DriftElv5CalculationRuntime.create(
      database,
      originDeviceId: 'test-device',
      nowUtc: () => DateTime.utc(2026, 10, 17),
    );

    expect(
      runtime.registry.registeredCodes,
      containsAll(<Elv5ProcessCode>{
        Elv5ProcessCode.cctv02,
        Elv5ProcessCode.cctv03,
        Elv5ProcessCode.lan01,
        Elv5ProcessCode.lan05,
        Elv5ProcessCode.acs03,
        Elv5ProcessCode.acs04,
        Elv5ProcessCode.acs05,
        Elv5ProcessCode.fa01,
        Elv5ProcessCode.fa02,
        Elv5ProcessCode.fa03,
        Elv5ProcessCode.fa04,
        Elv5ProcessCode.fa05,
        Elv5ProcessCode.fa06,
        Elv5ProcessCode.fa07,
        Elv5ProcessCode.fa08,
      }),
    );
    expect(runtime.registry.registeredCodes, hasLength(15));
  });
}
