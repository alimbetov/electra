import '../acs/acs01_role_profile_contract.dart';
import '../acs/acs01_runtime.dart';
import '../acs/acs02_resource_contract.dart';
import '../acs/acs02_runtime.dart';
import '../acs/acs03_electrical_contract.dart';
import '../acs/acs03_runtime.dart';
import '../acs/acs04_runtime.dart';
import '../acs/acs04_source_requirement_contract.dart';
import '../acs/acs05_autonomy_contract.dart';
import '../acs/acs05_runtime.dart';
import '../acs/acs06_runtime.dart';
import '../acs/acs06_topology_contract.dart';
import '../acs/elv5_acs_persistence.dart';
import '../cctv/cctv02_runtime.dart';
import '../cctv/cctv03_runtime.dart';
import '../cctv/elv5_cctv_persistence.dart';
import '../environment/ampacity_route_resolver.dart';
import '../fire/elv5_fire_persistence.dart';
import '../fire/fa01_address_capacity_contract.dart';
import '../fire/fa01_runtime.dart';
import '../fire/fa02_runtime.dart';
import '../fire/fa03_runtime.dart';
import '../fire/fa03_terminal_voltage_contract.dart';
import '../fire/fa04_runtime.dart';
import '../fire/fa04_source_requirement_contract.dart';
import '../fire/fa05_autonomy_contract.dart';
import '../fire/fa05_runtime.dart';
import '../fire/fa06_notification_contract.dart';
import '../fire/fa06_runtime.dart';
import '../fire/fa07_runtime.dart';
import '../fire/fa07_topology_contract.dart';
import '../fire/fa08_policy_contract.dart';
import '../fire/fa08_route_facts.dart';
import '../fire/fa08_runtime.dart';
import '../lan/elv3_realized_link_facts.dart';
import '../lan/elv5_lan_persistence.dart';
import '../lan/lan01_runtime.dart';
import '../lan/lan02_port_contract.dart';
import '../lan/lan02_runtime.dart';
import '../lan/lan03_poe_contract.dart';
import '../lan/lan03_runtime.dart';
import '../lan/lan04_compatibility_contract.dart';
import '../lan/lan04_runtime.dart';
import '../lan/lan05_optical_section_evidence.dart';
import '../lan/lan05_runtime.dart';
import '../power/elv4_current_evidence_source.dart';
import '../power/elv4_operating_fact_source.dart';
import 'elv5_blocked_capture.dart';
import 'elv5_calculation_runtime.dart';
import 'elv5_capture_guard.dart';

