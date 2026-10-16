# ELV5 Fire Alarm — production code-level process dossiers

Status: DESIGN HARDENING / RUNTIME NOT STARTED  
Parent: `process-code-level-specification.md`, `process-contracts.md`, `calculation-engine-contract.md`.

All vectors use fictional product-neutral data and are not regulatory requirements.

---

## FA-01 — Fire loop device/address capacity

### 1. Physical meaning
Counts physical devices and consumed address resources independently, validates full expanded address-set uniqueness inside explicit panel/loop address domains, and compares those resources with declared technical limits/spare policy.

### 2. Applicability matrix
Exact loop membership + address-consumption profile + explicit assignment/domain => applicable. Start-address only without deterministic expansion is unresolved. Unsupported noncontiguous addressing is blocked unless selected profile allows it.

### 3. Exact typed inputs
Panel/module/loop IDs, device membership set, immutable device profile with physical device count contribution and address-consumption rule, explicit address set or versioned deterministic expansion input, address domain `(panelId,loopId,subdomain)`, reserved address set, device/address capacity limits and spare policy.

### 4. Evidence requirements
Device address consumption comes from immutable profile edition; assignment closure must be complete. Reserved addresses are first-class resources and participate in uniqueness.

### 5. Operating cases
`DEVICE_COUNT`, `ADDRESS_COUNT`, `ADDRESS_UNIQUENESS`.

### 6. Mathematical model
Expand each assignment to a canonical full address set; require expansion cardinality equals profile consumption; union with reserved set and detect collisions on `(domain,address)`. Count physical devices separately from consumed addresses.

### 7. Equations
`deviceCount=|distinct DeviceId members|`; `addressCount=Σ |expandedAddressSet(device)|`; collision exists if `Σ cardinalities > |union(all assigned+reserved addresses)|`. Capacity margins: `Mdev=deviceLimit-deviceCount-requiredDeviceSpare`; `Maddr=addressLimit-addressCount-requiredAddressSpare`.

### 8. Exact/bounded arithmetic
All counts/addresses are exact integers. Address expansion is deterministic and bounded; no string sorting determines numeric address meaning.

### 9. Worst-case selection
Any address collision governs as FAIL regardless of spare capacity. Otherwise smallest signed device/address headroom governs.

### 10. Requirement composition
Device limit, address limit and spare rules remain separate dimensions. Address-domain semantics are profile-owned; panel/loop scopes cannot be merged silently.

### 11. Comparison equations
Inclusive capacity uses `available-consumed-spare`; uniqueness is exact set predicate over full domain/address keys.

### 12. Margin equation
Integer device/address headroom per resource pool; no combined percent.

### 13. Governing-case algorithm
Validate domain/expansion, detect collisions, then compare capacities. Collision > unresolved expansion > negative headroom > smallest positive headroom.

### 14. Limiting-factor algorithm
Return exact domain/address and all claimants for collision; otherwise loop/panel resource dimension with smallest headroom.

### 15. Missing/unsupported behavior
Missing expansion rule or address set leaves uniqueness/count unresolved. Never assume one device equals one address. Duplicate start address that expands to overlapping multi-address sets is a collision.

### 16. Dependency set
Panel/loop/device membership sets, immutable device profiles, address assignments/expansion inputs, reserved set, capacity/spare policy and selector markers for new matching devices.

### 17. Calculation trace
`FA01_EXPAND_ADDRESS_SET_V1`, `FA01_VALIDATE_CONSUMPTION_CARDINALITY_V1`, `FA01_DETECT_ADDRESS_COLLISION_V1`, `FA01_COUNT_DEVICES_V1`, `FA01_COUNT_ADDRESSES_V1`, `FA01_COMPARE_CAPACITY_V1`.

### 18. Complexity/resource bounds
O(D+A) expected with typed hash sets; canonical collision reporting O(C log C). Qualification requires 10,000 address claims. Expansion must reject code-owned hard-limit excess before materializing unbounded sets.

### 19. Pseudocode
```text
claimed = Map<AddressKey,List<DeviceId>>()
for device in members:
  addresses = expandOrRequireExplicit(device.assignment, device.profile)
  require(addresses.size == device.profile.addressConsumption)
  for a in addresses: claimed[a].add(device.id)
for reserved in reservedAddresses: claimed[reserved].add(RESERVED)
collisions = entries where claimants.size > 1
compareDeviceAndAddressCapacity()
```

### 20. Dart interfaces
```dart
final class Fa01Input { final FireLoopId loopId; final List<FireDeviceAssignment> devices; final Set<FireAddressKey> reserved; final FireAddressCapacityPolicy policy; }
final class Fa01Output { final int deviceCount; final int addressCount; final List<FireAddressCollision> collisions; final int deviceHeadroom; final int addressHeadroom; }
```

### 21. Positive reference vector
3 devices consume address counts 1,1,2 =>4 unique addresses; declared limit 5 and zero spare => +1 address headroom PASS.

### 22. Boundary vector
4 consumed addresses against limit 4 => margin 0 PASS if no collision. Two devices claiming the same address make uniqueness FAIL even though numeric count might remain <=4.

