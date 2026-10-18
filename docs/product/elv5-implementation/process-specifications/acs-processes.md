# ELV5 ACS — production code-level process dossiers

Status: DESIGN HARDENING / RUNTIME NOT STARTED  
Parent: `process-code-level-specification.md`, `process-contracts.md`, `calculation-engine-contract.md`.

All vectors use fictional product-neutral data.

---

## ACS-01 — Door role completeness

### 1. Physical meaning
Validates that each canonical door assembly contains the required access-control functional roles and allowed alternatives/multiplicities defined by its selected technical topology profile. It checks project topology completeness, not legal egress compliance.

### 2. Applicability matrix
| Condition | Result |
|---|---|
| Door assembly + exact role profile + assignments | APPLICABLE |
| Alternative group explicitly modeled | APPLICABLE |
| Unknown assignment state | affected role UNRESOLVED |
| Role inferred only from product/display name | UNSUPPORTED inference |
| Emergency/egress compliance requested | NOT_ASSESSED in ELV5 |

### 3. Exact typed inputs
`DoorAssemblyId`, `DoorTopologyProfileRef`, canonical `AcsRoleCode`, requirement expression tree containing `allOf/oneOf/atLeast/exactly`, assignment set `(ComponentId,RoleCode)`, multiplicity/share permissions, safety-mode ref where topology requires it.

### 4. Evidence requirements
Role capabilities come from immutable component definitions or explicit project role assignment; the profile edition is adopted/versioned. UI labels and component names are never role evidence.

### 5. Operating cases
`DOOR_ROLE_ALTERNATIVES`; each alternative branch is evaluated deterministically. Release-cause behavior belongs to ACS-06 and is not synthesized here.

### 6. Mathematical model
Evaluate a closed requirement-expression algebra over the canonical assignment multiset. A component may satisfy multiple roles only when the profile/capability explicitly allows that sharing. Alternative satisfaction is boolean plus exact chosen branch provenance.

### 7. Equations
For role `r`, `count(r)=|distinct eligible assignments|`. Predicates include `count(r)>=n`, `count(r)==n`; `allOf=AND(children)`, `oneOf=exactly one or at least one` only as explicitly encoded by operator type. No implicit alternative semantics.

### 8. Exact/bounded arithmetic
Role counts are exact integers; no probabilistic/approximate logic. Expression evaluation order is canonical by requirement node ID for trace only; boolean meaning is order-independent where operator semantics are set-like.

### 9. Worst-case selection
Any unsatisfied mandatory branch is FAIL; unknown evidence in all otherwise viable alternatives is UNRESOLVED. A satisfied explicit alternative avoids failure of non-selected optional branches.

### 10. Requirement composition
Multiple applicable technical door profiles must be deterministically merged or rejected as incompatible; developers may not pick a “reasonable” template. Regulatory/egress requirements are later ELV7 inputs.

### 11. Comparison equations
Role multiplicity margin for minimum `n`: `margin=count-n`. Maximum/exact constraints use corresponding signed integer headroom; boolean expression status follows three/five-valued field semantics.

### 12. Margin equation
Numeric role-count margins remain per requirement. No aggregate “door completeness percentage” determines PASS.

### 13. Governing-case algorithm
Evaluate all mandatory requirement nodes, classify FAIL > UNRESOLVED > PASS, then choose the earliest canonical failed leaf/alternative group as governing explanation. Numeric tie uses smallest signed role margin.

### 14. Limiting-factor algorithm
Return exact requirement node, role code, door assembly and missing/excess/conflicting assignment IDs.

### 15. Missing/unsupported behavior
Missing required role assignment yields FAIL if absence is positively known from a complete set, UNRESOLVED if assignment closure is incomplete. Never infer exit button, emergency release or contact role from a device name.

### 16. Dependency set
Door assembly root, role assignment member set, component definition refs, topology-profile edition/hash and selector markers for components assigned to the door.

### 17. Calculation trace
`ACS01_INDEX_ROLE_ASSIGNMENTS_V1`, `ACS01_COUNT_ROLE_V1`, `ACS01_EVAL_ALL_OF_V1`, `ACS01_EVAL_ALTERNATIVE_V1`, `ACS01_EVAL_MULTIPLICITY_V1`, `ACS01_SELECT_GOVERNING_REQUIREMENT_V1`.

### 18. Complexity/resource bounds
O(A+R) with assignments indexed by role; requirement tree is bounded and acyclic. No exponential search: alternatives are evaluated directly from closed predicates. Qualification must cover 2000 ACS assignments.

