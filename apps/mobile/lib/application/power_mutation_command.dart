import 'package:engineering_core/engineering_core.dart';

sealed class PowerMutationCommand {
  const PowerMutationCommand();

  String get operationId;
  String get projectId;
  String get designRevisionId;
  int get expectedRevision;
  String get commandType;
  String get payloadSchema;
  List<PowerDependencyKey> get changedDependencies;
  Map<String, Object?> get body;

  Map<String, Object?> get canonicalPayload => {
    'projectId': projectId,
    'designRevisionId': designRevisionId,
    'expectedRevision': expectedRevision,
    'body': body,
    'changedDependencies':
        changedDependencies.map((value) => value.encode()).toList()..sort(),
  };
}

mixin _PowerMutationFields implements PowerMutationCommand {
  @override
  late final String operationId;
  @override
  late final String projectId;
  @override
  late final String designRevisionId;
  @override
  late final int expectedRevision;
  @override
  late final List<PowerDependencyKey> changedDependencies;
}

List<PowerDependencyKey> _dependencies(
  Iterable<PowerDependencyKey> input,
  String projectId,
  String revisionId,
) {
  final result = input.toSet().toList()..sort();
  for (final key in result) {
    if (key.projectId != projectId || key.revisionId != revisionId) {
      throw ArgumentError(
        'Power mutation dependency scope must match project/revision.',
      );
    }
  }
  return List.unmodifiable(result);
}

abstract base class _BasePowerMutationCommand extends PowerMutationCommand
    with _PowerMutationFields {
  _BasePowerMutationCommand({
    required String operationId,
    required String projectId,
    required String designRevisionId,
    required int expectedRevision,
    required Iterable<PowerDependencyKey> changedDependencies,
  }) {
    this.operationId = _text(operationId, 'operationId');
    this.projectId = _text(projectId, 'projectId');
    this.designRevisionId = _text(designRevisionId, 'designRevisionId');
    if (expectedRevision < 1) {
      throw ArgumentError.value(expectedRevision, 'expectedRevision');
    }
    this.expectedRevision = expectedRevision;
    this.changedDependencies = _dependencies(
      changedDependencies,
      this.projectId,
      this.designRevisionId,
    );
  }
}

final class BindPowerPortCommand extends _BasePowerMutationCommand {
  BindPowerPortCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String bindingId,
    required this.binding,
  }) : bindingId = _text(bindingId, 'bindingId');

  final String bindingId;
  final PowerPortBinding binding;

  @override
  String get commandType => 'BIND_POWER_PROFILE';
  @override
  String get payloadSchema => 'electra.command.elv4.bind-power-profile.v1';
  @override
  Map<String, Object?> get body => {
    'bindingId': bindingId,
    'binding': binding.toMap(),
  };
}

final class ReleasePowerPortCommand extends _BasePowerMutationCommand {
  ReleasePowerPortCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String bindingId,
  }) : bindingId = _text(bindingId, 'bindingId');

  final String bindingId;

  @override
  String get commandType => 'RELEASE_POWER_PROFILE';
  @override
  String get payloadSchema => 'electra.command.elv4.release-power-profile.v1';
  @override
  Map<String, Object?> get body => {'bindingId': bindingId};
}

final class BindPowerComponentCommand extends _BasePowerMutationCommand {
  BindPowerComponentCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String bindingId,
    required this.binding,
  }) : bindingId = _text(bindingId, 'bindingId');

  final String bindingId;
  final PowerComponentBinding binding;

  @override
  String get commandType => 'BIND_POWER_COMPONENT';
  @override
  String get payloadSchema => 'electra.command.elv4.bind-power-component.v1';
  @override
  Map<String, Object?> get body => {
    'bindingId': bindingId,
    'binding': binding.toMap(),
  };
}

final class SetPowerLoadCommand extends _BasePowerMutationCommand {
  SetPowerLoadCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required this.contribution,
  });

  final PowerOwnLoadContribution contribution;

  @override
  String get commandType => 'SET_POWER_LOAD_PROFILE';
  @override
  String get payloadSchema => 'electra.command.elv4.set-power-load-profile.v1';
  @override
  Map<String, Object?> get body => contribution.toMap();
}

