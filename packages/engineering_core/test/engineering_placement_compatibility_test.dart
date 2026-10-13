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

PlacementCandidateContext compatibleContextFor(String profileCode) {
  switch (profileCode) {
    case 'CAMERA':
      return PlacementCandidateContext(
        projectId: 'p1',
        roomId: 'r1',
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
    case 'OUTLET':
      return PlacementCandidateContext(
        projectId: 'p1',
        roomId: 'r1',
        surfaceId: 'wall-2',
        installationSurface: InstallationSurface.wall,
        mountingMethod: MountingMethod.flush,
        environmentExposure: EnvironmentExposure.indoor,
        environmentClimate: EnvironmentClimate.conditioned,
        actualIpRating: IpProtectionClass.parse('IP20'),
        topologyShape: TopologyShape.star,
        topologyRole: TopologyParticipation.endpoint,
      );
    case 'READER':
      return PlacementCandidateContext(
        projectId: 'p1',
        roomId: 'r1',
        surfaceId: 'wall-3',
        installationSurface: InstallationSurface.wall,
        mountingMethod: MountingMethod.surface,
        environmentExposure: EnvironmentExposure.protectedOutdoor,
        environmentClimate: EnvironmentClimate.unconditioned,
        actualIpRating: IpProtectionClass.parse('IP55'),
        topologyShape: TopologyShape.star,
        topologyRole: TopologyParticipation.endpoint,
      );
    case 'DETECTOR':
      return PlacementCandidateContext(
        projectId: 'p1',
        roomId: 'r1',
        surfaceId: 'ceiling-1',
        installationSurface: InstallationSurface.ceiling,
        mountingMethod: MountingMethod.surface,
        environmentExposure: EnvironmentExposure.indoor,
        environmentClimate: EnvironmentClimate.conditioned,
        actualIpRating: IpProtectionClass.parse('IP20'),
        topologyShape: TopologyShape.loop,
        topologyRole: TopologyParticipation.endpoint,
      );
    default:
      throw ArgumentError(profileCode);
  }
}

PlacementCompatibilityResult evaluate(
  ComponentEngineeringProfile profile,
  PlacementCandidateContext context,
) =>
    const PlacementCompatibilityEngine().evaluate(
      profile: profile,
      catalogId: 'catalog-v1',
      catalogVersion: '1',
      context: context,
    );

void main() {
  group('PlacementCompatibilityEngine', () {
    test('uses one discipline-agnostic engine for CCTV LAN ACS and Fire', () {
      final catalog = fixture();

      for (final code in ['CAMERA', 'OUTLET', 'READER', 'DETECTOR']) {
        final result = evaluate(
          catalog.profile(code),
          compatibleContextFor(code),
        );
        expect(result.status, PlacementCompatibilityStatus.compatible,
            reason: code);
        expect(result.findings, isEmpty, reason: code);
      }
    });

    test('rejects a surface-method pair not declared by the profile', () {
      final profile = fixture().profile('CAMERA');
      final result = evaluate(
        profile,
        PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'wall-1',
          installationSurface: InstallationSurface.wall,
          mountingMethod: MountingMethod.surface,
          environmentExposure: EnvironmentExposure.indoor,
          environmentClimate: EnvironmentClimate.conditioned,
          ambientTemperatureC: 20,
          actualIpRating: IpProtectionClass.parse('IP54'),
          availableClearanceMm: 60,
          topologyShape: TopologyShape.star,
          topologyRole: TopologyParticipation.endpoint,
        ),
      );

      expect(result.status, PlacementCompatibilityStatus.forbidden);
      expect(
        result.findings.map((finding) => finding.code),
        contains(PlacementFindingCode.mountingCombinationNotAllowed),
      );
    });

    test('enforces enclosure and minimum clearance independently', () {
      final base = fixture().profile('OUTLET');
      final constrained = ComponentEngineeringProfile.fromMap({
        ...base.toMap(),
        'constraints': {
          ...base.constraints!.toMap(),
          'mounting': {
            'options': [
              {'surface': 'enclosure', 'method': 'insideEnclosure'}
            ],
            'enclosureRequired': true,
            'minimumClearanceMm': 100,
          },
        },
      });

      final result = evaluate(
        constrained,
        PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'cabinet-1',
          installationSurface: InstallationSurface.enclosure,
          mountingMethod: MountingMethod.insideEnclosure,
          environmentExposure: EnvironmentExposure.indoor,
          environmentClimate: EnvironmentClimate.conditioned,
          actualIpRating: IpProtectionClass.parse('IP20'),
          hasEnclosure: false,
          availableClearanceMm: 80,
          topologyShape: TopologyShape.star,
          topologyRole: TopologyParticipation.endpoint,
        ),
      );

      expect(result.status, PlacementCompatibilityStatus.forbidden);
      expect(
        result.findings.map((finding) => finding.code),
        containsAll([
          PlacementFindingCode.enclosureRequired,
          PlacementFindingCode.clearanceInsufficient,
        ]),
      );
    });

    test('returns unresolved when required placement evidence is missing', () {
      final result = evaluate(
        fixture().profile('CAMERA'),
        const PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'unknown',
        ),
      );

      expect(result.status, PlacementCompatibilityStatus.unresolved);
      expect(
        result.findings.map((finding) => finding.code),
        containsAll([
          PlacementFindingCode.mountingContextIncomplete,
          PlacementFindingCode.environmentExposureUnresolved,
          PlacementFindingCode.environmentClimateUnresolved,
          PlacementFindingCode.ambientTemperatureUnresolved,
          PlacementFindingCode.ipProtectionUnresolved,
          PlacementFindingCode.topologyShapeUnresolved,
          PlacementFindingCode.topologyRoleUnresolved,
        ]),
      );
    });

    test('legacy unspecified constraints never mean compatible', () {
      final base = fixture().profile('OUTLET');
      final map = Map<String, dynamic>.from(base.toMap());
      map.remove('constraints');
      map.remove('constraintsState');
      final legacy = ComponentEngineeringProfile.fromMap(map);

      final result = evaluate(legacy, compatibleContextFor('OUTLET'));

      expect(result.status, PlacementCompatibilityStatus.unresolved);
      expect(result.findings.single.code,
          PlacementFindingCode.legacyConstraintsUnspecified);
    });

    test('malformed defined constraints are not classified as legacy', () {
      final base = fixture().profile('OUTLET');
      final malformed = ComponentEngineeringProfile(
        code: base.code,
        label: base.label,
        engineeringClass: base.engineeringClass,
        characteristics: base.characteristics,
        capabilities: base.capabilities,
        portTemplates: base.portTemplates,
        portInterfaceCodes: base.portInterfaceCodes,
        constraintsState: ProfileConstraintsState.defined,
      );

      final result = evaluate(malformed, compatibleContextFor('OUTLET'));

      expect(result.status, PlacementCompatibilityStatus.unresolved);
      expect(
        result.findings.single.code,
        PlacementFindingCode.profileConstraintsInvalid,
      );
    });

    test('checks all environment dimensions with structured findings', () {
      final base = fixture().profile('OUTLET');
      final constrained = ComponentEngineeringProfile.fromMap({
        ...base.toMap(),
        'constraints': {
          ...base.constraints!.toMap(),
          'environment': {
            'allowedExposure': ['indoor'],
            'allowedMoisture': ['dry'],
            'allowedContamination': ['normal'],
            'allowedClimate': ['conditioned'],
            'minimumIpRating': 'IP54',
            'minimumTemperatureC': -5,
            'maximumTemperatureC': 40,
          },
        },
      });

      final result = evaluate(
        constrained,
        PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'wall-2',
          installationSurface: InstallationSurface.wall,
          mountingMethod: MountingMethod.flush,
          environmentExposure: EnvironmentExposure.protectedOutdoor,
          environmentMoisture: EnvironmentMoisture.wet,
          environmentContamination: EnvironmentContamination.dusty,
          environmentClimate: EnvironmentClimate.unconditioned,
          ambientTemperatureC: 50,
          actualIpRating: IpProtectionClass.parse('IP44'),
          topologyShape: TopologyShape.star,
          topologyRole: TopologyParticipation.endpoint,
        ),
      );

      expect(result.status, PlacementCompatibilityStatus.forbidden);
      expect(
        result.findings.map((finding) => finding.code),
        containsAll([
          PlacementFindingCode.environmentExposureNotAllowed,
          PlacementFindingCode.environmentMoistureNotAllowed,
          PlacementFindingCode.environmentContaminationNotAllowed,
          PlacementFindingCode.environmentClimateNotAllowed,
          PlacementFindingCode.temperatureAboveMaximum,
          PlacementFindingCode.ipProtectionInsufficient,
        ]),
      );
    });

    test('accepts exact temperature boundaries and sufficient IP rating', () {
      final profile = fixture().profile('CAMERA');
      final low = evaluate(
        profile,
        PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'wall-1',
          installationSurface: InstallationSurface.wall,
          mountingMethod: MountingMethod.bracket,
          environmentExposure: EnvironmentExposure.indoor,
          environmentClimate: EnvironmentClimate.conditioned,
          ambientTemperatureC: -10,
          actualIpRating: IpProtectionClass.parse('IP55'),
          availableClearanceMm: 50,
          topologyShape: TopologyShape.star,
          topologyRole: TopologyParticipation.endpoint,
        ),
      );
      final high = evaluate(
        profile,
        PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'wall-1',
          installationSurface: InstallationSurface.wall,
          mountingMethod: MountingMethod.bracket,
          environmentExposure: EnvironmentExposure.indoor,
          environmentClimate: EnvironmentClimate.conditioned,
          ambientTemperatureC: 50,
          actualIpRating: IpProtectionClass.parse('IP64'),
          availableClearanceMm: 50,
          topologyShape: TopologyShape.star,
          topologyRole: TopologyParticipation.endpoint,
        ),
      );

      expect(low.status, PlacementCompatibilityStatus.compatible);
      expect(high.status, PlacementCompatibilityStatus.compatible);
    });

    test('unknown numeric IP evidence remains unresolved', () {
      final result = evaluate(
        fixture().profile('CAMERA'),
        PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'wall-1',
          installationSurface: InstallationSurface.wall,
          mountingMethod: MountingMethod.bracket,
          environmentExposure: EnvironmentExposure.indoor,
          environmentClimate: EnvironmentClimate.conditioned,
          ambientTemperatureC: 20,
          actualIpRating: IpProtectionClass.parse('IPX4'),
          availableClearanceMm: 50,
          topologyShape: TopologyShape.star,
          topologyRole: TopologyParticipation.endpoint,
        ),
      );

      expect(result.status, PlacementCompatibilityStatus.unresolved);
      expect(
        result.findings.map((finding) => finding.code),
        contains(PlacementFindingCode.ipProtectionUnresolved),
      );
    });

    test('rejects incompatible topology intent without inspecting graph state',
        () {
      final result = evaluate(
        fixture().profile('DETECTOR'),
        PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'ceiling-1',
          installationSurface: InstallationSurface.ceiling,
          mountingMethod: MountingMethod.surface,
          environmentExposure: EnvironmentExposure.indoor,
          environmentClimate: EnvironmentClimate.conditioned,
          actualIpRating: IpProtectionClass.parse('IP20'),
          topologyShape: TopologyShape.star,
          topologyRole: TopologyParticipation.branch,
        ),
      );

      expect(result.status, PlacementCompatibilityStatus.forbidden);
      expect(
        result.findings.map((finding) => finding.code),
        containsAll([
          PlacementFindingCode.topologyShapeNotAllowed,
          PlacementFindingCode.topologyRoleNotAllowed,
        ]),
      );
    });

    test('finding order is deterministic and errors dominate unresolved state',
        () {
      final result = evaluate(
        fixture().profile('CAMERA'),
        const PlacementCandidateContext(
          projectId: 'p1',
          roomId: 'r1',
          surfaceId: 'wall-1',
          installationSurface: InstallationSurface.floor,
          mountingMethod: MountingMethod.surface,
        ),
      );

      expect(result.status, PlacementCompatibilityStatus.forbidden);
      expect(
        result.findings.map((finding) => finding.code).toList(),
        [
          PlacementFindingCode.mountingCombinationNotAllowed,
          PlacementFindingCode.clearanceUnresolved,
          PlacementFindingCode.environmentExposureUnresolved,
          PlacementFindingCode.environmentClimateUnresolved,
          PlacementFindingCode.ambientTemperatureUnresolved,
          PlacementFindingCode.ipProtectionUnresolved,
          PlacementFindingCode.topologyShapeUnresolved,
          PlacementFindingCode.topologyRoleUnresolved,
        ],
      );
    });
  });
}