### 19. Pseudocode
```text
roles = indexEligibleAssignmentsByRole()
result = eval(profile.rootRequirement, roles)
requireNoIllegalSharing(profile, assignments)
return buildDimensionResults(result, canonicalFailedLeaves(result))
```

### 20. Dart interfaces
```dart
final class Acs01Input { final DoorAssemblyId doorId; final AcsDoorTopologyProfile profile; final List<AcsRoleAssignment> assignments; final Map<ComponentId,AcsComponentCapabilities> capabilities; }
final class Acs01Output { final List<AcsRoleRequirementResult> requirements; final List<AcsSelectedAlternative> selectedAlternatives; }
```

### 21. Positive reference vector
Profile requires entry reader + lock + `(exitReader OR exitButton)`. Assignments contain entry reader, lock, exit button. PASS; selected alternative `exitButton` recorded.

### 22. Boundary vector
Profile minimum two door contacts and exactly two eligible assignments => integer margin 0 PASS. Third contact under exact-two rule => FAIL, not “more is better”.

### 23. Negative vector
Profile requires lock and contact; complete assignment set lacks contact => completed FAIL on contact role while other roles pass.

### 24. Adversarial vector
One component is assigned both `EXIT_BUTTON` and `EMERGENCY_RELEASE` but its capability/profile forbids role sharing. Must FAIL semantic sharing rather than satisfy two requirements with one row.

### 25. Cross-discipline vector
ACS-06 consumes the same door/role identities for path/release logic. ACS-01 role PASS cannot imply ACS-06 release truth-table PASS or ELV7 legal egress compliance.

---

## ACS-02 — Controller channel/resource capacity

### 1. Physical meaning
Checks independent controller resource pools—reader channels, relay outputs, supervised inputs and other explicitly profiled hardware resources—against exact door/device assignments and spare policy.

### 2. Applicability matrix
Exact resource inventory and assignments => applicable. Unknown resource type/capability => unresolved for that pool. Sharing/multiplexing is allowed only via an explicit supported model.

### 3. Exact typed inputs
`ControllerId`, typed physical `ControllerResourceId`, `AcsResourceKind`, capability metadata, assignment set, optional supported multiplexing relation, unavailable/reserved resources, spare policy per resource kind.

### 4. Evidence requirements
Controller resource inventory/capabilities from immutable definition; assignments revision-scoped. Spare policy is explicit and resource-kind aware.

### 5. Operating cases
`READER_CHANNELS`, `RELAY_CHANNELS`, `INPUT_CHANNELS` plus any code-owned additional resource kind selected by the controller profile.

### 6. Mathematical model
For each resource pool, validate unique assignments/share semantics, count occupied physical units, compute required spare, compare against available compatible units. Pools remain independent.

### 7. Equations
For pool `k`: `occupied_k=|distinct physical resources assigned|`; `spare_k=policy(k,occupied_k)`; `margin_k=available_k-occupied_k-spare_k`.

### 8. Exact/bounded arithmetic
Counts exact integers; ratio spare uses rational+ceil. Physical resource IDs prevent alias double counting.

### 9. Worst-case selection
Governing pool has smallest signed headroom or any incompatible/duplicate assignment. Free reader channels never compensate relay deficit.

### 10. Requirement composition
Spare/resource policies merge per resource kind only when semantics are compatible. Unsupported sharing model blocks instead of increasing capacity.

### 11. Comparison equations
Inclusive capacity PASS iff `margin_k>=0`; assignment compatibility independently required.

### 12. Margin equation
Integer resource headroom per pool; optional utilization is display-only.

### 13. Governing-case algorithm
Evaluate semantic assignment validity first, then all resource pools, choose FAIL/unresolved before PASS and smallest headroom among comparable pools.

### 14. Limiting-factor algorithm
Return exact controller, resource kind and conflicting/limiting channel IDs plus assignments.

### 15. Missing/unsupported behavior
Missing relay inventory can leave relay unresolved while reader capacity known. Do not infer available channel count from model name.

### 16. Dependency set
Controller definition/hash, physical resource set, assignment root/members, reserve/unavailable set and multiplex/spare policy.

### 17. Calculation trace
`ACS02_VALIDATE_RESOURCE_ASSIGNMENT_V1`, `ACS02_COUNT_OCCUPIED_V1`, `ACS02_COMPUTE_SPARE_V1`, `ACS02_COMPARE_POOL_CAPACITY_V1`.