### 23. Negative vector
5 unique consumed addresses against limit 4 => -1 address FAIL while physical device count may still pass.

### 24. Adversarial vector
Device A consumes `{10,11}`, device B starts at 11 and consumes `{11,12}`. Start-address-only uniqueness would miss overlap; full expanded-set check must report collision at 11.

### 25. Cross-discipline vector
FA-07 consumes exact expanded address/member identities for topology matching. Address PASS does not imply electrical/current/topology PASS in FA-02/03/07.

---

## FA-02 — Standby/alarm/current-state aggregation

### 1. Physical meaning
Computes complete technical current demand for fire devices/modules/panel-own loads across explicitly selected standby, alarm and startup/inrush states without duplicating loads because they participate in multiple signal relationships.

### 2. Applicability matrix
Complete membership + explicit state-current evidence => applicable. Missing one alarm current leaves alarm unresolved while known standby may remain complete. State label without current value is not evidence.

### 3. Exact typed inputs
Loop/auxiliary segment identity, complete distinct load-origin set, per-origin state-current profile (`standby`, `alarm`, optional startup/inrush plus duration), own-load boundary flags, simultaneity/state-selection policy, optional current-capacity requirement only if in process scope.

### 4. Evidence requirements
Each current value carries evidence basis and applicability (voltage/environment if required). Membership closure includes panel/module own current exactly once at declared boundary.

### 5. Operating cases
`STANDBY`, `ALARM`, and `STARTUP_INRUSH_WHEN_PROFILED`; additional explicit project states only through versioned policy.

### 6. Mathematical model
For each operating case, select one state current per distinct load origin according to state/simultaneity policy and sum. Signal-return participation or multiple graph edges do not create additional physical current origins.

### 7. Equations
`I_case=Σ_origin I(origin,state(case,origin))`. For interval currents, sum lower/upper bounds independently. Known subtotal is `Σ known`; missing-origin set is preserved separately.

### 8. Exact/bounded arithmetic
Current is exact/bounded rational amperes. No binary float or display mA rounding before aggregation/comparison. Pulse duration is preserved but does not get averaged unless an explicit supported model requests it.

### 9. Worst-case selection
For a maximum-capacity downstream use, governing current is the required case with greatest conservative upper current or smallest downstream capacity margin. Standby and alarm are retained separately because FA-05 needs ordered durations.

### 10. Requirement composition
Simultaneity/state selection is explicit. Project policy may specify subsets/alarm zones; missing policy cannot be replaced by “all devices in alarm” or a heuristic percentage.

### 11. Comparison equations
FA-02 primarily outputs demand. If an explicit output current limit is in scope, `margin=limit-Iupper`; otherwise no PASS is manufactured merely from a current value.

### 12. Margin equation
Optional current headroom in A. Primary state-current outputs are demand facts, not margins.

### 13. Governing-case algorithm
Build every required case; incomplete case remains unresolved. Among complete cases used for capacity risk, select greatest upper demand; preserve case identity for downstream FA-04/05/06.

### 14. Limiting-factor algorithm
For incomplete case identify first missing origin/state current; for high demand report top contributors sorted by current then canonical ID for explanation only.

### 15. Missing/unsupported behavior
Known subtotal never becomes complete PASS if any mandatory origin current is missing. Duplicate device membership is rejected/normalized by canonical load origin, not summed twice.

### 16. Dependency set
Device/module/panel membership sets, immutable state-current profiles, own-load boundary facts, simultaneity/state policy and selectors for all loads in the segment.

### 17. Calculation trace
`FA02_CANONICAL_LOAD_ORIGINS_V1`, `FA02_SELECT_STATE_CURRENT_V1`, `FA02_SUM_STATE_CURRENT_V1`, `FA02_RECORD_MISSING_REMAINDER_V1`, `FA02_SELECT_GOVERNING_CURRENT_CASE_V1`.

### 18. Complexity/resource bounds
O(N*C) for N load origins and small bounded C operating cases; no topology traversal. Qualification covers large loops/auxiliary sets and startup case generation without powerset enumeration.

### 19. Pseudocode
```text
origins = distinctPhysicalLoadOrigins(capturedMembership)
for case in requiredCases:
  total = 0
  missing = []
  for origin in origins:
    state = statePolicy.stateFor(origin, case)
    current = resolveCurrent(origin, state)
    if known: total += current else missing += origin
  emit(case, total, missing)
```

### 20. Dart interfaces
```dart
final class Fa02Input { final FireSegmentId segmentId; final List<FireLoadOrigin> origins; final FireStateSelectionPolicy statePolicy; }
final class Fa02Output { final Map<FireOperatingCase,FaCurrentCaseResult> cases; }
```

### 21. Positive reference vector
Two detectors 0.01 A standby each + module own 0.02 A => standby 0.04 A. Alarm 0.03+0.03+0.02=0.08 A. Both complete.

### 22. Boundary vector
One device current interval upper bound makes total exactly an explicit 0.5 A technical limit => zero margin PASS if inclusive; no rounding from 499.6 mA display.

