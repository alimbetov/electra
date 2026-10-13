import 'engineering_reference_catalog.dart';
import 'engineering_topology.dart';

enum ProfileRevisionChangeKind {
  discipline,
  engineeringClass,
  capabilities,
  ports,
  interfaces,
  characteristics,
  mounting,
  environment,
  topology,
  lifecycle,
  constraintsState,
}

class ProfileRevisionChange {
  const ProfileRevisionChange({
    required this.kind,
    required this.summary,
    required this.connectionRelevant,
    required this.placementRelevant,
  });

  final ProfileRevisionChangeKind kind;
  final String summary;
  final bool connectionRelevant;
  final bool placementRelevant;
}

class ProfileRevisionImpact {
  ProfileRevisionImpact({required Iterable<ProfileRevisionChange> changes})
      : changes = List.unmodifiable(changes);

  final List<ProfileRevisionChange> changes;

  bool get changed => changes.isNotEmpty;
  bool get affectsConnections => changes.any((change) => change.connectionRelevant);
  bool get affectsPlacement => changes.any((change) => change.placementRelevant);
}

ProfileRevisionImpact compareEngineeringProfileRevisions({
  required ComponentEngineeringProfile previous,
  required ComponentEngineeringProfile candidate,
}) {
  final changes = <ProfileRevisionChange>[];

  void add(
    ProfileRevisionChangeKind kind,
    String summary, {
    bool connection = false,
    bool placement = false,
  }) {
    changes.add(
      ProfileRevisionChange(
        kind: kind,
        summary: summary,
        connectionRelevant: connection,
        placementRelevant: placement,
      ),
    );
  }

  if (previous.discipline != candidate.discipline) {
    add(
      ProfileRevisionChangeKind.discipline,
      'Discipline changed.',
      connection: true,
      placement: true,
    );
  }
  if (previous.engineeringClass != candidate.engineeringClass) {
    add(
      ProfileRevisionChangeKind.engineeringClass,
      'Engineering class changed.',
      connection: true,
      placement: true,
    );
  }
  if (!_sameNames(previous.capabilities, candidate.capabilities)) {
    add(
      ProfileRevisionChangeKind.capabilities,
      'Capability set changed.',
      connection: true,
    );
  }
  if (!_samePortTemplates(previous.portTemplates, candidate.portTemplates)) {
    add(
      ProfileRevisionChangeKind.ports,
      'Port templates changed.',
      connection: true,
    );
  }
  if (!_sameStringMap(previous.portInterfaceCodes, candidate.portInterfaceCodes)) {
    add(
      ProfileRevisionChangeKind.interfaces,
      'Port interface bindings changed.',
      connection: true,
    );
  }
  if (!_mapEquals(
    previous.characteristics.toMap(),
    candidate.characteristics.toMap(),
  )) {
    add(
      ProfileRevisionChangeKind.characteristics,
      'Discipline engineering characteristics changed.',
    );
  }
  if (previous.deprecated != candidate.deprecated) {
    add(
      ProfileRevisionChangeKind.lifecycle,
      'Profile lifecycle state changed.',
      placement: true,
    );
  }
  if (previous.constraintsState != candidate.constraintsState) {
    add(
      ProfileRevisionChangeKind.constraintsState,
      'Constraint provenance state changed.',
      placement: true,
      connection: true,
    );
  }

  final previousConstraints = previous.constraints;
  final candidateConstraints = candidate.constraints;
  if (previousConstraints != null || candidateConstraints != null) {
    if (!_mapEquals(
      previousConstraints?.mounting.toMap(),
      candidateConstraints?.mounting.toMap(),
    )) {
      add(
        ProfileRevisionChangeKind.mounting,
        'Mounting constraints changed.',
        placement: true,
      );
    }
    if (!_mapEquals(
      previousConstraints?.environment.toMap(),
      candidateConstraints?.environment.toMap(),
    )) {
      add(
        ProfileRevisionChangeKind.environment,
        'Environment constraints changed.',
        placement: true,
      );
    }
    if (!_mapEquals(
      previousConstraints?.topology.toMap(),
      candidateConstraints?.topology.toMap(),
    )) {
      add(
        ProfileRevisionChangeKind.topology,
        'Topology constraints changed.',
        connection: true,
      );
    }
  }

  return ProfileRevisionImpact(changes: changes);
}

bool _sameNames(Iterable<Enum> a, Iterable<Enum> b) {
  final left = a.map((value) => value.name).toList()..sort();
  final right = b.map((value) => value.name).toList()..sort();
  return _sameStrings(left, right);
}

bool _samePortTemplates(
  Iterable<EngineeringPort> a,
  Iterable<EngineeringPort> b,
) {
  final left = a.toList()..sort((x, y) => x.code.compareTo(y.code));
  final right = b.toList()..sort((x, y) => x.code.compareTo(y.code));
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (!_mapEquals(left[index].toMap(), right[index].toMap())) return false;
  }
  return true;
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (b[entry.key] != entry.value) return false;
  }
  return true;
}

bool _mapEquals(Map<String, Object?>? a, Map<String, Object?>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || !_valueEquals(a[key], b[key])) return false;
  }
  return true;
}

bool _valueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return _mapEquals(a.cast<String, Object?>(), b.cast<String, Object?>());
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!_valueEquals(a[index], b[index])) return false;
    }
    return true;
  }
  return a == b;
}
