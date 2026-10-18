# Source systems: generator / PV / inverter / storage / transfer contract

Status: **CONTRACT_DEFINED / NO QUALIFIED AC-DER PRODUCER / RUNTIME NOT READY**.
Scope: design-time engineering, selection and verification. No real-time controller,
grid dispatch, protection relay control or external switching commands are added.
Registry: [source systems](source-systems-registry.json).
Readiness: [explicit gates](design-readiness.json).

## 1. Binding ownership decisions

| Concern | One authoritative owner | ELV6/7/8 obligation |
|---|---|---|
| Source assets, AC/DC terminals, topology and mode assignments | Existing electrical owner, extended through ELEC1/ELEC2 as necessary | Consume exact typed refs; never create a second source asset inside layout or selection |
| Scenario timeline, source connection/availability and transfer control model | Electrical scenario owner, future ELEC8 integration | Consume qualified immutable study, not a source label or widget state |
| Voltage/frequency/current/fault/conductor/protection study | Electrical calculation owner, applicable existing ELV4 plus future ELEC2/ELEC4/ELEC5/ELEC8 adapters | Do not fabricate AC generator/inverter fault study from a DC/PoE result |
| Charge/discharge/autonomy study | Qualified electrical/energy owner; reuse accepted ELV4 battery model only inside its proven domain | No catalogue Wh/Ah number alone proves system runtime |
| Reusable generator/module/inverter/battery/ATS product facts | Equipment Catalogue with existing ELV2/FL14 identities | Immutable adopted definition/source/settings editions |
| Cabinet/rack body, terminals, service/handling, mass/heat/openings/bonding geometry | ELV6 | Real LAY and safety evidence; no energy dispatch, fuel/exhaust or structural calculation |
| Applicable source/transfer/earthing/export/protection obligations | ELV7 | Typed requirements and scoped assessments, verified national/site/source authority |
| Candidate source/ATS/inverter/storage/control/host combination, BOM and reviewed apply | ELV8 | All declared scenarios, accessory and price closure before validated selection |

Logical producer roles above are not declarations that an accepted writer already
exists. P0 must bind each role to exact code/schema/public commands/qualified tests
and one canonical project identity. Until that binding passes, dependent runtime
features remain BLOCKED_UPSTREAM. Existing independent LAY measurements can run.
No new LAY process, normative family or source simulation kernel is hidden in a
helper merely to preserve a process count.

Existing `PowerSupplyOrigin.externalDeclared`, bidirectional ports and
`PowerScenarioSegment.selectedSourceBySupplySet` are useful adapters, not proof
of AC synchronization, parallel-source superposition or PV energy production.
A scenario role string does not set component/source states. Existing ELV4
single-source selection semantics cannot encode a parallel-source set silently;
that requires a new qualified projection/codec version with legacy replay kept.

## 2. Source and scenario identity

Every source configuration binds project/revision, canonical asset/port refs,
source kind, exact product/definition/settings hashes, topology hash, scenario set,
operating-domain evidence, earthing/neutral configuration, source/trust generations
and canonical version. A source kind cannot infer its available power or behavior.

Initial typed kinds are GRID_INTERFACE, TRANSFORMER, GENERATOR, PV_ARRAY,
INVERTER, UPS, BATTERY_BANK, BESS and TRANSFER_DEVICE. OTHER_DECLARED may preserve
wind/fuel-cell/other external sources only with a named versioned adapter and
declared capability domain; missing adapter yields UNSUPPORTED_SOURCE_MODEL.
It never maps to an unlimited generic source.

Inverter capability axes are distinct from the source kind: grid-following,
grid-forming, permitted island operation, black-start, charge/discharge directions,
AC/DC domains and certified grid-interface behavior. A marketing label "hybrid"
or bidirectional port is not evidence for any of these capabilities.

Scenario records have `scenarioId`, topology/configuration hash, ordered segment
IDs, exact start/duration, source/port/switch states, connected load set, source
capability domain, initial storage state and fault/maintenance assumptions. Validate
explicit exclusivity/parallel groups and their guards; no automatic NORMAL default.
Use stable IDs and generation dependencies, not enum labels alone.

## 3. Exact source facets and study inputs

