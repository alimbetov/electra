import '../../../application/elv5/fire/fa03_terminal_voltage_contract_write.dart';
import 'drift_fa03_terminal_voltage_contract_store.dart';
import '../../../application/elv5/fire/fa04_source_requirement_contract_write.dart';
import '../../../application/elv5/fire/fa05_autonomy_contract_write.dart';
import '../../../application/elv5/fire/fa06_notification_contract_write.dart';
import '../../database/app_database.dart';
import 'drift_elv5_dependency_invalidator.dart';
import 'drift_fa04_source_requirement_contract_store.dart';
import 'drift_fa05_autonomy_contract_store.dart';
import 'drift_fa06_notification_contract_store.dart';

/// Atomic production boundary for FIRE policy contracts consumed by ELV5.
///
/// The underlying stores own durable contract persistence and design-revision
/// CAS. This coordinator additionally invalidates any discipline evaluation
/// that consumed the previous immutable evidence reference, in the same outer
/// SQLite transaction. A committed contract replacement therefore cannot leave
/// an ELV5 pointer CURRENT against stale policy evidence.
final class DriftElv5FireContractMutationCoordinator {
  DriftElv5FireContractMutationCoordinator(
    this.database, {
    required String originDeviceId,
    DateTime Function()? nowUtc,
  }) : _fa03 = DriftFa03TerminalVoltageContractStore(
         database,
         originDeviceId: originDeviceId,
         nowUtc: nowUtc,
       ),
       _fa04 = DriftFa04SourceRequirementContractStore(
         database,
         originDeviceId: originDeviceId,
         nowUtc: nowUtc,
       ),
       _fa05 = DriftFa05AutonomyContractStore(
         database,
         originDeviceId: originDeviceId,
         nowUtc: nowUtc,
       ),
       _fa06 = DriftFa06NotificationContractStore(
         database,
         originDeviceId: originDeviceId,
         nowUtc: nowUtc,
       ),
       _invalidator = DriftElv5DependencyInvalidator(
         database,
         originDeviceId: originDeviceId,
         nowUtc: nowUtc,
       );

  final AppDatabase database;
  final DriftFa03TerminalVoltageContractStore _fa03;
  final DriftFa04SourceRequirementContractStore _fa04;
  final DriftFa05AutonomyContractStore _fa05;
  final DriftFa06NotificationContractStore _fa06;
  final DriftElv5DependencyInvalidator _invalidator;

  Future<void> replaceFa03(ReplaceFa03TerminalVoltageContractCommand command) =>
      database.transaction(() async {
        final previous = await _fa03.loadActiveForCircuit(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          circuitId: command.contract.circuitId,
        );
        await _fa03.replace(command);
        if (previous != null) {
          await _invalidator.invalidateSubject(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            relationKind: 'POLICY',
            domain: 'FA03_TERMINAL_VOLTAGE_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceFa04(
    ReplaceFa04SourceRequirementContractCommand command,
  ) => database.transaction(() async {
    final previous = await _fa04.loadActiveForSource(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      sourceId: command.contract.sourceId,
    );
    await _fa04.replace(command);
    if (previous != null) {
      await _invalidator.invalidateSubject(
        projectId: command.projectId,
        designRevisionId: command.designRevisionId,
        relationKind: 'POLICY',
        domain: 'FA04_SOURCE_REQUIREMENT_SET',
        subjectId: previous.evidenceRef,
      );
    }
  });

  Future<void> replaceFa05(ReplaceFa05AutonomyContractCommand command) =>
      database.transaction(() async {
        final previous = await _fa05.loadActiveForBank(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          bankId: command.contract.bankId,
        );
        await _fa05.replace(command);
        if (previous != null) {
          await _invalidator.invalidateSubject(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            relationKind: 'POLICY',
            domain: 'FA05_AUTONOMY_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceFa06(ReplaceFa06NotificationContractCommand command) =>
      database.transaction(() async {
        final previous = await _fa06.loadActiveForCircuit(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          circuitId: command.contract.circuitId,
        );
        await _fa06.replace(command);
        if (previous != null) {
          await _invalidator.invalidateSubject(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            relationKind: 'POLICY',
            domain: 'FA06_NOTIFICATION_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });
}
