import '../../database/app_database.dart';
import 'drift_elv5_dependency_invalidator.dart';
import '../../../application/elv5/cctv/cctv01_geometry_contract.dart';
import 'drift_cctv01_geometry_contract_store.dart';
import '../../../application/elv5/cctv/cctv04_pse_contract.dart';
import 'drift_cctv04_pse_contract_store.dart';
import '../../../application/elv5/cctv/cctv05_capability_contract.dart';
import 'drift_cctv05_capability_contract_store.dart';
import '../../../application/elv5/cctv/cctv06_link_contract.dart';
import 'drift_cctv06_link_contract_store.dart';

/// Atomic contract CAS and invalidation of consumers of the previous edition.
final class DriftElv5CctvContractMutationCoordinator {
  DriftElv5CctvContractMutationCoordinator(
    this.database, {
    required this.originDeviceId,
    DateTime Function()? nowUtc,
  }) : nowUtc = nowUtc ?? _defaultNow;
  final AppDatabase database;
  final String originDeviceId;
  final DateTime Function() nowUtc;
  static DateTime _defaultNow() => DateTime.now().toUtc();
  Future<void> replaceCctv01(ReplaceCctv01GeometryContractCommand command) =>
      database.transaction(() async {
        final store = DriftCctv01GeometryContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForCamera(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          cameraId: command.contract.cameraId,
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
            domain: 'CCTV01_GEOMETRY_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });
  Future<void> replaceCctv04(
    ReplaceCctv04PseProjectionContractCommand command,
  ) => database.transaction(() async {
    final store = DriftCctv04PseProjectionContractStore(
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
        domain: 'CCTV04_POE_PROJECTION_CONTRACT',
        subjectId: previous.evidenceRef,
      );
    }
  });
  Future<void> replaceCctv05(ReplaceCctv05CapabilityContractCommand command) =>
      database.transaction(() async {
        final store = DriftCctv05CapabilityContractStore(
          database,
          originDeviceId: originDeviceId,
          nowUtc: nowUtc,
        );
        final previous = await store.loadActiveForRecorder(
          projectId: command.projectId,
          designRevisionId: command.designRevisionId,
          recorderId: command.contract.recorderId,
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
            domain: 'CCTV05_CAPABILITY_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });
  Future<void> replaceCctv06(ReplaceCctv06LinkContractCommand command) =>
      database.transaction(() async {
        final store = DriftCctv06LinkContractStore(
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
            domain: 'CCTV06_LINK_CONTRACT',
            subjectId: previous.evidenceRef,
          );
        }
      });
}