### 23. Negative vector
Alarm total 0.56 A vs explicit 0.50 A output limit => -0.06 A FAIL; standby may pass.

### 24. Adversarial vector
Same module appears once as loop member and once as signal return participant. Canonical load-origin ID ensures own current counted once. A missing alarm current cannot default to standby current.

### 25. Cross-discipline vector
FA-04 and FA-05 consume exact FA-02 case demands. If the same physical source also feeds ACS, source sizing uses global ELV4 closure rather than adding FA-02 subtotal as a second physical load.

---

## FA-03 — Fire electrical terminal-voltage basis

### 1. Physical meaning
Checks fire circuit/feeder terminal voltage against explicit technical limits by consuming supported ELV4 PWR-03 physical evidence. A closed signal loop is not automatically a supported dual-fed electrical mesh.

### 2. Applicability matrix
Supported radial/declared one-control-point DC model + exact path => applicable. Unsupported dual-feed/shared-return/manufacturer-proprietary electrical loop => BLOCKED. Signal topology may still be assessed separately by FA-07.

### 3. Exact typed inputs
Fire circuit/segment ID, selected supported electrical-model code, conductor/termination path refs, technical terminal-voltage limits, exact PWR-03 evidence ID/hash/generation for required cases.

### 4. Evidence requirements
Installed conductor/termination facts from ELV3/ELV4; current/demand context must match the exact PWR-03 evaluation. Technical limits from immutable device/manufacturer/project policy.

### 5. Operating cases
`SUPPORTED_ELECTRICAL_MODEL` expanded to standby/alarm/notification cases when PWR-03 has case-specific terminal results.

### 6. Mathematical model
No local voltage-drop solve. Verify model applicability and evidence scope, project worst terminal-voltage interval from PWR-03, compare against declared allowed range.

### 7. Equations
For allowed `[Vmin,Vmax]`: `Mlow=VterminalLower-Vmin`; `Mhigh=Vmax-VterminalUpper`; governing voltage margin `min(Mlow,Mhigh)`.

### 8. Exact/bounded arithmetic
Voltage intervals are exact/bounded upstream values. No rounded nominal voltage comparison. Topology model code is part of input/output hash.

### 9. Worst-case selection
Across required terminals/cases choose smallest signed voltage margin. Unsupported model outranks numerical diagnostics.

### 10. Requirement composition
Multiple technical voltage ranges merge only if intersection semantics are compatible; empty intersection is requirement conflict. Normative circuit class remains ELV7.

### 11. Comparison equations
Range comparison as above; PASS only when whole conservative terminal interval lies within allowed range.

### 12. Margin equation
Voltage headroom in V; separate low/high margins retained.

### 13. Governing-case algorithm
Validate electrical model, then evaluate each required terminal/case, choose smallest lower-bound margin; tie by terminal ID/case rank.

### 14. Limiting-factor algorithm
Exact terminal/segment/case or unsupported model/topology code.

### 15. Missing/unsupported behavior
Unsupported loop electrical model => BLOCKED, never partial traversal PASS. Missing path/current evidence blocks affected terminal.

### 16. Dependency set
Electrical-model policy, exact PWR-03 refs/generations, installed path/termination fingerprints and technical voltage-limit edition.

### 17. Calculation trace
`FA03_VERIFY_ELECTRICAL_MODEL_V1`, `FA03_BIND_PWR03_TERMINALS_V1`, `FA03_VOLTAGE_RANGE_COMPARE_V1`, `FA03_SELECT_WORST_TERMINAL_V1`.

### 18. Complexity/resource bounds
O(T*C) over captured terminal results/cases; no graph power solve in ELV5.

### 19. Pseudocode
```text
requireSupportedElectricalModel(model)
e = requireExactPwr03(circuit, cases)
for terminal in requiredTerminals:
  range = e.voltageInterval(terminal)
  compareRange(range, policy.allowedVoltage)
return selectSmallestVoltageMargin()
```

### 20. Dart interfaces
```dart
final class Fa03Input { final FireCircuitId circuitId; final FireElectricalModel model; final Elv4Pwr03Evidence evidence; final FireVoltagePolicy policy; }
final class Fa03Output { final List<FireTerminalVoltageResult> terminals; final String governingCaseId; }
```

### 21. Positive reference vector
Supported radial fixture 24 V source, 0.5 A, 0.2 Ω total modeled path gives accepted terminal 23.9 V; technical allowed 22…26 V => +1.9 V low margin, +2.1 V high margin PASS.

### 22. Boundary vector
Terminal lower bound exactly 22 V => low margin 0 PASS for inclusive range.

### 23. Negative vector
Worst terminal 21.5 V against minimum22 V => -0.5 V FAIL.

### 24. Adversarial vector
Signal graph is a closed loop, but selected electrical model supports radial only. FA-03 must BLOCK instead of walking one arbitrary direction and returning PASS.

### 25. Cross-discipline vector
FA-07 can PASS signal closure while FA-03 is BLOCKED electrical-model-wise. Neither result overwrites the other; UI displays independent dimensions.

---

## FA-04 — Fire shared-source requirement

