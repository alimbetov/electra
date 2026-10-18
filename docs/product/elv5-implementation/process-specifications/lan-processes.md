# ELV5 LAN — production code-level process dossiers

Status: DESIGN HARDENING / RUNTIME NOT STARTED  
Parent: `process-code-level-specification.md`, `process-contracts.md`, `calculation-engine-contract.md`.

All numerical vectors are fictional product-neutral fixtures.

---

## LAN-01 — Permanent-link and channel length

### 1. Physical meaning
Computes installed permanent-link and complete-channel lengths from the exact ordered ELV3 realized sections, preserving which length contributions are already included. It prevents double adding service loops, terminations, slack or patch cords.

### 2. Applicability matrix
| Path state | Permanent length | Channel length |
|---|---|---|
| Complete ordered realized sections with class | APPLICABLE | APPLICABLE |
| Permanent sections complete, patch set unknown | APPLICABLE | UNRESOLVED |
| Duplicate/ambiguous section identity | INVALID/BLOCKED | INVALID/BLOCKED |
| Room distance only, no realized path | BLOCKED | BLOCKED |
| Policy lacks numeric limit | value reported | value reported, no threshold PASS |

### 3. Exact typed inputs
`LinkId`, ordered unique `RealizedLinkSectionId`, each section’s installed `LengthQ` interval/value, `LinkSectionClass {permanent,patch,otherExplicit}`, provenance flags showing included slack/termination/service loop, exact link policy edition with optional permanent/channel limits and inclusivity.

### 4. Evidence requirements
Lengths and section ordering come only from canonical ELV3 realized path evidence. Additional not-yet-included allowances require explicit project facts with ownership/provenance. A generic percentage is never added from a UI default.

### 5. Operating cases
`PERMANENT_LINK` and `CHANNEL`. Both use the same captured path but different section predicates.

### 6. Mathematical model
Partition the ordered path by explicit section class. Permanent length is exact sum of permanent installed contributions plus only explicit additions marked not already included. Channel length is the exact union/sum of all included channel sections, with each canonical section counted once.

### 7. Equations
`Lperm = Σ length(s), s∈Permanent + Σ explicitNotIncludedAllowance`.
`Lchannel = Σ length(s), s∈ChannelUnique`.
For limits: `Mperm=LpermMax-LpermUpper`; `Mchannel=LchannelMax-LchannelUpper` for maximum constraints.

### 8. Exact/bounded arithmetic
Lengths use exact decimal/rational SI representation or conservative intervals. Sum lower/upper bounds independently. Display rounding occurs after comparison. Duplicate canonical section IDs are rejected before summation.

### 9. Worst-case selection
Maximum-length requirements use upper length bounds. Governing case is the smaller signed headroom among permanent and channel required dimensions. A known permanent PASS cannot cover unresolved channel length.

### 10. Requirement composition
Permanent and channel limits are independent requirements from the selected policy edition. If multiple compatible project policies constrain the same quantity, deterministic merger selects the strongest maximum. No universal hardcoded 90/100 m rule exists in kernel code.

### 11. Comparison equations
For inclusive maximum `L<=Lmax`, `margin=Lmax-Lupper`. PASS iff margin>=0. For exclusive maximum, PASS iff margin>0.

### 12. Margin equation
Margins remain `LengthQ`. Optional utilization `L/Lmax` is display/diagnostic and never substitutes exact length margin.

### 13. Governing-case algorithm
Resolve both case dimensions. Any invalid path identity governs as BLOCKED. Otherwise FAIL outranks unresolved/pass; among comparable numeric dimensions choose the smallest signed margin, tie-breaking permanent before channel then canonical requirement code.

### 14. Limiting-factor algorithm
For an over-limit path, report the governing dimension plus ordered section contribution list. The “limiting section” is not necessarily the longest section; output exact cumulative point where the limit is crossed for explanation, while verdict is based on total.

### 15. Missing/unsupported behavior
Unknown section length leaves affected aggregate unresolved with known subtotal labeled. Unknown classification prevents permanent/channel partition. Do not infer patch/permanent from component names. No straight-line fallback.

### 16. Dependency set
ELV3 realized path root/member fingerprints, section lengths/classes/provenance, explicit allowance facts, policy edition/hash and any selector marker that determines path membership.

### 17. Calculation trace
`LAN01_VALIDATE_PATH_IDENTITY_V1`, `LAN01_PARTITION_SECTIONS_V1`, `LAN01_SUM_PERMANENT_V1`, `LAN01_SUM_CHANNEL_V1`, `LAN01_ADD_EXPLICIT_ALLOWANCE_V1`, `LAN01_COMPARE_PERMANENT_V1`, `LAN01_COMPARE_CHANNEL_V1`.

