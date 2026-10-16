# P5 — Access-control implementation

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1/P2, canonical assemblies and power kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [typed process API](typed-process-api.md); [hardening amendments](code-level-hardening-amendments.md); [ACS code-level dossiers](process-specifications/acs-processes.md); [Flutter performance contract](flutter-performance-contract.md).

Inherited implementation and mandatory new extensions: [baseline contract P5](implemented-baseline.md#p5); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P5-001 | Implement ACS-01 explicit door-role alternatives/multiplicities with scoped canonical assignments | P5-T01 |
| ELV5-P5-002 | Implement ACS-02 independent controller reader/relay/input resource capacities | P5-T02 |
| ELV5-P5-003 | Implement ACS-03 lock holding/active/startup mode and shared-trunk voltage evidence | P5-T03 |
| ELV5-P5-004 | Implement ACS-04 shared-source requirement composition with reserve/derating once | P5-T04 |
| ELV5-P5-005 | Implement ACS-05 full protected sequence/model policy and global bank evidence | P5-T05 |
| ELV5-P5-006 | Implement ACS-06 independent reader/control/feed/monitoring/release topology plus explicit safety/release truth table | P5-T06 |
| ELV5-P5-007 | Integrate assignment/deletion/adoption guards, findings and consumed dependency projection | P5-T07 |
| ELV5-P5-008 | Qualify role/resource/power/release positives/negatives, shared non-ACS loads, restart and historical evidence | P5-T08 |

## Normative code-level binding

Runtime implementation MUST match ACS-01…06 in [process-specifications/acs-processes.md](process-specifications/acs-processes.md) across all 25 sections. The package summary does not authorize alternate formulas, hidden steady-state assumptions or a simplified release model.

Implementation priority inside P5 is **ACS-03 → ACS-04 → ACS-05**, because these force correct transient/shared-source/battery integration with ELV4 before the simpler role/resource and topology checks.

## ACS-01 — door role completeness

Door assembly membership is non-owning. Requirements are a closed typed expression algebra over explicit role assignments: alternatives and multiplicities are not free-form formulas. One component may satisfy multiple roles only when the exact profile/capability allows sharing. Role absence is FAIL only when the assignment closure is complete; incomplete closure is UNRESOLVED.

## ACS-02 — controller resources

Reader, relay, supervised-input and other physical resource pools are independent typed pools. Capacity is based on canonical physical resource identities, not component count or labels. Spare ratio uses exact rational arithmetic and code-owned `ceil`. Unsupported sharing/multiplexing cannot manufacture additional capacity.

## ACS-03 — lock electrical/transient basis

ACS-03 is a discipline wrapper over exact shared ELV4 physical evidence. It MUST distinguish:

```text
control path != conductive power feed
lock branch current != shared trunk current
steady holding != active/release != startup/inrush
```

The runtime builds a bounded deterministic temporal-event envelope from explicit state profiles and simultaneity policy; it never enumerates an unbounded powerset and never assumes “all start together” or “none start together” without policy.

For each required event it consumes exact matching PWR-01/PWR-03 evidence. Typical terminal-voltage comparisons are:

```text
lowMargin  = terminalVoltageLower - requiredMinVoltage
highMargin = requiredMaxVoltage - terminalVoltageUpper
```

The governing event is the required event/dimension with the worst valid signed margin/status. A short startup event can govern despite all steady-state cases passing. Reduced ACS-only trunk arithmetic is forbidden.

## ACS-04 — shared source/PSU requirement

ACS-04 consumes complete global PWR-01 demand and exact PWR-02 source capability/requirement evidence. Source-owned deterministic requirement composition applies reserve/derating once. Conceptually, where the selected source model uses these terms:

```text
requiredCapability = globalPhysicalDemand × effectiveReserve
availableCapability = rating × applicableDerating
margin = availableCapability - requiredCapability
```

The actual physical demand remains separate from required capability. Repeating a source reserve per door/load is a hard defect. Fire/other disciplines sharing the source remain in the same physical closure and requirement set.

## ACS-05 — shared backup/autonomy

ACS-05 verifies an exact complete protected sequence against PWR-04. The sequence is ordered, duration-explicit and includes shared non-ACS loads. Simple supported energy models may expose `E=Σ(P×t)`, but battery losses/discharge/EOD/current applicability remain ELV4 PWR-04 ownership.

Energy PASS cannot hide peak-current/EOD failure. Nominal Ah cannot be converted into universal usable Wh without the supported model.

## ACS-06 — door control/feed/release topology

Persisted aggregate includes:

```text
doorAssemblyId
topologyProfileRef
safetyMode = FAIL_SAFE | FAIL_SECURE | PROJECT_DEFINED
roleAssignments
releaseTruthTable
```

Exactly five initial release causes are canonical:

```text
NORMAL_ACCESS
REQUEST_TO_EXIT
FIRE_RELEASE
EMERGENCY_BREAK_GLASS
POWER_FAILURE
```

Runtime separately evaluates typed data/control, conductive feed, monitoring/supervision and release/interlock paths. A dry contact is control evidence only. The truth table must be complete/canonical before evaluation; duplicate/missing cause rows are rejected.

Passing all five technical rows is still not verified egress/fire-code compliance; that remains ELV7.

## Shared-source and cross-discipline rules

ACS-03/04/05 preserve complete physical membership. Discipline contribution may be projected for explanation, but source/trunk/bank totals never remove concurrent CCTV/LAN/Fire/other loads. ACS-06 may consume an exact fire-release interface fact without taking ownership of the fire system or normative determination.

## Dependency and invalidation rules

Dependencies include door-role and controller-resource sets/selectors, lock state profile and temporal policy, control/feed/release graph sets, safety mode/truth table, exact ELV4 evaluation hashes/generations, source/bank requirement policies and MISSING markers. Replacement invalidation uses old+new closure and newly matching selectors. Unrelated doors stay unaffected unless a shared physical source/bank/policy dependency truly changed.

## Public-command qualification

P5 primary and supplemental vectors execute through schema-24 file SQLite, production capture/resolver, `Elv5CalculationExecutor` where appropriate, pure ACS kernels, guarded atomic publication, targeted workspace projection and close/reopen verification.

Required vectors include role alternatives/exact multiplicity, resource-pool boundary, control-without-feed, startup governing steady state, source reserve repeated-door adversary, shared-bank non-ACS load, energy-pass/current-fail bank case, complete fail-safe and fail-secure/project-defined five-cause truth tables, duplicate/missing cause rows and technical-vs-ELV7 claim separation.

## Performance obligations

P5 follows [flutter-performance-contract.md](flutter-performance-contract.md):

- ACS-01 requirement tree/role indexing is O(A+R), not combinatorial alternative search;
- ACS-02 resource assignment is O(R+A) keyed by canonical resource ID;
- ACS-03 uses a bounded code-owned transient event envelope, never powerset enumeration;
- ACS-06 scopes graph reachability to the door-local graph and runs five O(V+E) cause checks;
- medium/large batches execute outside the native Flutter UI isolate;
- rapid door/profile edits supersede/coalesce stale calculations;
- one door update rebuilds only affected process cards/rows.

## Exit

P5 runtime acceptance requires P5-T01…T08, both primary POS/NEG entries for ACS-01…06, all ACS boundary/adversarial/cross-discipline dossier vectors and required L0–L6/performance evidence at the same tested source SHA and authority fingerprint.

P5 cannot close if ACS-06 reports generic PASS with an unproven required release cause, if control is mistaken for power feed, if shared-source membership is reduced by discipline filtering, or if technical release evidence is labelled verified legal/normative compliance.
