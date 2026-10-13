import 'dart:convert';
import 'dart:io';

import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

EngineeringReferenceCatalog fixture() => EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );

EngineeringProfileConstraints cameraConstraints({
  bool outdoor = false,
  bool loop = false,
}) =>
    EngineeringProfileConstraints(
      discipline: ReferenceDiscipline.cctv,
      mounting: MountingConstraintProfile(
        allowedSurfaces: const [
          InstallationSurface.wall,
          InstallationSurface.ceiling,
        ],
        allowedMethods: const [MountingMethod.bracket, MountingMethod.surface],
        minimumClearanceMm: 50,
      ),
      environment: EnvironmentConstraintProfile(
        allowedClasses: [
          EnvironmentClass.indoor,
          if (outdoor) EnvironmentClass.outdoor,
        ],
        minimumIpRating: outdoor ? 'IP66' : 'IP20',
        minimumTemperatureC: outdoor ? -40 : 0,
        maximumTemperatureC: 50,
      ),
      topology: TopologyConstraintProfile(
        allowedShapes: [TopologyShape.star, if (loop) TopologyShape.loop],
        allowedRoles: const [TopologyParticipation.endpoint],
        branchingAllowed: false,
      ),
    );

void main() {
  test('typed placement and topology constraints roundtrip without free-form values',
      () {
    final profile = cameraConstraints(outdoor: true);
    expect(profile.validate(), isEmpty);

    final restored = EngineeringProfileConstraints.fromMap(
      jsonDecode(jsonEncode(profile.toMap())) as Map<String, dynamic>,
    );

    expect(restored.discipline, ReferenceDiscipline.cctv);
    expect(
      restored.mounting.allowedSurfaces,
      containsAll([InstallationSurface.wall, InstallationSurface.ceiling]),
    );
    expect(restored.environment.allowedClasses, contains(EnvironmentClass.outdoor));
    expect(restored.environment.minimumIpRating, 'IP66');
    expect(restored.topology.allowedShapes, [TopologyShape.star]);
    expect(restored.topology.allowedRoles, [TopologyParticipation.endpoint]);
  });

  test('invalid environment and topology policies are rejected before publication',
      () {
    final invalidEnvironment = EnvironmentConstraintProfile(
      allowedClasses: const [EnvironmentClass.indoor],
      minimumTemperatureC: 40,
      maximumTemperatureC: 10,
    );
    final invalidTopology = TopologyConstraintProfile(
      allowedShapes: const [TopologyShape.star],
      allowedRoles: const [TopologyParticipation.endpoint],
      closedLoopRequired: true,
    );

    expect(invalidEnvironment.validate(), isNotEmpty);
    expect(invalidTopology.validate(), isNotEmpty);
  });

  test('revision impact tells engineer whether placement or connections are affected',
      () {
    final previous = fixture().profile('CAMERA');
    final changedPort = EngineeringPort.fromMap({
      ...previous.portTemplates.first.toMap(),
      'capacity': previous.portTemplates.first.capacity + 1,
    });
    final candidate = ComponentEngineeringProfile.fromMap({
      ...previous.toMap(),
      'portTemplates': [
        changedPort.toMap(),
        ...previous.portTemplates.skip(1).map((p) => p.toMap()),
      ],
    });

    final impact = compareEngineeringProfileRevisions(
      previous: previous,
      candidate: candidate,
      previousConstraints: cameraConstraints(),
      candidateConstraints: cameraConstraints(outdoor: true, loop: true),
    );

    expect(impact.changed, isTrue);
    expect(impact.affectsConnections, isTrue);
    expect(impact.affectsPlacement, isTrue);
    expect(
      impact.changes.map((c) => c.kind),
      containsAll([
        ProfileRevisionChangeKind.ports,
        ProfileRevisionChangeKind.environment,
        ProfileRevisionChangeKind.topology,
      ]),
    );
  });

  test('unchanged revision produces an empty impact', () {
    final profile = fixture().profile('OUTLET');
    final impact = compareEngineeringProfileRevisions(
      previous: profile,
      candidate: ComponentEngineeringProfile.fromMap(profile.toMap()),
    );

    expect(impact.changed, isFalse);
    expect(impact.affectsConnections, isFalse);
    expect(impact.affectsPlacement, isFalse);
  });
}
