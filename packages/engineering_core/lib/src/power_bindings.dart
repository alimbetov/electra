import 'power_definition_ref.dart';
import 'power_numeric.dart';
import 'power_profiles.dart';

enum PowerPortRole { source, consumer, bidirectional, passive }

enum PowerComponentCapability {
  source,
  consumer,
  transfer,
  storage,
  distribution,
  poeSource,
  poeConsumer,
  charger,
  backup,
}

enum PowerProjectionField {
  currentKind,
  voltageEnvelope,
  powerDirection,
  frequency,
  terminalRoles,
}

enum PowerProjectionOwnerKind { elv1, elv2, elv4 }

final class PowerProjectionClaim {
  PowerProjectionClaim({
    required this.field,
    required this.ownerKind,
    required String ownerRef,
  }) : ownerRef = _requiredText(ownerRef, 'ownerRef');

  final PowerProjectionField field;
  final PowerProjectionOwnerKind ownerKind;
  final String ownerRef;

  Map<String, Object?> toMap() => {
        'field': field.name,
        'ownerKind': ownerKind.name.toUpperCase(),
        'ownerRef': ownerRef,
      };

  factory PowerProjectionClaim.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {'field', 'ownerKind', 'ownerRef'});
    return PowerProjectionClaim(
      field: PowerProjectionField.values.byName(map['field'] as String),
      ownerKind: PowerProjectionOwnerKind.values.singleWhere(
        (value) => value.name.toUpperCase() == map['ownerKind'],
      ),
      ownerRef: map['ownerRef'] as String,
    );
  }
}

/// Field-level ownership prevents a typed ELV4 binding from silently replacing
/// an existing ELV1/ELV2 projection owner. A field can have exactly one owner.
final class PowerProjectionOwnership {
  PowerProjectionOwnership(Iterable<PowerProjectionClaim> claims)
      : claims = List.unmodifiable(_normalizeClaims(claims));

  final List<PowerProjectionClaim> claims;

  PowerProjectionClaim? ownerOf(PowerProjectionField field) =>
      claims.where((claim) => claim.field == field).firstOrNull;

  Map<String, Object?> toMap() => {
        'claims': claims.map((claim) => claim.toMap()).toList(growable: false),
      };

  factory PowerProjectionOwnership.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {'claims'});
    return PowerProjectionOwnership(
      (map['claims'] as List<Object?>).map(
        (value) => PowerProjectionClaim.fromMap(
          (value as Map<Object?, Object?>).cast<String, Object?>(),
        ),
      ),
    );
  }

  static List<PowerProjectionClaim> _normalizeClaims(
    Iterable<PowerProjectionClaim> input,
  ) {
    final result = input.toList(growable: false)
      ..sort((a, b) => a.field.name.compareTo(b.field.name));
    final seen = <PowerProjectionField>{};
    for (final claim in result) {
      if (!seen.add(claim.field)) {
        throw ArgumentError(
          'Power projection field ${claim.field.name} has more than one owner.',
        );
      }
    }
    return result;
  }
}

final class PowerPortBinding {
  PowerPortBinding({
    required String portId,
    required this.profileRef,
    required this.role,
    required this.voltageEnvelope,
    required Iterable<String> terminalRoles,
    required this.ownership,
  })  : portId = _requiredText(portId, 'portId'),
        terminalRoles = List.unmodifiable(_normalizedUniqueCodes(
          terminalRoles,
          field: 'terminalRoles',
        )) {
    if (profileRef.definitionKind != PowerDefinitionKind.port &&
        profileRef.definitionKind != PowerDefinitionKind.interface) {
      throw ArgumentError('Power port binding requires a port/interface ref.');
    }
    if (this.terminalRoles.isEmpty) {
      throw ArgumentError('Power port binding requires terminal roles.');
    }
    final requiredFields = <PowerProjectionField>{
      PowerProjectionField.currentKind,
      PowerProjectionField.voltageEnvelope,
      PowerProjectionField.powerDirection,
      PowerProjectionField.terminalRoles,
      if (voltageEnvelope.currentKind == PowerCurrentKind.ac)
        PowerProjectionField.frequency,
    };
    for (final field in requiredFields) {
      if (ownership.ownerOf(field) == null) {
        throw ArgumentError(
          'Power port binding is missing projection ownership for ${field.name}.',
        );
      }
    }
  }

  final String portId;
  final PowerDefinitionRef profileRef;
  final PowerPortRole role;
  final PowerVoltageEnvelope voltageEnvelope;
  final List<String> terminalRoles;
  final PowerProjectionOwnership ownership;