### 18. Complexity/resource bounds
O(R+A) using resource-ID maps; no door×resource Cartesian scan.

### 19. Pseudocode
```text
inventory = indexResourcesByKindAndId()
validateAssignments(assignments, inventory, sharingModel)
for kind in requiredKinds:
  occupied = distinctOccupied(kind)
  spare = policy.requiredSpare(kind, occupied)
  compare(available(kind), occupied + spare)
```

### 20. Dart interfaces
```dart
final class Acs02Input { final ControllerId controllerId; final List<AcsControllerResource> resources; final List<AcsResourceAssignment> assignments; final AcsResourceSparePolicy sparePolicy; }
final class Acs02Output { final Map<AcsResourceKind,AcsResourcePoolResult> pools; }
```

### 21. Positive reference vector
4 reader channels/3 used => +1; 2 relay/2 used => 0; explicit zero spare => both PASS.

### 22. Boundary vector
2 supervised inputs, 1 used, spare policy requires 1 => margin 0 PASS.

### 23. Negative vector
Third relay assignment against 2 exclusive relay outputs => relay FAIL while reader pool remains PASS.

### 24. Adversarial vector
Same physical relay appears under two logical labels. Canonical `ControllerResourceId` exposes collision; it cannot become two units.

### 25. Cross-discipline vector
ACS-03 may use a relay control relationship, but controller relay capacity never means the relay supplies lock power. Power feed is separate ELV4 physical evidence.

---

## ACS-03 — Lock electrical demand and terminal-voltage transient basis

### 1. Physical meaning
Evaluates lock electrical behavior across holding, active/release and startup/inrush temporal events while preserving complete shared-trunk load and exact ELV4 terminal-voltage/current evidence. It distinguishes control contact from power feed.

### 2. Applicability matrix
| Condition | Result |
|---|---|
| Explicit lock state profile + conductive feed + supported ELV4 DC model | APPLICABLE |
| Control relay path only, no feed | BLOCKED/FAIL required-feed |
| Startup pulse specified and ELV4 transient/simultaneity model supported | APPLICABLE |
| Startup specified but transient model unsupported | startup UNRESOLVED/BLOCKED |
| Shared trunk membership incomplete | BLOCKED |

### 3. Exact typed inputs
`DoorAssemblyId`, `LockId`, state-load profile (`holding`, `active/release`, `startup/inrush` current/power and duration where relevant), state transition policy, simultaneity/event envelope, conductive feed path refs, control path refs, minimum/maximum permitted terminal voltage if technical policy requires, exact PWR-01/PWR-03 evidence per generated operating event.

### 4. Evidence requirements
Lock state values require explicit catalog/project evidence basis. Conductive feed comes from canonical topology, not controller adjacency. ELV4 evidence must include complete shared trunk/source membership including non-ACS loads where applicable.

### 5. Operating cases
At least `HOLDING`, `ACTIVE`, `STARTUP_INRUSH`; additional `FIRE_RELEASE`/`POWER_FAILURE` electrical states when ACS-06 truth table and lock profile make them electrically distinct. Cases carry explicit event duration and overlap/simultaneity semantics.

### 6. Mathematical model
Generate a bounded set of physically possible temporal demand events from lock state profile and simultaneity policy. Resolve each event through exact matching ELV4 physical evidence; do not solve voltage drop locally. For each case evaluate lock terminal voltage and shared source/trunk current/capacity dimensions.

### 7. Equations
Lock contribution for state `c` is captured `I_lock(c)` or `P_lock(c)`. Shared trunk current is authoritative upstream `I_trunk(c)`, not `I_lock`. For minimum terminal voltage requirement: `Mlow=VterminalLower-Vmin`. For maximum allowed voltage: `Mhigh=Vmax-VterminalUpper`. Source/current margin is reused from upstream physical evidence where exposed.

### 8. Exact/bounded arithmetic
Electrical quantities are exact/bounded types. Temporal event intervals/durations are exact. No multiplying startup current by an arbitrary duty factor unless policy/model explicitly defines an RMS/thermal transformation. Voltage/current calculations are not reimplemented in ELV5.

### 9. Worst-case selection
Select the smallest signed required electrical margin across all generated events and required feed points. A short startup case can govern even when steady holding/active states pass. Missing required transient evidence prevents using steady-state PASS as overall PASS.

### 10. Requirement composition
Lock technical voltage/current requirements compose with source-owned ELV4 requirement sets. Startup simultaneity comes from explicit project policy; “all locks start together” or “none do” is never silently assumed.

