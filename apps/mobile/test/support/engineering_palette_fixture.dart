import 'dart:convert';
import 'dart:io';

import 'package:electra_mobile/application/engineering_reference_repository.dart';
import 'package:electra_mobile/application/engineering_system_repository.dart';
import 'package:electra_mobile/application/geometry_repository.dart';
import 'package:electra_mobile/domain/project_models.dart';
import 'package:engineering_core/engineering_core.dart';

EngineeringReferenceCatalog paletteCatalog() =>
    EngineeringReferenceCatalog.fromMap(
      jsonDecode(
        File('../../docs/examples/elv2-reference-catalog.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>,
    );
final paletteProject = ProjectRecord(
  id: 'p1',
  name: 'Palette project',
  reference: 'P3',
  measurementSystem: MeasurementSystem.metric,
  defaultStructuralHeightMm: 3200,
  defaultFinishedCeilingHeightMm: 3000,
  revision: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  originDeviceId: 'test',
);
final paletteRoom = RoomRecord(
  id: 'r1',
  floorId: 'f1',
  name: 'Palette room',
  type: RoomType.office,
  category: RoomCategory.commercial,
  widthMm: 4000,
  depthMm: 3000,
  revision: 1,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  originDeviceId: 'test',
);
SurfacePatch palettePatch(String id) => SurfacePatch(
  id: id,
  roomId: 'r1',
  surfaceId: id,
  frame: LocalCoordinateFrame(
    origin: const Point3Mm(0, 0, 0),
    uAxis: const Vector3D(1, 0, 0),
    vAxis: const Vector3D(0, 0, 1),
  ),
  boundary: Polygon2Mm(const [
    Point2Mm(0, 0),
    Point2Mm(4000, 0),
    Point2Mm(4000, 3000),
    Point2Mm(0, 3000),
  ]),
  orientation: SurfaceOrientation.vertical,
);
final paletteGeometry = RoomGeometrySnapshot(
  roomId: 'r1',
  patches: [palettePatch('wall-1'), palettePatch('wall-2')],
);
ProjectEngineeringReferences paletteSnapshot({
  EngineeringReferenceCatalog? catalog,
  List<EngineeringSystem>? systems,
}) => ProjectEngineeringReferences(
  systems: ProjectEngineeringSystemsSnapshot(
    project: paletteProject,
    families: bundledEngineeringSystemFamilies,
    systems:
        systems ??
        [
          for (final code in ['CCTV', 'LAN', 'ACS', 'FIRE'])
            EngineeringSystem(
              id: code,
              projectId: 'p1',
              code: code,
              name: code,
              familyId: bundledEngineeringSystemFamilies
                  .singleWhere((f) => f.code == code)
                  .id,
              familyVersion: '1',
            ),
        ],
    memberships: [],
    components: [],
  ),
  catalogs: [catalog ?? paletteCatalog()],
  bindings: [],
);
PlacementCandidateContext knownCandidate(String code) =>
    PlacementCandidateContext(
      projectId: 'p1',
      roomId: 'r1',
      surfaceId: 'wall-1',
      installationSurface: code == 'DETECTOR'
          ? InstallationSurface.ceiling
          : InstallationSurface.wall,
      mountingMethod: switch (code) {
        'CAMERA' => MountingMethod.bracket,
        'OUTLET' => MountingMethod.flush,
        _ => MountingMethod.surface,
      },
      environmentExposure: code == 'READER'
          ? EnvironmentExposure.protectedOutdoor
          : EnvironmentExposure.indoor,
      environmentClimate: code == 'READER'
          ? EnvironmentClimate.unconditioned
          : EnvironmentClimate.conditioned,
      ambientTemperatureC: 20,
      actualIpRating: IpProtectionClass.parse(
        code == 'CAMERA'
            ? 'IP54'
            : code == 'READER'
            ? 'IP55'
            : 'IP20',
      ),
      availableClearanceMm: 50,
      hasEnclosure: false,
      topologyShape: code == 'DETECTOR'
          ? TopologyShape.loop
          : TopologyShape.star,
      topologyRole: TopologyParticipation.endpoint,
    );
