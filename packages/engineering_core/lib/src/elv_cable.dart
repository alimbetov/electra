import 'elv_cable_reference.dart';

enum CableLifecycleState { active, archived }

final class Cable {
  const Cable({
    required this.id,
    required this.projectId,
    required this.label,
    required this.name,
    required this.definitionRef,
    required this.lifecycleState,
    required this.revision,
  });

  final String id;
  final String projectId;
  final String label;
  final String name;
  final CableDefinitionRef definitionRef;
  final CableLifecycleState lifecycleState;
  final int revision;

  String get normalizedLabel => label.trim().toUpperCase();

  List<String> validate() => [
    if (id.trim().isEmpty) 'Cable id is required.',
    if (projectId.trim().isEmpty) 'Cable projectId is required.',
    if (label.trim().isEmpty) 'Cable label is required.',
    if (name.trim().isEmpty) 'Cable name is required.',
    if (revision < 1) 'Cable revision must be >= 1.',
    ...definitionRef.validate(),
  ];

  Map<String, Object?> toMap() => {
    'id': id,
    'projectId': projectId,
    'label': label,
    'name': name,
    'definitionRef': definitionRef.toMap(),
    'lifecycleState': lifecycleState.name,
    'revision': revision,
  };

  factory Cable.fromMap(Map<String, dynamic> map) => Cable(
    id: map['id'] as String,
    projectId: map['projectId'] as String,
    label: map['label'] as String,
    name: map['name'] as String,
    definitionRef: CableDefinitionRef.fromMap(
      map['definitionRef'] as Map<String, dynamic>,
    ),
    lifecycleState: CableLifecycleState.values.byName(
      map['lifecycleState'] as String,
    ),
    revision: map['revision'] as int,
  );
}
