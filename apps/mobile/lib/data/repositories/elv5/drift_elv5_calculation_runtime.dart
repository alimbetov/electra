import '../../../application/elv5/calculation/elv5_calculation_runtime.dart';
import '../../../application/elv5/calculation/elv5_calculation_service.dart';
import '../../../application/elv5/calculation/elv5_initial_vertical_registry.dart';
import '../../../application/elv5/environment/ampacity_route_resolver.dart';
import '../../database/app_database.dart';
import '../drift_elv_cable_run_repository.dart';
import 'drift_acs01_role_profile_contract_store.dart';
import 'drift_acs02_resource_contract_store.dart';
import 'drift_acs03_electrical_contract_store.dart';
import 'drift_acs04_source_requirement_contract_store.dart';
import 'drift_acs05_autonomy_contract_store.dart';
import 'drift_acs06_topology_contract_store.dart';
import 'drift_ampacity_section_contract_store.dart';
import 'drift_elv3_realized_link_fact_source.dart';
import 'drift_elv4_current_evidence_source.dart';
import 'drift_elv4_operating_fact_source.dart';
import 'drift_elv5_calculation_fact_stores.dart';
import 'drift_elv5_calculation_write_unit_of_work.dart';
import 'drift_elv5_capture_revision_source.dart';
import 'drift_environment_profile_store.dart';
import 'drift_environment_scope_resolver.dart';
import 'drift_fa01_address_capacity_contract_store.dart';
import 'drift_fa03_terminal_voltage_contract_store.dart';
import 'drift_fa04_source_requirement_contract_store.dart';
import 'drift_fa05_autonomy_contract_store.dart';
import 'drift_fa06_notification_contract_store.dart';
import 'drift_fa07_topology_contract_store.dart';
import 'drift_fa08_policy_contract_store.dart';
import 'drift_fa08_route_cable_fact_source.dart';
import 'drift_lan02_port_contract_store.dart';
import 'drift_lan03_poe_contract_store.dart';
import 'drift_lan05_optical_section_evidence_source.dart';

final class DriftElv5CalculationRuntime {
  DriftElv5CalculationRuntime._({required this.registry, required this.service});

  final Elv5ProcessCalculationRegistry registry;
  final Elv5CalculationService service;

  factory DriftElv5CalculationRuntime.create(
    AppDatabase database, {
    String originDeviceId = 'local-device',
    DateTime Function()? nowUtc,
  }) {
    final cctvFacts = DriftElv5CctvCalculationFactStore(database, originDeviceId: originDeviceId);
    final lanFacts = DriftElv5LanCalculationFactStore(database, originDeviceId: originDeviceId);
    final acsFacts = DriftElv5AcsCalculationFactStore(database, originDeviceId: originDeviceId);
    final fireFacts = DriftElv5FireCalculationFactStore(database, originDeviceId: originDeviceId);
    final cableRuns = DriftElvCableRunRepository(database, originDeviceId: originDeviceId);

    final environmentProfiles = DriftElv5EnvironmentProfileStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final environmentResolver = DriftElv5EnvironmentScopeResolver(database: database, profileSource: environmentProfiles);
    final ampacitySections = DriftElv5AmpacitySectionContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final ampacityRouteResolver = Elv5AmpacityRouteResolver(
      cableRuns: cableRuns,
      environments: environmentResolver,
      sectionEvidence: ampacitySections,
    );

    final lan02Contracts = DriftLan02PortContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final lan03Contracts = DriftLan03PoeProjectionContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final acs01Contracts = DriftAcs01RoleProfileContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final acs02Contracts = DriftAcs02ResourceContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final acs03Contracts = DriftAcs03ElectricalContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final acs04Contracts = DriftAcs04SourceRequirementContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final acs05Contracts = DriftAcs05AutonomyContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final acs06Contracts = DriftAcs06TopologyContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final fa01Contracts = DriftFa01AddressCapacityContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final fa03Contracts = DriftFa03TerminalVoltageContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final fa04Contracts = DriftFa04SourceRequirementContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final fa05Contracts = DriftFa05AutonomyContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final fa06Contracts = DriftFa06NotificationContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final fa07Contracts = DriftFa07TopologyContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);
    final fa08Contracts = DriftFa08CablePolicyContractStore(database, originDeviceId: originDeviceId, nowUtc: nowUtc);

    final currentPowerEvidence = DriftElv4CurrentEvidenceSource(database);
    final registry = buildElv5InitialVerticalRegistry(
      cctvStore: cctvFacts,
      lanStore: lanFacts,
      acsStore: acsFacts,
      fireStore: fireFacts,
      elv3LinkFacts: DriftElv3RealizedLinkFactSource(database),
      opticalSectionEvidence: DriftLan05OpticalSectionEvidenceSource(database),
      lan02Contracts: lan02Contracts,
      lan03Contracts: lan03Contracts,
      acs01Contracts: acs01Contracts,
      acs02Contracts: acs02Contracts,
      acs03Contracts: acs03Contracts,
      acs04Contracts: acs04Contracts,
      acs05Contracts: acs05Contracts,
      acs06Contracts: acs06Contracts,
      fa01Contracts: fa01Contracts,
      fa03Contracts: fa03Contracts,
      fa04Contracts: fa04Contracts,
      fa05Contracts: fa05Contracts,
      fa06Contracts: fa06Contracts,
      fa07Contracts: fa07Contracts,
      fa08Contracts: fa08Contracts,
      ampacityRouteResolver: ampacityRouteResolver,
      fa08RouteCableFacts: DriftFa08RouteCableFactSource(database: database, cableRuns: cableRuns),
      currentPowerEvidence: currentPowerEvidence,
      powerOperatingFacts: DriftElv4OperatingFactSource(database),
      captureRevisions: DriftElv5CaptureRevisionSource(database),
      nowUtc: nowUtc,
    );
    final service = Elv5CalculationService(
      registry: registry,
      publicationUnitOfWork: DriftElv5CalculationWriteUnitOfWork(database, originDeviceId: originDeviceId),
      originDeviceId: originDeviceId,
      now: nowUtc,
    );
    return DriftElv5CalculationRuntime._(registry: registry, service: service);
  }
}
