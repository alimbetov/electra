import 'package:drift/native.dart';
import 'package:electra_mobile/data/database/app_database.dart';
import 'package:electra_mobile/data/repositories/elv5/drift_elv5_calculation_runtime.dart';
import 'package:engineering_core/engineering_core_elv5.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'production calculation runtime registers all 27 ELV5 processes',
    () async {
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
          Elv5ProcessCode.cctv01,
          Elv5ProcessCode.cctv02,
          Elv5ProcessCode.cctv03,
          Elv5ProcessCode.cctv04,
          Elv5ProcessCode.cctv05,
          Elv5ProcessCode.cctv06,
          Elv5ProcessCode.lan01,
          Elv5ProcessCode.lan02,
          Elv5ProcessCode.lan03,
          Elv5ProcessCode.lan04,
          Elv5ProcessCode.lan05,
          Elv5ProcessCode.lan06,
          Elv5ProcessCode.lan07,
          Elv5ProcessCode.acs01,
          Elv5ProcessCode.acs02,
          Elv5ProcessCode.acs03,
          Elv5ProcessCode.acs04,
          Elv5ProcessCode.acs05,
          Elv5ProcessCode.acs06,
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
      expect(runtime.registry.registeredCodes, hasLength(27));
    },
  );
}