/// Public wire semantic for SET_POWER_LOAD_PROFILE: the supplied list is the
/// complete active load profile for one component, including the empty list.
final class ReplacePowerLoadProfileCommand extends _BasePowerMutationCommand {
  ReplacePowerLoadProfileCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String componentId,
    required Iterable<PowerOwnLoadContribution> loads,
  }) : componentId = _text(componentId, 'componentId'),
       loads = List.unmodifiable(loads) {
    if (this.loads.any((load) => load.componentId != this.componentId)) {
      throw ArgumentError('Every load must belong to componentId.');
    }
    final ids = this.loads.map((load) => load.id).toList();
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('Load profile ids must be unique.');
    }
  }

  final String componentId;
  final List<PowerOwnLoadContribution> loads;

  @override
  String get commandType => 'SET_POWER_LOAD_PROFILE';
  @override
  String get payloadSchema => 'electra.command.elv4.set-power-load-profile.v1';
  @override
  Map<String, Object?> get body => {
    'componentId': componentId,
    'loads': loads.map((value) => value.toMap()).toList(growable: false),
  };
}

final class ReplacePowerTransferCommand extends _BasePowerMutationCommand {
  ReplacePowerTransferCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required this.transfer,
  });

  final PowerTransferBinding transfer;

  @override
  String get commandType => 'REPLACE_POWER_TRANSFER';
  @override
  String get payloadSchema => 'electra.command.elv4.replace-power-transfer.v1';
  @override
  Map<String, Object?> get body => transfer.toMap();
}

/// Public wire semantic for REPLACE_POWER_TRANSFERS: the supplied list is the
/// complete active transfer set for one component, including the empty list.
final class ReplacePowerTransfersCommand extends _BasePowerMutationCommand {
  ReplacePowerTransfersCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String componentId,
    required Iterable<PowerTransferBinding> transfers,
  }) : componentId = _text(componentId, 'componentId'),
       transfers = List.unmodifiable(transfers) {
    if (this.transfers.any(
      (transfer) => transfer.componentId != this.componentId,
    )) {
      throw ArgumentError('Every transfer must belong to componentId.');
    }
    final ids = this.transfers.map((transfer) => transfer.id).toList();
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('Transfer ids must be unique.');
    }
  }

  final String componentId;
  final List<PowerTransferBinding> transfers;

  @override
  String get commandType => 'REPLACE_POWER_TRANSFERS';
  @override
  String get payloadSchema => 'electra.command.elv4.replace-power-transfers.v1';
  @override
  Map<String, Object?> get body => {
    'componentId': componentId,
    'transfers': transfers.map((value) => value.toMap()).toList(growable: false),
  };
}

final class ReplacePowerCapacityGroupCommand extends _BasePowerMutationCommand {
  ReplacePowerCapacityGroupCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required this.group,
  });

  final PowerCapacityGroup group;

  @override
  String get commandType => 'REPLACE_POWER_CAPACITY_GROUP';
  @override
  String get payloadSchema =>
      'electra.command.elv4.replace-power-capacity-group.v1';
  @override
  Map<String, Object?> get body => group.toMap();
}

final class ReplacePowerSupplyRequirementCommand
    extends _BasePowerMutationCommand {
  ReplacePowerSupplyRequirementCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required this.requirement,
  });

  final PowerSupplyRequirement requirement;

  @override
  String get commandType => 'REPLACE_POWER_SUPPLY_REQUIREMENT';
  @override
  String get payloadSchema =>
      'electra.command.elv4.replace-power-supply-requirement.v1';
  @override
  Map<String, Object?> get body => requirement.toMap();
}

final class ReplacePowerScenarioCommand extends _BasePowerMutationCommand {
  ReplacePowerScenarioCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required this.scenario,
  });

  final PowerOperatingScenario scenario;

  @override
  String get commandType => 'REPLACE_POWER_SCENARIO';
  @override
  String get payloadSchema => 'electra.command.elv4.replace-power-scenario.v1';
  @override
  Map<String, Object?> get body => scenario.toMap();
}

final class ArchivePowerScenarioCommand extends _BasePowerMutationCommand {
  ArchivePowerScenarioCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String scenarioId,
  }) : scenarioId = _text(scenarioId, 'scenarioId');

  final String scenarioId;

  @override
  String get commandType => 'ARCHIVE_POWER_SCENARIO';
  @override
  String get payloadSchema => 'electra.command.elv4.archive-power-scenario.v1';
  @override
  Map<String, Object?> get body => {'scenarioId': scenarioId};
}