### 11. Comparison equations
`Mlow=VterminalLower-Vmin`; `Mhigh=Vmax-VterminalUpper`; source capability margins are reused from accepted upstream results. Required-feed topology is boolean and independent.

### 12. Margin equation
Voltage margins in V, source/current margins in A/W as their own dimensions. Governing status may be selected across dimensions by status/severity, but physical margins are never numerically added/normalized into a fake unitless engineering margin.

### 13. Governing-case algorithm
Generate required temporal events in deterministic event-key order, require matching PWR evidence, evaluate terminal/source dimensions, then choose any FAIL, then unresolved, else smallest policy-relative headroom. Record exact event ID and duration.

### 14. Limiting-factor algorithm
Return temporal event, lock/feed segment and terminal/source dimension. For missing conductive feed, limiting factor is topology edge absence rather than relay control path.

### 15. Missing/unsupported behavior
Control-only relay adjacency cannot stand in for feed. Missing startup current/duration leaves startup dimension unresolved when required. Unsupported shared topology/model blocks affected event; do not approximate with branch-only current.

### 16. Dependency set
Lock immutable state profile, door/lock membership, conductive feed topology, control topology for separation proof, simultaneity/event policy, exact PWR-01/PWR-03 evaluation IDs/hashes/generations and shared-membership selector markers.

### 17. Calculation trace
`ACS03_BUILD_TEMPORAL_EVENTS_V1`, `ACS03_BIND_LOCK_STATE_LOAD_V1`, `ACS03_VERIFY_CONDUCTIVE_FEED_V1`, `ACS03_BIND_PWR01_SHARED_DEMAND_V1`, `ACS03_BIND_PWR03_TERMINAL_VOLTAGE_V1`, `ACS03_VOLTAGE_MARGIN_V1`, `ACS03_SELECT_GOVERNING_EVENT_V1`.

### 18. Complexity/resource bounds
Event generation is O(L*E) only over bounded selected locks/events, not all combinations. The simultaneity policy must produce a bounded envelope rather than powerset enumeration. Qualification includes startup overlap scenarios and shared non-ACS trunk loads.

### 19. Pseudocode
```text
requireConductiveFeed(lock)
events = simultaneityPolicy.buildBoundedEvents(lockStateProfile)
for event in events:
  pwr01 = requireExactPwr01(event.scope, event.case)
  pwr03 = requireExactPwr03(lock.feedTerminal, event.case)
  assertGlobalMembershipClosure(pwr01, pwr03)
  assessTerminalVoltage(pwr03, lock.voltageRequirements)
  assessSourceAndTrunkMargins(pwr01, pwr03)
return selectGoverningEvent()
```

### 20. Dart interfaces
```dart
final class Acs03Input { final DoorAssemblyId doorId; final LockId lockId; final AcsLockElectricalProfile lockProfile; final AcsTransientEnvelopePolicy transientPolicy; final Elv4PowerEvidenceSet evidence; final AcsLockElectricalRequirements requirements; }
final class Acs03Output { final List<AcsLockOperatingCaseResult> cases; final String governingCaseId; final Elv5LimitingFactor limitingFactor; }
```

### 21. Positive reference vector
Shared trunk currents 0.3 A + 0.5 A = 0.8 A at 24 V; trunk resistance 0.5 Ω gives 0.40 V drop and 23.60 V branch origin; lock branch current 0.3 A through 0.3 Ω gives 0.09 V branch drop. Accepted ELV4 evidence therefore gives lock terminal **23.51 V**. Requirement minimum 22.00 V => **+1.51 V** margin; shared 0.8 A retained.

### 22. Boundary vector
Startup event terminal lower bound exactly equals 22.0 V minimum => 0 V margin inclusive PASS. Holding event has larger margin; startup remains governing.

### 23. Negative vector
Steady states pass, startup event terminal lower bound 20.8 V vs 22 V => -1.2 V startup FAIL; completed process FAIL despite short event duration.

### 24. Adversarial vector
Developer attempts branch-only voltage drop using 0.3 A and ignores another 0.5 A shared trunk load. Cross-check against PWR evidence/membership fingerprint rejects reduced closure. A dry relay connection with no source/feed must not calculate voltage.

### 25. Cross-discipline vector
The same shared DC trunk may feed ACS, fire auxiliaries or other ELV loads. ACS-03 uses global ELV4 current/voltage evidence; discipline filtering affects contribution/explanation only, never physical trunk current.

---

## ACS-04 — ACS source/PSU requirement