### 1. Physical meaning
Checks shared physical source capability against the complete global demand and effective source-owned requirement set when fire policy participates, preserving independent standby/alarm/auxiliary cases.

### 2. Applicability matrix
Complete PWR-01 global demand + PWR-02 source capability/requirement evidence + compatible fire policy => applicable. Missing auxiliary/non-fire shared loads or conflicting policy blocks full sizing PASS.

### 3. Exact typed inputs
Source ID, fire requirement policy, required source cases, exact FA-02 case refs where they form fire contribution, exact global PWR-01 evidence, PWR-02 capability evidence, complete participating requirement-set fingerprint.

### 4. Evidence requirements
Global demand closure includes panel/loop/module/notification/auxiliary and concurrent non-fire loads sharing source. Source rating/derating evidence exact and applicable.

### 5. Operating cases
`STANDBY_SOURCE_CASE`, `ALARM_SOURCE_CASE`, plus explicitly selected notification/startup or other fire cases supported by the source model.

### 6. Mathematical model
Deterministically merge fire and other discipline source requirements on one global physical demand; consume PWR-02 required/available capability result. FA-02 is contribution/state evidence, not a second load added outside global PWR-01.

### 7. Equations
Conceptually, where policy uses reserve: `Required_case=GlobalDemand_case*EffectiveReserve`; `Available_case=RatedCapability*ApplicableDerating`; `Margin=Available-Required`. Actual execution is owned by PWR-02; FA-04 projects exact evidence.

### 8. Exact/bounded arithmetic
Exact rationals/intervals. Reserve/derating applied once. Demand and required capability are distinct values.

### 9. Worst-case selection
Smallest signed source capability margin across required cases/dimensions. Alarm need not always govern if another explicit case has a worse margin.

### 10. Requirement composition
Strongest compatible requirement per dimension via deterministic merger; conflicts explicit. No per-device/per-loop reserve multiplication.

### 11. Comparison equations
`margin=available-required` from exact source evidence. Requirement-set hash must match captured contributors.

### 12. Margin equation
Per dimension W/A/etc., never mixed without ELV4-supported transformation.

### 13. Governing-case algorithm
Verify global closure and requirement-set fingerprint; evaluate all mandatory source cases; choose conflict/FAIL/unresolved then smallest positive margin.

### 14. Limiting-factor algorithm
Source, case, dimension and requirement contributor(s), including missing auxiliary load closure when applicable.

### 15. Missing/unsupported behavior
Missing auxiliary load/current prevents full sizing PASS. Fire-only subtotal cannot replace global source demand.

### 16. Dependency set
FA-02 refs when consumed, PWR-01/PWR-02 refs/generations, source definition/environment, fire policy and global requirement/membership selectors.

### 17. Calculation trace
`FA04_VERIFY_GLOBAL_SOURCE_CLOSURE_V1`, `FA04_MERGE_SOURCE_REQUIREMENTS_V1`, `FA04_BIND_PWR02_V1`, `FA04_COMPARE_CAPABILITY_V1`, `FA04_SELECT_GOVERNING_CASE_V1`.

### 18. Complexity/resource bounds
O(C+R) cases/requirements; no physical graph solve.

### 19. Pseudocode
```text
requireCompleteGlobalPwr01(source)
req = mergeDeterministically(globalRequirementSet including firePolicy)
e = requireExactPwr02(source, req.hash)
for case/dimension in req:
  assess(e.available - e.required)
return selectGoverning()
```

### 20. Dart interfaces
```dart
final class Fa04Input { final PowerSourceId sourceId; final FireSourceRequirementPolicy firePolicy; final Elv4Pwr01Evidence demand; final Elv4Pwr02Evidence capability; final Elv5RequirementSetFingerprint globalRequirements; }
final class Fa04Output { final List<SourceCapabilityDimensionResult> dimensions; final Elv5LimitingFactor limitingFactor; }
```

### 21. Positive reference vector
Explicit global demand24 W, effective reserve1.25 =>30 W required; 40 W available => +10 W PASS.

### 22. Boundary vector
Required capability equals available exactly => zero-margin PASS if inclusive and all evidence complete.

### 23. Negative vector
Required 42 W, available40 W => -2 W FAIL.

### 24. Adversarial vector
Panel own current already included in PWR-01 and also visible in FA-02. FA-04 must not add FA-02 subtotal onto PWR-01 again. A repeated fire policy bound is merged idempotently by requirement identity.

### 25. Cross-discipline vector
ACS-04 sharing the source sees identical global demand/capability result. Strongest effective source requirement may originate in Fire and governs both discipline projections without duplicating source arithmetic.

---

## FA-05 — Fire standby/alarm backup/autonomy sequence

### 1. Physical meaning
Validates fire-required protected standby/alarm sequence against exact global battery-bank PWR-04 evidence, including complete shared protected loads and supported bank factors/model limits.

### 2. Applicability matrix
Explicit ordered durations + complete protected membership + supported PWR-04 model => applicable. Missing duration or model outside discharge/EOD applicability => BLOCKED. Nominal Ah shortcut unsupported unless model defines it.

