enum CableTerminationEnd { a, b }

final class CableTerminationMapping {
  CableTerminationMapping({
    required this.id,
    required this.allocationId,
    required this.resourceIdentity,
    required this.end,
    required this.endpointPortId,
    this.endpointTerminalRef,
    this.terminationRole,
  }) : resourceIdentity = resourceIdentity.trim().toUpperCase(),
       endpointTerminalRef = _normalizeNullable(endpointTerminalRef),
       terminationRole = _normalizeNullable(terminationRole);

  final String id;
  final String allocationId;
  final String resourceIdentity;
  final CableTerminationEnd end;
  final String endpointPortId;
  final String? endpointTerminalRef;
  final String? terminationRole;

  List<String> validate() => [
        if (id.trim().isEmpty) 'Termination mapping id is required.',
        if (allocationId.trim().isEmpty)
          'Termination mapping allocationId is required.',
        if (resourceIdentity.isEmpty)
          'Termination mapping resourceIdentity is required.',
        if (endpointPortId.trim().isEmpty)
          'Termination mapping endpointPortId is required.',
      ];

  String get uniquenessKey =>
      '${allocationId.trim()}|$resourceIdentity|${end.name.toUpperCase()}';
}

List<String> validateTerminationSet(
  Iterable<CableTerminationMapping> mappings,
) {
  final list = mappings.toList(growable: false);
  final errors = <String>[
    for (final mapping in list) ...mapping.validate(),
  ];
  final keys = list.map((mapping) => mapping.uniquenessKey).toList();
  if (keys.toSet().length != keys.length) {
    errors.add('Termination mappings must be unique per allocation/resource/end.');
  }
  return errors;
}

String? _normalizeNullable(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}
