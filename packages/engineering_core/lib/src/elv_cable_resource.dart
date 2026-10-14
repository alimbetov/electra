import 'elv_cable_reference.dart';
import 'elv_cable_resource_definition.dart';
import 'engineering_hash.dart';

sealed class CableResourceSelection {
  const CableResourceSelection();

  Map<String, Object?> toMap();
}

final class WholeCableSelection extends CableResourceSelection {
  const WholeCableSelection();

  @override
  Map<String, Object?> toMap() => const {'kind': 'WHOLE_CABLE'};
}

final class ResourceSetSelection extends CableResourceSelection {
  ResourceSetSelection(Iterable<String> resourceIdentities)
      : resourceIdentities = List.unmodifiable(
          resourceIdentities
              .map((value) => value.trim().toUpperCase())
              .where((value) => value.isNotEmpty),
        );

  final List<String> resourceIdentities;

  @override
  Map<String, Object?> toMap() => {
        'kind': 'RESOURCE_SET',
        'resourceIdentities': resourceIdentities,
      };
}

final class DefinitionGroupSelection extends CableResourceSelection {
  DefinitionGroupSelection(String groupIdentity)
      : groupIdentity = groupIdentity.trim().toUpperCase();

  final String groupIdentity;

  @override
  Map<String, Object?> toMap() => {
        'kind': 'DEFINITION_GROUP',
        'groupIdentity': groupIdentity,
      };
}

CableResourceSelection cableResourceSelectionFromMap(Map<String, dynamic> map) {
  return switch (map['kind'] as String) {
    'WHOLE_CABLE' => const WholeCableSelection(),
    'RESOURCE_SET' => ResourceSetSelection(
        (map['resourceIdentities'] as List? ?? const []).cast<String>(),
      ),
    'DEFINITION_GROUP' => DefinitionGroupSelection(map['groupIdentity'] as String),
    final kind => throw FormatException('Unknown cable resource selection kind: $kind'),
  };
}

final class ResolvedCableResourceSelection {
  const ResolvedCableResourceSelection({
    required this.selection,
    required this.atomicResourceIdentities,
    required this.selectionSha256,
  });

  final CableResourceSelection selection;
  final List<String> atomicResourceIdentities;
  final String selectionSha256;
}

final class CableResourceResolutionException implements Exception {
  const CableResourceResolutionException(this.code, [this.details = const {}]);

  final String code;
  final Map<String, Object?> details;

  @override
  String toString() => 'CableResourceResolutionException($code, $details)';
}

abstract final class CableResourceResolver {
  static ResolvedCableResourceSelection resolve({
    required CableDefinition definition,
    required CableResourceSelection selection,
  }) {
    final definitionErrors = definition.validate();
    if (definitionErrors.isNotEmpty) {
      throw CableResourceResolutionException(
        'ELV_ALLOC_DEFINITION_INVALID',
        {'errors': definitionErrors},
      );
    }

    final byId = <String, CableResourceDefinition>{
      for (final resource in definition.resourceDefinitions)
        resource.identity: resource,
    };

    late final Set<String> atoms;
    switch (selection) {
      case WholeCableSelection():
        atoms = _wholeCableClaims(definition);
      case ResourceSetSelection(:final resourceIdentities):
        if (resourceIdentities.isEmpty) {
          throw const CableResourceResolutionException(
            'ELV_ALLOC_RESOURCE_SELECTION_EMPTY',
          );
        }
        atoms = <String>{};
        for (final id in resourceIdentities) {
          final resource = byId[id];
          if (resource == null) {
            throw CableResourceResolutionException(
              'ELV_ALLOC_RESOURCE_UNKNOWN',
              {'resourceIdentity': id},
            );
          }
          if (!resource.allocatable) {
            throw CableResourceResolutionException(
              'ELV_ALLOC_RESOURCE_NOT_ADDRESSABLE',
              {'resourceIdentity': id},
            );
          }
          if (resource.kind == CableResourceKind.wholeCable) {
            atoms.addAll(_wholeCableClaims(definition));
          } else {
            atoms.addAll(_resolveAtomicDescendants(resource, byId));
          }
        }
      case DefinitionGroupSelection(:final groupIdentity):
        if (groupIdentity.isEmpty) {
          throw const CableResourceResolutionException(
            'ELV_ALLOC_RESOURCE_GROUP_EMPTY',
          );
        }
        final grouped = definition.resourceDefinitions
            .where(
              (resource) =>
                  resource.allocatable &&
                  resource.kind != CableResourceKind.wholeCable &&
                  resource.groupMembership.contains(groupIdentity),
            )
            .toList(growable: false);
        if (grouped.isEmpty) {
          throw CableResourceResolutionException(
            'ELV_ALLOC_RESOURCE_GROUP_UNKNOWN',
            {'groupIdentity': groupIdentity},
          );
        }
        atoms = <String>{};
        for (final resource in grouped) {
          atoms.addAll(_resolveAtomicDescendants(resource, byId));
        }
    }

    if (atoms.isEmpty) {
      throw const CableResourceResolutionException(
        'ELV_ALLOC_RESOURCE_SELECTION_EMPTY',
      );
    }

    final sortedAtoms = atoms.toList()..sort();
    final normalizedSelection = _normalizeSelection(selection);
    final sha = sha256HexUtf8(
      canonicalEngineeringJsonV1({
        'schema': 'electra.cable-resource-selection.v1',
        'selection': normalizedSelection.toMap(),
        'resolvedAtoms': sortedAtoms,
      }),
    );
    return ResolvedCableResourceSelection(
      selection: normalizedSelection,
      atomicResourceIdentities: List.unmodifiable(sortedAtoms),
      selectionSha256: sha,
    );
  }

  static Set<String> _wholeCableClaims(CableDefinition definition) => {
        '__WHOLE_CABLE__',
        for (final resource in definition.resourceDefinitions)
          if (resource.atomic && resource.kind != CableResourceKind.wholeCable)
            resource.identity,
      };

  static Set<String> _resolveAtomicDescendants(
    CableResourceDefinition resource,
    Map<String, CableResourceDefinition> byId,
  ) {
    if (resource.atomic) return {resource.identity};
    return {
      for (final childId in resource.childResourceIds)
        ..._resolveAtomicDescendants(byId[childId]!, byId),
    };
  }

  static CableResourceSelection _normalizeSelection(
    CableResourceSelection selection,
  ) => switch (selection) {
        WholeCableSelection() => const WholeCableSelection(),
        ResourceSetSelection(:final resourceIdentities) =>
          ResourceSetSelection((resourceIdentities.toSet().toList()..sort())),
        DefinitionGroupSelection(:final groupIdentity) =>
          DefinitionGroupSelection(groupIdentity),
      };
}