### 18. Complexity/resource bounds
O(P) over ordered path sections; no route search in LAN-01. Canonical output remains path ordered. Shared code-owned path-size bound applies; qualification requires realistic multi-section paths and rejects duplicate identity before allocation-heavy work.

### 19. Pseudocode
```text
path = requireUniqueOrderedRealizedSections(linkId)
perm = 0
channel = 0
for s in path:
  channel += s.installedLength
  if s.class == PERMANENT: perm += s.installedLength
for allowance in explicitNotIncludedAllowances:
  applyToDeclaredAggregateExactlyOnce(allowance)
compare(perm, policy.permanentLimit)
compare(channel, policy.channelLimit)
selectSmallestMargin()
```

### 20. Dart interfaces
```dart
final class Lan01Input { final LinkId linkId; final List<RealizedLinkSection> orderedSections; final List<ExplicitLengthAllowance> allowances; final LanLengthPolicy policy; }
final class Lan01Output { final Elv5Interval<LengthQ> permanentLength; final Elv5Interval<LengthQ> channelLength; final Elv5Field<Elv5SignedMargin<LengthQ>> permanentMargin; final Elv5Field<Elv5SignedMargin<LengthQ>> channelMargin; }
```

### 21. Positive reference vector
Permanent installed sections total 28 m, explicit patch cords total 2 m, no extra allowance. Policy permanent<=28 m/channel<=30 m. Both margins 0 m, PASS.

### 22. Boundary vector
Permanent interval `[27.999,28.000] m` against inclusive 28 m => worst-case margin 0 and PASS. Upper bound `28.000001 m` => FAIL despite UI formatting to 28.0 m.

### 23. Negative vector
Permanent 28 m passes; patches total 3 m => channel 31 m against 30 m limit, channel FAIL -1 m, permanent remains PASS.

### 24. Adversarial vector
A 1 m service loop is already embedded in installed ELV3 section length while a legacy UI flag also says “add service loop”. Provenance prevents second addition. Duplicate section ID is rejected rather than double-counted.

### 25. Cross-discipline vector
CCTV-06 consuming the same link must observe the same realized lengths/section IDs. A route edit invalidates both via ELV3 dependency fingerprints; neither process writes a second cable length.

---

## LAN-02 — Switch physical port capacity

### 1. Physical meaning
Determines whether explicit physical switch port pools can host assigned endpoints while satisfying media/speed compatibility and project spare-capacity policy.

### 2. Applicability matrix
Exact port inventory+assignments => applicable. Unknown physical inventory => blocked. Port label without media/speed capabilities => compatibility unresolved. Explicit supported breakout/multiplexing model may alter capacity units; otherwise one physical port is one capacity unit.

### 3. Exact typed inputs
`SwitchId`, physical `PortId` inventory with media/speed capability, endpoint assignment set, reservation set, spare policy (ratio and/or absolute minimum with composition rule), optional explicit multiplexing model.

### 4. Evidence requirements
Port inventory/capabilities come from immutable component edition; assignments are revision-scoped project facts. Spare policy edition is explicit. Pre-reserved ports are identities, not an extra numeric load.

### 5. Operating cases
`PHYSICAL_PORT_ASSIGNMENT` partitioned by compatible resource pool where the profile defines distinct pools.

### 6. Mathematical model
Validate one assignment per non-shareable physical port, test compatibility, count distinct occupied ports, compute required spare from policy, compare occupied+spare with available compatible physical ports excluding explicitly unavailable ports once.

### 7. Equations
For ratio `r>=0`, `ratioSpare=ceil(occupied*r)`. If policy requires max of absolute `A` and ratio: `requiredSpare=max(A,ratioSpare)`. `required=occupied+requiredSpare`; `margin=available-required`.

### 8. Exact/bounded arithmetic
Counts are exact integers; spare ratio is exact rational. Ceil occurs exactly at spare-count boundary. No floating rounding.

### 9. Worst-case selection
Across independent resource pools, governing pool has smallest integer headroom; any incompatible assignment is immediate FAIL regardless of free ports elsewhere.

### 10. Requirement composition
Absolute and ratio spare rules combine only according to explicit policy (`MAX`, `SUM`, or another code-owned supported combiner). No developer-chosen merger.

### 11. Comparison equations
`marginPorts=availableCompatible-occupied-requiredSpare`. PASS iff margin>=0 for inclusive capacity. Compatibility is an independent boolean dimension.

### 12. Margin equation
Integer port headroom; utilization percentage may be derived for UI.

### 13. Governing-case algorithm
First semantic duplicate/incompatibility; otherwise smallest headroom resource pool. Tie by canonical pool ID.

### 14. Limiting-factor algorithm
Return switch/pool/port and assignment causing incompatibility or pool with smallest headroom; include spare requirement provenance.