| Asset/facet | Mandatory facts when consumed by the corresponding check |
|---|---|
| Grid/PCC | Connection voltage/frequency/phase arrangement, approved import/export domain, source impedance/fault study, point of common coupling and site/utility authority refs |
| Transformer | Winding/phase/neutral relation, rated and derated operating domain, impedance/loss evidence, earthing relation and actual upstream source |
| Generator | Real/apparent/reactive capability domain, voltage/frequency/phase/neutral, duty/environment derating, startup/readiness and step-load limits, fault-current-versus-time evidence, control/starting supply, fuel-duration basis if autonomy claimed |
| PV modules/array | Exact module revision, Voc/Isc/Vmp/Imp and temperature-domain evidence, series/parallel topology, string/combiner cable/protection refs, irradiance/temperature scenario and uncertainty; no nameplate output guarantee |
| Inverter/MPPT | Exact port map; AC/DC voltage/current/power domains, MPPT start/operating/max-input domains, string/input allocation, conversion/loss domain, residual/leakage declarations, fault current limit versus time, grid/island/black-start capabilities and firmware/setting evidence |
| Battery/BESS | Chemistry and exact voltage/SoC/temperature/age domain, usable energy versus operating point, charge/discharge C-rate/current/power, cutoff and reserve, efficiency model, BMS/contactor/precharge/fuse compatibility, auxiliary demand and adopted control limits |
| UPS | Normal/inverter/battery/static-bypass/maintenance-bypass modes, capacity/overload/fault domains, transfer interruption, battery/charger compatibility and qualified load behavior |
| ATS/transfer | Tested complete assembly/variant, poles and actual neutral map, source/switch topology, open/closed/delayed/bypass capabilities, utilization/current/fault withstand domain, interlocks, controller/control supply and timing guards |
| Common physical | Body/mounting/terminal/cable-entry geometry, service/removal/airflow envelopes, mass/CoG, mode-dependent heat-loss basis and declared environmental capability; ELV6 consumes only exact adopted facts |

Fields are conditionally required by typed rule and source role. Missing generator
fuel evidence blocks a fuel-autonomy claim, not independent cabinet containment.
Absent heat data blocks thermal completeness, not unrelated body dimensions.
Missing source/transfer data blocks configuration eligibility for the scenario.
No duplicate source energy is counted through inverter/charger/UPS representations;
identify conversion edges and one physical storage bank once.

Numeric values use existing exact dimensional quantities/intervals with schema and
canonical versions: W/VA/var are distinct, AC rms/peak/residual current semantics
are distinct, storage energy and power differ, geometry is integer µm and mass
integer grams. No current from W alone without the applicable phase/voltage/power
factor model; no autonomy from kWh alone without usable state and load/efficiency.
PV sizing, loss, fault and SoC formulas belong to qualified owner kernels, not UI
or catalogue JSON scripts. Unknown remains unknown, not zero or unlimited.

## 4. Four explicit upstream projections

Schemas in the registry are proposed until qualified:

1. `electra.electrical-source-configuration.v1`: canonical source/port/connection
   refs, product/settings/topology hashes, allowed source combinations and scenario
   definitions; site authorization and operating capability evidence.
2. `electra.electrical-source-study.v1`: per scenario/segment/observation point,
   direction-aware voltage/current/power domains, minimum/maximum prospective
   fault evidence and time-dependent current-limiting behavior; actual protective
   settings, conductor/loop/earthing and source contribution assumptions.
3. `electra.electrical-transfer-sequence.v1`: initial state, ordered events/guards,
   actual switch/pole states per interval, readiness/synchronization/isolation
   proof refs, interruption intervals, control-supply behavior and load continuity.
4. `electra.electrical-energy-balance.v1`: initial SoC/usable-state evidence,
   time intervals, source availability bounds, input/output/conversion/auxiliary
   powers, storage transitions/limits, curtailed/exported/unserved energy and final
   state; energy balance/residual tolerances are explicit qualified model policy.

Each carries project/revision/scope/scenario, producer/algorithm/canonical versions,
execution/completion/freshness, consumed definition/source/settings hashes,
generation/selector tokens, coverage and missing facts. ELV7/8 refuse a mix of
configuration, study, transfer or energy projections from different captures,
topologies, source modes or settings. Every consumed applicability domain must
cover the actual scenario; averaging a missing segment cannot prove continuity.

