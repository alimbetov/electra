import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'P6 topology validation snapshot is resolved inside owner transaction',
    () {
      final source =
          File(
            'lib/data/repositories/drift_engineering_reference_adoption_repository.dart',
          ).readAsStringSync();

      final transaction = source.indexOf(
        'return database.transaction(() async {',
      );
      final topologyLoad = source.indexOf(
        'DriftEngineeringTopologyRepository(',
      );
      final graphFingerprint = source.indexOf(
        'final currentGraphFingerprint =',
      );

      expect(transaction, greaterThanOrEqualTo(0));
      expect(topologyLoad, greaterThan(transaction));
      expect(graphFingerprint, greaterThan(transaction));
      expect(topologyLoad, greaterThan(graphFingerprint));
      expect(
        source.substring(0, transaction),
        isNot(contains('DriftEngineeringTopologyRepository(')),
      );
    },
  );
}
