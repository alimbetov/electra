# ELV5 — Third-pass production-readiness audit

Date: 2026-10-16  
Branch: `feat/flutter-elv5-power-topology-design`  
Status: DESIGN HARDENED / RUNTIME NOT STARTED

This audit follows the initial 80-requirement/27-process review and the second engineering/architecture hardening pass. Its purpose is narrower and stricter: review ELV5 as code that must survive wrong identities, partial evidence, adversarial payloads, replay/restart, concurrency and life-safety technical edge cases without producing a convincing but false PASS.

Normative remediation: [third-pass hardening contract](../product/elv5-implementation/code-level-hardening-v2.md).

## Verdict

The existing specification is already unusually detailed, but it still contained implementation ambiguity that could produce materially different correct-looking implementations. The third pass identifies **15 additional findings: 11 HIGH and 4 MEDIUM**. All are `SPEC_RESOLVED / RUNTIME_NOT_IMPLEMENTED` by the new amendment.

The branch is suitable to start P1/P2 only if the new amendment is treated as normative and its qualification additions are carried into P8. It is not runtime-ready and none of these findings is a code fix yet.

## Findings

| ID | Severity | Finding | Risk | Spec remediation |
|---|---|---|---|---|
| ELV5-HARD3-01 | HIGH | Raw `String` identities in typed API | Cross-kind ID substitution can compile and resolve wrong physical subject | Strong/opaque domain IDs and typed scope/subject discriminators |
| ELV5-HARD3-02 | HIGH | Nullable semantic fields are ambiguous | `null` may be interpreted as missing, N/A, unsupported or unknown and can alter verdict semantics | Closed `Elv5ResolvedField<T>` algebra; nullable only at strict adapters |
| ELV5-HARD3-03 | HIGH | Exact arithmetic/collection sizes are unbounded | Huge rationals, paths, schedules or claims can exhaust CPU/memory before engineering validation | Versioned codec/resource limits and one-over-limit tests |
| ELV5-HARD3-04 | HIGH | Generic quantity wrapper does not by itself guarantee legal algebra | Dimension-safe storage may still permit invalid arithmetic in implementation | Code-owned typed quantity operations and forbidden-operation tests |
| ELV5-HARD3-05 | HIGH | `tzdbVersion` label alone is not sufficient reproduction evidence | Historical calculation may not reproduce after bundled/host timezone rules change | Capture immutable timezone rules artifact/transition slice + hash |
| ELV5-HARD3-06 | MEDIUM | Measurement provenance lacks mandatory calibration/uncertainty semantics for threshold-grade evidence | Measured nominal near a limit may be accepted without conservative uncertainty | Method, calibration, uncertainty, validity and applicability evidence |
| ELV5-HARD3-07 | HIGH | “Strongest applicable requirement” lacks deterministic merger algebra | Two policies can be combined differently by different developers; reserve may be double-applied | Per-dimension merger kind and explicit conflict set/provenance |
| ELV5-HARD3-08 | HIGH | Operating-case labels do not fully model coincident startup/inrush pulses | Shared source may be falsely passed or grossly oversized by naïve peak handling | Temporal demand events + versioned simultaneity rules; unsupported transient model blocks |
| ELV5-HARD3-09 | HIGH | ACS-06 truth-table hardening is not fully visible in canonical process prose | Implementer following process contract alone can omit required release cases | Make five-cause release matrix normative and independently prove outcome/path/supervision |
| ELV5-HARD3-10 | HIGH | Fire signal continuity/topology does not by itself model supervision/fault states | Closed loop can appear healthy while technical open/short/EOL supervision behavior is unproved | Registered fault-state/supervision model for FA-06/FA-07 when profile requires it |
| ELV5-HARD3-11 | HIGH | Negative dependency capture needs explicit selector semantics | Creating a new row that matches a previously consumed query can leave result CURRENT | Versioned selector/set dependency markers and old/new invalidation |
| ELV5-HARD3-12 | MEDIUM | Atomic multi-node publication lacks explicit transaction/resource bound | Large coherent batches may hit SQLite parameter/transaction limits or be silently split | Maximum target count, deterministic ordering and bounded SQL chunks inside one transaction |
| ELV5-HARD3-13 | MEDIUM | Engineer acceptance/waiver boundary is not explicit | Workflow override can accidentally mutate technical FAIL into PASS | Separate immutable engineering result from review/deviation decision |
| ELV5-HARD3-14 | MEDIUM | Finding/step cardinality is unbounded | Large designs can create huge duplicate diagnostics and unstable UI/persistence behavior | Deterministic aggregation, bounded samples, explicit truncation metadata |
| ELV5-HARD3-15 | HIGH | Normative authority chain is too complex without a machine guard | Runtime may implement an older contract while docs all appear internally valid | Explicit precedence + generated contract manifest/hash + CI consistency gate |