### 1. Physical meaning
Determines whether the shared physical DC source capability satisfies the effective source-owned requirement set when ACS policy participates, while keeping actual physical demand separate from sizing reserve/derating.

### 2. Applicability matrix
Applicable with complete global demand evidence (PWR-01), exact source capability/requirement evaluation (PWR-02) and compatible ACS requirement policy. Conflicting requirement semantics are BLOCKED, not arbitrarily merged.

### 3. Exact typed inputs
Source ID, required scenario set, ACS policy requirements (reserve factor/min margin/derating applicability or equivalent typed constraints), exact PWR-01 demand evidence, PWR-02 source capability evidence, source definition ref and complete participating discipline requirement set fingerprint.

### 4. Evidence requirements
Demand must be complete global physical source demand. Rating/derating comes from immutable source/equipment evidence or explicit project environment. ACS policy is versioned and source-applicable.

### 5. Operating cases
`SOURCE_REQUIREMENT_SET` per required operating case/scenario, including normal/peak/startup where PWR-02 model distinguishes them.

### 6. Mathematical model
Use deterministic requirement merger to build the effective requirement for each physical dimension on one global demand. Consume PWR-02 output that applies reserve/derating at the source capability boundary once. ELV5 exposes ACS requirement provenance and resulting global margin; it does not create a second source calculation.

### 7. Equations
Conceptual requirement where policy explicitly uses multiplicative reserve: `RequiredCapability = GlobalDemand * ReserveFactor`. Available capability where supported: `Available = NameplateRating * DeratingFactor`. `Margin=Available-RequiredCapability`. These equations are owned/executed by the source/PWR-02 model; ACS-04 verifies and projects the exact resulting evidence.

### 8. Exact/bounded arithmetic
Reserve/derating are exact rationals/intervals with applicability. No percentage rounding. Physical demand remains its original value and is not overwritten with reserved requirement.

### 9. Worst-case selection
Across source scenarios/dimensions select smallest signed capability margin after deterministic requirement merge. A policy conflict/missing global load governs before a positive local estimate.

### 10. Requirement composition
For same dimension/direction, strongest compatible source requirement wins while all contributors remain in provenance. Incompatible reserve semantics, environmental applicability or scenario meanings yield explicit conflict. Reserve is never multiplied once per door/load.

### 11. Comparison equations
`margin=effectiveAvailableCapability-effectiveRequiredCapability`; PASS iff conservative lower margin >=0. `GlobalDemand` is separately reported and not compared as if it already includes reserve unless PWR-02 schema explicitly says so.

### 12. Margin equation
Per source dimension (W/A/etc.) signed headroom. No mixing W and A without an explicit supported electrical transformation owned by ELV4.

### 13. Governing-case algorithm
Verify PWR-01/PWR-02 closure and matching requirement-set hash, then collect mandatory source-dimension margins across cases and choose smallest lower-bound margin; requirement conflict => BLOCKED governing reason.

### 14. Limiting-factor algorithm
Return source, operating case, physical dimension and requirement contributor(s) that created the effective strongest requirement or conflict.

### 15. Missing/unsupported behavior
Missing auxiliary/non-ACS loads blocks global sizing PASS. Missing derating evidence when required leaves available capability unresolved. Never estimate capability from label/model name.

### 16. Dependency set
PWR-01 and PWR-02 evaluation IDs/hashes/generations, source definition/environment facts, ACS policy edition, global participating requirement-set selector/fingerprint.

### 17. Calculation trace
`ACS04_VERIFY_GLOBAL_DEMAND_V1`, `ACS04_MERGE_SOURCE_REQUIREMENTS_V1`, `ACS04_BIND_PWR02_CAPABILITY_V1`, `ACS04_COMPARE_EFFECTIVE_CAPABILITY_V1`, `ACS04_SELECT_GOVERNING_SOURCE_CASE_V1`.

### 18. Complexity/resource bounds
O(Q+C) over source dimensions and requirement contributors; deterministic merger uses indexed dimension keys, not pairwise policy comparison explosion.

### 19. Pseudocode
```text
demand = requireExactPwr01Global(source, cases)
requirements = mergeDeterministically(allApplicableSourceRequirements)
pwr02 = requireExactPwr02(source, demand.hash, requirements.hash)
for dimension in requirements.requiredDimensions:
  margin = pwr02.available(dimension) - pwr02.required(dimension)
  assess(margin)
return selectSmallestMarginOrConflict()
```

