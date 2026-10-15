import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:electra_mobile/application/engineering_reference_revision_preview.dart';
import 'package:electra_mobile/application/engineering_system_repository.dart';
import 'package:electra_mobile/application/engineering_topology_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringReferenceCatalog _fixture() => EngineeringReferenceCatalog.fromMap(
  jsonDecode(
        File(
          '../../docs/examples/elv2-reference-catalog.json',
        ).readAsStringSync(),
      )
      as Map<String, dynamic>,
);

void main() {
  test('internal-mapping-only dependency is reviewer-visible in P5', () {
    final previous = _fixture();
    final camera = previous.profile('CAMERA');
    final changedPort = EngineeringPort.fromMap({
      ...camera.portTemplates.first.toMap(),
      'capacity': camera.portTemplates.first.capacity + 1,
    });
    final candidate = EngineeringReferenceCatalog.fromMap({
      ...previous.toMap(),
      'id': '${previous.id}-v2',
      'version': '2',
      'profiles': [
        for (final profile in previous.profiles)
          if (profile.code == 'CAMERA')
            {
              ...profile.toMap(),
              'portTemplates': [changedPort.toMap()],
            }
          else
            profile.toMap(),
      ],
    });
    final references = ProjectEngineeringReferences(
      systems: const ProjectEngineeringSystemsSnapshot(
        project: null,
        families: [],
        systems: [],
        memberships: [],
        components: [],
      ),
      catalogs: [previous],
      bindings: [
        ComponentReferenceBinding(
          componentId: 'camera-1',
          catalogId: previous.id,
          profileCode: 'CAMERA',
          catalogVersion: previous.version,
          profile: camera,
          portIds: const ['camera-port'],
        ),
      ],
    );
    final topology = ProjectEngineeringTopologySnapshot(
      systems: references.systems,
      ports: const [],
      connectionProfiles: const [],
      connections: const [],
      internalLinks: const [
        InternalConnectivity(
          id: 'internal-1',
          componentId: 'camera-1',
          fromPortId: 'camera-port',
          toPortId: 'switch-port',
          layer: ConnectionLayer.data,
          bidirectional: false,
          evidence: 'round2',
        ),
      ],
      topologyProfiles: const [],
      groups: const [],
      assemblyProfiles: const [],
      assemblies: const [],
    );

    final preview = previewCatalogRevision(
      references: references,
      topology: topology,
      candidate: candidate,
    );

    final impact = preview.bindingImpacts.single;
    expect(impact.internalMappingIds, ['internal-1']);
    expect(impact.affectsProjectGraph, isTrue);
    expect(preview.affectedInternalMappingIds, {'internal-1'});
  });
}
