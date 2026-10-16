# P1 — Typed discipline profiles and process registry

Status: DESIGN HARDENED / RUNTIME NOT STARTED
Depends on: P0 ownership/scope map.
Parent: [ELV5 design](../elv5-discipline-calculations-design-specification.md); [process contracts](process-contracts.md); [code-level runtime contract](code-level-runtime-contract.md); [engineering primitives](engineering-primitives-contract.md); [typed process API](typed-process-api.md).

Inherited implementation and mandatory new extensions: [baseline contract P1](implemented-baseline.md#p1); [pinned evidence](baseline.json).

## Requirements and planned proof

| Requirement | Required implementation behavior | Planned acceptance |
|---|---|---|
| ELV5-P1-001 | Register exactly 27 stable discipline process codes with algorithm/input/output/numeric versions | P1-T01 |
| ELV5-P1-002 | Define typed immutable policy editions with exact applicability, units, source/evidence basis and hashes | P1-T02 |
| ELV5-P1-003 | Define DESIGN/SEGMENT/SEQUENCE key and process input/output scope + operating-case compatibility | P1-T03 |
| ELV5-P1-004 | Model stream/subscription/recording, link/port, door/channel and fire/address assignments without duplicate canonical identities | P1-T04 |
| ELV5-P1-005 | Implement dimension-safe exact quantities, signed coordinate/dBm rules and versioned bounded geometry | P1-T05 |
| ELV5-P1-006 | Define shared-source requirement composition without repeated reserves/losses or reduced membership totals | P1-T06 |
| ELV5-P1-007 | Implement canonical serialization/hash primitives and strict 16-operation wire registry/examples | P1-T07 |
| ELV5-P1-008 | Define code-owned dependency/evaluation registry, model-limit outcomes, per-dimension status and deterministic kernel contract | P1-T08 |

## Concrete contract

The machine-readable process registry is the design source for process membership, modes and planned oracles. Runtime registry is compiled/code-owned, not arbitrary expressions imported from profiles. Policy definitions are data, versioned and validated before adoption. Imported executable formula/script content is not supported.

The runtime implementation MUST expose one closed `Elv5ProcessRegistry` containing exactly CCTV-01…06, LAN-01…07, ACS-01…06 and FA-01…08. Each definition pins `algorithmVersion`, `inputSchemaVersion`, `outputSchemaVersion`, `numericBackendVersion`, required dimension codes, discipline, legal scope kinds and typed upstream bindings. Startup/test construction fails on missing/duplicate code, unknown upstream process, unknown binder, invalid scope compatibility or cycle.

`Elv5EngineeringNodeKeyV3` is owner-isolated from `PowerNodeKeyV2` and serializes `[engineering-node-v3, ELV5, revision, scenarioKey, scopeKind, scopeId, processCode, subjectKind, subjectId]`. DESIGN uses scenarioKey `NONE`; SEGMENT/SEQUENCE require actual scenario context when registered. UI scenario selection never silently rewrites calculation identity.

Freshness, completion, assessment and execution are separate types. `CURRENT` is pointer freshness, not a verdict. A completed technical violation is SUCCEEDED/COMPLETE/FAIL; missing model/input may be BLOCKED/UNRESOLVED; ELV6/7/8-owned dimensions remain explicitly NOT_ASSESSED where the process contract says so.

### Dimension-safe engineering primitives

P1 MUST implement shared primitives equivalent to the [engineering primitives contract](engineering-primitives-contract.md):

- exact normalized `Elv5Decimal` / `Elv5Rational`;
- `Elv5Quantity<D>` or equivalent code-owned dimension-safe wrappers;
- distinct dB attenuation and dBm optical-level types;
- conservative exact/bounded intervals;
- evidence basis (`manufacturerGuaranteed`, `manufacturerTypical`, `measured`, `estimated`, fixture, etc.);
- applicability/environment envelope;
- `Elv5OperatingCaseRef` and state selection;
- deterministic temporal policy with IANA zone + tzdb version + DST policy;
- explicit coordinate-frame/transform identity;
- stable finding/comparison model;
- canonical encoder `electra.canonical-json.v1`.

A plain exact number does not satisfy P1 if its engineering dimension/evidence basis can be confused with another quantity.

### Canonical hashes

P1-T07 includes exact canonical projections for:

```text
command request hash
process input fingerprint
process deterministic output hash
frozen discipline snapshot hash
```

Raw JSON textual ordering is not a hash contract. Unordered map/set order must not affect the hash; path/sequence order must. `evaluationId` and `completedAtUtc` are excluded from deterministic output hash while all engineering dimensions/findings/provenance remain included.

### Typed process surface

The generic interface shape alone is insufficient. P1 MUST provide process-specific input/output types equivalent to [typed-process-api.md](typed-process-api.md) for all 27 codes.

Dynamic maps are limited to strict codec/storage/projection boundaries and may not flow through calculation kernels as semantic property bags.

At minimum P1 proves:

- all 27 typed definitions are registered exactly once;
- process registry legal scope and required dimensions match definition metadata;
- every required engineering value declares acceptable evidence basis;
- every output field affecting assessment participates in deterministic output hashing;
- generic executable formula/expression fields are absent.

### Shared physical evidence rule

DESIGN consumers of power evidence, such as CCTV-06, declare the complete required scenario/segment applicability set in their policy and consume those exact evidence refs. They do not use whichever UI scenario happens to be selected. Source-owned requirement sets consider every participating discipline and select the strongest applicable capability constraint per dimension on one physical demand; incompatible scenario policies require explicit project composition.

### Mandatory codec examples before implementation entry

P1-T07 is not satisfied by naming the schema. The specification/fixture set includes one canonical valid JSON payload and at least one rejection mutation for each of the 16 registered operations. The three hardened payloads for camera streams/subscriptions, recording time/reserve/redundancy and ACS release truth table are governed by [code-level hardening amendments](code-level-hardening-amendments.md) and the machine registry.

## Exit

P1 runtime acceptance requires its numbered assertions at the same accepted source SHA and its prerequisite gates. This document is a design contract, not proof of source implementation.

P1 implementation entry is blocked until:

1. 27 process registry rows and 27 typed definitions are mutually consistent;
2. primitives/canonical-hash contracts are frozen and have L0 tests;
3. exact 16-operation registry/examples are mutually consistent;
4. no dimension/evidence/time/frame behavior depends on locale, host timezone, map iteration order or UI formatting.

## Audit refinements

Initial audit resolutions remain mandatory: exact pool/copy/sizing/channel basis types; integer-capacity rounding separate from UI formatting; signed optical physical-loss interval separate from design reserve; full expanded fire address sets; gross/net rack capacity tag; typed acyclic dependencies.

Second-pass hardening additionally requires type-safe engineering dimensions, evidence-basis/applicability semantics, operating-case identity, deterministic timezone/frame behavior and canonical hash projections. These are P1 runtime obligations, not optional library conveniences.