### 20. Dart interfaces
```dart
final class Acs04Input { final PowerSourceId sourceId; final AcsSourceRequirementPolicy acsPolicy; final Elv4Pwr01Evidence demand; final Elv4Pwr02Evidence capability; final Elv5RequirementSetFingerprint globalRequirementSet; }
final class Acs04Output { final List<SourceCapabilityDimensionResult> dimensions; final PowerQ globalDemand; final List<RequirementContributorRef> requirementContributors; }
```

### 21. Positive reference vector
Global demand 30 W; effective reserve factor 1.2 => required 36 W; source rating 50 W with applicable derating 0.8 => available 40 W; margin +4 W. Actual physical demand remains 30 W.

### 22. Boundary vector
Required 40 W and derated available exactly 40 W => 0 W inclusive PASS. Display as 40 W does not hide exact rational factors.

### 23. Negative vector
Global demand 35 W, reserve 1.2 =>42 W required; available40 W => -2 W FAIL.

### 24. Adversarial vector
Five doors each carry same source reserve policy ref. Requirement merger must apply the source-owned reserve once, not compute `demand*1.2^5` or reserve each door then sum. A reduced ACS-only demand is rejected.

### 25. Cross-discipline vector
Fire and ACS policies on the same source participate in one requirement set. The strongest compatible requirement can originate from Fire while ACS-04 still reports the same global source result; discipline ownership affects provenance, not physical source arithmetic.

---

## ACS-05 — ACS backup/autonomy requirement

### 1. Physical meaning
Projects ACS protected-load contribution and autonomy policy onto the complete shared protected sequence and exact ELV4 PWR-04 bank model, proving required sequence energy/capacity only within the selected supported battery model.

### 2. Applicability matrix
Applicable with explicit ordered protected sequence, complete global load membership, exact required durations and supported PWR-04 battery model/evidence. Nominal Ah shortcut outside model applicability is unsupported.

### 3. Exact typed inputs
BatteryBankId, protected sequence ID, ordered state segments with durations/cases, ACS contribution membership, autonomy policy, exact PWR-04 evaluation ref/hash/generation, bank definition/environment/end-of-discharge evidence and any required peak-current dimension.

### 4. Evidence requirements
All protected loads—ACS and non-ACS—must be present. Durations are explicit policy facts. Bank usable energy/capacity comes from exact supported ELV4 model with temperature/aging/EOD applicability where modeled.

### 5. Operating cases
`PROTECTED_SEQUENCE` consisting of ordered standby/active/release/etc. segments; transient peak-current subcases remain separate if bank model requires them.

### 6. Mathematical model
Do not recompute battery behavior locally. Verify that PWR-04 evaluated the exact protected sequence and bank model. Expose global required/available energy/capacity margin and ACS energy contribution computed from canonical upstream contributor segmentation for explanation.

### 7. Equations
For an energy-capable sequence model, conceptual segment energy `E_i=P_i*t_i`; global `Ereq=Σ E_i` plus only model-owned physical losses/factors. `MarginEnergy=Eavailable-Erequired`. ACS contribution `Eacs=Σ ACS contributor energy` without replacing global requirement.

### 8. Exact/bounded arithmetic
Power×duration uses exact rational energy units; conversions Wh/J are exact scale transformations. Ah is only used when PWR-04 model defines voltage/current/discharge relation. Do not equate nominal Ah with usable Wh generically.

### 9. Worst-case selection
Use upstream PWR-04 governing sequence segment/dimension, including energy, current or EOD constraint. An energy-positive result cannot hide peak-current failure.

### 10. Requirement composition
Autonomy durations/extensions merge through explicit policy rules; shared bank factors/losses/aging/temperature are applied once by PWR-04. No discipline-local battery reserve duplication.

### 11. Comparison equations
Reuse upstream `available-required` energy/capacity/current margins. Duration coverage is explicit: every required segment duration must be represented in sequence fingerprint.

### 12. Margin equation
Energy margin (Wh/J), current margin (A) and any capacity model margin remain separate. ACS contribution is explanatory quantity, not margin.

### 13. Governing-case algorithm
Verify exact sequence fingerprint and bank evidence; preserve PWR-04 governing dimension/segment. Additional ACS duration requirement can govern only by producing a new exact sequence/evaluation, not by post-hoc relabeling old evidence.

### 14. Limiting-factor algorithm
Bank model, segment/case and physical dimension from PWR-04; if closure incomplete identify missing protected load/duration.