The physical/requirement/evidence nine-schema agreement stays unchanged. These
four schemas are additional electrical producer prerequisites consumed through
that agreement, not four implemented ELV6 processes or new competing owners.

## 4.1 Typed record shapes and unknown encoding

The following shapes are normative design constraints for source projection
codecs. A named payload type in the registry is a typed composition of these
records and the existing common evidence/quantity types, never a free-form map.

| Record | Required fields / meaning |
|---|---|
| `Fact<T>` | Exactly one tagged case: KNOWN(value:T, sourceEvidenceRef, conditionsRef), UNKNOWN(reasonCode, missingRefs), NOT_APPLICABLE(exclusionProofRef); known zero is a value, not UNKNOWN |
| `CanonicalElectricalAssetRef` | ownerCode, kind, id, projectId, designRevisionId, assetRevision, definitionEditionRef/hash; preserves the existing electrical asset identity |
| `CanonicalElectricalPortRef` | assetRef, portCode, interfaceDefinitionRef/hash, conductorRole, phaseOrPolarity; N/PE/PEN are explicit roles, not display labels |
| `TypedPortConnection` | id, fromPortRef, toPortRef, permittedDirection, connectionDefinitionRef, stateBySegment; converter edges state conversion owner/model |
| `ScopedProductCapabilityRef` | productEditionRef/hash, hardwareVariantHash, firmwareSettingRef/hash where applicable, capabilityCode, domainRef, sourceEvidenceRef, validity |
| `OrderedScenarioDefinition` | id, purpose, requiredModeCoverageIds, initialStateRef, orderedSegments, explicitAssumptions; each segment has id, ordinal, duration, source/switch/load/storage state refs |
| `ScopedOperatingPointRef` | scenarioId, segmentId, observationPointRef, sourceMode, loadSetHash, environmentRef, settingHash, domainRef |
| `DimensionedScenarioInterval` | operatingPointRef, quantityMeaning, unitDefinitionRef, exact lower/upper, endpoint inclusion and source/uncertainty refs; vector component/phase explicit |
| `ProspectiveFaultVersusTimeEvidence` | operatingPointRef, faultType, metricKind, contributionModelRef, timeSegments, faultEnvelope, initialConditions, sourceStudyRef/hash; metricKind distinguishes PROSPECTIVE_AT_POINT, SOURCE_LIMITED_WAVEFORM and DEVICE_LET_THROUGH |
| `ImmutableSettingRef` | ownerRef, editionId, schema, payloadHash; release, inverter, BMS and transfer-controller settings are separate typed domains |
| `ScenarioEarthingLoopEvidenceRef` | scenarioId/segmentId, topologyHash, sourceNeutralBondMapHash, earthingModelRef, loopStudyRef/hash, proofDomain; geometric bond point alone is not a loop proof |
| `OrderedGuardedTransferEvent` | eventId, ordinal, relativeTimeInterval, atomicGroupId?, guardRefs, affectedSwitchPoleRefs, beforeStateHash, afterStateHash, failureBranchRef?; omitted optional group/branch means absent, never successful fallback |
| `PortAndPoleIntervalState` | switchRef, poleRef, timeInterval, commandedState, evidencedState, sourceRef, proofRef; state enum OPEN/CLOSED/UNKNOWN, actual evidence is independent of command |
| `ScopedGuardEvidenceRef` | guardCode, domainRef, factRef, applicabilityProofRef, expectedConfigurationHash; guardCode/algorithm must be registered, no arbitrary expression |
| `QualifiedIsolationSynchronizationRef` | scenarioId, segmentId, actual source set, topology/state hash, authority/capability refs, synchronization/isolation result evidence, validity domain |
| `LoadServiceInterruptionEvidence` | loadRef, scenarioId, time intervals, served/unserved/unknown state, continuityRequirementRef and source evidence |
| `ControlSupplyAvailabilityRef` | controlAssetRef, powerPathRef, scenarioId/segmentId, supplyStudyRef/hash, availability Fact; mechanical fallback needs separate explicit evidence |
| `ExplicitFaultAssumption` | subjectRef, faultCode, occurrence interval, assumed/observed status, scope/provenance; an assumption cannot be relabelled as field verification |
| `UsableStorageStateEvidence` | bankRef, stateInstant, SoC/temperature/age/cutoff/reserve facts, usableEnergyDomainRef, BMS/settings hash, stateEvidenceRef |
| `EnergyBalanceSegment` | scenarioId, segmentId, interval, source/input/output/conversion/auxiliary flow refs, storage before/after refs, curtailed/exported/unserved refs, residual proof |
| `ScopedPowerAvailabilityEvidence` | sourceRef, operatingPointRef, available-power interval/time basis, limitation/forecast/model ref, confidence/uncertainty status; forecast is not a guarantee |
| `QualifiedLossAuxiliaryModelRef` | ownerRef, model/schema/version/hash, input domain, exact loss/efficiency/auxiliary evidence, calibration/oracle refs |
| `BoundedStorageTransition` | bankRef, interval, before/after state refs, charge/discharge/net-flow refs, limiting-setting evidence and conservation proof; one bank identity counted once |
| `DimensionedEnergyInterval` | scenarioId/segmentId, source/sink refs, flow meaning, exact interval value, unit and evidence; imported/exported/curtailed/unserved are distinct meanings |
| `EffectiveAuthorityRef` | source/site/jurisdiction ID, exact edition/decision hash, operation domain, effective interval, knowledge instant, approval/trust generation; unknown authority has an explicit UNKNOWN Fact |
| `ModeCoverageRequirement` / `ModeExclusionProof` | modeId, topology/purpose derivation, required subject/scenario set or proof of exclusion, consumed refs and membership hash |

