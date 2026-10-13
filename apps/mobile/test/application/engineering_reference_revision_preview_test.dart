import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:electra_mobile/application/engineering_reference_revision_preview.dart';
import 'package:electra_mobile/application/engineering_system_repository.dart';
import 'package:electra_mobile/application/engineering_topology_repository.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

EngineeringReferenceCatalog fixture() => EngineeringReferenceCatalog.fromMap(
  jsonDecode(
        File(
          '../../docs/examples/elv2-reference-catalog.json',
        ).readAsStringSync(),
      )
      as Map<String, dynamic>,
);

void main() {
  test(
    'candidate edition reports bound component and exact affected connection',
    () {
      final previous = fixture();
      final previousCamera = previous.profile('CAMERA');
      final changedPort = EngineeringPort.fromMap({
        ...previousCamera.portTemplates.first.toMap(),
        'capacity': previousCamera.portTemplates.first.capacity + 1,
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
                'portTemplates': [
                  changedPort.toMap(),
                  ...profile.portTemplates.skip(1).map((port) => port.toMap()),
                ],
              }
            else
              profile.toMap(),
        ],
      });

      final systems = ProjectEngineeringSystemsSnapshot(
        project: null,
        families: const [],
        systems: const [],
        memberships: const [],
        components: const [
          EngineeringComponentView(
            id: 'camera-1',
            name: 'Camera 1',
            roomName: 'R1',
          ),
        ],
      );
      final binding = ComponentReferenceBinding(
        componentId: 'camera-1',
        catalogId: previous.id,
        profileCode: 'CAMERA',
        catalogVersion: previous.version,
        profile: previousCamera,
        portIds: const ['camera-port'],
      );
      final references = ProjectEngineeringReferences(
        systems: systems,
        catalogs: [previous],
        bindings: [binding],
      );
      final topology = ProjectEngineeringTopologySnapshot(
        systems: systems,
        ports: const [],
        connectionProfiles: const [],
        connections: const [
          EngineeringConnection(
            id: 'link-17',
            systemId: 'cctv',
            fromPortId: 'camera-port',
            toPortId: 'switch-port',
            profileId: 'ethernet',
            medium: ConnectionMedium.wired,
          ),
        ],
        internalLinks: const [],
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

      expect(preview.affectedBindingCount, 1);
      expect(preview.affectedConnectionIds, {'link-17'});
      expect(preview.affectsConnections, isTrue);
      expect(preview.bindingImpacts.single.componentId, 'camera-1');
      expect(
        preview.bindingImpacts.single.profileImpact.changes.map(
          (change) => change.kind,
        ),
        contains(ProfileRevisionChangeKind.ports),
      );
    },
  );

  test('removed profile is surfaced before any adoption is allowed', () {
    final previous = fixture();
    final candidate = EngineeringReferenceCatalog.fromMap({
      ...previous.toMap(),
      'id': '${previous.id}-v2',
      'version': '2',
      'profiles':
          previous.profiles
              .where((profile) => profile.code != 'CAMERA')
              .map((profile) => profile.toMap())
              .toList(),
    });
    final systems = ProjectEngineeringSystemsSnapshot(
      project: null,
      families: const [],
      systems: const [],
      memberships: const [],
      components: const [],
    );
    final references = ProjectEngineeringReferences(
      systems: systems,
      catalogs: [previous],
      bindings: [
        ComponentReferenceBinding(
          componentId: 'camera-1',
          catalogId: previous.id,
          profileCode: 'CAMERA',
          catalogVersion: previous.version,
          profile: previous.profile('CAMERA'),
          portIds: const ['camera-port'],
        ),
      ],
    );
    final topology = ProjectEngineeringTopologySnapshot(
      systems: systems,
      ports: const [],
      connectionProfiles: const [],
      connections: const [],
      internalLinks: const [],
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

    expect(preview.removedProfileCodes, ['CAMERA']);
    expect(preview.affectedBindingCount, 0);
  });
}