### 15. Missing/unsupported behavior
Unknown port capability makes affected assignment unresolved. Duplicate endpoint assignment to same exclusive port is invalid. Never assume unused UI row equals physical spare.

### 16. Dependency set
Switch definition hash, port inventory set, assignment root/members, reservation/unavailable set, spare policy and optional multiplexing model.

### 17. Calculation trace
`LAN02_VALIDATE_PORT_ASSIGNMENTS_V1`, `LAN02_COMPATIBILITY_MATCH_V1`, `LAN02_COUNT_OCCUPIED_V1`, `LAN02_CEIL_RATIO_SPARE_V1`, `LAN02_COMPOSE_SPARE_V1`, `LAN02_CAPACITY_COMPARE_V1`.

### 18. Complexity/resource bounds
O(P+A) with maps keyed by PortId; no pairwise endpoint scan. Qualification includes at least 5000 LAN mappings across devices.

### 19. Pseudocode
```text
inventory = indexPortsById()
for assignment in assignments:
  requireExclusiveOrSupportedSharing(assignment)
  checkCompatibility(inventory[assignment.portId], assignment.endpoint)
occupied = distinctAssignedPhysicalPorts()
spare = policy.computeSpare(occupied)
compare(availableCompatible, occupied + spare)
```

### 20. Dart interfaces
```dart
final class Lan02Input { final SwitchId switchId; final List<LanPhysicalPort> ports; final List<LanPortAssignment> assignments; final Set<PortId> unavailable; final LanSparePolicy sparePolicy; }
final class Lan02Output { final CountQ occupied; final CountQ requiredSpare; final CountQ available; final int headroomPorts; final List<PortCompatibilityResult> compatibility; }
```

### 21. Positive reference vector
6 occupied, 8 available, ratio 0.25 => ceil(1.5)=2 spare, required 8, margin 0 PASS.

### 22. Boundary vector
4 occupied, ratio 0.25 => exact 1 spare; available 5 => margin 0 PASS.

### 23. Negative vector
7 occupied, 8 available, ratio 0.25 => ceil(1.75)=2, required 9 => -1 port FAIL.

### 24. Adversarial vector
Same physical port assigned twice through two aliases must be detected by canonical PortId. A pre-reserved physical port is not counted once as unavailable and again as required spare unless policy explicitly models both roles.

### 25. Cross-discipline vector
PoE loads assigned to ports still use ELV4/CCTV-04/LAN-03 global power evidence; LAN-02 port availability cannot imply PoE power capacity.

---

## LAN-03 — LAN PoE shared-source context

### 1. Physical meaning
Projects LAN load contribution/policy onto the same global PWR-06 evidence used by other disciplines; it does not construct a LAN-only PSE budget.

### 2. Applicability matrix
Applicable only with exact current PWR-06 closure/evaluation for required segments/scenarios. Partial discipline-filtered source evidence is invalid.

### 3. Exact typed inputs
PSE/source ID, LAN load membership IDs, required segment/scenario set, exact PWR-06 evidence ref/hash/generation, LAN policy edition.

### 4. Evidence requirements
Canonical ELV4 load identities and immutable PWR-06 evidence with matching closure fingerprint.

### 5. Operating cases
`UPSTREAM_PWR06_CASE_SET`.

### 6. Mathematical model
Reuse global physical demand/capability/margin. Sum LAN-classified contributor values only for explanation.

### 7. Equations
`LanContribution=Σ globalContributors where discipline=LAN`; `GlobalMargin=upstreamMargin`.

### 8. Exact/bounded arithmetic
No new electrical solve. Exact upstream quantities reused; contribution sum is exact.

### 9. Worst-case selection
Upstream global governing case across required scenario set.

### 10. Requirement composition
LAN requirement can participate in source-owned deterministic requirement merger, without changing physical demand or duplicating reserve.

### 11. Comparison equations
Reuse upstream comparison; additional compatible LAN requirement compares against same global basis.

### 12. Margin equation
Global upstream margin only; LAN contribution has no independent capacity margin.

### 13. Governing-case algorithm
Verify evidence closure, then preserve upstream governing case unless a stricter compatible requirement becomes governing through the shared requirement merger.

### 14. Limiting-factor algorithm
Preserve upstream source/segment limiting factor; expose LAN policy conflict separately.

### 15. Missing/unsupported behavior
Stale/partial/mismatched evidence => BLOCKED. Never subtract CCTV/ACS loads from the physical total.

### 16. Dependency set
PWR-06 evidence ID/hash/generation, PSE closure set marker, LAN membership set, policy edition.

