import '../../database/app_database.dart';
import 'drift_elv5_dependency_invalidator.dart';
import '../../../application/elv5/acs/acs01_role_profile_contract_write.dart';
import 'drift_acs01_role_profile_contract_store.dart';
import '../../../application/elv5/acs/acs02_resource_contract.dart';
import 'drift_acs02_resource_contract_store.dart';
import '../../../application/elv5/acs/acs04_source_requirement_contract_write.dart';
import 'drift_acs04_source_requirement_contract_store.dart';
import '../../../application/elv5/acs/acs05_autonomy_contract_write.dart';
import 'drift_acs05_autonomy_contract_store.dart';
import '../../../application/elv5/acs/acs06_topology_contract_write.dart';
import 'drift_acs06_topology_contract_store.dart';

/// Public atomic boundary for ACS contract persistence and consumer invalidation.
/// The source CAS, immutable edition and exact consumed-member invalidation
/// either all commit or all roll back.
final class DriftElv5AcsContractMutationCoordinator {
  DriftElv5AcsContractMutationCoordinator(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : nowUtc = nowUtc ?? _defaultNow;
  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() nowUtc;
  static DateTime _defaultNow() => DateTime.now().toUtc();

  Future<void> replaceAcs01(ReplaceAcs01RoleProfileContractCommand command) =>
      database.transaction(() async {
        final store = DriftAcs01RoleProfileContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForDoor(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          doorId: command.contract.doorId,
        );
        await store.replace(command);
        if (previous != null) {
          await DriftElv5DependencyInvalidator(
            database,
            originDeviceId: originDeviceId,
            nowUtc: nowUtc,
          ).invalidateSubject(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            relationKind: 'POLICY',
            domain: 'ACS01_ROLE_PROFILE_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceAcs02(ReplaceAcs02ResourceContractCommand command) =>
      database.transaction(() async {
        final store = DriftAcs02ResourceContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForController(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          controllerId: command.contract.controllerId,
        );
        await store.replace(command);
        if (previous != null) {
          await DriftElv5DependencyInvalidator(
            database,
            originDeviceId: originDeviceId,
            nowUtc: nowUtc,
          ).invalidateSubject(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            relationKind: 'POLICY',
            domain: 'ACS02_RESOURCE_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceAcs04(
    ReplaceAcs04SourceRequirementContractCommand command,
  ) => database.transaction(() async {
    final store = DriftAcs04SourceRequirementContractStore(
      database,
      originDeviceId: originDeviceId,
      nowUtc: nowUtc,
    );
    final previous = await store.loadActiveForSource(
      projectId: command.projectId,
      designRevisionId: command.designRevisionId,
      sourceId: command.contract.sourceId,
    );
    await store.replace(command);
    if (previous != null) {
      await DriftElv5DependencyInvalidator(
        database,
        originDeviceId: originDeviceId,
        nowUtc: nowUtc,
      ).invalidateSubject(
        projectId: command.projectId,
        designRevisionId: command.designRevisionId,
        relationKind: 'POLICY',
        domain: 'ACS04_SOURCE_REQUIREMENT_SET',
        subjectId: previous.evidenceRef,
      );
    }
  });

  Future<void> replaceAcs05(ReplaceAcs05AutonomyContractCommand command) =>
      database.transaction(() async {
        final store = DriftAcs05AutonomyContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForBank(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          bankId: command.contract.bankId,
        );
        await store.replace(command);
        if (previous != null) {
          await DriftElv5DependencyInvalidator(
            database,
            originDeviceId: originDeviceId,
            nowUtc: nowUtc,
          ).invalidateSubject(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            relationKind: 'POLICY',
            domain: 'ACS05_AUTONOMY_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceAcs06(ReplaceAcs06TopologyContractCommand command) =>
      database.transaction(() async {
        final store = DriftAcs06TopologyContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForDoor(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          doorId: command.contract.doorId,
        );
        await store.replace(command);
        if (previous != null) {
          await DriftElv5DependencyInvalidator(
            database,
            originDeviceId: originDeviceId,
            nowUtc: nowUtc,
          ).invalidateSubject(
            projectId: command.projectId,
            designRevisionId: command.designRevisionId,
            relationKind: 'POLICY',
            domain: 'ACS06_TOPOLOGY_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });
}