### 3. Exact typed inputs
Bank ID, fire autonomy policy with ordered segment durations/state cases, complete protected sequence fingerprint, exact FA-02 state demand refs where used, global PWR-04 evidence, bank definition/environment/EOD applicability and fire contribution membership IDs.

### 4. Evidence requirements
Standby/alarm durations are explicit adopted policy, not hardcoded standard hours. Protected load closure includes shared non-fire loads. Bank usable capacity/factors are exact upstream evidence.

### 5. Operating cases
Ordered `STANDBY_SEQUENCE` then `ALARM_SEQUENCE`, plus explicitly modeled transitional/notification segments when selected policy requires them.

### 6. Mathematical model
Construct/verify one ordered global protected sequence and bind exact PWR-04 evaluation. PWR-04 owns energy/current/discharge/loss physics. FA-05 verifies required duration coverage and exposes fire contribution/global margin.

### 7. Equations
Conceptual energy for simple supported model: `Ereq=Σ P_segment*t_segment`; `MarginEnergy=Eusable-Erequired`. Peak current/EOD constraints remain additional independent margins from PWR-04.

### 8. Exact/bounded arithmetic
Power×time exact rational energy; no rounding hours/Ah. Battery factors applied once upstream. Sequence order/duration is hash-significant.

### 9. Worst-case selection
Preserve PWR-04 governing energy/current/EOD segment. A passing total Wh cannot hide alarm peak-current or end-of-discharge failure.

### 10. Requirement composition
Duration requirements compose by explicit policy semantics; fire sequence can be stronger than another discipline’s requirement but all shared loads remain in one physical sequence/bank evaluation.

### 11. Comparison equations
Reuse upstream `available-required` margins and explicitly verify every required duration/state segment is represented exactly in sequence.

### 12. Margin equation
Energy, current, capacity/EOD margins remain separate; no single synthetic autonomy score.

### 13. Governing-case algorithm
Validate sequence hash/duration coverage, then preserve upstream governing constraint; missing duration/closure governs BLOCKED before numerical margin.

### 14. Limiting-factor algorithm
Exact bank constraint + sequence segment/case; or missing protected load/duration.

### 15. Missing/unsupported behavior
No default standby/alarm hours. Missing one protected load blocks full autonomy PASS. Unsupported battery model does not degrade to nominal Ah/current arithmetic.

### 16. Dependency set
FA-02 state refs, sequence root/members/durations, protected-load selectors, bank definition/environment, PWR-04 ID/hash/generation and fire autonomy policy.

### 17. Calculation trace
`FA05_BUILD_REQUIRED_SEQUENCE_V1`, `FA05_VERIFY_PROTECTED_CLOSURE_V1`, `FA05_BIND_PWR04_V1`, `FA05_VERIFY_DURATION_COVERAGE_V1`, `FA05_REUSE_BANK_MARGINS_V1`.

### 18. Complexity/resource bounds
O(S+C) over bounded sequence segments/contributors; no discharge integration in ELV5. Qualification includes long-duration sequence arithmetic and shared bank loads.

### 19. Pseudocode
```text
requiredSeq = firePolicy.requiredSequence()
actualSeq = requireCompleteGlobalProtectedSequence(requiredSeq)
e = requireExactPwr04(bankId, actualSeq.hash)
requireDurationCoverage(e, requiredSeq)
fireContribution = selectFireContributors(e)
return projectGlobalBankMargins(e, fireContribution)
```

### 20. Dart interfaces
```dart
final class Fa05Input { final BatteryBankId bankId; final FireAutonomyPolicy policy; final ProtectedSequence sequence; final Elv4Pwr04Evidence evidence; final Set<LoadId> fireProtectedLoads; }
final class Fa05Output { final EnergyQ requiredEnergy; final EnergyQ availableEnergy; final EnergyQ energyMargin; final List<BankConstraintResult> constraints; }
```

### 21. Positive reference vector
12 W standby for7200 s =24 Wh; 24 W alarm for1800 s =12 Wh; total36 Wh in simple supported fixture. Usable134.4 Wh => +98.4 Wh energy margin.

### 22. Boundary vector
Total required energy equals usable energy exactly, but peak current also exactly equals inclusive limit => both zero-margin PASS.

### 23. Negative vector
Energy fits but alarm-segment current exceeds supported bank/source current by 0.4 A => overall FAIL on alarm current.

### 24. Adversarial vector
Caller multiplies “standby hours” again after sequence already contains those durations or excludes ACS shared loads. Fingerprint/closure checks reject both. Changing host timezone cannot change UTC sequence evidence.

### 25. Cross-discipline vector
ACS-05 sharing the bank must consume the same global PWR-04 physical evaluation for overlapping sequence scope. Fire policy can extend sequence duration, invalidating/recomputing shared bank evidence rather than appending a discipline-only Wh subtotal.

---

## FA-06 — Notification circuit output/current/terminal-voltage capacity

### 1. Physical meaning
Checks notification output assignment, active/startup current, supported supervision/fault cases and terminal voltage using complete shared physical evidence. It does not assess acoustic coverage or audibility.