### 17. Calculation trace
`LAN03_VERIFY_PWR06_SCOPE_V1`, `LAN03_SELECT_LAN_CONTRIBUTORS_V1`, `LAN03_SUM_CONTRIBUTION_V1`, `LAN03_REUSE_GLOBAL_MARGIN_V1`.

### 18. Complexity/resource bounds
O(K) contributor projection only; bounded by upstream evidence size.

### 19. Pseudocode
```text
e = requireExactCurrentPwr06()
requireClosureFingerprint(e)
lan = exactSum(e.contributors intersect lanMembership)
return project(e.globalDemand, e.margin, lan, e.governingCase)
```

### 20. Dart interfaces
```dart
final class Lan03Input { final PseId pseId; final Set<LoadId> lanLoads; final Elv4Pwr06Evidence evidence; final LanPoePolicy policy; }
final class Lan03Output { final PowerQ globalDemand; final PowerQ lanContribution; final PowerQ globalMargin; }
```

### 21. Positive reference vector
Global demand 30 W, available 35 W, LAN 18 W, CCTV 12 W => global margin 5 W; LAN contribution 18 W.

### 22. Boundary vector
Global margin exactly 0 W => PASS if inclusive upstream requirement.

### 23. Negative vector
Global margin -3 W => FAIL even if LAN contribution alone is below PSE capability.

### 24. Adversarial vector
Filtering the source to only LAN contributors and rerunning must be rejected by closure mismatch.

### 25. Cross-discipline vector
LAN-03 and CCTV-04 over the same PSE must have identical global totals/hash and non-overlapping explanatory contribution subsets unless a canonical load intentionally belongs to multiple reporting classifications, which must be explicitly modeled.

---

## LAN-04 — Copper/path compatibility basis

### 1. Physical meaning
Evaluates the weakest technical capability of every ordered passive/active path section against selected media, interface, speed, connector and shielding policy. Cable category label alone cannot qualify the path.

### 2. Applicability matrix
Applicable with exact path sections and a versioned compatibility matrix. Missing shield continuity or connector capability makes only affected dimension unresolved. Unsupported media/speed combination returns unsupported rather than guessing.

### 3. Exact typed inputs
Ordered sections, cable/connector/interface edition refs, medium, category/class tokens, shielding/continuity facts, selected speed/mode, link policy/matrix edition.

### 4. Evidence requirements
Exact immutable catalog definitions plus ELV3 realized section identities. No text parsing of product names.

### 5. Operating cases
`SELECTED_LINK_MODE`; additional mode only if project explicitly evaluates alternatives as separate what-if cases.

### 6. Mathematical model
Fold path left-to-right through explicit compatibility predicates. For ordered capability domains supplied by policy, path capability is the meet/minimum of section capabilities; otherwise each predicate remains independent.

### 7. Equations
Categorical relations are policy-owned. Numeric sublimits use standard conservative margins. `PathCapability = meet(Capability(section_i))` only when matrix defines a closed ordered lattice/ordering.

### 8. Exact/bounded arithmetic
No ordinal numbers are assigned to categories unless code-owned policy defines them. Numeric length facts reuse LAN-01/ELV3 evidence rather than recalculation.

### 9. Worst-case selection
First incompatible section by canonical path order is explanatory limiting factor; any incompatibility fails path. If all compatible, weakest declared capability relation is governing.

### 10. Requirement composition
Media/speed/connector/shield requirements compose by selected policy edition. Conflicting matrices block; “higher label wins” is forbidden unless explicitly encoded.

### 11. Comparison equations
Compatibility `supports(sectionCapability, requiredMode)`; optional numeric requirement `limit-realized`.

### 12. Margin equation
No fake numeric margin for category compatibility. Numeric subdimensions retain physical units.

### 13. Governing-case algorithm
Unsupported/missing required predicate first; then failed path element; otherwise weakest capability element.

### 14. Limiting-factor algorithm
Return exact section/connector/interface ID and property code that failed/limited capability.

### 15. Missing/unsupported behavior
Unknown one section blocks that property; do not extrapolate from neighboring cable. Missing shield continuity is unresolved rather than assumed from shielded cable type.

### 16. Dependency set
Ordered path fingerprints, immutable component/connector editions, selected mode, compatibility matrix and LAN-01 evidence where referenced.

### 17. Calculation trace
`LAN04_RESOLVE_SECTION_CAPABILITY_V1`, `LAN04_INTERFACE_MATCH_V1`, `LAN04_SHIELD_CONTINUITY_V1`, `LAN04_PATH_MEET_V1`, `LAN04_POLICY_MATCH_V1`.

### 18. Complexity/resource bounds
O(P*R) where `R` is bounded property count per section; typically linear. Matrix lookup must be indexed, not scan an arbitrary imported rule list.

