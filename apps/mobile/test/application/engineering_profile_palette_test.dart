import 'package:electra_mobile/application/engineering_profile_palette.dart';
import 'package:engineering_core/engineering_core.dart';
import 'package:flutter_test/flutter_test.dart';
import '../support/engineering_palette_fixture.dart';

void main() {
  test(
    'palette uses exact system family editions and typed discipline, never labels',
    () {
      final s = paletteSnapshot();
      for (final pair
          in {
            'CCTV': 'CAMERA',
            'LAN': 'OUTLET',
            'ACS': 'READER',
            'FIRE': 'DETECTOR',
          }.entries) {
        final values = canonicalPaletteChoices(s, 'p1', pair.key);
        expect(values.map((c) => c.profile.code), contains(pair.value));
        expect(
          values.every(
            (c) => c.profile.discipline.name == pair.key.toLowerCase(),
          ),
          isTrue,
        );
        final choice = values.singleWhere((c) => c.profile.code == pair.value);
        final result = const PlacementCompatibilityEngine().evaluate(
          profile: choice.profile,
          catalogId: choice.catalog.id,
          catalogVersion: choice.catalog.version,
          context: knownCandidate(pair.value),
        );
        expect(result.status, PlacementCompatibilityStatus.compatible);
        expect(result.catalogId, choice.catalog.id);
        expect(isCurrentPaletteChoice(choice, s, 'p1'), isTrue);
      }
      final cctv = s.systems.systems.first;
      final wrong = EngineeringSystem.fromMap({
        ...cctv.toMap(),
        'familyVersion': '2',
        'name': 'CCTV',
      });
      expect(
        canonicalPaletteChoices(
          paletteSnapshot(systems: [wrong]),
          'p1',
          'CCTV',
        ),
        isEmpty,
      );
      final namedCamera = EngineeringSystem.fromMap({
        ...cctv.toMap(),
        'familyId':
            bundledEngineeringSystemFamilies
                .singleWhere((f) => f.code == 'LAN')
                .id,
        'name': 'CCTV Camera',
      });
      expect(
        canonicalPaletteChoices(
          paletteSnapshot(systems: [namedCamera]),
          'p1',
          'CCTV',
        ).map((c) => c.profile.code),
        ['OUTLET'],
      );
      expect(canonicalPaletteChoices(s, 'other', 'CCTV'), isEmpty);
    },
  );
  test(
    'selection invalidates on archive, edition replacement and changed system topology',
    () {
      final s = paletteSnapshot(),
          choice =
              canonicalPaletteChoices(paletteSnapshot(), 'p1', 'CCTV').single;
      expect(
        isCurrentPaletteChoice(choice, paletteSnapshot(systems: []), 'p1'),
        isFalse,
      );
      final newer = EngineeringReferenceCatalog.fromMap({
        ...choice.catalog.toMap(),
        'id': 'v2',
        'version': '2',
      });
      expect(
        isCurrentPaletteChoice(choice, paletteSnapshot(catalog: newer), 'p1'),
        isFalse,
      );
      final updated = EngineeringSystem.fromMap({
        ...choice.system.toMap(),
        'topologyProfile': {'id': 'star', 'version': '2'},
      });
      expect(
        isCurrentPaletteChoice(
          choice,
          paletteSnapshot(systems: [updated]),
          'p1',
        ),
        isFalse,
      );
      expect(isCurrentPaletteChoice(choice, s, 'p1'), isTrue);
    },
  );
  test('system topology resolves exact project identity and edition only', () {
    final s = EngineeringSystem.fromMap({
      ...paletteSnapshot().systems.systems.first.toMap(),
      'topologyProfile': {'id': 't', 'version': '1'},
    });
    TopologyProfile profile(String project, String version) => TopologyProfile(
      identity: ProfileIdentity(
        id: 't',
        projectId: project,
        code: 'T',
        version: version,
        source: 'fictional',
      ),
      shape: TopologyShape.star,
      layer: TraceLayer.data,
    );
    expect(resolvePaletteTopology(s, [profile('p1', '2')]), isNull);
    expect(resolvePaletteTopology(s, [profile('other', '1')]), isNull);
    expect(resolvePaletteTopology(s, [profile('p1', '1')]), TopologyShape.star);
    final unknown = emptyPaletteContext(
      projectId: 'p1',
      roomId: 'r1',
      surfaceId: 'surface with camera label',
    );
    expect(unknown.installationSurface, isNull);
    expect(unknown.environmentExposure, isNull);
    expect(unknown.mountingMethod, isNull);
  });
}