### 2. Applicability matrix
Explicit notification membership + state current + supported physical path/PWR evidence => applicable. Missing startup current blocks startup dimension when required. Acoustic claim always NOT_ASSESSED without separate model.

### 3. Exact typed inputs
NotificationCircuitId/output ID, distinct device assignments, active and optional startup/inrush current profiles/durations, simultaneous activation policy, output current/device-count technical limits, exact PWR-01/PWR-03 evidence per required case, supported supervision/fault-state profile.

### 4. Evidence requirements
Device currents/capabilities from immutable definitions or explicit measured/project facts. Membership closure complete. Output/PWR evidence matches same assignments/path/scenarios.

### 5. Operating cases
`ACTIVE_NOTIFICATION`, `STARTUP_INRUSH_WHEN_PROFILED`, and selected `OPEN_FAULT`, `SHORT_FAULT`, `RETURN_LOSS` supervision cases only when a supported model exists.

### 6. Mathematical model
Count distinct active devices, bind complete global/output current evidence, bind terminal-voltage evidence at required devices/ends, and evaluate supported fault-state topology/electrical predicates separately. Do not derive sound pressure.

### 7. Equations
Device-count margin `Mcount=deviceLimit-activeCount`; output current margin `Mcurrent=outputLimit-Iupper` when current limit is directly modeled; terminal voltage `Mlow=Vlower-Vmin`, `Mhigh=Vmax-Vupper`. Physical voltage/current should come from PWR evidence rather than local conductor solve.

### 8. Exact/bounded arithmetic
Exact integer counts and exact/bounded A/V quantities. Startup pulse is not averaged into active current unless model says so.

### 9. Worst-case selection
Any mandatory fault-state failure or unsupported required model governs; otherwise smallest signed output-current/device-count/terminal-voltage margin across required cases.

### 10. Requirement composition
Notification simultaneity/output limits and supervision requirements are explicit technical policy. Reserve/derating remains source/output owner responsibility and is not repeated here.

### 11. Comparison equations
Standard `available-required` and voltage range comparisons. PASS requires all mandatory dimensions/cases complete.

### 12. Margin equation
Count, current and voltage margins remain separate. No acoustic margin.

### 13. Governing-case algorithm
Evaluate membership/count, active/startup physical evidence, fault states, then choose mandatory FAIL/unresolved before smallest numeric headroom. Cause/case retained.

### 14. Limiting-factor algorithm
Output ID, device/event/terminal/fault-state plus exact requirement code.

### 15. Missing/unsupported behavior
Count PASS cannot override current/voltage failure. Missing acoustic model => acoustic NOT_ASSESSED, not PASS. Unsupported supervision electrical model is BLOCKED only for required supervision dimension.

### 16. Dependency set
Notification assignment/member selectors, device state-current profiles, output capability policy, PWR-01/PWR-03 refs/generations, supported fault/supervision model.

### 17. Calculation trace
`FA06_COUNT_ACTIVE_DEVICES_V1`, `FA06_BIND_ACTIVE_CURRENT_V1`, `FA06_BIND_STARTUP_CURRENT_V1`, `FA06_BIND_TERMINAL_VOLTAGE_V1`, `FA06_EVAL_FAULT_STATE_V1`, `FA06_COMPARE_OUTPUT_CAPACITY_V1`.

### 18. Complexity/resource bounds
O(N*C + F*(V+E)) for N devices, small bounded cases C and optional local fault graph F. Capture scopes the local circuit graph. No whole-project traversal.

### 19. Pseudocode
```text
members = distinctNotificationDevices()
compareDeviceCount(members.size)
for case in requiredElectricalCases:
  pwr01 = requireExactOutputDemand(case)
  pwr03 = requireExactTerminalEvidence(case)
  compareCurrentAndVoltage(pwr01, pwr03)
for fault in requiredSupportedFaultCases:
  evaluateFaultState(fault)
return selectGoverning()
```

### 20. Dart interfaces
```dart
final class Fa06Input { final NotificationCircuitId circuitId; final List<NotificationDeviceAssignment> devices; final NotificationOutputPolicy outputPolicy; final Elv4PowerEvidenceSet evidence; final Elv5Field<FireSupervisionModel> supervisionModel; }
final class Fa06Output { final Map<FireOperatingCase,NotificationCaseResult> cases; final int activeDeviceCount; }
```

### 21. Positive reference vector
3 active devices at 0.1 A each =>0.3 A against explicit0.5 A output limit; all terminals inside allowed voltage => PASS.

### 22. Boundary vector
Startup upper current exactly0.5 A and minimum terminal exactly required lower limit => zero margins PASS if inclusive.

### 23. Negative vector
Device count passes but startup current0.62 A >0.5 A => -0.12 A FAIL; or one terminal below minimum independently fails.

### 24. Adversarial vector
One device appears through two signal relationships; canonical load identity counts one current origin. A “0.5 A” display rounded from exact 0.4996 A capacity must not be compared against rounded current. Acoustic label in device metadata cannot generate coverage PASS.