### 19. Pseudocode
```text
for section in orderedPath:
  capability = resolveDefinition(section.definitionRef)
  for requirement in policy.requiredProperties:
    result = policyMatrix.match(capability, requirement)
    record(section, requirement, result)
return aggregateWeakestOrFailure()
```

### 20. Dart interfaces
```dart
final class Lan04Input { final LinkId linkId; final List<LanPathSection> orderedSections; final LanLinkMode requiredMode; final LanCompatibilityPolicy policy; }
final class Lan04Output { final List<LanSectionCompatibility> sections; final Elv5Field<LanPathCapability> pathCapability; }
```

### 21. Positive reference vector
Every section explicitly supports fixture 1 Gb/s mode and required connector/shield predicates => technical policy-match PASS.

### 22. Boundary vector
One section capability exactly equals required capability in an ordered matrix => PASS; there is no “spare category” inference unless policy defines it.

### 23. Negative vector
Main cable supports mode but one patch connector does not => path FAIL on that connector.

### 24. Adversarial vector
A product name contains a higher category token while immutable definition says unsupported. Definition governs; string label is ignored.

### 25. Cross-discipline vector
CCTV-06 may reuse same path facts; LAN-04 remains technical compatibility, while ELV7 owns verified standards compliance.

---

## LAN-05 — Bidirectional optical loss/power budget

### 1. Physical meaning
Computes conservative optical receive-power intervals and sensitivity/overload headroom in both directions using exact wavelength-specific Tx/Rx specifications and installed path loss events. Optical power-budget PASS does not prove protocol reach, dispersion or bandwidth-distance compatibility.

### 2. Applicability matrix
| Evidence | Sensitivity | Overload | Reach |
|---|---|---|---|
| Tx min/max, Rx sensitivity/max, path loss min/max | APPLICABLE | APPLICABLE | NOT_ASSESSED |
| Missing Tx max | sensitivity may assess | overload UNRESOLVED | NOT_ASSESSED |
| Missing Rx overload max | sensitivity assess | UNRESOLVED | NOT_ASSESSED |
| Explicit reach/dispersion profile | same | same | separate optional assessment |
| Mixed wavelength/fiber model without compatible data | BLOCKED | BLOCKED | BLOCKED |

### 3. Exact typed inputs
Per direction: transmitter optic edition, `TxMinDbm`, `TxMaxDbm`; receiver edition, `RxSensitivityDbm`, `RxOverloadMaxDbm`; wavelength; ordered fiber sections with attenuation interval dB/km and length; mated connector-pair loss intervals; splice/event loss intervals; explicit nonnegative required sensitivity design margin; optional separate reach profile.

### 4. Evidence requirements
Guaranteed sensitivity/overload qualification requires guaranteed/worst-case manufacturer or commissioned evidence as selected by policy. Typical optical values may produce estimate-only output. Connector loss is per mated pair/event according to exact definition; connector ends are not automatically doubled.

### 5. Operating cases
Four mandatory physical cases when evidence exists: `A_TO_B_SENSITIVITY`, `A_TO_B_OVERLOAD`, `B_TO_A_SENSITIVITY`, `B_TO_A_OVERLOAD`. Optional reach/dispersion is an additional isolated dimension, never inferred from these four.

### 6. Mathematical model
For each direction, sum a physical attenuation interval from fiber, mated pairs, splices and declared events. Worst low received power uses Tx minimum and loss maximum. Worst high received power uses Tx maximum and loss minimum. Compare low case to sensitivity+required margin and high case to overload maximum.

### 7. Equations
`LossMin=Σ(alphaMin_i*length_i/1000)+Σ connectorLossMin+Σ spliceLossMin+...` dB.
`LossMax` analogous with maxima.
`RxLow=TxMin-LossMax` dBm.
`RxHigh=TxMax-LossMin` dBm.
Sensitivity margin: `Msens=RxLow-(Sensitivity+RequiredSensitivityMargin)` dB.
Overload margin: `Mover=ReceiverMax-RxHigh` dB.
PASS requires both margins >=0 in both required directions.

### 8. Exact/bounded arithmetic
`dBm` optical levels and `dB` attenuation are distinct types. Adding dBm+dBm is illegal. Physical losses are nonnegative dB intervals. Wavelength-specific attenuation multiplication uses exact rational conversion of meters to kilometers. No midpoint loss or rounded dBm decides verdict.

### 9. Worst-case selection
Governing physical case is the smallest signed margin among the four direction/constraint cases. This intentionally allows overload, not only sensitivity, to govern. Optional reach has its own status and cannot change optical power arithmetic.

### 10. Requirement composition
Physical path loss is computed without design reserve hidden inside loss. Required sensitivity margin is an explicit requirement term. Multiple compatible sensitivity margins merge to strongest requirement; no reserve is added to overload loss minimum.

