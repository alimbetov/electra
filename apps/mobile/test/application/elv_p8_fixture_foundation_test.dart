import 'package:flutter_test/flutter_test.dart';

import '../support/elv_test_catalog.dart';
import '../support/elv_test_ids.dart';
import '../support/elv_test_project.dart';
import '../support/elv_test_routing.dart';
import '../support/elv_test_topology.dart';

void main() {
  group('ELV3 P8 deterministic fixture foundation', () {
    test('project, topology and routing identities are deterministic', () {
      final firstIds = FixedSequenceIdGenerator();
      final secondIds = FixedSequenceIdGenerator();

      final first = _buildCctvFoundation(firstIds);
      final second = _buildCctvFoundation(secondIds);

      expect(first, second);
      expect(first.projectId, startsWith(ElvFixturePrefixes.project));
      expect(first.connectionId, startsWith(ElvFixturePrefixes.connection));
      expect(first.runId, startsWith(ElvFixturePrefixes.run));
      expect(first.traversalIds, hasLength(3));
    });

    test('ACS fixture partitions one 8-core cable without overlap', () {
      const partitions = <String, Set<String>>{
        'reader': {'CORE-1', 'CORE-2'},
        'door-contact': {'CORE-3', 'CORE-4'},
        'rex': {'CORE-5', 'CORE-6'},
        'lock': {'CORE-7', 'CORE-8'},
      };

      final selected = partitions.values.expand((atoms) => atoms).toList();

      expect(selected.toSet(), hasLength(8));
      expect(selected.toSet(), containsAll(ElvTestCatalog.eightCore.resourceAtoms));
    });

    test('fiber fixture exposes overlap as a deterministic set conflict', () {
      const allocationA = {'FIBER-1', 'FIBER-2'};
      const allocationB = {'FIBER-3', 'FIBER-4'};
      const invalidAllocation = {'FIBER-2', 'FIBER-5'};

      expect(allocationA.intersection(allocationB), isEmpty);
      expect(allocationA.intersection(invalidAllocation), {'FIBER-2'});
    });

    test('catalog foundation includes CCTV/LAN, ACS and fiber resources', () {
      expect(ElvTestCatalog.cat6.resourceAtoms, hasLength(4));
      expect(ElvTestCatalog.eightCore.resourceAtoms, hasLength(8));
      expect(ElvTestCatalog.twelveFiber.resourceAtoms, hasLength(12));
    });
  });
}

({
  String projectId,
  String connectionId,
  String runId,
  List<String> traversalIds,
}) _buildCctvFoundation(FixedSequenceIdGenerator ids) {
  final project = buildElvTestProject(ids);
  final connection = buildElvTestConnection(ids, role: 'CCTV_ETH_POE');
  final routing = buildElvTestRouting(ids);
  return (
    projectId: project.projectId,
    connectionId: connection.connectionId,
    runId: routing.runId,
    traversalIds: routing.traversalIds,
  );
}