### 25. Cross-discipline vector
FA-06 current/voltage evidence shares ELV4 physical source/path with FA-04/05 and possibly ACS auxiliary loads. It must not filter those from global upstream calculations; FA-07 signal topology remains separate.

---

## FA-07 — Fire signal topology integrity and supported fault behavior

### 1. Physical meaning
Validates directed signal-loop/source/return closure, branch policy, address-topology consistency and, when explicitly supported, isolator/supervision behavior under declared fault states. It does not solve unsupported electrical power meshes.

### 2. Applicability matrix
Normal topology with exact signal graph/profile => applicable. Fault survivability only when selected supported fault model exists. Component presence alone does not prove isolator behavior.

### 3. Exact typed inputs
FireLoopId, directed typed signal graph, source/return ports, device/address membership from FA-01, branch/closure policy, isolator placements/capabilities, optional supported fault model defining open/short/return-loss transformations and expected reachable sets.

### 4. Evidence requirements
Graph edges/ports are canonical project facts; device address identities exact. Isolator behavior from immutable definition/model edition, not name inference.

### 5. Operating cases
`NORMAL_TOPOLOGY`; optional `OPEN_FAULT`, `SHORT_FAULT`, `RETURN_LOSS` cases selected only by supported model/policy.

### 6. Mathematical model
Evaluate directed reachability/return closure and forbidden branch predicates on the normal graph. For supported faults, deterministically transform graph according to fault model and compare expected supervised/reachable/isolation properties. Consume full FA-01 address sets.

### 7. Equations
Graph predicates: source reaches required devices, required return reaches source/return port, branch-degree constraints, address uniqueness/membership consistency. Fault transforms are code-owned graph operations; no numeric electrical equation implied.

### 8. Exact/bounded arithmetic
Deterministic graph/set algebra. Edge ordering irrelevant except canonical trace order. No probabilistic survivability score.

### 9. Worst-case selection
Any mandatory normal/fault case failure governs; unsupported required fault model blocks. Multiple fault cases are not combined into an unrequested simultaneous multi-fault powerset.

### 10. Requirement composition
Closure/branch/isolation/fault requirements merge by explicit topology profile. Normative class/survivability compliance belongs to ELV7.

### 11. Comparison equations
Boolean/set predicates only: required reachable set inclusion, forbidden edge/branch absence, expected isolated set equality/subset as profile defines.

### 12. Margin equation
No fabricated numeric margin; optional counts are diagnostics unless explicit profile threshold exists.

### 13. Governing-case algorithm
Canonical case order normal→open→short→return-loss; first FAIL/UNRESOLVED required case is governing explanation while all findings retained.

### 14. Limiting-factor algorithm
Exact graph edge/node/isolator/address/fault case causing closure/branch/reachability mismatch.

### 15. Missing/unsupported behavior
Broken return/illegal branch => FAIL when graph complete. Unsupported short-circuit behavior => fault dimension BLOCKED, not inferred from isolator presence. FA-03 electrical blockage does not automatically fail signal topology.

### 16. Dependency set
Signal graph edge/root/member fingerprints, source/return ports, FA-01 evaluation/address sets, isolator definitions, topology/fault policy and selectors for graph/device membership.

### 17. Calculation trace
`FA07_BUILD_TYPED_SIGNAL_GRAPH_V1`, `FA07_VALIDATE_NORMAL_CLOSURE_V1`, `FA07_VALIDATE_BRANCH_POLICY_V1`, `FA07_MATCH_ADDRESS_MEMBERSHIP_V1`, `FA07_APPLY_FAULT_TRANSFORM_V1`, `FA07_EVAL_FAULT_REACHABILITY_V1`.

### 18. Complexity/resource bounds
Each graph case O(V+E); bounded small number of supported cases. Do not enumerate every possible fault location unless policy explicitly requests a bounded sweep; such sweep complexity is O(F*(V+E)) with F hard-limited.

### 19. Pseudocode
```text
g = buildTypedGraph(edges)
checkNormalClosureAndBranches(g)
checkAddressMembership(g, fa01.expandedAddresses)
for faultCase in selectedSupportedFaultCases:
  gf = faultModel.transform(g, faultCase)
  checkExpectedReachabilityAndIsolation(gf, faultCase)
return aggregateRequiredCases()
```

### 20. Dart interfaces
```dart
final class Fa07Input { final FireLoopId loopId; final FireSignalGraph graph; final Fa01Evidence addresses; final FireTopologyPolicy policy; final Elv5Field<FireFaultModel> faultModel; }
final class Fa07Output { final Map<FireTopologyCase,FireTopologyCaseResult> cases; }
```

### 21. Positive reference vector
Source→D1→D2→return closes with no forbidden branch and unique matching addresses => normal topology PASS.

### 22. Boundary vector
Profile permits exactly one declared branch and graph contains exactly one at permitted node => PASS. A second branch => FAIL.

### 23. Negative vector
Return edge missing in complete graph => normal closure FAIL while address uniqueness may pass.

### 24. Adversarial vector
An isolator component exists but has no supported fault behavior definition. Short-fault survivability remains BLOCKED; product label cannot generate behavior. Reordered edge serialization must not change result/hash.

