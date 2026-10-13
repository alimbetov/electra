import 'dart:convert';
import 'dart:io';

import 'package:engineering_core/engineering_core.dart';
import 'package:test/test.dart';

EngineeringReferenceCatalog fixture() => EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );

EngineeringProfileConstraints cameraConstraints({
  bool outdoor = false,
  bool loop = false,
}) =>
    EngineeringProfileConstraints(
      mounting: MountingConstraintProfile(
        options: const [
          MountingOption(
            surface: InstallationSurface.wall,
            method: MountingMethod.bracket,
          ),
          MountingOption(
            surface: InstallationSurface.ceiling,
            method: MountingMethod.surface,
          ),
        ],
        minimumClearanceMm: 50,
      ),
      environment: EnvironmentConstraintProfile(
        allowedExposure: [
          EnvironmentExposure.indoor,
          if (outdoor) EnvironmentExposure.exposedOutdoor,
        ],
        allowedClimate: const [EnvironmentClimate.conditioned],
        minimumIpRating: IpProtectionClass.parse(outdoor ? 'IP66' : 'IP20'),
        minimumTemperatureC: outdoor ? -40 : 0,
        maximumTemperatureC: 50,
      ),
      topology: TopologyConstraintProfile(
        allowedShapes: [TopologyShape.star, if (loop) TopologyShape.loop],
        allowedRoles: const [TopologyParticipation.endpoint],
        branchingAllowed: false,
      ),
    );

ComponentEngineeringProfile legacyProfile(String code) {
  final map = Map<String, dynamic>.from(fixture().profile(code).toMap())
    ..remove('constraints')
    ..remove('constraintsState');
  return ComponentEngineeringProfile.fromMap(map);
}

void main() {
  test('typed constraint contract roundtrips exact mounting pairs and IP value', () {
    final constraints = cameraConstraints(outdoor: true);
    expect(constraints.validate(), isEmpty);

    final restored = EngineeringProfileConstraints.fromMap(
      jsonDecode(jsonEncode(constraints.toMap())) as Map<String, dynamic>,
    );

    expect(
      restored.mounting.allows(
        InstallationSurface.wall,
        MountingMethod.bracket,
      ),
      isTrue,
    );
    expect(
      restored.mounting.allows(
        InstallationSurface.wall,
        MountingMethod.surface,
      ),
      isFalse,
    );
    expect(
      restored.environment.allowedExposure,
      contains(EnvironmentExposure.exposedOutdoor),
    );
    expect(restored.environment.minimumIpRating?.value, 'IP66');
  });

  test('invalid IP, environment range and topology policy are rejected', () {
    expect(() => IpProtectionClass.parse('hello'), throwsFormatException);

    final invalidEnvironment = EnvironmentConstraintProfile(
      allowedExposure: const [EnvironmentExposure.indoor],
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

  test('legacy profile remains readable but cannot be published or instantiated', () {
    final legacy = legacyProfile('CAMERA');

    expect(legacy.constraintsState, ProfileConstraintsState.legacyUnspecified);
    expect(legacy.constraints, isNull);
    expect(legacy.validate(), isEmpty);
    expect(legacy.validateForPublication(), isNotEmpty);
    expect(
      () => legacy.instantiate(
        componentId: 'camera',
        catalogId: 'legacy',
        version: '1',
        nextId: () => 'p1',
      ),
      throwsStateError,
    );
  });

  test('embedded constraints participate in self-contained revision impact', () {
    final previous = fixture().profile('CAMERA');
    final changedPort = EngineeringPort.fromMap({
      ...previous.portTemplates.first.toMap(),
      'capacity': previous.portTemplates.first.capacity + 1,
    });
    final candidate = ComponentEngineeringProfile.fromMap({
      ...previous.toMap(),
      'constraints': cameraConstraints(outdoor: true, loop: true).toMap(),
      'portTemplates': [changedPort.toMap()],
    });

    final impact = compareEngineeringProfileRevisions(
      previous: previous,
      candidate: candidate,
    );

    expect(impact.changed, isTrue);
    expect(impact.affectsConnections, isTrue);
    expect(impact.affectsPlacement, isTrue);
    expect(
      impact.changes.map((change) => change.kind),
      containsAll([
        ProfileRevisionChangeKind.ports,
        ProfileRevisionChangeKind.environment,
        ProfileRevisionChangeKind.topology,
      ]),
    );
  });

  test('port template ordering alone does not create a semantic revision', () {
    final profile = fixture().profile('DETECTOR');
    final reordered = ComponentEngineeringProfile.fromMap({
      ...profile.toMap(),
      'portTemplates': profile.portTemplates.reversed
          .map((port) => port.toMap())
          .toList(),
    });

    expect(
      compareEngineeringProfileRevisions(previous: profile, candidate: reordered)
          .changed,
      isFalse,
    );
  });
}