## Engineering review by discipline

### CCTV

The formula set is fundamentally sound after the second pass: geometry is bounded, storage separates estimate vs guaranteed sizing, and payload vs physical wire rate are not conflated. The remaining material risks are implementation-system risks: nullable peak/wire evidence, recurrence reproducibility, exact-arithmetic resource limits and selector invalidation when stream/path membership changes.

Required hardening effect:

- no hidden `null => 0` or `null => use expected bitrate` behavior;
- historical storage output remains reproducible from captured timezone transition evidence;
- a new matching stream subscription invalidates affected edge/recorder calculations even when the subscription did not exist at capture time;
- oversized schedule/path payloads reject before expensive expansion.

### LAN

The current LAN scope correctly avoids claiming ELV6 rack fit and ELV7 compliance. Optical dB/dBm separation and bidirectional overload/sensitivity checks are strong. The third pass mainly hardens identity and algebra boundaries so a link/port/panel ID cannot be substituted accidentally and generic quantity code cannot add incompatible units.

Rack demand remains a handoff basis only. No ELV5 PASS may mean actual cabinet U-position, depth/clearance, thermal or cable-management fit.

### ACS

ACS carries the highest human-safety semantic risk in this stage. The release behavior must be represented as project technical truth, not inferred from labels or one normal-state wiring path.

Minimum captured/replayed release causes are:

```text
NORMAL_ACCESS
REQUEST_TO_EXIT
FIRE_RELEASE
EMERGENCY_BREAK_GLASS
POWER_FAILURE
```

For each applicable cause the process proves expected lock state plus the required control/release/feed path and selected monitoring evidence. `FAIL_SAFE`/`FAIL_SECURE` alone is not a complete proof. ELV7 still owns jurisdictional egress/fire requirements.

Startup/inrush handling must use a declared simultaneity/transient model. If the ELV4 physical kernel cannot represent the required transient, the correct result is unsupported/blocked, not a steady-state approximation presented as PASS.

### Fire alarm

The current split between FA-03 electrical basis and FA-07 signal topology is correct and must remain strict. A signal loop that closes is not automatically a supported electrical mesh.

The missing technical layer was supervision/fault behavior. Where the selected panel/module/project profile calls for supervision, the model needs explicit supported fault states such as open, short, EOL invalid/missing, isolator operation or return loss as applicable. These are technical manufacturer/project behaviors, not universal regulatory numbers.

No hardcoded EOL resistance, isolator spacing, address count, autonomy duration or national compliance rule is introduced by this audit.

## Cross-cutting implementation invariants added

1. Partial closure cannot produce full-claim PASS.
2. Reserve, derating, redundancy and uncertainty are named independent transformations and cannot be silently multiplied twice.
3. Every unit conversion is typed and visible in deterministic steps.
4. Human/product labels never determine electrical or safety behavior.
5. Shared-source wrappers cannot remove other discipline loads.
6. Old stale PASS cannot become current when a new calculation fails or loses publication race.
7. Missing/query-negative facts participate in invalidation through selector markers.
8. Mutable review/waiver state cannot rewrite immutable engineering output.
9. Host timezone/current tzdb cannot change an immutable historical output.
10. Engineering violations are successful executions with FAIL assessment; exceptions do not encode normal design failure.

## Required P8 additions

The existing 54 POS/NEG primary verticals remain mandatory. Add focused hardening suites for:

- typed identity misuse;
- explicit missing/N-A/unsupported resolution variants;
- arithmetic/collection resource bounds;
- legal dimension algebra;
- captured timezone-rules reproduction;
- measured uncertainty comparison;
- requirement merger/conflict algebra;
- startup/inrush simultaneity;
- ACS five-cause release matrix;
- fire supervision/fault behavior;
- selector negative-dependency invalidation;
- SQL-chunked but atomic publication;
- waiver/result immutability;
- bounded deterministic diagnostics;
- contract-manifest consistency.

These tests supplement rather than replace the 54 process verticals and 16 command codec/adversarial matrix.

## Final assessment

After applying the third-pass contract, the ELV5 design can be considered **implementation-grade at specification level**, subject to one condition: implementation work must treat the authority chain and machine registries as one coherent contract and must fail CI on drift.

The specification should no longer be judged by page count. The closure criterion is stronger: every CURRENT engineering conclusion must be reproducible, attributable, dimensionally valid, based on complete applicable physical evidence, invalidated when that evidence changes, and incapable of claiming ELV6/ELV7/ELV8 conclusions prematurely.

Runtime status remains `NOT_STARTED` until production Dart/Drift implementation and exact-SHA P8/P9 evidence exist.