Elv5ProcessCalculationRegistry buildElv5InitialVerticalRegistry({
  required Elv5CctvMutationStore cctvStore,
  required Elv5LanMutationStore lanStore,
  required Elv5AcsMutationStore acsStore,
  required Elv5FireMutationStore fireStore,
  required Elv3RealizedLinkFactSource elv3LinkFacts,
  required Lan05OpticalSectionEvidenceSource opticalSectionEvidence,
  required Lan02PortContractSource lan02Contracts,
  required Lan03PoeProjectionContractSource lan03Contracts,
  required Lan04CompatibilityContractSource lan04Contracts,
  required Acs01RoleProfileContractSource acs01Contracts,
  required Acs02ResourceContractSource acs02Contracts,
  required Acs03ElectricalContractSource acs03Contracts,
  required Acs04SourceRequirementContractSource acs04Contracts,
  required Acs05AutonomyContractSource acs05Contracts,
  required Acs06TopologyContractSource acs06Contracts,
  required Fa01AddressCapacityContractSource fa01Contracts,
  required Fa03TerminalVoltageContractSource fa03Contracts,
  required Fa04SourceRequirementContractSource fa04Contracts,
  required Fa05AutonomyContractSource fa05Contracts,
  required Fa06NotificationContractSource fa06Contracts,
  required Fa07TopologyContractSource fa07Contracts,
  required Fa08CablePolicyContractSource fa08Contracts,
  required Elv5AmpacityRouteResolver ampacityRouteResolver,
  required Fa08RouteCableFactSource fa08RouteCableFacts,
  required Elv4CurrentEvidenceSource currentPowerEvidence,
  required Elv4OperatingFactSource powerOperatingFacts,
  required Elv5CaptureRevisionSource captureRevisions,
  DateTime Function()? nowUtc,
}) {
  Elv5ProcessInputResolver<I> guarded<I>(Elv5ProcessInputResolver<I> inner) =>
      Elv5RevisionGuardedInputResolver<I>(inner: inner, revisions: captureRevisions);
  Elv5ProcessCalculationAdapter blocked<I>(
    Elv5ProcessInputResolver<I> resolver,
    Elv5PureProcessExecutor<I> executor,
  ) => Elv5BlockedAwareTypedProcessCalculationAdapter<I>(
    resolver: guarded(resolver),
    executor: executor,
    nowUtc: nowUtc,
  );

  return Elv5ProcessCalculationRegistry(<Elv5ProcessCalculationAdapter>[
    blocked(Cctv02PersistedInputResolver(store: cctvStore, nowUtc: nowUtc), buildCctv02Executor(nowUtc: nowUtc)),
    blocked(Cctv03PersistedInputResolver(store: cctvStore, nowUtc: nowUtc), buildCctv03Executor(nowUtc: nowUtc)),
    blocked(
      Lan01PersistedInputResolver(lanStore: lanStore, elv3Facts: elv3LinkFacts, nowUtc: nowUtc),
      buildLan01Executor(nowUtc: nowUtc),
    ),
    blocked(
      Lan02PersistedInputResolver(lanStore: lanStore, contractSource: lan02Contracts, nowUtc: nowUtc),
      buildLan02Executor(nowUtc: nowUtc),
    ),
    blocked(
      Lan03PersistedInputResolver(contractSource: lan03Contracts, powerEvidence: currentPowerEvidence, nowUtc: nowUtc),
      buildLan03Executor(nowUtc: nowUtc),
    ),
    blocked(
      Lan04PersistedInputResolver(lanStore: lanStore, contractSource: lan04Contracts, nowUtc: nowUtc),
      buildLan04Executor(nowUtc: nowUtc),
    ),
    blocked(
      Lan05PersistedInputResolver(
        lanStore: lanStore,
        elv3Facts: elv3LinkFacts,
        opticalEvidence: opticalSectionEvidence,
        nowUtc: nowUtc,
      ),
      buildLan05Executor(nowUtc: nowUtc),
    ),
    blocked(
      Acs01PersistedInputResolver(acsStore: acsStore, contractSource: acs01Contracts, nowUtc: nowUtc),
      buildAcs01Executor(nowUtc: nowUtc),
    ),
    blocked(
      Acs02PersistedInputResolver(acsStore: acsStore, contractSource: acs02Contracts, nowUtc: nowUtc),
      buildAcs02Executor(nowUtc: nowUtc),
    ),
    blocked(
      Acs03PersistedInputResolver(
        acsStore: acsStore,
        contractSource: acs03Contracts,
        powerEvidence: currentPowerEvidence,
        nowUtc: nowUtc,
      ),
      buildAcs03Executor(nowUtc: nowUtc),
    ),
    blocked(
      Acs04PersistedInputResolver(contractSource: acs04Contracts, powerEvidence: currentPowerEvidence, nowUtc: nowUtc),
      buildAcs04Executor(nowUtc: nowUtc),
    ),
    blocked(
      Acs05PersistedInputResolver(contractSource: acs05Contracts, powerEvidence: currentPowerEvidence, nowUtc: nowUtc),
      buildAcs05Executor(nowUtc: nowUtc),
    ),
    blocked(
      Acs06PersistedInputResolver(acsStore: acsStore, contractSource: acs06Contracts, nowUtc: nowUtc),
      buildAcs06Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa01PersistedInputResolver(fireStore: fireStore, contractSource: fa01Contracts, nowUtc: nowUtc),
      buildFa01Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa02PersistedInputResolver(fireStore: fireStore, powerFacts: powerOperatingFacts, nowUtc: nowUtc),
      buildFa02Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa03PersistedInputResolver(contractSource: fa03Contracts, powerEvidence: currentPowerEvidence, nowUtc: nowUtc),
      buildFa03Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa04PersistedInputResolver(contractSource: fa04Contracts, powerEvidence: currentPowerEvidence, nowUtc: nowUtc),
      buildFa04Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa05PersistedInputResolver(contractSource: fa05Contracts, powerEvidence: currentPowerEvidence, nowUtc: nowUtc),
      buildFa05Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa06PersistedInputResolver(
        fireStore: fireStore,
        contractSource: fa06Contracts,
        powerEvidence: currentPowerEvidence,
        nowUtc: nowUtc,
      ),
      buildFa06Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa07PersistedInputResolver(fireStore: fireStore, contractSource: fa07Contracts, nowUtc: nowUtc),
      buildFa07Executor(nowUtc: nowUtc),
    ),
    blocked(
      Fa08PersistedInputResolver(
        policySource: fa08Contracts,
        ampacityResolver: ampacityRouteResolver,
        routeCableFacts: fa08RouteCableFacts,
        nowUtc: nowUtc,
      ),
      buildFa08Executor(nowUtc: nowUtc),
    ),
  ]);
}
