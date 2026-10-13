import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/engineering_placement_command.dart';
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

ProjectEngineeringSystemsSnapshot systems() =>
    const ProjectEngineeringSystemsSnapshot(
      project: null,
      families: [],
      systems: [],
      memberships: [],
      components: [
        EngineeringComponentView(
          id: 'camera-1',
          name: 'Camera 1',
          roomName: 'R1',
        ),
        EngineeringComponentView(
          id: 'camera-2',
          name: 'Camera 2',
          roomName: 'R1',
        ),
      ],
    );

PlacementCandidateContext cameraContext() => PlacementCandidateContext(
  projectId: 'project-1',
  roomId: 'room-1',
  surfaceId: 'wall-1',
  installationSurface: InstallationSurface.wall,
  mountingMethod: MountingMethod.bracket,
  environmentExposure: EnvironmentExposure.indoor,
  environmentClimate: EnvironmentClimate.conditioned,
  ambientTemperatureC: 20,
  actualIpRating: IpProtectionClass.parse('IP54'),
  hasEnclosure: false,
  availableClearanceMm: 50,
  topologyShape: TopologyShape.star,
  topologyRole: TopologyParticipation.endpoint,
);

PlaceEngineeringProfileCommand reviewedCommand(
  EngineeringReferenceCatalog catalog,
) => PlaceEngineeringProfileCommand(
  operationId: 'place-camera-1',
  projectId: 'project-1',
  roomId: 'room-1',
  systemId: 'cctv',
  membershipRole: canonicalElvMembershipRole,
  catalogId: catalog.id,
  catalogVersion: catalog.version,
  profileCode: 'CAMERA',
  hostSurfacePatchId: 'wall-1',
  localPosition: const Point2Mm(100, 100),
  rotationRadians: 0,
  placementContext: cameraContext(),
);

ComponentReferenceBinding cameraBinding(
  EngineeringReferenceCatalog catalog, {
  String componentId = 'camera-1',
  List<String> portIds = const ['camera-port'],
  bool withEvidence = false,
}) => ComponentReferenceBinding(
  componentId: componentId,
  catalogId: catalog.id,
  profileCode: 'CAMERA',
  catalogVersion: catalog.version,
  profile: catalog.profile('CAMERA'),
  portIds: portIds,
  placementCommand: withEvidence ? reviewedCommand(catalog) : null,
);

ProjectEngineeringTopologySnapshot topology({
  List<EngineeringConnection> connections = const [],
  List<TopologyGroup> groups = const [],
}) => ProjectEngineeringTopologySnapshot(
  systems: systems(),
  ports: const [],
  connectionProfiles: const [],
  connections: connections,
  internalLinks: const [],
  topologyProfiles: const [],
  groups: groups,
  assemblyProfiles: const [],
  assemblies: const [],
);

EngineeringReferenceCatalog candidateWithCamera(
  EngineeringReferenceCatalog previous,
  Map<String, Object?> cameraPatch,
) => EngineeringReferenceCatalog.fromMap({
  ...previous.toMap(),
  'id': '${previous.id}-v2',
  'version': '2',
  'profiles': [
    for (final profile in previous.profiles)
      if (profile.code == 'CAMERA') {...profile.toMap(), ...cameraPatch} else profile.toMap(),
  ],
});