### 15. Missing/unsupported behavior
Missing duration/load/model applicability => BLOCKED. No default “X hours”. Sequence energy subtotal may be shown but never qualify autonomy.

### 16. Dependency set
PWR-04 evaluation ID/hash/generation, protected load set+selector marker, sequence segment root/members, bank definition/environment and ACS autonomy policy.

### 17. Calculation trace
`ACS05_VERIFY_SEQUENCE_FINGERPRINT_V1`, `ACS05_SELECT_ACS_CONTRIBUTION_V1`, `ACS05_REUSE_PWR04_ENERGY_V1`, `ACS05_VERIFY_DURATION_COVERAGE_V1`, `ACS05_REUSE_BANK_MARGIN_V1`.

### 18. Complexity/resource bounds
O(S+C) sequence segments/contributors; no discharge numerical integration in ELV5. Sequence segment count is bounded by shared resource limits.

### 19. Pseudocode
```text
seq = requireCompleteProtectedSequence()
pwr04 = requireExactPwr04(bankId, seq.hash, policy.hash)
requireAllDurationsCovered(pwr04, policy)
acsContribution = sum(pwr04.segmentContributors where discipline=ACS)
return project(pwr04.required, pwr04.available, pwr04.margin, acsContribution, pwr04.governing)
```

### 20. Dart interfaces
```dart
final class Acs05Input { final BatteryBankId bankId; final ProtectedSequence sequence; final Set<LoadId> acsProtectedLoads; final AcsAutonomyPolicy policy; final Elv4Pwr04Evidence evidence; }
final class Acs05Output { final EnergyQ globalRequiredEnergy; final EnergyQ acsContributionEnergy; final EnergyQ availableEnergy; final EnergyQ energyMargin; final Elv5LimitingFactor limitingFactor; }
```

### 21. Positive reference vector
Supported fixture: constant 19.2 W global protected demand for 3600 s =>19.2 Wh required; usable bank134.4 Wh => +115.2 Wh global energy margin.

### 22. Boundary vector
Required sequence energy exactly equals usable supported bank energy => 0 Wh margin PASS only if peak-current/EOD dimensions also pass.

### 23. Negative vector
Energy requirement fits, but exact PWR-04 peak-current dimension fails in a release/startup segment. Overall FAIL on peak-current limiting segment.

### 24. Adversarial vector
ACS-only protected loads would require 10 Wh while shared fire/other loads raise global requirement to 140 Wh >134.4 Wh. Discipline filtering must not yield false PASS. Nominal Ah conversion without supported voltage/discharge model is rejected.

### 25. Cross-discipline vector
FA-05 and ACS-05 sharing a bank must reference the same global protected sequence/evaluation where policy scopes overlap, each exposing discipline contribution without duplicating physical losses/reserves.

---

## ACS-06 — Door control/feed/release topology and truth table

### 1. Physical meaning
Validates typed ACS door control, data, power-feed, monitoring and release behavior for five canonical causes, using an explicit fail-safe/fail-secure/project-defined safety mode. It proves project technical topology behavior, not legal egress certification.

### 2. Applicability matrix
| Cause/model | Requirement |
|---|---|
| NORMAL_ACCESS | control path + expected lock behavior |
| REQUEST_TO_EXIT | selected REX path/behavior |
| FIRE_RELEASE | explicit fire-release dependency when profile requires |
| EMERGENCY_BREAK_GLASS | explicit independent/manual path where profile requires |
| POWER_FAILURE | behavior derived from explicit safety mode/feed topology |
Unknown safety mode or incomplete truth table => BLOCKED; no device-name inference.

### 3. Exact typed inputs
Door assembly/role assignments, controller/reader/lock IDs, typed directed graph edges (`DATA`, `CONTROL`, `POWER_FEED`, `MONITOR`, `RELEASE`), `AcsLockSafetyMode`, exact five-row `AcsReleaseTruthTable`, topology profile, supervision requirements and optional exact fire-interface evidence ref.

### 4. Evidence requirements
Paths are canonical project graph facts; component role/capability definitions explicit. Truth-table rows are persisted/versioned, complete and canonicalized. Fire release integration is technical signal evidence only.

### 5. Operating cases
Exactly `NORMAL_ACCESS`, `REQUEST_TO_EXIT`, `FIRE_RELEASE`, `EMERGENCY_BREAK_GLASS`, `POWER_FAILURE` unless a future version changes the schema. Every row is evaluated independently.

### 6. Mathematical model
For each cause, evaluate reachability/path-role predicates plus expected lock outcome from the persisted truth table and safety mode. Control reachability and power-feed reachability are different graphs/edge predicates. Supervision path is independent where required.