### 11. Comparison equations
Sensitivity PASS iff `TxMin-LossMax >= RxSensitivity+RequiredMargin`.
Overload PASS iff `TxMax-LossMin <= RxOverloadMax`.
Equivalent signed margins are given above and use positive=headroom.

### 12. Margin equation
Return four exact/bounded dB margins plus optional reach headroom in its own dimension. Overall display may show governing minimum dB margin but must retain all four.

### 13. Governing-case algorithm
Compute both directions independently, gather all mandatory margins, choose the lowest lower-bound signed margin. Tie order: A→B sensitivity, A→B overload, B→A sensitivity, B→A overload.

### 14. Limiting-factor algorithm
For loss-driven cases, include direction and largest/top contributors for explanation, but limiting factor is the governing receiver constraint/path. For missing evidence, identify exact optic/wavelength/property.

### 15. Missing/unsupported behavior
Missing TxMin blocks sensitivity only; missing TxMax blocks overload only. Unknown connector event count blocks affected loss interval. Unsupported wavelength/fiber pair blocks direction. Never conclude reach from positive power margin.

### 16. Dependency set
Ordered ELV3 fiber path, lengths, connector/splice event sets, optic definition refs, wavelength, loss policy and optional reach model. Path/set selector markers must invalidate when an event is added.

### 17. Calculation trace
`LAN05_FIBER_LOSS_INTERVAL_V1`, `LAN05_CONNECTOR_PAIR_LOSS_V1`, `LAN05_SPLICE_LOSS_V1`, `LAN05_TOTAL_LOSS_V1`, `LAN05_RX_LOW_V1`, `LAN05_RX_HIGH_V1`, `LAN05_SENSITIVITY_MARGIN_V1`, `LAN05_OVERLOAD_MARGIN_V1`, `LAN05_SELECT_GOVERNING_V1`.

### 18. Complexity/resource bounds
O(P+E) per direction over path sections and loss events; no combinatorial uncertainty enumeration because interval algebra propagates bounds directly. Resource limits bound sections/events; canonical output sorting is O(E log E) only for explanation ordering.

### 19. Pseudocode
```text
for direction in [A_TO_B, B_TO_A]:
  loss = exactLossInterval(direction.path, wavelength)
  rxLow = tx.minDbm - loss.maxDb
  rxHigh = tx.maxDbm - loss.minDb
  sensMargin = rxLow - (rx.sensitivityDbm + requiredMarginDb)
  overloadMargin = rx.overloadMaxDbm - rxHigh
  assess(sensMargin)
  assess(overloadMargin)
governing = minSignedMargin(allRequiredMargins)
```

### 20. Dart interfaces
```dart
final class Lan05DirectionInput { final OpticalEndpoint tx; final OpticalEndpoint rx; final WavelengthQ wavelength; final List<FiberSectionLoss> sections; final List<OpticalLossEvent> events; final AttenuationDbQ requiredSensitivityMargin; }
final class Lan05Input { final Lan05DirectionInput aToB; final Lan05DirectionInput bToA; final Elv5Field<OpticalReachProfile> reachProfile; }
final class Lan05DirectionOutput { final Elv5Interval<AttenuationDbQ> physicalLoss; final OpticalLevelDbmQ rxLow; final OpticalLevelDbmQ rxHigh; final AttenuationDbQ sensitivityMargin; final AttenuationDbQ overloadMargin; }
```

### 21. Positive reference vector
A→B: Tx min/max -3/-2 dBm, loss interval 2.5 dB, sensitivity -15 dBm, overload -1 dBm, required margin 0. `RxLow=-5.5`, sensitivity margin 9.5 dB; `RxHigh=-4.5`, overload margin 3.5 dB. Symmetric B→A passes.

### 22. Boundary vector
`TxMin=-10 dBm`, `LossMax=3 dB`, sensitivity `-13 dBm`, required margin 0 => sensitivity margin 0 dB inclusive PASS. Any positive additional required margin creates FAIL unless evidence changes.

### 23. Negative vector
TxMax=-1 dBm, LossMin=0 dB, receiver overload max=-3 dBm => RxHigh=-1 dBm, overload margin=-2 dB FAIL even if sensitivity margin is large positive.

### 24. Adversarial vector
Two connector ends representing one mated pair must not be counted as two pair-loss events. Reordered loss events produce same sum/hash when semantically a set. A positive optical margin with no reach profile must keep reach `NOT_ASSESSED`.

### 25. Cross-discipline vector
LAN-05 uses exact ELV3 path sections. CCTV/other disciplines referencing the same fiber link must consume the same path identity. ELV7 certification/reach rules may later evaluate applicability without rewriting this immutable technical power-budget result.

