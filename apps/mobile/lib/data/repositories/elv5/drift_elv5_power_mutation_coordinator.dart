import '../../../application/elv4_wire_command_dispatcher.dart';
import '../../../application/elv4_wire_power_payload.dart';
import '../../../application/power_mutation_command.dart';
import '../../database/app_database.dart';
import '../drift_elv4_wire_aggregate_service.dart';
import '../drift_power_command_service.dart';
import 'drift_elv5_dependency_invalidator.dart';

/// Atomic cross-boundary mutation entry point for ELV4 power facts that are
/// consumed by ELV5 discipline calculations.
///
/// ELV4 owns persistence and its own dependency graph. ELV5 owns discipline
/// evaluation pointers. This coordinator keeps both invalidation domains in the
/// same outer SQLite transaction so a committed source mutation cannot leave an
/// ELV5 CURRENT pointer referring to stale power evidence.
final class DriftElv5PowerMutationCoordinator {
  DriftElv5PowerMutationCoordinator(
    this.database, {
    required String originDeviceId,
    DateTime Function()? nowUtc,
  }) : _power = DriftPowerCommandService(
         database,
         originDeviceId: originDeviceId,
         now: nowUtc,
       ),
       _aggregate = DriftElv4WireAggregateService(
         database,
         originDeviceId: originDeviceId,
         now: nowUtc,
       ),
       _invalidator = DriftElv5DependencyInvalidator(
         database,
         originDeviceId: originDeviceId,
         nowUtc: nowUtc,
       );

  final AppDatabase database;
  final DriftPowerCommandService _power;
  final DriftElv4WireAggregateService _aggregate;
  final DriftElv5DependencyInvalidator _invalidator;

  Future<PowerMutationReceipt> execute(PowerMutationCommand command) =>
      database.transaction(() async {
        final receipt = await _power.execute(command);
        if (receipt.replayed) return receipt;

        switch (command) {
          case SetPowerLoadCommand value:
            await _invalidateComponentLoads(
              projectId: value.projectId,
              designRevisionId: value.designRevisionId,
              componentId: value.contribution.componentId,
            );
          case ReplacePowerScenarioCommand value:
            await _invalidateScenario(
              projectId: value.projectId,
              designRevisionId: value.designRevisionId,
              scenarioId: value.scenario.scenarioId,
            );
          case ArchivePowerScenarioCommand value:
            await _invalidateScenario(
              projectId: value.projectId,
              designRevisionId: value.designRevisionId,
              scenarioId: value.scenarioId,
            );
          default:
            break;
        }
        return receipt;
      });

  /// Public-wire aggregate load replacement keeps one stable [originId] across
  /// multiple explicit device states. FA-02 consumes that exact state matrix.
  Future<PowerMutationReceipt> replaceLoadProfile({
    required Elv4WireCommandEnvelope envelope,
    required Iterable<String> changedDependencyRefs,
    required String componentId,
    required Iterable<Elv4WireLoadEntry> loads,
  }) => database.transaction(() async {
    final receipt = await _aggregate.replaceLoadProfile(
      envelope: envelope,
      changedDependencyRefs: changedDependencyRefs,
      componentId: componentId,
      loads: loads,
    );
    if (!receipt.replayed) {
      await _invalidateComponentLoads(
        projectId: envelope.projectId,
        designRevisionId: envelope.designRevisionId,
        componentId: componentId,
      );
    }
    return receipt;
  });

  Future<void> _invalidateComponentLoads({
    required String projectId,
    required String designRevisionId,
    required String componentId,
  }) async {
    await _invalidator.invalidateSubject(
      projectId: projectId,
      designRevisionId: designRevisionId,
      relationKind: 'FACT',
      domain: 'POWER_COMPONENT_STATE_LOADS',
      subjectId: componentId,
    );
  }

  Future<void> _invalidateScenario({
    required String projectId,
    required String designRevisionId,
    required String scenarioId,
  }) async {
    await _invalidator.invalidateSubject(
      projectId: projectId,
      designRevisionId: designRevisionId,
      relationKind: 'SET',
      domain: 'POWER_OPERATING_SCENARIO',
      subjectId: scenarioId,
    );
  }
}