  Map<String, Object?> toMap() => {
        'portId': portId,
        'profileRef': profileRef.toMap(),
        'role': role.name.toUpperCase(),
        'voltageEnvelope': voltageEnvelope.toMap(),
        'terminalRoles': terminalRoles,
        'ownership': ownership.toMap(),
      };

  factory PowerPortBinding.fromMap(Map<String, Object?> map) {
    _exactKeys(map, {
      'portId',
      'profileRef',
      'role',
      'voltageEnvelope',
      'terminalRoles',
      'ownership',
    });
    return PowerPortBinding(
      portId: map['portId'] as String,
      profileRef: PowerDefinitionRef.fromMap(
        (map['profileRef'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
      role: PowerPortRole.values.singleWhere(
        (value) => value.name.toUpperCase() == map['role'],
      ),
      voltageEnvelope: PowerVoltageEnvelope.fromMap(
        (map['voltageEnvelope'] as Map<Object?, Object?>)
            .cast<String, Object?>(),
      ),
      terminalRoles: (map['terminalRoles'] as List<Object?>).cast<String>(),
      ownership: PowerProjectionOwnership.fromMap(
        (map['ownership'] as Map<Object?, Object?>).cast<String, Object?>(),
      ),
    );
  }
}

final class PowerComponentBinding {
  PowerComponentBinding({
    required String componentId,
    required Iterable<PowerComponentCapability> capabilities,
    required Iterable<PowerDefinitionRef> definitionRefs,
    Iterable<String> ownLoadContributionIds = const [],
  })  : componentId = _requiredText(componentId, 'componentId'),
        capabilities = List.unmodifiable(_uniqueEnumValues(
          capabilities,
          field: 'capabilities',
        )),
        definitionRefs = List.unmodifiable(definitionRefs),
        ownLoadContributionIds = List.unmodifiable(_normalizedUniqueCodes(
          ownLoadContributionIds,
          field: 'ownLoadContributionIds',
        )) {
    if (this.capabilities.isEmpty) {
      throw ArgumentError('Power component binding requires capabilities.');
    }
    if (this.definitionRefs.isEmpty) {
      throw ArgumentError('Power component binding requires exact definitions.');
    }
    if (this.definitionRefs.any(
          (ref) => ref.definitionKind != PowerDefinitionKind.component,
        )) {
      throw ArgumentError('Power component binding accepts component refs only.');
    }
  }

  final String componentId;
  final List<PowerComponentCapability> capabilities;
  final List<PowerDefinitionRef> definitionRefs;
  final List<String> ownLoadContributionIds;

  Map<String, Object?> toMap() => {
        'componentId': componentId,
        'capabilities': capabilities
            .map((capability) => capability.name.toUpperCase())
            .toList(growable: false),
        'definitionRefs':
            definitionRefs.map((ref) => ref.toMap()).toList(growable: false),
        'ownLoadContributionIds': ownLoadContributionIds,
      };
}

enum PowerAccountingKind { consumerInput, transferIdle }

final class PowerOwnLoadContribution {
  PowerOwnLoadContribution({
    required String id,
    required String componentId,
    required String inputPortId,
    required this.accountingKind,
    required String stateCode,
    required this.demand,
  })  : id = _normalizedCode(id, 'id'),
        componentId = _requiredText(componentId, 'componentId'),
        inputPortId = _requiredText(inputPortId, 'inputPortId'),
        stateCode = _normalizedCode(stateCode, 'stateCode');

  final String id;
  final String componentId;
  final String inputPortId;
  final PowerAccountingKind accountingKind;
  final String stateCode;
  final PowerDemand demand;

  Map<String, Object?> toMap() => {
        'id': id,
        'componentId': componentId,
        'inputPortId': inputPortId,
        'accountingKind': accountingKind.name.toUpperCase(),
        'stateCode': stateCode,
        'demand': demand.toMap(),
      };
}

enum PowerTransferKind {
  transformer,
  acDc,
  dcDc,
  psu,
  ups,
  charger,
  distributor,
  fuse,
  pse,
  passive,
}

final class PowerTransferBinding {
  PowerTransferBinding({
    required String id,
    required String componentId,
    required this.definitionRef,
    required this.kind,
    required Iterable<String> inputPortIds,
    required Iterable<String> outputPortIds,
    required Iterable<String> enabledStateCodes,
    required String inputAccountingOrigin,
    this.lossDefinition,
    String? idleContributionId,
  })  : id = _normalizedCode(id, 'id'),
        componentId = _requiredText(componentId, 'componentId'),
        inputPortIds = List.unmodifiable(_uniqueTexts(
          inputPortIds,
          field: 'inputPortIds',
        )),
        outputPortIds = List.unmodifiable(_uniqueTexts(
          outputPortIds,
          field: 'outputPortIds',
        )),
        enabledStateCodes = List.unmodifiable(_normalizedUniqueCodes(
          enabledStateCodes,
          field: 'enabledStateCodes',
        )),
        inputAccountingOrigin =
            _normalizedCode(inputAccountingOrigin, 'inputAccountingOrigin'),
        idleContributionId = idleContributionId == null
            ? null
            : _normalizedCode(idleContributionId, 'idleContributionId') {
    if (definitionRef.definitionKind != PowerDefinitionKind.transfer) {
      throw ArgumentError('Power transfer binding requires a transfer ref.');
    }
    if (this.inputPortIds.isEmpty || this.outputPortIds.isEmpty) {
      throw ArgumentError('Power transfer requires input and output ports.');
    }
    if (this.inputPortIds.toSet().intersection(this.outputPortIds.toSet()).isNotEmpty) {
      throw ArgumentError('Transfer input/output port ownership must be distinct.');
    }
    if (this.enabledStateCodes.isEmpty) {
      throw ArgumentError('Power transfer requires explicit enabled states.');
    }
    final activeLossRequired = switch (kind) {
      PowerTransferKind.transformer ||
      PowerTransferKind.acDc ||
      PowerTransferKind.dcDc ||
      PowerTransferKind.psu ||
      PowerTransferKind.ups ||
      PowerTransferKind.charger ||
      PowerTransferKind.pse => true,
      PowerTransferKind.distributor ||
      PowerTransferKind.fuse ||
      PowerTransferKind.passive => false,
    };
    if (activeLossRequired && lossDefinition == null) {
      throw ArgumentError('Active conversion transfer requires a loss model.');
    }
    if (lossDefinition != null &&
        !lossDefinition!.idleW.isZero &&
        this.idleContributionId == null) {
      throw ArgumentError(
        'Separate transfer idle power requires a unique contribution id.',
      );
    }
  }

  final String id;
  final String componentId;
  final PowerDefinitionRef definitionRef;
  final PowerTransferKind kind;
  final List<String> inputPortIds;
  final List<String> outputPortIds;
  final List<String> enabledStateCodes;
  final String inputAccountingOrigin;
  final PowerLossDefinition? lossDefinition;
  final String? idleContributionId;

  Map<String, Object?> toMap() => {
        'id': id,
        'componentId': componentId,
        'definitionRef': definitionRef.toMap(),
        'kind': kind.name.toUpperCase(),
        'inputPortIds': inputPortIds,
        'outputPortIds': outputPortIds,
        'enabledStateCodes': enabledStateCodes,
        'inputAccountingOrigin': inputAccountingOrigin,
        'lossDefinition': lossDefinition?.toMap(),
        'idleContributionId': idleContributionId,
      };
}

enum PowerCapacityDimension { watt, ampere, voltAmpere }

final class PowerCapacityLimit {
  PowerCapacityLimit({required this.dimension, required this.limit}) {
    if (limit <= PowerRational.zero) {
      throw ArgumentError.value(limit, 'limit', 'Must be positive.');
    }
  }

  final PowerCapacityDimension dimension;
  final PowerRational limit;

  Map<String, Object?> toMap() => {
        'dimension': dimension.name.toUpperCase(),
        'limit': limit.toWireDecimal(),
      };
}

final class PowerCapacityGroup {
  PowerCapacityGroup({
    required String id,
    required String ownerComponentId,
    required Iterable<String> memberOutputPortIds,
    required Iterable<PowerCapacityLimit> limits,
    required Iterable<String> applicabilityStateCodes,
    PowerRational? deratingFactor,
  })  : id = _normalizedCode(id, 'id'),
        ownerComponentId = _requiredText(ownerComponentId, 'ownerComponentId'),
        memberOutputPortIds = List.unmodifiable(_uniqueTexts(
          memberOutputPortIds,
          field: 'memberOutputPortIds',
        )),
        limits = List.unmodifiable(limits),
        applicabilityStateCodes = List.unmodifiable(_normalizedUniqueCodes(
          applicabilityStateCodes,
          field: 'applicabilityStateCodes',
        )),
        deratingFactor = deratingFactor ?? PowerRational.one {
    if (this.memberOutputPortIds.isEmpty || this.limits.isEmpty) {
      throw ArgumentError('Capacity group requires members and limits.');
    }
    final dimensions = this.limits.map((limit) => limit.dimension).toSet();
    if (dimensions.length != this.limits.length) {
      throw ArgumentError('Capacity dimensions must be unique per group.');
    }
    if (this.applicabilityStateCodes.isEmpty) {
      throw ArgumentError('Capacity group requires explicit applicability.');
    }
    if (this.deratingFactor <= PowerRational.zero ||
        this.deratingFactor > PowerRational.one) {
      throw ArgumentError('Derating factor must be in (0, 1].');
    }
  }

  final String id;
  final String ownerComponentId;
  final List<String> memberOutputPortIds;
  final List<PowerCapacityLimit> limits;
  final List<String> applicabilityStateCodes;
  final PowerRational deratingFactor;

  Map<String, Object?> toMap() => {
        'id': id,
        'ownerComponentId': ownerComponentId,
        'memberOutputPortIds': memberOutputPortIds,
        'limits': limits.map((limit) => limit.toMap()).toList(growable: false),
        'applicabilityStateCodes': applicabilityStateCodes,
        'deratingFactor': deratingFactor.toWireDecimal(),
      };
}

enum PowerSupplySelectionMode { single, alternative }

final class PowerSupplyRequirement {
  PowerSupplyRequirement({
    required String id,
    required String consumerComponentId,
    required String supplySetId,
    required Iterable<String> inputPortIds,
    required this.selectionMode,
    required Iterable<String> candidateSourceIds,
    required this.requiredCurrentKind,
    required Iterable<String> requiredStateCodes,
  })  : id = _normalizedCode(id, 'id'),
        consumerComponentId =
            _requiredText(consumerComponentId, 'consumerComponentId'),
        supplySetId = _normalizedCode(supplySetId, 'supplySetId'),
        inputPortIds = List.unmodifiable(_uniqueTexts(
          inputPortIds,
          field: 'inputPortIds',
        )),
        candidateSourceIds = List.unmodifiable(_uniqueTexts(
          candidateSourceIds,
          field: 'candidateSourceIds',
        )),
        requiredStateCodes = List.unmodifiable(_normalizedUniqueCodes(
          requiredStateCodes,
          field: 'requiredStateCodes',
        )) {
    if (this.inputPortIds.isEmpty || this.requiredStateCodes.isEmpty) {
      throw ArgumentError('Supply requirement needs inputs and required states.');
    }
    if (selectionMode == PowerSupplySelectionMode.single &&
        this.candidateSourceIds.length != 1) {
      throw ArgumentError('Single-source requirement needs exactly one source.');
    }
    if (selectionMode == PowerSupplySelectionMode.alternative &&
        this.candidateSourceIds.length < 2) {
      throw ArgumentError('Alternative supply requires at least two sources.');
    }
  }

  final String id;
  final String consumerComponentId;
  final String supplySetId;
  final List<String> inputPortIds;
  final PowerSupplySelectionMode selectionMode;
  final List<String> candidateSourceIds;
  final PowerCurrentKind requiredCurrentKind;
  final List<String> requiredStateCodes;

  Map<String, Object?> toMap() => {
        'id': id,
        'consumerComponentId': consumerComponentId,
        'supplySetId': supplySetId,
        'inputPortIds': inputPortIds,
        'selectionMode': selectionMode.name.toUpperCase(),
        'candidateSourceIds': candidateSourceIds,
        'requiredCurrentKind': requiredCurrentKind.name.toUpperCase(),
        'requiredStateCodes': requiredStateCodes,
      };
}

String _requiredText(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}

String _normalizedCode(String value, String field) {
  final normalized = _requiredText(value, field).toUpperCase();
  if (!RegExp(r'^[A-Z][A-Z0-9_-]{0,127}$').hasMatch(normalized)) {
    throw ArgumentError.value(value, field, 'Invalid canonical code.');
  }
  return normalized;
}

List<String> _uniqueTexts(Iterable<String> values, {required String field}) {
  final result = values.map((value) => _requiredText(value, field)).toList();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  result.sort();
  return result;
}

List<String> _normalizedUniqueCodes(
  Iterable<String> values, {
  required String field,
}) {
  final result = values.map((value) => _normalizedCode(value, field)).toList();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  result.sort();
  return result;
}

List<T> _uniqueEnumValues<T extends Enum>(
  Iterable<T> values, {
  required String field,
}) {
  final result = values.toList();
  if (result.toSet().length != result.length) {
    throw ArgumentError('$field must be unique.');
  }
  result.sort((a, b) => a.name.compareTo(b.name));
  return result;
}

void _exactKeys(Map<String, Object?> map, Set<String> expected) {
  if (map.length != expected.length || !expected.every(map.containsKey)) {
    throw FormatException('Expected exactly: ${expected.join(', ')}.');
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