### 7. Equations
Topology uses graph predicates: `reachable(source,target,allowedEdgeKinds)`, required cut/release dependencies and expected-state equality. No numeric equation for release correctness. Optional path-length/electrical facts remain upstream processes.

### 8. Exact/bounded arithmetic
Pure deterministic graph/set operations; no timing assumption unless an explicit bounded timing model is added in a later algorithm version.

### 9. Worst-case selection
Any mandatory cause failure makes overall topology FAIL. Unknown evidence in a required cause is UNRESOLVED/BLOCKED. PASS requires all required causes complete and passing.

### 10. Requirement composition
Door profile and project safety mode/truth table must be compatible. Fire/emergency requirements may add technical dependencies; regulatory adequacy remains ELV7.

### 11. Comparison equations
Boolean typed predicates: required path exists, forbidden dependency absent, expected lock outcome equals modeled outcome, supervision requirement satisfied. Numeric margins are not fabricated.

### 12. Margin equation
Not numeric. Optional resource/path metrics are diagnostics only unless profile defines explicit numeric limits.

### 13. Governing-case algorithm
Evaluate causes in stable canonical order. Overall status follows mandatory row statuses; first FAIL in canonical cause order is default governing cause, but findings include all failures.

### 14. Limiting-factor algorithm
Return cause plus missing/incorrect graph edge/path role or expected-vs-modeled lock outcome. For power failure, include safety mode and feed dependency.

### 15. Missing/unsupported behavior
Missing any required row/safety mode/profile path evidence blocks completeness. Lock connected only to a dry relay with no independent feed fails required-feed topology. Do not infer “fail safe” from lock name.

### 16. Dependency set
Door assembly, role assignments, typed graph edge sets/selectors, safety mode, truth table hash, topology profile, controller resources and optional fire-interface technical evidence.

### 17. Calculation trace
`ACS06_CANONICALIZE_TRUTH_TABLE_V1`, `ACS06_VALIDATE_FIVE_CAUSES_V1`, `ACS06_REACHABILITY_BY_EDGE_KIND_V1`, `ACS06_EXPECTED_LOCK_OUTCOME_V1`, `ACS06_VERIFY_REQUIRED_FEED_V1`, `ACS06_VERIFY_SUPERVISION_V1`.

### 18. Complexity/resource bounds
For bounded door-local graph V/E, five reachability checks are O(5*(V+E)); reuse indexed adjacency by edge kind. Never traverse whole project graph when capture already scopes the door subgraph.

### 19. Pseudocode
```text
requireCompleteCanonicalFiveRowTruthTable()
graph = buildDoorLocalTypedAdjacency(capturedEdges)
for cause in canonicalCauses:
  expected = truthTable[cause]
  paths = evaluateRequiredPaths(graph, profile, cause)
  modeled = deriveLockOutcome(paths, safetyMode, feedFacts, cause)
  assess(paths, modeled == expected)
return aggregateAllRequiredCauses()
```

### 20. Dart interfaces
```dart
final class Acs06Input { final DoorAssemblyId doorId; final AcsDoorGraph graph; final AcsDoorTopologyProfile profile; final AcsLockSafetyMode safetyMode; final AcsReleaseTruthTable truthTable; }
final class Acs06Output { final Map<AcsReleaseCause,AcsReleaseCauseResult> causes; }
```

### 21. Positive reference vector
Explicit reader→controller data, controller→relay control, independent 24 V lock feed, exit-button path, fire-release input and emergency break-glass path. Five truth-table rows match modeled outcomes => technical topology PASS.

### 22. Boundary vector
All five rows pass except supervision is optional under selected profile: supervision dimension is NOT_APPLICABLE, not PASS by absence. Overall can pass if no other mandatory requirement exists.

### 23. Negative vector
Lock has controller dry-contact control but no conductive power feed. NORMAL_ACCESS control path exists; required-feed dimension FAIL and overall topology FAIL.

### 24. Adversarial vector
Truth table contains duplicate FIRE_RELEASE row and omits POWER_FAILURE; canonicalization rejects table before graph evaluation. A component name “Emergency Door Release” without assigned role/path provides no evidence.

### 25. Cross-discipline vector
Fire-interface edge used by FIRE_RELEASE may originate in Fire topology, but ACS-06 verifies only selected technical dependency. ELV7 later determines whether that behavior satisfies applicable life-safety rules; ACS result remains immutable technical evidence.