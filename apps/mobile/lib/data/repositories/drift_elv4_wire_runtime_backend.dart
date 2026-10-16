import '../../application/elv4_wire_command_dispatcher.dart';
import '../../application/elv4_wire_power_payload.dart';
import '../../application/elv4_wire_runtime_registry.dart';
import '../../application/elv4_wire_semantic_adapter.dart';
import '../database/app_database.dart';
import 'drift_elv4_wire_aggregate_service.dart';

/// Production composition boundary for the two public ELV4 aggregate commands
/// whose wire semantics cannot be implemented by looping the older singular
/// runtime commands.
///
/// Every non-aggregate operation is delegated unchanged to the installed
/// runtime backend. `SET_POWER_LOAD_PROFILE` and `REPLACE_POWER_TRANSFERS`
/// instead execute through [DriftElv4WireAggregateService], preserving one
/// transaction, one design-row CAS and one durable operation receipt while
/// consuming only server-reviewed dependency refs from [Elv4ResolvedWireImpact].
final class DriftElv4WireRuntimeBackend
    implements Elv4WireRuntimeBackend<Object?> {
  DriftElv4WireRuntimeBackend(
    AppDatabase database, {
    required String originDeviceId,
    required Elv4WireRuntimeBackend<Object?> delegate,
    DateTime Function()? now,
    DriftElv4WireAggregateService? aggregateService,
  }) : _delegate = delegate,
       _aggregateService =
           aggregateService ??
           DriftElv4WireAggregateService(
             database,
             originDeviceId: originDeviceId,
             now: now,
           );

  final Elv4WireRuntimeBackend<Object?> _delegate;
  final DriftElv4WireAggregateService _aggregateService;

  @override
  Future<Object?> bindPowerProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.bindPowerProfile(envelope, payload, impact);

  @override
  Future<Object?> adoptPowerProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.adoptPowerProfile(envelope, payload, impact);

  @override
  Future<Object?> releasePowerProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.releasePowerProfile(envelope, payload, impact);

  @override
  Future<Object?> setPowerLoadProfile(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) {
    final loads = payload
        .list('loads')
        .map((value) {
          if (value is! Map) {
            throw const FormatException('loads entries must be objects.');
          }
          return Elv4WireLoadEntry.fromMap(value.cast<String, Object?>());
        })
        .toList(growable: false);
    return _aggregateService.replaceLoadProfile(
      envelope: envelope,
      changedDependencyRefs: impact.changedDependencyRefs,
      componentId: payload.string('componentId'),
      loads: loads,
    );
  }

  @override
  Future<Object?> replacePowerTransfers(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) {
    final transfers = payload
        .list('transfers')
        .map((value) {
          if (value is! Map) {
            throw const FormatException('transfers entries must be objects.');
          }
          return Elv4WireTransferEntry.fromMap(value.cast<String, Object?>());
        })
        .toList(growable: false);
    return _aggregateService.replaceTransfers(
      envelope: envelope,
      changedDependencyRefs: impact.changedDependencyRefs,
      componentId: payload.string('componentId'),
      transfers: transfers,
    );
  }

  @override
  Future<Object?> replacePowerCapacityGroup(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.replacePowerCapacityGroup(envelope, payload, impact);

  @override
  Future<Object?> replacePowerSupplyRequirement(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.replacePowerSupplyRequirement(envelope, payload, impact);

  @override
  Future<Object?> createPowerScenario(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.createPowerScenario(envelope, payload, impact);

  @override
  Future<Object?> replacePowerScenario(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.replacePowerScenario(envelope, payload, impact);

  @override
  Future<Object?> archivePowerScenario(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.archivePowerScenario(envelope, payload, impact);

  @override
  Future<Object?> bindPoeDelivery(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.bindPoeDelivery(envelope, payload, impact);

  @override
  Future<Object?> replacePoeDelivery(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.replacePoeDelivery(envelope, payload, impact);

  @override
  Future<Object?> configureBackupAssembly(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.configureBackupAssembly(envelope, payload, impact);

  @override
  Future<Object?> replaceBatteryBank(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.replaceBatteryBank(envelope, payload, impact);

  @override
  Future<Object?> calculatePowerProcess(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.calculatePowerProcess(envelope, payload, impact);

  @override
  Future<Object?> freezeDesignRevision(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.freezeDesignRevision(envelope, payload, impact);

  @override
  Future<Object?> createNextWorkingDesignRevision(
    Elv4WireCommandEnvelope envelope,
    Elv4ValidatedWirePayload payload,
    Elv4ResolvedWireImpact impact,
  ) => _delegate.createNextWorkingDesignRevision(envelope, payload, impact);
}