---

## LAN-06 — Rack demand/capacity basis

### 1. Physical meaning
Computes aggregate rack demand basis (RU, weight and depth requirements where declared) and optional simple capacity comparison. It explicitly does not perform slot placement, collision, clearance, airflow or cabinet-fit layout; ELV6 owns those.

### 2. Applicability matrix
Demand can be computed from exact equipment dimensions even without rack capacity. Numeric capacity comparison applies only with explicit compatible gross/net basis. Physical fit remains NOT_ASSESSED in ELV5.

### 3. Exact typed inputs
Rack ID, distinct equipment membership, each equipment RU/weight/depth requirement, capacity basis enum `GROSS_WITH_EXCLUSIONS|NET_USABLE`, gross/net capacity facts, explicit excluded/reserved set with provenance, spare policy if any.

### 4. Evidence requirements
Equipment dimensions from immutable definitions; membership from project facts. Capacity/exclusion basis must say whether exclusions are already incorporated.

### 5. Operating cases
`RU`, `WEIGHT`, `DEPTH_WHEN_AVAILABLE` as separate dimensions. Depth is a maximum item requirement, not a sum.

### 6. Mathematical model
RU demand is sum of distinct equipment RU; weight demand sum of weights; required depth is max equipment depth plus only explicit not-included clearance if policy defines a numeric basis. Gross capacity subtracts explicit exclusions once; net capacity does not subtract them again.

### 7. Equations
`RUreq=Σ RU_i + explicitSpareRU` where policy says spare is demand. `WeightReq=Σ W_i`. `DepthReq=max(D_i)` for basis only. `NetFromGross=Gross-ExcludedOnce`. `marginRU=AvailableRU-RUreq`; weight/depth analogous where comparable.

### 8. Exact/bounded arithmetic
RU/count integers or exact half/defined unit if project supports; weight/depth exact quantities. No layout rounding.

### 9. Worst-case selection
Smallest resolved capacity headroom among RU/weight/depth can govern the basis result, but layout status remains NOT_ASSESSED even if all numeric margins pass.

### 10. Requirement composition
Gross/net basis is mutually exclusive for the same capacity value. Spare/exclusion policy is explicit; double subtracting reservations is forbidden.

### 11. Comparison equations
`available-required` per numeric dimension. Depth comparison is only a coarse basis check when explicit rack usable depth exists; it is not placement proof.

### 12. Margin equation
Separate RU, weight and depth margins; no scalar combination.

### 13. Governing-case algorithm
Any basis ambiguity/missing required equipment dimension first; else smallest signed numeric headroom. Always emit layout `NOT_ASSESSED` sentinel.

### 14. Limiting-factor algorithm
Exact dimension and rack/equipment or exclusion fact causing smallest headroom/ambiguity.

### 15. Missing/unsupported behavior
Unknown depth leaves depth unresolved while RU may pass. Missing rack layout cannot be hidden as PASS. Never infer fit from RU alone.

### 16. Dependency set
Equipment membership set, immutable dimensions, rack capacity basis, exclusion/reservation set and spare policy.

### 17. Calculation trace
`LAN06_DISTINCT_EQUIPMENT_V1`, `LAN06_SUM_RU_V1`, `LAN06_SUM_WEIGHT_V1`, `LAN06_MAX_DEPTH_V1`, `LAN06_NET_CAPACITY_BASIS_V1`, `LAN06_COMPARE_CAPACITY_V1`.

### 18. Complexity/resource bounds
O(E) equipment members; max/sum one pass. Designed for thousands of equipment rows without slot-grid construction.

### 19. Pseudocode
```text
members = distinctEquipment()
ru = sum(members.ru)
weight = sumKnown(members.weight)
depth = maxKnown(members.depth)
available = resolveGrossOrNetExactlyOnce()
compareIndependentDimensions()
setLayoutStatus(NOT_ASSESSED)
```

### 20. Dart interfaces
```dart
final class Lan06Input { final RackId rackId; final List<RackEquipmentDemand> equipment; final RackCapacityBasis capacityBasis; final RackCapacityFacts capacity; final List<RackExclusion> exclusions; }
final class Lan06Output { final RackDemand demand; final List<Elv5DimensionAssessment> basisAssessments; final Elv5Assessment layoutAssessment; }
```

### 21. Positive reference vector
Equipment 2 RU +1 RU and explicit 1 RU spare demand =4 RU; available 6 RU => +2 RU basis margin; layout NOT_ASSESSED.

### 22. Boundary vector
Required RU exactly equals available RU => margin 0 PASS for RU basis, still layout NOT_ASSESSED.

### 23. Negative vector
Required weight 110 kg vs explicit 100 kg basis => -10 kg FAIL while RU may pass.

