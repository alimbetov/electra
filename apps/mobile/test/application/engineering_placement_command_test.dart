import 'package:electra_mobile/application/engineering_placement_command.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PlaceEngineeringProfileCommand', () {
    test('accepts canonical P4 command shape', () {
      final command = _command();

      expect(command.validate(), isEmpty);
      expect(command.normalizedMembershipRole, canonicalElvMembershipRole);
      expect(command.normalizedDisplayNameOverride, 'Camera A');
    });

    test('rejects context identity mismatches and invalid role', () {
      final command = _command(
        membershipRole: 'endpoint',
        context: _context(projectId: 'other-project', surfaceId: 'other-patch'),
      );

      final failures = command.validate();
      expect(failures, hasLength(3));
      expect(
        failures.map((failure) => failure.code).toSet(),
        {EngineeringPlacementFailureCode.invalidCommand},
      );
    });

    test('rejects non-finite engineering evidence', () {
      final command = _command(
        rotationRadians: double.infinity,
        context: _context(ambientTemperatureC: double.nan),
      );

      expect(command.validate(), hasLength(2));
    });
  });

  group('engineeringPlacementFingerprintV1', () {
    test('is deterministic and SHA-256 shaped', () {
      final first = engineeringPlacementFingerprintV1(_command());
      final second = engineeringPlacementFingerprintV1(_command());

      expect(first, second);
      expect(first, matches(RegExp(r'^[0-9a-f]{64}$')));
    });

    test('normalizes negative zero to positive zero', () {
      final positive = engineeringPlacementFingerprintV1(
        _command(rotationRadians: 0.0),
      );
      final negative = engineeringPlacementFingerprintV1(
        _command(rotationRadians: -0.0),
      );

      expect(negative, positive);
    });

    test('changes for material command evidence', () {
      final base = engineeringPlacementFingerprintV1(_command());
      final moved = engineeringPlacementFingerprintV1(
        _command(localPosition: const Point2Mm(121, 80)),
      );
      final renamed = engineeringPlacementFingerprintV1(
        _command(displayNameOverride: 'Camera B'),
      );
      final wetter = engineeringPlacementFingerprintV1(
        _command(context: _context(moisture: EnvironmentMoisture.damp)),
      );

      expect(moved, isNot(base));
      expect(renamed, isNot(base));
      expect(wetter, isNot(base));
    });

    test('rejects invalid commands instead of fingerprinting them', () {
      expect(
        () => engineeringPlacementFingerprintV1(
          _command(membershipRole: 'endpoint'),
        ),
        throwsA(
          isA<EngineeringPlacementFailure>().having(
            (failure) => failure.code,
            'code',
            EngineeringPlacementFailureCode.invalidCommand,
          ),
        ),
      );
    });
  });

  test('EngineeringPlacementResult freezes port ids', () {
    final mutable = <String>['port-1'];
    final result = EngineeringPlacementResult(
      operationId: 'op-1',
      componentId: 'component-1',
      systemId: 'system-1',
      membershipRole: canonicalElvMembershipRole,
      catalogId: 'catalog-1',
      catalogVersion: '1',
      profileCode: 'CAMERA',
      bindingComponentId: 'component-1',
      portIds: mutable,
      placementStatus: PlacementCompatibilityStatus.compatible,
      committedAt: DateTime.utc(2026, 10, 13),
    );

    mutable.add('port-2');
    expect(result.portIds, ['port-1']);
    expect(() => result.portIds.add('port-3'), throwsUnsupportedError);
  });

  test('EngineeringPlacementFailure freezes structured details', () {
    final details = <String, Object?>{'field': 'profileCode'};
    final failure = EngineeringPlacementFailure(
      code: EngineeringPlacementFailureCode.profileNotFound,
      message: 'Profile does not exist.',
      details: details,
    );

    details['field'] = 'changed';
    expect(failure.details['field'], 'profileCode');
    expect(
      () => failure.details['other'] = 'value',
      throwsUnsupportedError,
    );
  });
}

PlaceEngineeringProfileCommand _command({
  String membershipRole = canonicalElvMembershipRole,
  Point2Mm localPosition = const Point2Mm(120, 80),
  double rotationRadians = 0.25,
  PlacementCandidateContext? context,
  String? displayNameOverride = '  Camera A  ',
}) => PlaceEngineeringProfileCommand(
  operationId: 'op-1',
  projectId: 'project-1',
  roomId: 'room-1',
  systemId: 'system-1',
  membershipRole: membershipRole,
  catalogId: 'catalog-1',
  catalogVersion: '1.0.0',
  profileCode: 'CAMERA',
  hostSurfacePatchId: 'patch-1',
  localPosition: localPosition,
  rotationRadians: rotationRadians,
  placementContext: context ?? _context(),
  displayNameOverride: displayNameOverride,
);

PlacementCandidateContext _context({
  String projectId = 'project-1',
  String roomId = 'room-1',
  String surfaceId = 'patch-1',
  EnvironmentMoisture moisture = EnvironmentMoisture.dry,
  double ambientTemperatureC = 20,
}) => PlacementCandidateContext(
  projectId: projectId,
  roomId: roomId,
  surfaceId: surfaceId,
  installationSurface: InstallationSurface.wall,
  mountingMethod: MountingMethod.bracket,
  environmentExposure: EnvironmentExposure.indoor,
  environmentMoisture: moisture,
  environmentContamination: EnvironmentContamination.normal,
  environmentClimate: EnvironmentClimate.conditioned,
  ambientTemperatureC: ambientTemperatureC,
  actualIpRating: IpProtectionClass.parse('IP54'),
  hasEnclosure: false,
  availableClearanceMm: 50,
  topologyShape: TopologyShape.star,
  topologyRole: TopologyParticipation.endpoint,
);
