import '../../../application/power_mutation_command.dart';
import '../../database/app_database.dart';
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
       _invalidator = DriftElv5DependencyInvalidator(
         database,
         originDeviceId: originDeviceId,
         nowUtc: nowUtc,
       );

  final AppDatabase database;
  final DriftPowerCommandService _power;
  final DriftElv5DependencyInvalidator _invalidator;

  Future<PowerMutationReceipt> execute(PowerMutationCommand command) =>
      database.transaction(() async {
        final receipt = await _power.execute(command);
        if (receipt.replayed) return receipt;

        switch (command) {
          case SetPowerLoadCommand value:
            await _invalidator.invalidateSubject(
              projectId: value.projectId,
              designRevisionId: value.designRevisionId,
              relationKind: 'FACT',
              domain: 'POWER_COMPONENT_STATE_LOADS',
              subjectId: value.contribution.componentId,
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
