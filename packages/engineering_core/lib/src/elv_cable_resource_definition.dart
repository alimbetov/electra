enum CableResourceKind {
  wholeCable,
  pair,
  conductor,
  fiber,
  coreGroup,
  shield,
  drain,
  protectiveEarth,
  functionalEarth,
}

enum TerminationPolicyMode {
  bothEnds,
  aEndOnly,
  bEndOnly,
  optional,
  groupLevel,
}

final class TerminationPolicy {
  TerminationPolicy({
    required this.mode,
    required this.terminalRequired,
    Iterable<String> allowedRoles = const [],
  }) : allowedRoles = List.unmodifiable(
          allowedRoles.map((value) => value.trim().toUpperCase()),
        );

  final TerminationPolicyMode mode;
  final bool terminalRequired;
  final List<String> allowedRoles;

  List<String> validate() => [
        if (allowedRoles.any((value) => value.isEmpty))
          'Termination roles must not be empty.',
        if (allowedRoles.toSet().length != allowedRoles.length)
          'Termination roles must be unique.',
      ];

  Map<String, Object?> toMap() => {
        'mode': mode.name,
        'terminalRequired': terminalRequired,
        'allowedRoles': allowedRoles,
      };

  factory TerminationPolicy.fromMap(Map<String, dynamic> map) =>
      TerminationPolicy(
        mode: TerminationPolicyMode.values.byName(map['mode'] as String),
        terminalRequired: map['terminalRequired'] as bool,
        allowedRoles: (map['allowedRoles'] as List? ?? const []).cast<String>(),
      );
}

final class CableResourceDefinition {
  CableResourceDefinition({
    required String identity,
    required this.kind,
    required this.allocatable,
    required this.atomic,
    required this.terminationPolicy,
    String? parentResourceId,
    Iterable<String> childResourceIds = const [],
    Iterable<String> groupMembership = const [],
  })  : identity = identity.trim().toUpperCase(),
        parentResourceId = parentResourceId?.trim().toUpperCase(),
        childResourceIds = List.unmodifiable(
          childResourceIds.map((value) => value.trim().toUpperCase()),
        ),
        groupMembership = List.unmodifiable(
          groupMembership.map((value) => value.trim().toUpperCase()),
        );

  final String identity;
  final CableResourceKind kind;
  final bool allocatable;
  final bool atomic;
  final String? parentResourceId;
  final List<String> childResourceIds;
  final List<String> groupMembership;
  final TerminationPolicy terminationPolicy;

  List<String> validateLocal() => [
        if (identity.isEmpty) 'Cable resource identity is required.',
        if (kind == CableResourceKind.wholeCable &&
            identity != '__WHOLE_CABLE__')
          'WHOLE_CABLE identity must be __WHOLE_CABLE__.',
        if (kind != CableResourceKind.wholeCable &&
            identity == '__WHOLE_CABLE__')
          '__WHOLE_CABLE__ is reserved for WHOLE_CABLE.',
        if (atomic && childResourceIds.isNotEmpty)
          'Atomic cable resource cannot have child resources.',
        if (childResourceIds.any((value) => value.isEmpty))
          'Child resource identities must not be empty.',
        if (childResourceIds.toSet().length != childResourceIds.length)
          'Child resource identities must be unique.',
        if (groupMembership.any((value) => value.isEmpty))
          'Resource group codes must not be empty.',
        if (groupMembership.toSet().length != groupMembership.length)
          'Resource group codes must be unique.',
        ...terminationPolicy.validate(),
      ];

  Map<String, Object?> toMap() => {
        'identity': identity,
        'kind': kind.name,
        'allocatable': allocatable,
        'atomic': atomic,
        'parentResourceId': parentResourceId,
        'childResourceIds': childResourceIds,
        'groupMembership': groupMembership,
        'terminationPolicy': terminationPolicy.toMap(),
      };

  factory CableResourceDefinition.fromMap(Map<String, dynamic> map) =>
      CableResourceDefinition(
        identity: map['identity'] as String,
        kind: CableResourceKind.values.byName(map['kind'] as String),
        allocatable: map['allocatable'] as bool,
        atomic: map['atomic'] as bool,
        parentResourceId: map['parentResourceId'] as String?,
        childResourceIds:
            (map['childResourceIds'] as List? ?? const []).cast<String>(),
        groupMembership:
            (map['groupMembership'] as List? ?? const []).cast<String>(),
        terminationPolicy: TerminationPolicy.fromMap(
          map['terminationPolicy'] as Map<String, dynamic>,
        ),
      );
}