### 25. Cross-discipline vector
FA-03 may be BLOCKED for unsupported electrical loop while FA-07 normal signal topology passes. ACS-06 may consume a fire-release interface edge, but that does not grant ACS ownership of the fire loop.

---

## FA-08 — Fire cable/environment policy evidence basis

### 1. Physical meaning
Matches exact cable-edition and route-environment evidence against an explicit selected project/technical fire-cable policy, while clearly separating technical policy match from verified regulatory compliance.

### 2. Applicability matrix
Exact cable/environment facts + explicit policy => technical policy match assessable. Missing class/environment => BLOCKED. Verified compliance remains UNRESOLVED/NOT_ASSESSED unless ELV7 provides an actual verified compliance result.

### 3. Exact typed inputs
Cable/section IDs and immutable cable edition/classes, ordered route environment facts, installation/context tags, selected policy requirements with source/status, optional ELV7 compliance evidence ref only when actually available.

### 4. Evidence requirements
Cable properties from exact immutable edition; route environment from canonical ELV3 facts. Policy source is explicit and cannot masquerade as law/standard applicability.

### 5. Operating cases
`CABLE_ENVIRONMENT_POLICY_MATCH`; optional separate projection of `VERIFIED_COMPLIANCE` only from exact ELV7 evidence in future integration.

### 6. Mathematical model
Evaluate explicit typed requirement predicates against each applicable cable/path section and route environment. Aggregate all required policy predicates. No free-text class hierarchy inference.

### 7. Equations
Categorical predicate matching; numeric limits where policy explicitly defines them use standard conservative comparison. Verified compliance is a separate evidence state, not equation from technical match.

### 8. Exact/bounded arithmetic
Exact typed enums/IDs and physical numeric quantities. No parsing of marketing strings/class names into ordered ranks unless policy defines a code-owned relation.

### 9. Worst-case selection
First missing/mismatched mandatory evidence by ordered route section/requirement is limiting; any required mismatch fails technical policy match.

### 10. Requirement composition
Multiple project policies merge only through deterministic compatible predicate composition. Jurisdictional applicability/precedence is ELV7 responsibility.

### 11. Comparison equations
Boolean/categorical predicate satisfaction; numeric `limit-realized` where applicable.

### 12. Margin equation
Only explicit numeric policy limits have margins; categorical class match does not get a fabricated score.

### 13. Governing-case algorithm
Evaluate route sections in canonical order and requirements by stable code; select first FAIL/UNRESOLVED mandatory predicate, otherwise smallest numeric headroom if any.

### 14. Limiting-factor algorithm
Exact cable/route section, environment property and policy requirement code.

### 15. Missing/unsupported behavior
Missing cable class or route evidence => BLOCKED technical match. Fictional/project policy can never output `VERIFIED_COMPLIANT` by itself.

### 16. Dependency set
Cable edition refs, ordered route/environment facts, project policy edition/hash and optional future ELV7 evidence ref.

### 17. Calculation trace
`FA08_RESOLVE_CABLE_EDITION_V1`, `FA08_RESOLVE_ROUTE_ENVIRONMENT_V1`, `FA08_MATCH_POLICY_PREDICATE_V1`, `FA08_COMPARE_NUMERIC_LIMIT_V1`, `FA08_SEPARATE_COMPLIANCE_CLAIM_V1`.

### 18. Complexity/resource bounds
O(S*R) for route sections×bounded requirement predicates; indexed policy rules prevent arbitrary script execution.

### 19. Pseudocode
```text
for section in orderedRoute:
  cable = requireImmutableCableEdition(section.cableRef)
  env = requireRouteEnvironment(section)
  for req in policy.requirementsApplicableTo(section, env):
    evaluateTypedPredicate(cable, env, req)
setVerifiedCompliance(fromElv7EvidenceOrNotAssessed)
```

### 20. Dart interfaces
```dart
final class Fa08Input { final List<FireCableRouteSection> orderedSections; final FireCableTechnicalPolicy policy; final Elv5Field<Elv7ComplianceEvidence> complianceEvidence; }
final class Fa08Output { final List<FireCablePolicyResult> policyResults; final Elv5Assessment technicalPolicyMatch; final Elv5Assessment verifiedCompliance; }
```

### 21. Positive reference vector
Fictional policy requires `TEST_CLASS_A`; exact cable edition says `TEST_CLASS_A`; applicable route environment evidence complete => technical policy-match PASS, verified compliance NOT_ASSESSED.

### 22. Boundary vector
Explicit numeric environmental limit equals conservative captured value exactly => zero-margin PASS if inclusive. Compliance remains separate.

### 23. Negative vector
One route section cable class mismatches selected project policy => technical policy FAIL on that section.

### 24. Adversarial vector
Cable marketing/display name contains the required class while immutable edition property is missing. Must BLOCK, not parse name. A project policy titled with a jurisdiction name still cannot emit verified compliance.

### 25. Cross-discipline vector
ELV3 owns route/cable facts; ELV7 later owns normative applicability/compliance. FA-08 technical evidence is consumed by ELV7 but historical FA-08 output is not rewritten when compliance determination changes.