import 'elv_cable_resource_definition.dart';
import 'engineering_hash.dart';

final class CableDefinitionRef {
  const CableDefinitionRef({
    required this.catalogId,
    required this.catalogVersion,
    required this.definitionCode,
    required this.definitionContentHash,
  });

  final String catalogId;
  final String catalogVersion;
  final String definitionCode;
  final String definitionContentHash;

  CableDefinitionRef normalized() => CableDefinitionRef(
        catalogId: catalogId.trim(),
        catalogVersion: catalogVersion.trim(),
        definitionCode: definitionCode.trim().toUpperCase(),
        definitionContentHash: definitionContentHash.trim().toLowerCase(),
      );

  List<String> validate() {
    final n = normalized();
    final hashPattern = RegExp(r'^[0-9a-f]{64}$');
    return [
      if (n.catalogId.isEmpty) 'Cable definition catalogId is required.',
      if (n.catalogVersion.isEmpty)
        'Cable definition catalogVersion is required.',
      if (n.definitionCode.isEmpty) 'Cable definition code is required.',
      if (!hashPattern.hasMatch(n.definitionContentHash))
        'Cable definition content hash must be 64 lowercase hex characters.',
    ];
  }

  Map<String, Object?> toMap() {
    final n = normalized();
    return {
      'catalogId': n.catalogId,
      'catalogVersion': n.catalogVersion,
      'definitionCode': n.definitionCode,
      'definitionContentHash': n.definitionContentHash,
    };
  }

  factory CableDefinitionRef.fromMap(Map<String, dynamic> map) =>
      CableDefinitionRef(
        catalogId: map['catalogId'] as String,
        catalogVersion: map['catalogVersion'] as String,
        definitionCode: map['definitionCode'] as String,
        definitionContentHash: map['definitionContentHash'] as String,
      ).normalized();
}

final class CableDefinition {
  CableDefinition({
    required String code,
    required this.label,
    required String mediaCode,
    required Iterable<CableResourceDefinition> resourceDefinitions,
    this.deprecated = false,
    String? categoryCode,
    String? conductorMaterialCode,
    String? shieldingCode,
    String? firePerformanceCode,
    Iterable<String> environmentClassCodes = const [],
    Iterable<String> installationClassCodes = const [],
    Iterable<String> technicalClassCodes = const [],
    this.conductorCount,
    this.pairCount,
    this.fiberCount,
    this.conductorCrossSectionMm2,
    this.characteristicImpedanceOhm,
    this.dcResistanceOhmPerKm,
    this.capacitanceNfPerKm,
    this.inductanceMhPerKm,
    this.voltageRatingV,
    this.outerDiameterMm,
    this.occupiedAreaMm2,
    this.minimumBendRadiusMm,
    this.maximumPullingForceN,
  })  : code = code.trim().toUpperCase(),
        mediaCode = mediaCode.trim().toUpperCase(),
        categoryCode = _normalizeNullable(categoryCode),
        conductorMaterialCode = _normalizeNullable(conductorMaterialCode),
        shieldingCode = _normalizeNullable(shieldingCode),
        firePerformanceCode = _normalizeNullable(firePerformanceCode),
        environmentClassCodes = _normalizedCodes(environmentClassCodes),
        installationClassCodes = _normalizedCodes(installationClassCodes),
        technicalClassCodes = _normalizedCodes(technicalClassCodes),
        resourceDefinitions = List.unmodifiable(resourceDefinitions);

  final String code;
  final String label;
  final bool deprecated;
  final String mediaCode;
  final String? categoryCode;
  final String? conductorMaterialCode;
  final String? shieldingCode;
  final String? firePerformanceCode;
  final List<String> environmentClassCodes;
  final List<String> installationClassCodes;
  final List<String> technicalClassCodes;
  final int? conductorCount;
  final int? pairCount;
  final int? fiberCount;
  final double? conductorCrossSectionMm2;
  final double? characteristicImpedanceOhm;
  final double? dcResistanceOhmPerKm;
  final double? capacitanceNfPerKm;
  final double? inductanceMhPerKm;
  final double? voltageRatingV;
  final double? outerDiameterMm;
  final double? occupiedAreaMm2;
  final double? minimumBendRadiusMm;
  final double? maximumPullingForceN;
  final List<CableResourceDefinition> resourceDefinitions;

