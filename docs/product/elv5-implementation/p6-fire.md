# P6 — Fire-alarm implementation

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1/P2, signal topology and supported electrical kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [typed process API](typed-process-api.md); [engineering primitives](engineering-primitives-contract.md); [Fire code-level dossiers](process-specifications/fire-processes.md); [Flutter performance contract](flutter-performance-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P6](implemented-baseline.md#p6); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P6-001 | Implement FA-01 distinct physical-device/address-resource limits, reserved resources and full expanded-address uniqueness | P6-T01 |
| ELV5-P6-002 | Implement FA-02 explicit standby/alarm/simultaneous current origins, evidence basis and membership completeness without own-load duplication | P6-T02 |
| ELV5-P6-003 | Implement FA-03 only for explicitly supported electrical models; closed signal topology never implies solved power mesh | P6-T03 |
| ELV5-P6-004 | Implement FA-04 complete shared panel/loop/notification/auxiliary source requirement composition once | P6-T04 |
| ELV5-P6-005 | Implement FA-05 explicit ordered standby/alarm sequence, duration provenance and exact bank-model applicability | P6-T05 |
| ELV5-P6-006 | Implement FA-06 independent notification count/active/startup-current/terminal-voltage dimensions | P6-T06 |
| ELV5-P6-007 | Implement FA-07 signal closure/branch/address topology and FA-08 project policy/evidence basis without false survivability/compliance claims | P6-T07 |
| ELV5-P6-008 | Qualify safety-critical missing-policy/evidence behavior, restart/history and no-false-PASS scenarios through public commands | P6-T08 |

## Normative code-level binding

Runtime implementation MUST match FA-01…08 in [process-specifications/fire-processes.md](process-specifications/fire-processes.md) across all 25 dossier sections. Safety-critical missing/unsupported behavior is part of the algorithm, not optional error handling.

Implementation priority inside P6 is **FA-02 → FA-04 → FA-05 → FA-06**. This sequence proves state-current accounting, shared-source composition, autonomy sequence and notification transient/terminal behavior before the remaining address/topology/policy basis processes.

## FA-01 — loop device/address capacity

Physical device count and consumed address count are separate resources. Runtime expands the complete effective address set in an explicit domain and collision-checks `(domain,address)` across device claims and reserved resources. Expansion cardinality must match the immutable device profile. Distinct start addresses are insufficient if expanded sets overlap.

Capacity margin is exact integer headroom; any collision governs FAIL even when numerical address/device limits are not exhausted.

## FA-02 — standby/alarm/startup current

Canonical physical load origins are counted exactly once. Each origin has explicit state-current evidence; signal-return/multiple graph participation cannot duplicate a physical current.

Required cases are explicit standby/alarm and startup/inrush where profiled. For each case:

```text
Icase = Σ I(origin, selectedState)
```

Known subtotal plus missing mandatory current remains UNRESOLVED, never PASS. Pulse/current durations remain explicit and are not averaged into a guessed duty factor.

## FA-03 — electrical terminal-voltage basis

FA-03 only consumes an explicitly supported electrical-model/PWR-03 result. A closed signal loop does not authorize solving an unsupported dual-feed/shared-return mesh. For a required allowed voltage range:

```text
lowMargin  = terminalVoltageLower - requiredMin
highMargin = requiredMax - terminalVoltageUpper
```

The worst required terminal/case margin governs. Unsupported model is BLOCKED even if FA-07 signal topology passes.

## FA-04 — shared fire source requirement

FA-04 consumes complete global PWR-01 demand and exact PWR-02 capability/requirement evidence. Fire current facts such as FA-02 may explain contribution/state selection but are not added a second time onto an already complete global PWR demand.

Source-owned requirement composition applies reserve/derating once and retains all discipline contributors. Fire-only filtering cannot create a passing physical source result.

## FA-05 — standby/alarm backup sequence

Autonomy is an ordered explicit protected sequence, not `nominal current × assumed hours`.

Each segment carries state, exact duration, policy provenance and complete protected membership. The exact PWR-04 model owns battery losses/discharge/EOD/current physics. In a simple supported energy case:

```text
Erequired = Σ(Psegment × duration)
EnergyMargin = Eavailable - Erequired
```

Energy PASS cannot hide peak-current/EOD FAIL. No national/project hours are inserted as defaults, and nominal Ah is not universally converted to usable energy.

## FA-06 — notification circuit capacity

Independent mandatory dimensions/cases can include:

```text
active device count
ACTIVE_NOTIFICATION current
STARTUP_INRUSH current when profiled
output current capability
worst terminal voltage
supported OPEN/SHORT/RETURN_LOSS supervision cases when selected
```

Count PASS cannot mask current/voltage/fault-state failure. Acoustic/audibility/candela coverage is NOT_ASSESSED unless a future explicit model exists.

## FA-07 — signal topology integrity

FA-07 evaluates signal-layer closure/branch/address consistency and only supported fault transformations. Isolator presence or marketing label is not survivability evidence. Graph processing is deterministic and separate from FA-03 electrical applicability.

## FA-08 — cable/environment technical policy basis

FA-08 keeps separate:

```text
technical project-policy match
route/cable evidence completeness
verified jurisdictional compliance
```

The first two are ELV5 technical outputs. Verified compliance requires actual ELV7 evidence; project/fictional policy titles cannot manufacture it.

## Engineering evidence and environmental applicability

Manufacturer/project values retain immutable source hash, evidence basis and applicability envelope. Typical/estimated current/capacity/property data cannot satisfy guaranteed-bound requirements. Environmental constraints must be captured rather than silently assuming room/default conditions.

## Dependencies and invalidation

Dependency closure includes fire-loop device/address sets and selectors, expanded claims/domain, state-current definitions/state selection, panel/module/auxiliary membership, electrical model and exact PWR evidence, source requirement policy, ordered autonomy segments/durations, notification assignments/output/path, signal graph/fault model, route/cable/environment facts, FA-08 policy and MISSING markers.

Adding a previously absent fact or a newly selector-matching device invalidates prior blocked/current nodes through P7. Unrelated CCTV/LAN/ACS edits remain negative controls except where a true shared physical source/bank/path dependency exists.

## Public-command qualification

Primary and supplemental FA vectors execute through public setup, schema-24 file SQLite, production capture/resolver, `Elv5CalculationExecutor` where workload requires, pure Fire kernel, guarded atomic publication, targeted workspace projection and close/reopen verification.

Required cases include multi-address overlap, reserved collision, exact address capacity boundary, missing alarm current, signal topology PASS with unsupported electrical model BLOCKED, shared non-fire source load retained, standby+alarm sequence with explicit durations, energy-pass/current-fail bank case, count PASS with startup-current/terminal FAIL, supported/unsupported supervision behavior, technical fire policy without verified compliance, stale prior PASS and frozen historical evidence.

## Performance obligations

P6 follows [flutter-performance-contract.md](flutter-performance-contract.md):

- FA-01 uses O(D+A) hash-set address collision detection and supports the 10,000-claim fixture without pairwise comparison;
- FA-02 uses O(N×C) over load origins and a small bounded case set, never duplicate graph-origin scans;
- FA-05 is O(S+C) over ordered sequence/contributors and does not perform battery physics again;
- FA-06/FA-07 graph fault evaluation is scoped/bounded and cannot enumerate an unbounded multi-fault powerset;
- medium/large native work is off the Flutter UI isolate;
- adding one fire device/address invalidates exact dependent loops/processes only;
- large address/finding/trace collections are virtualized/lazy in the workspace UI.

## Exit

P6 runtime acceptance requires P6-T01…T08, both primary POS/NEG entries for FA-01…08, all Fire boundary/adversarial/cross-discipline dossier vectors and required L0–L6/performance evidence at the same source SHA and authority fingerprint.

P6 cannot close if missing safety-critical evidence produces PASS, signal closure is treated as an unsupported electrical mesh solution, source/bank loads are discipline-filtered, or technical project-policy match is labelled verified compliance.