`QualifiedLoadServiceEvidenceRef` and `ImmutableSourceSwitchStateRef` are common
scoped evidence refs to load-service and complete initial switch/source state;
`QualifiedNumericTolerancePolicyRef` is an immutable versioned numeric policy
with exact tolerance/domain/oracle evidence. They are not new mutable owners.
Refs are resolved against the captured immutable closure; dangling, cross-revision
or mismatched schema/domain refs block publication. Semantic validators reject
unknown fields and unsupported quantity/state tags before writes. Runtime P1 must
freeze generated concrete Dart/JSON codecs against these shapes and then qualify
their exact byte/hash/replay representation; a design table is not that evidence.

An atomic group is a simulation-state update rule, not proof that physical contacts
switch simultaneously. Contact timing uncertainty and possible overlap must be
represented by intervals and checked against the actual adopted transfer guards.

## 5. Transfer and prohibited-state semantics

Every transfer step declares guard facts, affected poles/ports, pre/post source
sets, time domain, observation points and interruption/load-service obligations.
Event ordering uses explicit ordinal; equal-time events require an atomic group
with declared all-or-nothing state transition. Unsupported race/order is BLOCKED.

- Open transition must prove the required source separation under the adopted
  topology/guard policy. Never infer isolation merely from an ATS label.
- Any temporary or sustained source paralleling needs matching equipment/domain,
  synchronization/control evidence, protection/earthing study and applicable site/
  utility authorization. Unknown permission/capability blocks eligibility.
- Welded/stuck contacts, failed sensor/control supply and bypass/maintenance states
  are explicit fault scenarios when in scope, never silently assumed successful.
- Grid-following does not imply ability to energize an isolated bus. Island supply
  needs an explicitly qualified forming source and compatible control/protection.
- Grid return/retransfer, generator cooldown and permitted reconnect conditions
  are explicit intervals/guards, not zero-time transitions.
- Neutral and N/PE/PEN/bond state is evaluated per mode/transition by the qualified
  owner and applicable ELV7 profile. Do not universally require or forbid a neutral
  switch, or infer bonding from a PE geometry point. Never synthesize a PE switch.
- Anti-islanding, intentional islanding and load continuity are different proofs.
  An anti-islanding test declaration alone does not prove an approved whole site.
- Zero-export is a bounded control/measurement/protection capability plus the
  authorized operating policy; a negative-power display or a zero setpoint alone
  cannot prove no grid injection during all required fault/transfer intervals.

No fixed universal switching delay, RCD type, grid-export permission, fault
multiplier, usable SoC, loss factor or weather profile is introduced here. Values
come from exact adopted source/product/study/site authority within domain.