  List<String> validate() {
    final errors = <String>[];
    if (code.isEmpty || label.trim().isEmpty || mediaCode.isEmpty) {
      errors.add('Cable definition code, label and mediaCode are required.');
    }
    for (final count in [conductorCount, pairCount, fiberCount]) {
      if (count != null && count < 0)
        errors.add('Cable counts cannot be negative.');
    }
    for (final value in [
      conductorCrossSectionMm2,
      characteristicImpedanceOhm,
      dcResistanceOhmPerKm,
      capacitanceNfPerKm,
      inductanceMhPerKm,
      voltageRatingV,
      outerDiameterMm,
      occupiedAreaMm2,
      minimumBendRadiusMm,
      maximumPullingForceN,
    ]) {
      if (value != null && (!value.isFinite || value < 0)) {
        errors.add('Cable numeric facts must be finite and nonnegative.');
        break;
      }
    }
    if (resourceDefinitions.isEmpty) {
      errors.add('Cable definition must provide resource definitions.');
      return errors;
    }
    for (final resource in resourceDefinitions) {
      errors.addAll(resource.validateLocal());
    }
    final byId = {
      for (final resource in resourceDefinitions) resource.identity: resource
    };
    if (byId.length != resourceDefinitions.length) {
      errors.add('Cable resource identities must be unique.');
      return errors;
    }
    final whole = resourceDefinitions
        .where((resource) => resource.kind == CableResourceKind.wholeCable)
        .toList(growable: false);
    CableResourceDefinition? wholeResource;
    if (whole.length != 1 || whole.single.identity != '__WHOLE_CABLE__') {
      errors.add(
          'Cable definition must contain exactly one __WHOLE_CABLE__ resource.');
    } else {
      wholeResource = whole.single;
    }
    for (final resource in resourceDefinitions) {
      final parentId = resource.parentResourceId;
      if (parentId != null) {
        final parent = byId[parentId];
        if (parent == null) {
          errors.add(
              'Cable resource ${resource.identity} references unknown parent $parentId.');
        } else if (!parent.childResourceIds.contains(resource.identity)) {
          errors.add('Cable resource parent/child links must be reciprocal.');
        }
      }
      for (final childId in resource.childResourceIds) {
        final child = byId[childId];
        if (child == null) {
          errors.add(
              'Cable resource ${resource.identity} references unknown child $childId.');
        } else if (child.parentResourceId != resource.identity) {
          errors.add('Cable resource parent/child links must be reciprocal.');
        }
      }
    }
    if (_hasCycle(byId)) errors.add('Cable resource graph must be acyclic.');
    if (wholeResource != null) {
      final finerAllocatable = resourceDefinitions.any(
        (resource) =>
            resource.identity != wholeResource!.identity && resource.allocatable,
      );
      if (finerAllocatable) {
        if (wholeResource.atomic) {
          errors.add(
            '__WHOLE_CABLE__ must be composite when finer allocatable cable resources exist.',
          );
        }
        if (wholeResource.parentResourceId != null) {
          errors.add(
            '__WHOLE_CABLE__ must be a root resource when finer allocatable cable resources exist.',
          );
        }
        final descendants = _resourceDescendants(wholeResource.identity, byId);
        for (final resource in resourceDefinitions.where(
          (resource) => resource.identity != wholeResource!.identity,
        )) {
          if (!descendants.contains(resource.identity)) {
            errors.add(
              'Cable resource ${resource.identity} must be a descendant of __WHOLE_CABLE__.',
            );
          }
        }
      }
    }
    for (final resource
        in resourceDefinitions.where((r) => r.allocatable && !r.atomic)) {
      if (_atomicDescendants(resource.identity, byId).isEmpty) {
        errors.add(
            'Allocatable composite ${resource.identity} must resolve to atomic descendants.');
      }
    }
    return errors;
  }

  Map<String, Object?> toMap() => {
        'code': code,
        'label': label,
        'deprecated': deprecated,
        'mediaCode': mediaCode,
        'categoryCode': categoryCode,
        'conductorMaterialCode': conductorMaterialCode,
        'shieldingCode': shieldingCode,
        'firePerformanceCode': firePerformanceCode,
        'environmentClassCodes': environmentClassCodes,
        'installationClassCodes': installationClassCodes,
        'technicalClassCodes': technicalClassCodes,
        'conductorCount': conductorCount,
        'pairCount': pairCount,
        'fiberCount': fiberCount,
        'conductorCrossSectionMm2': conductorCrossSectionMm2,
        'characteristicImpedanceOhm': characteristicImpedanceOhm,
        'dcResistanceOhmPerKm': dcResistanceOhmPerKm,
        'capacitanceNfPerKm': capacitanceNfPerKm,
        'inductanceMhPerKm': inductanceMhPerKm,
        'voltageRatingV': voltageRatingV,
        'outerDiameterMm': outerDiameterMm,
        'occupiedAreaMm2': occupiedAreaMm2,
        'minimumBendRadiusMm': minimumBendRadiusMm,
        'maximumPullingForceN': maximumPullingForceN,
        'resourceDefinitions':
            resourceDefinitions.map((item) => item.toMap()).toList(),
      };

