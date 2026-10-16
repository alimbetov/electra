# P6 — Fire-alarm implementation

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P1/P2, signal topology and supported electrical kernels.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [typed process API](typed-process-api.md); [engineering primitives](engineering-primitives-contract.md).

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

## FA-01 — loop device/address capacity

Physical device count and consumed address count are separate resources. One device/module may occupy multiple, non-contiguous addresses only when its exact immutable expansion profile allows it.

Runtime materializes the full effective address claim set in an explicit scoped domain. Collision detection is on `(addressDomain,address)`, not only on device start addresses. Reserved addresses participate in availability/uniqueness rules.

A passing physical device-count dimension cannot mask address exhaustion or overlap.

## FA-02 — standby/alarm current

Device, module, panel and auxiliary current origins are identified exactly once. Each current value carries an explicit state and evidence basis. State labels do not invent current values.

Standby/alarm/active/startup/project-defined cases are explicit operating-case selections. A missing mandatory alarm current produces a known partial subtotal plus missing membership evidence; it cannot become a complete PASS because the known subtotal fits.

Where the same physical loads feed ELV4 PWR calculations, FA-02 must reference/prepare the same uniquely identified origins rather than create a second additive copy of their load.

## FA-03 — electrical basis

FA-03 only applies to an explicitly registered electrical model supported by the underlying physical kernel. A closed signal loop, return path or ring topology does **not** prove that a dual-fed/shared-return electrical network is correctly solved.

Supported radial/one-common-point cases may consume PWR-03 exact evidence and compare declared manufacturer/project voltage limits. Unsupported mesh/dual-feed arrangements return BLOCKED/UNRESOLVED according to the contract, even when FA-07 signal topology passes.

The model discriminator, applicability envelope and exact consumed PWR evidence are part of input fingerprint/provenance.

## FA-04 — shared fire supply requirement

The physical source demand includes every concurrent load actually on the source, including non-fire loads when the source is shared. Fire-specific reserve/capability requirements are composed into the source-owned requirement set once.

No per-loop/per-device repetition of reserve or derating is allowed if the factor is owned at source capability boundary. Contribution views are explanatory only; the global physical source evidence remains authoritative.

## FA-05 — standby/alarm backup

Autonomy is an ordered protected sequence, not a nominal current × guessed hours shortcut.

Each phase has:

```text
phase identity
selected state case
explicit duration
source/policy provenance
complete protected membership
```

The exact bank/PWR-04 model must be applicable to the captured sequence/voltage/current/environment conditions. Missing duration or model applicability blocks the affected claim. No national/project standby/alarm hours are silently inserted as defaults.

The result separates required sequence energy, available usable energy and margin. It does not relabel a technical project policy as verified national compliance.

## FA-06 — notification circuit capacity

Notification circuit checks remain independent:

```text
active device count
active output current
startup/inrush current where applicable
output current limit
worst terminal voltage over supported physical path
```

Count fitting does not mask current or voltage failure. A current/voltage PASS does not assert sound-pressure, intelligibility, candela or visual/audibility coverage; those dimensions are outside this process version unless a future exact model is added.

## FA-07 — signal topology integrity

FA-07 validates signal-layer source/return closure, branch policy, membership and consistency with the full FA-01 address set.

Presence of isolator devices/components alone is not proof of short-circuit survivability, fault containment or normative loop survivability. Such a claim requires an explicit supported behavior/fault model and later normative applicability where relevant.

A topology can therefore be technically closed while survivability remains NOT_ASSESSED/UNRESOLVED.

## FA-08 — fire cable/project policy evidence basis

FA-08 separates three concepts:

```text
technical project-policy match
route/cable evidence completeness
verified jurisdictional compliance
```

ELV5 can evaluate the first two against exact selected policy/definition editions. `FICTIONAL` or `PROJECT_AUTHORED` policy can never yield verified regulatory compliance. ELV7 owns authoritative jurisdiction/rule applicability and certification.

Missing cable/route/environment evidence blocks the technical basis rather than falling back to a device label or generic “fire cable” class.

## Engineering evidence and environmental applicability

Manufacturer/project values retain source ref/hash, basis and applicability. Typical/estimated current, capacity or cable/environment properties cannot satisfy dimensions whose selected policy requires guaranteed limits.

Environmental conditions required by a consumed definition—temperature, installation environment, enclosure/route class or other exact applicability tags—must be provably covered. No room-temperature/default-environment substitution is allowed in a safety-critical claim.

## Dependencies and invalidation

Exact dependency closure includes:

```text
fire-loop device SET
expanded address-claim SET/address domain
state-current profile refs and state selection
panel/module/auxiliary membership SET
selected electrical model + exact PWR evidence
source requirement policy
ordered autonomy phase set/durations
notification assignment/output/path evidence
signal graph/branch/return set
route/cable/environment evidence
FA-08 policy edition/hash/source status
MISSING markers for absent mandatory evidence
```

Adding a previously missing address/current/policy fact must invalidate a prior blocked result. Unrelated optical/CCTV edits remain negative controls unless a shared physical power dependency actually changed.

## Public-command qualification

Primary FA-01…08 oracles execute through public setup, schema-24 file SQLite, production capture/resolver/kernel/publication, workspace projection and close/reopen verification.

Required cases include:

- multi-address overlap despite distinct start addresses;
- reserved address consumption/collision;
- missing mandatory alarm current → partial/unresolved, not PASS;
- FA-07 signal closure PASS while unsupported FA-03 electrical model remains BLOCKED;
- non-fire shared source load retained in FA-04;
- explicit standby+alarm sequence with no default hours;
- count PASS but notification startup-current or terminal-voltage FAIL;
- isolator present but survivability not proven;
- fictional/project policy match without verified compliance;
- stale prior PASS remains stale after relevant evidence mutation;
- frozen R1 remains immutable after R2 fire-loop/policy edits.

## Exit

P6 runtime acceptance requires P6-T01…T08 and both primary POS/NEG entries for FA-01…08 at the same accepted source SHA, together with required L0–L6 qualification.

This document is a hardened design contract, not proof of source implementation.
