import 'package:engineering_core/engineering_core.dart';

import 'engineering_reference_repository.dart';

/// Session selection only: it never creates a component, port or binding.
class CanonicalProfileChoice {
  const CanonicalProfileChoice({
    required this.system,
    required this.catalog,
    required this.profile,
  });
  final EngineeringSystem system;
  final EngineeringReferenceCatalog catalog;
  final ComponentEngineeringProfile profile;
  String get identity =>
      '${system.id}/${catalog.id}/${catalog.version}/${profile.code}';
}

ReferenceDiscipline? paletteDiscipline(
  EngineeringSystem system,
  Iterable<EngineeringSystemFamily> families,
) {
  final family = families
      .where(
        (f) => f.id == system.familyId && f.version == system.familyVersion,
      )
      .firstOrNull;
  return switch (family?.code) {
    'CCTV' => ReferenceDiscipline.cctv,
    'LAN' => ReferenceDiscipline.lan,
    'ACS' => ReferenceDiscipline.acs,
    'FIRE' => ReferenceDiscipline.fire,
    _ => null,
  };
}

List<CanonicalProfileChoice> canonicalPaletteChoices(
  ProjectEngineeringReferences snapshot,
  String projectId,
  String systemId,
) {
  if (snapshot.systems.project?.id != projectId) return [];
  final system = snapshot.systems.systems
      .where((s) => s.id == systemId && s.projectId == projectId)
      .firstOrNull;
  if (system == null) return [];
  final discipline = paletteDiscipline(system, snapshot.systems.families);
  if (discipline == null) return [];
  return [
    for (final catalog in snapshot.catalogs)
      for (final profile in catalog.profiles)
        if (profile.discipline == discipline)
          CanonicalProfileChoice(
            system: system,
            catalog: catalog,
            profile: profile,
          ),
  ]..sort(
    (
      a,
      b,
    ) => '${a.profile.engineeringClass.name}/${a.profile.code}/${a.catalog.code}/${a.catalog.version}/${a.catalog.id}'
        .compareTo(
          '${b.profile.engineeringClass.name}/${b.profile.code}/${b.catalog.code}/${b.catalog.version}/${b.catalog.id}',
        ),
  );
}

bool isCurrentPaletteChoice(
  CanonicalProfileChoice choice,
  ProjectEngineeringReferences? snapshot,
  String projectId,
) =>
    snapshot != null &&
    canonicalPaletteChoices(snapshot, projectId, choice.system.id).any(
      (c) =>
          c.identity == choice.identity &&
          canonicalEngineeringJson(c.profile.toMap()) ==
              canonicalEngineeringJson(choice.profile.toMap()) &&
          canonicalEngineeringJson(c.catalog.toMap()) ==
              canonicalEngineeringJson(choice.catalog.toMap()) &&
          canonicalEngineeringJson(c.system.toMap()) ==
              canonicalEngineeringJson(choice.system.toMap()),
    );

TopologyShape? resolvePaletteTopology(
  EngineeringSystem system,
  Iterable<TopologyProfile> profiles,
) {
  final ref = system.topologyProfile;
  if (ref == null) return null;
  return profiles
      .where(
        (p) =>
            p.id == ref.id &&
            p.identity.version == ref.version &&
            p.identity.projectId == system.projectId &&
            p.validate().isEmpty,
      )
      .firstOrNull
      ?.shape;
}

PlacementCandidateContext emptyPaletteContext({
  required String projectId,
  required String roomId,
  required String surfaceId,
  TopologyShape? topologyShape,
}) => PlacementCandidateContext(
  projectId: projectId,
  roomId: roomId,
  surfaceId: surfaceId,
  topologyShape: topologyShape,
);