  factory CableDefinition.fromMap(Map<String, dynamic> map) => CableDefinition(
        code: map['code'] as String,
        label: map['label'] as String,
        deprecated: map['deprecated'] as bool? ?? false,
        mediaCode: map['mediaCode'] as String,
        categoryCode: map['categoryCode'] as String?,
        conductorMaterialCode: map['conductorMaterialCode'] as String?,
        shieldingCode: map['shieldingCode'] as String?,
        firePerformanceCode: map['firePerformanceCode'] as String?,
        environmentClassCodes:
            (map['environmentClassCodes'] as List? ?? const []).cast<String>(),
        installationClassCodes:
            (map['installationClassCodes'] as List? ?? const []).cast<String>(),
        technicalClassCodes:
            (map['technicalClassCodes'] as List? ?? const []).cast<String>(),
        conductorCount: map['conductorCount'] as int?,
        pairCount: map['pairCount'] as int?,
        fiberCount: map['fiberCount'] as int?,
        conductorCrossSectionMm2:
            (map['conductorCrossSectionMm2'] as num?)?.toDouble(),
        characteristicImpedanceOhm:
            (map['characteristicImpedanceOhm'] as num?)?.toDouble(),
        dcResistanceOhmPerKm: (map['dcResistanceOhmPerKm'] as num?)?.toDouble(),
        capacitanceNfPerKm: (map['capacitanceNfPerKm'] as num?)?.toDouble(),
        inductanceMhPerKm: (map['inductanceMhPerKm'] as num?)?.toDouble(),
        voltageRatingV: (map['voltageRatingV'] as num?)?.toDouble(),
        outerDiameterMm: (map['outerDiameterMm'] as num?)?.toDouble(),
        occupiedAreaMm2: (map['occupiedAreaMm2'] as num?)?.toDouble(),
        minimumBendRadiusMm: (map['minimumBendRadiusMm'] as num?)?.toDouble(),
        maximumPullingForceN: (map['maximumPullingForceN'] as num?)?.toDouble(),
        resourceDefinitions: (map['resourceDefinitions'] as List).map((value) =>
            CableResourceDefinition.fromMap(value as Map<String, dynamic>)),
      );
}

String cableDefinitionContentHashV1(CableDefinition definition) =>
    sha256HexUtf8(
      canonicalEngineeringJsonV1({
        'schema': 'electra.cable-definition.v1',
        'definition': definition.toMap(),
      }),
    );

String? _normalizeNullable(String? value) {
  final normalized = value?.trim().toUpperCase();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

List<String> _normalizedCodes(Iterable<String> values) => List.unmodifiable(
      values
          .map((value) => value.trim().toUpperCase())
          .where((value) => value.isNotEmpty),
    );

bool _hasCycle(Map<String, CableResourceDefinition> byId) {
  final visiting = <String>{};
  final visited = <String>{};
  bool visit(String id) {
    if (visiting.contains(id)) return true;
    if (!visited.add(id)) return false;
    visiting.add(id);
    for (final child in byId[id]!.childResourceIds) {
      if (byId.containsKey(child) && visit(child)) return true;
    }
    visiting.remove(id);
    return false;
  }

  return byId.keys.any(visit);
}

Set<String> _resourceDescendants(
  String id,
  Map<String, CableResourceDefinition> byId, [
  Set<String>? visiting,
]) {
  final resource = byId[id];
  if (resource == null) return const {};
  final path = visiting ?? <String>{};
  if (!path.add(id)) return const {};
  final result = <String>{};
  for (final child in resource.childResourceIds) {
    if (!byId.containsKey(child)) continue;
    result.add(child);
    result.addAll(_resourceDescendants(child, byId, {...path}));
  }
  return result;
}

Set<String> _atomicDescendants(
  String id,
  Map<String, CableResourceDefinition> byId, [
  Set<String>? visiting,
]) {
  final resource = byId[id];
  if (resource == null) return const {};
  final path = visiting ?? <String>{};
  if (!path.add(id)) return const {};
  if (resource.atomic) return {resource.identity};
  final result = <String>{};
  for (final child in resource.childResourceIds) {
    result.addAll(_atomicDescendants(child, byId, {...path}));
  }
  return result;
}