### 24. Adversarial vector
Net usable capacity already excludes 2 RU reservation; a separate reservation record with provenance “included in net” must not subtract another 2 RU.

### 25. Cross-discipline vector
ELV6 consumes this demand/membership but owns actual slot/depth/thermal layout. ELV6 may fail fit even when LAN-06 capacity basis passes; it must not mutate historical LAN-06 output.

---

## LAN-07 — Patch-panel utilization and mapping completeness

### 1. Physical meaning
Accounts for physical patch-panel port occupancy/reserve and validates declared end-to-end termination/patch mapping completeness without double counting passive continuation relationships.

### 2. Applicability matrix
Applicable with explicit panel port inventory and mapping assignments. Unknown destination or duplicate exclusive mapping fails/unresolves mapping dimension. Port count can still be known independently.

### 3. Exact typed inputs
PatchPanelId, physical PortId set, termination assignments, patch mappings/endpoints, reserved/unavailable port set, spare policy and mapping requirement profile.

### 4. Evidence requirements
Panel port inventory from immutable definition; mappings revision-scoped and identity-safe. No row-count inference.

### 5. Operating cases
`PORT_OCCUPANCY`, `SPARE`, `MAPPING_COMPLETENESS`.

### 6. Mathematical model
Count distinct occupied physical ports from canonical assignments; compute free/reserved/spare headroom; validate required mapping graph relations separately so one physical port is not counted for both internal termination and external continuation.

### 7. Equations
`free=available-occupied`; `marginSpare=free-requiredSpare`. Mapping completeness is set relation: every required source/role has exactly allowed destination cardinality.

### 8. Exact/bounded arithmetic
Counts exact integer; spare ratio if present uses exact rational+ceil. Mapping identities are canonical typed IDs.

### 9. Worst-case selection
Any mapping collision/missing required edge governs before a positive port-count margin; otherwise smallest port/spare headroom.

### 10. Requirement composition
Spare and mapping rules merge only from explicit panel/project policy; reservations already excluded from available capacity are not subtracted twice.

### 11. Comparison equations
Capacity `available-occupied-requiredSpare`; mapping set equality/cardinality predicates per role.

### 12. Margin equation
Integer spare headroom; mapping has no fake numeric margin unless policy explicitly defines count cardinality.

### 13. Governing-case algorithm
Validate identities/mapping, then capacity. Overall FAIL if either mandatory dimension fails; limiting reason selects mapping error first only when it is a hard semantic invalidity, otherwise smallest status/margin by canonical rule.

### 14. Limiting-factor algorithm
Return exact panel port and endpoint/mapping edge or panel spare pool.

### 15. Missing/unsupported behavior
Unknown destination makes mapping unresolved; it does not free/occupy another phantom port. Duplicate endpoint mapping is rejected.

### 16. Dependency set
Panel definition, physical port set, assignment/mapping roots+members, reservation set and spare/mapping policy.

### 17. Calculation trace
`LAN07_COUNT_OCCUPIED_PORTS_V1`, `LAN07_COMPUTE_FREE_V1`, `LAN07_COMPUTE_SPARE_V1`, `LAN07_VALIDATE_MAPPING_CARDINALITY_V1`, `LAN07_SPARE_COMPARE_V1`.

### 18. Complexity/resource bounds
O(P+M) with maps keyed by port/endpoint; no all-pairs graph walk. Qualification includes thousands of mappings.

### 19. Pseudocode
```text
ports = indexPhysicalPorts()
occupied = canonicalOccupiedSet(assignments)
validateMappings(assignments, requiredMappingProfile)
free = available(ports) - occupied.size
spare = policy.requiredSpare(occupied.size)
compare(free, spare)
```

### 20. Dart interfaces
```dart
final class Lan07Input { final PatchPanelId panelId; final List<LanPatchPort> ports; final List<LanPatchAssignment> assignments; final LanPatchPolicy policy; }
final class Lan07Output { final int occupied; final int free; final int requiredSpare; final List<LanMappingResult> mappings; }
```

### 21. Positive reference vector
8 physical ports, 5 occupied, 2 required spare => 3 free, +1 spare headroom; declared mappings complete => PASS.

### 22. Boundary vector
8 ports, 6 occupied, 2 required spare => free 2, margin 0 PASS.

### 23. Negative vector
Port capacity passes but one required destination missing => mapping completeness FAIL.

### 24. Adversarial vector
Internal termination relation plus patch relation for the same physical port must still count one occupied PortId. Two UI aliases to same PortId cannot create capacity.

### 25. Cross-discipline vector
LAN-07 mapping may feed LAN-01/04 ordered path construction through canonical link facts, but LAN-07 does not own path length/capability. A mapping edit invalidates only dependent links/processes.