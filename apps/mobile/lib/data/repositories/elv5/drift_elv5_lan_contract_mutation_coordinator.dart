import '../../database/app_database.dart';
import 'drift_elv5_dependency_invalidator.dart';
import '../../../application/elv5/lan/lan02_port_contract.dart';
import 'drift_lan02_port_contract_store.dart';
import '../../../application/elv5/lan/lan03_poe_contract.dart';
import 'drift_lan03_poe_contract_store.dart';
import '../../../application/elv5/lan/lan04_compatibility_contract.dart';
import 'drift_lan04_compatibility_contract_store.dart';
import '../../../application/elv5/lan/lan06_rack_contract.dart';
import 'drift_lan06_rack_contract_store.dart';
import '../../../application/elv5/lan/lan07_patch_contract.dart';
import 'drift_lan07_patch_contract_store.dart';

/// Atomic typed LAN policy replacements with exact consumed-member invalidation.
final class DriftElv5LanContractMutationCoordinator {
  DriftElv5LanContractMutationCoordinator(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : nowUtc = nowUtc ?? _defaultNow;
  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() nowUtc;
  static DateTime _defaultNow() => DateTime.now().toUtc();

  Future<void> replaceLan02(ReplaceLan02PortContractCommand command) =>
      database.transaction(() async {
        final store = DriftLan02PortContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForSwitch(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          switchId: command.contract.switchId,
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
            domain: 'LAN02_PORT_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceLan03(ReplaceLan03PoeProjectionContractCommand command) =>
      database.transaction(() async {
        final store = DriftLan03PoeProjectionContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForPse(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          pseId: command.contract.pseId,
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
            domain: 'LAN03_POE_PROJECTION_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceLan04(ReplaceLan04CompatibilityContractCommand command) =>
      database.transaction(() async {
        final store = DriftLan04CompatibilityContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForLink(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          linkId: command.contract.linkId,
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
            domain: 'LAN04_COMPATIBILITY_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceLan06(ReplaceLan06RackBasisContractCommand command) =>
      database.transaction(() async {
        final store = DriftLan06RackBasisContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForRack(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          rackId: command.contract.rackId,
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
            domain: 'LAN06_RACK_BASIS_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });

  Future<void> replaceLan07(ReplaceLan07PatchPanelContractCommand command) =>
      database.transaction(() async {
        final store = DriftLan07PatchPanelContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForPanel(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          panelId: command.contract.panelId,
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
            domain: 'LAN07_PATCH_PANEL_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });
}