void main() {
  test(
    'connection-only revision joins exact component connection and group without fabricating placement result',
    () {
      final previous = fixture();
      final camera = previous.profile('CAMERA');
      final changedPort = EngineeringPort.fromMap({
        ...camera.portTemplates.first.toMap(),
        'capacity': camera.portTemplates.first.capacity + 1,
      });
      final candidate = candidateWithCamera(previous, {
        'portTemplates': [changedPort.toMap()],
      });
      final references = ProjectEngineeringReferences(
        systems: systems(),
        catalogs: [previous],
        bindings: [cameraBinding(previous)],
      );
      final preview = previewCatalogRevision(
        references: references,
        topology: topology(
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
          groups: const [
            TopologyGroup(
              id: 'group-3',
              systemId: 'cctv',
              code: 'G3',
              profileId: 'star',
              startPortId: 'camera-port',
            ),
          ],
        ),
        candidate: candidate,
      );

      expect(preview.affectedBindingCount, 1);
      expect(preview.affectedConnectionIds, {'link-17'});
      expect(preview.affectedTopologyGroupIds, {'group-3'});
      expect(preview.affectsConnections, isTrue);
      expect(preview.affectsPlacement, isFalse);
      expect(preview.adoptionBlocked, isFalse);
      expect(preview.bindingImpacts.single.placementResult, isNull);
      expect(preview.bindingImpacts.single.placementBlockerReason, isNull);
      expect(
        preview.bindingImpacts.single.profileImpact.changes.map(
          (change) => change.kind,
        ),
        contains(ProfileRevisionChangeKind.ports),
      );
    },
  );

  test('removed profile is an affected binding and adoption blocker', () {
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
    final references = ProjectEngineeringReferences(
      systems: systems(),
      catalogs: [previous],
      bindings: [cameraBinding(previous)],
    );
    final preview = previewCatalogRevision(
      references: references,
      topology: topology(
        connections: const [
          EngineeringConnection(
            id: 'link-removed',
            systemId: 'cctv',
            fromPortId: 'camera-port',
            toPortId: 'switch-port',
            profileId: 'ethernet',
            medium: ConnectionMedium.wired,
          ),
        ],
      ),
      candidate: candidate,
    );

    expect(preview.removedProfileCodes, ['CAMERA']);
    expect(preview.affectedBindingCount, 1);
    expect(preview.affectedConnectionIds, {'link-removed'});
    expect(preview.affectsPlacement, isTrue);
    expect(preview.affectsConnections, isTrue);
    expect(preview.adoptionBlocked, isTrue);
    final impact = preview.bindingImpacts.single;
    expect(impact.disposition, BoundProfileRevisionDisposition.removed);
    expect(impact.adoptionBlocked, isTrue);
    expect(impact.placementBlockerReason, isNotNull);
    expect(
      impact.profileImpact.changes.single.kind,
      ProfileRevisionChangeKind.removed,
    );
  });

  test('placement constraint change revalidates frozen P4 evidence', () {
    final previous = fixture();
    final camera = previous.profile('CAMERA');
    final candidate = candidateWithCamera(previous, {
      'constraints': {
        ...camera.constraints!.toMap(),
        'mounting': {
          'options': [
            {'surface': 'ceiling', 'method': 'surface'},
          ],
          'enclosureRequired': false,
          'minimumClearanceMm': 50,
        },
      },
    });
    final references = ProjectEngineeringReferences(
      systems: systems(),
      catalogs: [previous],
      bindings: [cameraBinding(previous, withEvidence: true)],
    );

    final preview = previewCatalogRevision(
      references: references,
      topology: topology(),
      candidate: candidate,
    );

    final impact = preview.bindingImpacts.single;
    expect(impact.disposition, BoundProfileRevisionDisposition.changed);
    expect(impact.profileImpact.affectsPlacement, isTrue);
    expect(
      impact.placementResult!.status,
      PlacementCompatibilityStatus.forbidden,
    );
    expect(impact.adoptionBlocked, isTrue);
    expect(preview.adoptionBlocked, isTrue);
  });

  test(
    'placement-relevant historical binding without reviewed evidence stays unresolved and blocking',
    () {
      final previous = fixture();
      final camera = previous.profile('CAMERA');
      final candidate = candidateWithCamera(previous, {
        'constraints': {
          ...camera.constraints!.toMap(),
          'mounting': {
            ...camera.constraints!.mounting.toMap(),
            'minimumClearanceMm': 60,
          },
        },
      });
      final references = ProjectEngineeringReferences(
        systems: systems(),
        catalogs: [previous],
        bindings: [cameraBinding(previous)],
      );

      final impact = previewCatalogRevision(
        references: references,
        topology: topology(),
        candidate: candidate,
      ).bindingImpacts.single;

      expect(impact.profileImpact.affectsPlacement, isTrue);
      expect(impact.placementResult, isNull);
      expect(impact.placementBlockerReason, contains('no reviewed placement evidence'));
      expect(impact.adoptionBlocked, isTrue);
    },
  );

  test('deprecated candidate profile cannot appear safe', () {
    final previous = fixture();
    final candidate = candidateWithCamera(previous, {'deprecated': true});
    final references = ProjectEngineeringReferences(
      systems: systems(),
      catalogs: [previous],
      bindings: [cameraBinding(previous, withEvidence: true)],
    );

    final impact = previewCatalogRevision(
      references: references,
      topology: topology(),
      candidate: candidate,
    ).bindingImpacts.single;

    expect(
      impact.profileImpact.changes.map((change) => change.kind),
      contains(ProfileRevisionChangeKind.lifecycle),
    );
    expect(
      impact.placementResult!.status,
      PlacementCompatibilityStatus.forbidden,
    );
    expect(impact.adoptionBlocked, isTrue);
  });

  test('publication-invalid candidate blocks edition adoption', () {
    final previous = fixture();
    final camera = previous.profile('CAMERA');
    final candidate = candidateWithCamera(previous, {
      'capabilities': [
        ...camera.capabilities.map((capability) => capability.name),
        camera.capabilities.first.name,
      ],
    });
    final references = ProjectEngineeringReferences(
      systems: systems(),
      catalogs: [previous],
      bindings: [cameraBinding(previous)],
    );

    final preview = previewCatalogRevision(
      references: references,
      topology: topology(),
      candidate: candidate,
    );

    expect(preview.candidateValidationErrors, isNotEmpty);
    expect(preview.bindingImpacts.single.candidateProfileValidationErrors, isNotEmpty);
    expect(preview.adoptionBlocked, isTrue);
  });

  test('unchanged bound profile creates no project impact', () {
    final previous = fixture();
    final candidate = EngineeringReferenceCatalog.fromMap({
      ...previous.toMap(),
      'id': '${previous.id}-v2',
      'version': '2',
    });
    final references = ProjectEngineeringReferences(
      systems: systems(),
      catalogs: [previous],
      bindings: [cameraBinding(previous, withEvidence: true)],
    );

    final preview = previewCatalogRevision(
      references: references,
      topology: topology(),
      candidate: candidate,
    );

    expect(preview.bindingImpacts, isEmpty);
    expect(preview.removedProfileCodes, isEmpty);
    expect(preview.candidateValidationErrors, isEmpty);
    expect(preview.adoptionBlocked, isFalse);
  });

  test('multiple affected bindings are deterministically ordered', () {
    final previous = fixture();
    final camera = previous.profile('CAMERA');
    final changedPort = EngineeringPort.fromMap({
      ...camera.portTemplates.first.toMap(),
      'capacity': camera.portTemplates.first.capacity + 1,
    });
    final candidate = candidateWithCamera(previous, {
      'portTemplates': [changedPort.toMap()],
    });
    final references = ProjectEngineeringReferences(
      systems: systems(),
      catalogs: [previous],
      bindings: [
        cameraBinding(
          previous,
          componentId: 'camera-2',
          portIds: const ['camera-2-port'],
        ),
        cameraBinding(previous),
      ],
    );

    final preview = previewCatalogRevision(
      references: references,
      topology: topology(),
      candidate: candidate,
    );

    expect(
      preview.bindingImpacts.map((impact) => impact.componentId),
      ['camera-1', 'camera-2'],
    );
  });
}