final class PowerPoePathMemberInput {
  PowerPoePathMemberInput({
    this.connectionId,
    this.allocationId,
    Map<String, Object?> evidence = const {},
  }) : evidence = Map.unmodifiable(evidence) {
    if (connectionId == null && allocationId == null) {
      throw ArgumentError('PoE path member requires connection or allocation.');
    }
  }

  final String? connectionId;
  final String? allocationId;
  final Map<String, Object?> evidence;

  Map<String, Object?> toMap() => {
    'connectionId': connectionId,
    'allocationId': allocationId,
    'evidence': evidence,
  };
}

final class BindPoeDeliveryCommand extends _BasePowerMutationCommand {
  BindPoeDeliveryCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String deliveryId,
    required String psePortId,
    required String pdPortId,
    required String accountingMode,
    required this.definition,
    required Iterable<PowerPoePathMemberInput> path,
  }) : deliveryId = _text(deliveryId, 'deliveryId'),
       psePortId = _text(psePortId, 'psePortId'),
       pdPortId = _text(pdPortId, 'pdPortId'),
       accountingMode = _text(accountingMode, 'accountingMode').toUpperCase(),
       path = List.unmodifiable(path) {
    if (this.path.isEmpty) {
      throw ArgumentError('PoE delivery requires an explicit physical path.');
    }
  }

  final String deliveryId;
  final String psePortId;
  final String pdPortId;
  final String accountingMode;
  final PoeDeliveryDefinition definition;
  final List<PowerPoePathMemberInput> path;

  @override
  String get commandType => 'BIND_POE_DELIVERY';
  @override
  String get payloadSchema => 'electra.command.elv4.bind-poe-delivery.v1';
  @override
  Map<String, Object?> get body => {
    'deliveryId': deliveryId,
    'psePortId': psePortId,
    'pdPortId': pdPortId,
    'accountingMode': accountingMode,
    'definition': definition.toMap(),
    'path': path.map((value) => value.toMap()).toList(growable: false),
  };
}

final class ConfigureBackupAssemblyCommand extends _BasePowerMutationCommand {
  ConfigureBackupAssemblyCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String assemblyId,
    this.upsComponentId,
    this.chargerComponentId,
    this.bankComponentId,
    required Iterable<String> protectedOutputPortIds,
    Map<String, Object?> policy = const {},
  }) : assemblyId = _text(assemblyId, 'assemblyId'),
       protectedOutputPortIds = List.unmodifiable(
         protectedOutputPortIds.map((value) => _text(value, 'outputPortId')),
       ),
       policy = Map.unmodifiable(policy) {
    if (upsComponentId == null &&
        chargerComponentId == null &&
        bankComponentId == null) {
      throw ArgumentError('Backup assembly requires at least one component.');
    }
    if (this.protectedOutputPortIds.toSet().length !=
        this.protectedOutputPortIds.length) {
      throw ArgumentError('Protected output ports must be unique.');
    }
  }

  final String assemblyId;
  final String? upsComponentId;
  final String? chargerComponentId;
  final String? bankComponentId;
  final List<String> protectedOutputPortIds;
  final Map<String, Object?> policy;

  @override
  String get commandType => 'CONFIGURE_BACKUP_ASSEMBLY';
  @override
  String get payloadSchema =>
      'electra.command.elv4.configure-backup-assembly.v1';
  @override
  Map<String, Object?> get body => {
    'assemblyId': assemblyId,
    'upsComponentId': upsComponentId,
    'chargerComponentId': chargerComponentId,
    'bankComponentId': bankComponentId,
    'protectedOutputPortIds': protectedOutputPortIds,
    'policy': policy,
  };
}

final class ReplaceBatteryBankCommand extends _BasePowerMutationCommand {
  ReplaceBatteryBankCommand({
    required super.operationId,
    required super.projectId,
    required super.designRevisionId,
    required super.expectedRevision,
    required super.changedDependencies,
    required String bindingId,
    required this.binding,
  }) : bindingId = _text(bindingId, 'bindingId');

  final String bindingId;
  final BatteryBankBinding binding;

  @override
  String get commandType => 'REPLACE_BATTERY_BANK';
  @override
  String get payloadSchema => 'electra.command.elv4.replace-battery-bank.v1';
  @override
  Map<String, Object?> get body => {
    'bindingId': bindingId,
    'binding': binding.toMap(),
  };
}

String _text(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, field, 'Must not be empty.');
  }
  return normalized;
}