## 6. Mandatory mode coverage

The registry lists explicit coverage obligations for:
GRID_NORMAL, GRID_LOSS, GENERATOR_START, GENERATOR_SUPPLY, GENERATOR_FAILURE,
RETRANSFER_TO_GRID, UPS_INVERTER, UPS_BYPASS, PV_GRID_CONNECTED, PV_UNAVAILABLE,
INTENTIONAL_ISLAND, STORAGE_CHARGE, STORAGE_DISCHARGE, STORAGE_DEPLETED,
MAINTENANCE_ISOLATION and TRANSFER_CONTROL_FAILURE.

These are named coverage classes, not automatic state-setting enums. Project
required scenarios are derived from installed source/control topology and declared
critical-load purposes. A provably absent generator can exclude generator modes;
a present generator cannot omit startup/failure because no scenario was entered.
Evidence of non-applicability is persisted. Unresolved required mode blocks a
full-system claim, while independent scope results remain available.

A scenario set binds normal, minimum-availability and required failure cases.
PV installed nameplate/forecast is not guaranteed critical-load backup. Assess
night/low-generation cases if the stated continuity purpose requires them.
Generator and current-limited inverter fault envelopes must be checked separately;
maximum grid fault cannot establish disconnection in island mode. Parallel-source
fault study uses a qualified topology/model, not arithmetic addition of labels.

## 7. ELV6, ELV7 and ELV8 required behavior

ELV6 binds exact external connection/interface definitions, AC/DC cable-end and
terminal polarity/phase identity, entries, compartment/segregation geometry,
handling/removal space, support mass, operating-point heat/airflow and enclosure
integrity. It distinguishes interfaces outside its enclosure boundary from local
placements. Generator engine/exhaust/fuel design and PV roof/structural/shading
simulation stay outside ELV6; their interface/provenance is explicit input, not
fabricated layout compliance. No rooftop geometry solver is implied by PV support.

ELV7 applies existing NRM families through source-domain rule instances for
all relevant modes: source applicability/authority, disconnect/interrupting/TCC,
residual protection, earthing/bonding, thermal/ampacity, SPD, separation/access,
assembly/environment and manual commissioning. A rule with no qualified source
parameters/producer remains NOT_EVALUABLE. Existing 45 families are not silently
expanded by an unregistered calculation. A genuinely new checker family must
reopen its registry and qualification plan explicitly before implementation.

ELV8 creates whole compatible alternatives (source/inverter/storage/ATS/control
supply/bus/protection/cables/terminals/host/accessories) using all required mode
constraints first. Economic ranking uses complete comparable BOM/installation
scope; fuel/tariff/lifetime objectives need separate explicit model/horizon/source
and cannot masquerade as simple acquisition cost. A source candidate may be
recorded as unresolved draft but cannot be VALIDATED or normal final dossier if
required scenario study/permission/protection/energy evidence is missing.
Read-only what-if cannot mutate live source connections. Accepted changes use
existing canonical owner participants in one shared UoW with CAS/replay, then
actual electrical/layout/normative revalidation. No procurement or real switching.

## 8. Persistence, invalidation and historical reproduction

Shared source refs/settings/scenario/topology/capability/permission/SoC/forecast
inputs and their evidence generations enter source-consuming dependency closures.
Changing a source mode, phase/neutral map, transfer timing/control supply, firmware,
site authorization, storage initial state, load or environment invalidates exactly
the affected study/layout/normative/selection/economic consumers. Missing selector
membership and new same-hash generations remain part of the normal agreement.

Freeze captures adopted source/configuration/settings/scenario and exact consumed
study/sequence/energy hashes with the respective owner evidence. ELV6 stores only
its physical consumed basis, ELV7 its obligations/results, ELV8 its complete
selected/adopted configuration closure. Do not duplicate mutable source state in
all three sections, modify old ELV4 manifests or add strict-v2 wire keys. Missing
legacy source capture is NOT_CAPTURED, not proof of normal mains supply.
Create-next restores mutable bindings through the source owner typed remapping,
without copying CURRENT results, permissions/approval validity or old receipts as
new valid evidence. Historical replay uses pinned scenario/site/source/knowledge
instants, not current weather, stock, time or external network.
