import '../../../application/elv5/calculation/elv5_calculation_runtime.dart';
import '../../../application/elv5/calculation/elv5_calculation_service.dart';
import '../../../application/elv5/calculation/elv5_initial_vertical_registry.dart';
import '../../database/app_database.dart';
import 'drift_acs03_electrical_contract_store.dart';
import 'drift_acs04_source_requirement_contract_store.dart';
import 'drift_elv3_realized_link_fact_source.dart';
import 'drift_elv4_current_evidence_source.dart';
import 'drift_elv4_operating_fact_source.dart';
import 'drift_elv5_calculation_fact_stores.dart';
import 'drift_elv5_calculation_write_unit_of_work.dart';
import 'drift_elv5_capture_revision_source.dart';
import 'drift_lan05_optical_section_evidence_source.dart';

/// Production composition root for the persisted ELV5 calculation vertical.
/// Application runtime depends on interfaces; Drift construction remains here
/// at the data edge.
final class DriftElv5CalculationRuntime {
  DriftElv5CalculationRuntime._({
    required this.registry,
    required this.service,
  });

  final Elv5ProcessCalculationRegistry registry;
  final Elv5CalculationService service;

  factory DriftElv5CalculationRuntime.create(
    AppDatabase database, {
    String originDeviceId = 'local-device',
    DateTime Function()? nowUtc,
  }) {
    final cctvFacts = DriftElv5CctvCalculationFactStore(
      database,
      originDeviceId: originDeviceId,
    );
    final lanFacts = DriftElv5LanCalculationFactStore(
      database,
      originDeviceId: originDeviceId,
    );
    final acsFacts = DriftElv5AcsCalculationFactStore(
      database,
      originDeviceId: originDeviceId,
    );
    final fireFacts = DriftElv5FireCalculationFactStore(
      database,
      originDeviceId: originDeviceId,
    );
    final acs03Contracts = DriftAcs03ElectricalContractStore(
      database,
      originDeviceId: originDeviceId,
      nowUtc: nowUtc,
    );
    final acs04Contracts = DriftAcs04SourceRequirementContractStore(
      database,
      originDeviceId: originDeviceId,
      nowUtc: nowUtc,
    );
    final currentPowerEvidence = DriftElv4CurrentEvidenceSource(database);
    final registry = buildElv5InitialVerticalRegistry(
      cctvStore: cctvFacts,
      lanStore: lanFacts,
      acsStore: acsFacts,
      fireStore: fireFacts,
      elv3LinkFacts: DriftElv3RealizedLinkFactSource(database),
      opticalSectionEvidence: DriftLan05OpticalSectionEvidenceSource(database),
      acs03Contracts: acs03Contracts,
      acs04Contracts: acs04Contracts,
      currentPowerEvidence: currentPowerEvidence,
      powerOperatingFacts: DriftElv4OperatingFactSource(database),
      captureRevisions: DriftElv5CaptureRevisionSource(database),
      nowUtc: nowUtc,
    );
    final service = Elv5CalculationService(
      registry: registry,
      publicationUnitOfWork: DriftElv5CalculationWriteUnitOfWork(
        database,
        originDeviceId: originDeviceId,
      ),
      originDeviceId: originDeviceId,
      now: nowUtc,
    );
    return DriftElv5CalculationRuntime._(
      registry: registry,
      service: service,
    );
  }
}
