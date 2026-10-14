# Electra — ELV2 Round-2 Remediation Specification

Status: implementation specification — audit-driven remediation  
Baseline ELV2 closure SHA: `179f11d8afcbcf433466f4cdb34b60a993a13167`  
Audit branch: `audit/elv2-hard-review-round-2`  
Source audit: `docs/audit/elv2-hard-review-round-2.md`  
Source PR: #7

## 1. Purpose

This specification defines the mandatory remediation work required before the already implemented ELV2 P1–P7 baseline may be accepted as merge-ready under Round-2 review standards.

It does **not** redesign ELV2 and does **not** introduce ELV3 behavior. It hardens the existing contracts against defects discovered by adversarial review.

The previous ELV2 closure remains a historical baseline, not proof of defect absence.

Round-2 follows this rule:

```text
confirmed finding
    ↓
write regression that fails on baseline
    ↓
implement smallest contract-preserving fix
    ↓
run focused acceptance
    ↓
run full regression
    ↓
exact-SHA push + PR GREEN
```

No finding is considered closed by code inspection alone.

## 2. Non-negotiable principles

1. **Regression first.** Every defect fix must be preceded by a test that fails against the audited baseline semantics.
2. **Fail closed.** Ambiguous identity, stale review, conflicting migration intent or incomplete dependency evidence must reject the operation.
3. **One canonical identity.** Engineering identity normalization must be consistent across import, lookup, fingerprints, persistence and adoption.
4. **One commit-time snapshot.** P6 stale-review validation and graph compatibility checks must operate on the same transaction-owned durable state.
5. **Review visibility equals commit-time safety.** A dependency that can block adoption must be visible in P5 impact output.
6. **No silent repair.** Round-2 fixes may reject invalid state but must not mutate historical engineering state to make it appear valid.
7. **No ELV3 leakage.** Cable routes, pathways, CableRun ownership, route fill and physical routing remain out of scope.
8. **Exact-SHA closure.** Final acceptance requires both normal push and pull-request workflows green on one identical head SHA.

## 3. Execution sequence

```text
R2.0 repository / CI hygiene
   ↓
R2.1 canonical reference identity
   ↓
R2.2 compatibility adversarial verification
   ↓
R2.3 palette / stale UI evidence verification
   ↓
R2.4 P4 atomic placement + history review
   ↓
R2.5 P5 impact completeness
   ↓
R2.6 P6 adoption / migration / transaction snapshot
   ↓
R2.7 four-discipline restart / provenance re-acceptance
   ↓
Round-2 exact-SHA gate
```

The phases are gates. Later phases may be reviewed in parallel, but Round-2 cannot close while any `BLOCKER` or `HIGH` finding remains open.

---

# 4. R2.0 — Repository and CI hygiene

## R2-001 — committed toolchain/build artifacts

Severity: **HIGH**

### Problem

PR #7 contains tracked runtime/generated artifacts including:

```text
apps/mobile/.dart_tool/**
apps/mobile/build/**
Flutter/Dart build snapshots
native assets
Drift intermediate generator JSON
```

This obscures review and makes local machine/toolchain output part of source history.

### Required behavior

The repository must distinguish:

```text
source-controlled source/generated contract files
        vs
transient build/toolchain artifacts
```

Transient files must never be committed.

### Required implementation

1. Add repository-appropriate ignore rules covering at minimum:
   - `.dart_tool/`
   - `build/`
   - transient Flutter native asset/build caches.
2. Remove already tracked transient files from the Round-2 branch.
3. Keep `apps/mobile/lib/data/database/app_database.g.dart` only if the repository intentionally treats Drift generated source as version-controlled output.
4. Add a CI guard that fails when prohibited tracked paths return.
5. The guard must inspect Git-tracked paths, not only filesystem existence after `build_runner`.

### Required regression

A repository test/script must fail when a tracked path matches a prohibited pattern, e.g.:

```text
apps/mobile/.dart_tool/**
apps/mobile/build/**
```

### Acceptance

- meaningful PR diff no longer contains build/toolchain caches;
- normal `flutter pub get`, `build_runner`, analyze and tests still succeed;
- CI proves generated runtime artifacts cannot silently re-enter version control.

---

# 5. R2.1 — Canonical reference identity

## R2-002 — normalized profile identity collision

Severity: **HIGH**

### Problem

Catalog profile uniqueness currently uses case-sensitive raw values while P6 command identity normalizes `profileCode` with `trim().toUpperCase()`.

Therefore:

```text
CAMERA
camera
```

can be distinct lookup identities but identical adoption fingerprint identities.

### Required canonical identity function

ELV2 must define one reusable canonical code normalization function:

```text
canonicalEngineeringCode(value)
    = value.trim().toUpperCase()
```

The function must be used consistently for logical code identity where the domain treats codes case-insensitively.

### Required implementation

At minimum, normalize/reject consistently for:

- `ComponentEngineeringProfile.code` uniqueness;
- profile lookup by code;
- port template code uniqueness;
- `portInterfaceCodes` keys;
- P5 profile matching;
- P6 `profileCode` identity and fingerprint;
- explicit port migration codes.

Do **not** silently rewrite immutable historical payloads on read. Historical payload parsing may preserve raw serialized content, but publication/import of new canonical editions must reject noncanonical ambiguity.

### Required publication rules

A publishable catalog must reject:

```text
CAMERA + camera
" CAMERA " + CAMERA
ETH + eth as two logical port templates
```

Normalized duplicate identity is a validation error.

### Required lookup semantics

One policy must be explicit and tested:

- either all canonical persisted new codes must already equal `canonicalEngineeringCode(raw)` and lookups use canonical values;
- or lookup canonicalizes both sides.

No caller-dependent casing semantics are allowed.

### Required regression tests

1. Catalog with `CAMERA` and `camera` fails publication.
2. Catalog with profile whitespace alias fails publication.
3. Case/whitespace alias cannot produce two different lookup targets sharing one P6 fingerprint.
4. Port template normalized duplicates fail publication.
5. Interface binding keys resolve by the same canonical port-code policy.

### Acceptance

The following invariant must hold:

```text
same canonical code
    ⇒ same logical engineering identity
```

and:

```text
different logical engineering identities
    ⇒ different canonical fingerprint material
```

---

## R2-004 — explicit port mapping normalization collision

Severity: **MEDIUM**

### Problem

`explicitPortMappings` is currently normalized directly into a `Map`, so two raw keys may collapse before validation can report ambiguity.

Example:

```text
"eth"   -> "DATA"
" ETH " -> "DATA2"
```

### Required implementation

Construction must preserve raw entries long enough to validate canonical uniqueness.

Required sequence:

```text
raw mappings
   ↓
normalize each old/new code
   ↓
validate non-empty
   ↓
reject duplicate normalized source codes
   ↓
reject duplicate normalized target codes
   ↓
construct immutable normalized map
```

### Required regression tests

- duplicate normalized source key is rejected;
- duplicate normalized target is rejected;
- input iteration order cannot change result;
- valid one-to-one mapping remains deterministic in fingerprint serialization.

### Acceptance

Ambiguous engineer-authored remapping must never be silently collapsed or repaired.

---

# 6. R2.2 — P2 adversarial compatibility verification

No confirmed P2 correctness defect exists at specification creation time. This phase is still mandatory because P2 controls placement/adoption fail-closed behavior.

### Required adversarial matrix

Re-run and extend tests for:

- `ERROR > UNRESOLVED > WARNING > COMPATIBLE` aggregation;
- missing environment evidence;
- malformed/non-finite temperature and clearance;
- IP `X` semantics;
- exact mounting-pair behavior;
- legacy constraints;
- invalid defined constraints;
- topology shape/role only at pre-placement boundary;
- CCTV/LAN/ACS/FIRE same-engine path.

### Explicit boundary

P2 does **not** prove persisted graph degree, loop closure, branch count or node ordering. Those remain topology graph responsibilities.

### Acceptance

No missing fact may result in `COMPATIBLE` when that fact is required to prove a profile constraint.

---

# 7. R2.3 — P3 palette and stale UI evidence

No confirmed P3 defect exists yet. Round-2 must nevertheless verify the UI/application boundary cannot become authority.

### Required review targets

1. Palette choices resolve only active exact project/system/catalog/profile state.
2. A stale selected profile cannot commit after catalog/system/surface state changes.
3. UI candidate context cannot overwrite durable project/room/surface/system identity.
4. Missing exact topology edition remains unresolved.
5. Deprecated/legacy profiles remain inspectable only under existing product rules and cannot bypass P4 commit-time validation.
6. Profile identity normalization changes from R2.1 must not create duplicate palette entries.

### Required regressions

At least one stale-selection test must change durable state after preview and prove P4 rejects commit.

---

# 8. R2.4 — P4 atomic placement / history / idempotency hard review

No new confirmed P4 finding exists at specification creation time, but the following open targets are mandatory before Round-2 closure.

### Required targets

- same-operation concurrent placement under SQLite transaction behavior;
- restart replay from durable ledger;
- undo after downstream graph mutation remains blocked;
- redo cannot bypass current location/system/profile validation;
- P4 history after later successful P6 adoption must not restore stale pre-adoption provenance accidentally;
- placement ledger namespace must remain unambiguous from adoption ledger namespace;
- aggregate snapshot comparison must remain deterministic after schema-17 persistence/reopen.

### Required acceptance

Any discovered P4 defect becomes an amendment to this specification with severity and regression-first remediation before Round-2 may close.

---

# 9. R2.5 — P5 revision-impact completeness

## R2-005 — internal mappings hidden from reviewer-visible impact

Severity: **MEDIUM**

### Problem

P5 graph fingerprint includes `internalLinks`, but `BoundProfileRevisionImpact` exposes only:

```text
connectionIds
topologyGroupIds
```

P6 treats internal mappings as live dependencies capable of blocking adoption.

### Required implementation

Add deterministic reviewer-visible internal dependency identity:

```text
internalMappingIds
```

to each affected binding impact.

Preview-level API must expose a deduplicated aggregate set, e.g.:

```text
affectedInternalMappingIds
```

`affectsProjectGraph` must become true when **any** of these exist:

```text
connections
topology groups
internal mappings
```

### Required deterministic ordering

- internal mapping ids sorted;
- binding impacts remain component/profile sorted;
- aggregate sets deduplicated.

### Required regressions

1. Internal-mapping-only dependency yields `affectsProjectGraph == true`.
2. Reviewer-visible impact contains exact internal mapping id.
3. P6 blocking reason can be traced back to dependency already present in P5 impact.
4. No new write is introduced into P5.

### Acceptance

Anything that can block P6 because of an ELV1 dependency must be review-visible in P5.

---

## P5 additional hard-review targets

Classify before closure:

- assembly/member dependency completeness;
- remote endpoint changes with stable connection id;
- candidate/current catalog row-vs-payload provenance symmetry;
- removed profile impact across all dependency types;
- deterministic fingerprint after SQLite reopen.

If assemblies can constrain port retirement/remapping, P5/P6 must either include them in dependency evidence or explicitly prove they cannot own/reference ELV2 port identity in the current model.

---

# 10. R2.6 — P6 adoption / migration hardening

## R2-003 — graph snapshot outside adoption transaction

Severity: **HIGH**

### Problem

P6 currently loads a topology snapshot before `database.transaction()`, then performs fingerprint checks using rows re-read inside the transaction while graph compatibility validation uses the earlier snapshot.

This violates the intended one-snapshot commit boundary.

### Required transaction contract

P6 adoption must become:

```text
BEGIN TRANSACTION
   ↓
load active component/binding
   ↓
load exact current + candidate catalog editions
   ↓
load current membership/system/family
   ↓
load current bound ports
   ↓
load current connections/groups/internal mappings
   ↓
build transaction-owned topology validation snapshot
   ↓
compare reviewed binding + graph fingerprints
   ↓
P2 revalidation
   ↓
plan port migration
   ↓
validate candidate graph against SAME transaction-owned graph state
   ↓
perform port/binding writes
   ↓
postconditions
   ↓
write adoption operation result
   ↓
COMMIT
```

No graph state used for compatibility validation may originate from a pre-transaction load.

### Required implementation constraints

- do not open an independently committing topology repository transaction from inside adoption;
- use transaction-scoped reads/helpers or construct `EngineeringTopologyGraph` directly from rows loaded in the owner transaction;
- fingerprint comparison and candidate graph validation must consume the same logical row set;
- postconditions must execute before commit.

### Required concurrency regression

Introduce a deterministic seam/test proving this scenario fails closed:

```text
review graph A
   ↓
concurrent graph becomes B
   ↓
adoption starts/commits
```

The adoption must either:

- observe B consistently and reject as stale/incompatible; or
- serialize such that the transaction consistently owns the valid snapshot.

It must never fingerprint B while validating candidate compatibility against A.

### Acceptance

P6 commit-time safety must have a single durable transaction truth.

---

## P6 same-edition behavior

The existing P6 contract requires adoption to the already-bound exact edition to be a deterministic no-op only when current ports/provenance already satisfy candidate postconditions.

Round-2 must explicitly test:

- same exact edition + exact correct aggregate => deterministic zero-write/no-op result;
- same exact edition + drifted port provenance => not silently accepted;
- different candidate edition imported later cannot affect an already reviewed exact-edition command.

---

## P6 dependency matrix

Adoption must fail closed when migration would invalidate active:

- port connection;
- internal mapping;
- topology group endpoint;
- assembly/member relation when the current model can reference the affected engineering identity.

No dependency may be silently deleted.

---

# 11. R2.7 — P7 re-acceptance matrix

After all Round-2 fixes, repeat the four-discipline acceptance from a fresh database lifecycle.

Required matrix:

| Discipline | Canonical profile | Placement | Binding | Ports | P5 impact | P6 adoption | Restart provenance |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CCTV | CAMERA | PASS | PASS | ETH | PASS | PASS | PASS |
| LAN | OUTLET | PASS | PASS | ETH | PASS | PASS | PASS |
| ACS | READER | PASS | PASS | BUS | PASS | PASS | PASS |
| FIRE | DETECTOR | PASS | PASS | IN + OUT | PASS | PASS | PASS |

### Restart requirements

The test must close and reopen persistence, then prove:

- exact catalog id/version/profile preserved;
- frozen profile/constraints preserved;
- exact port ids preserved where migration policy requires preservation;
- exact template/interface/protocol provenance preserved;
- placement/adoption ledger replay remains idempotent;
- no duplicate component, membership, binding, port or operation row appears;
- later imported catalog edition is not silently substituted.

---

# 12. Open audit targets that must be classified

Round-2 is not complete until each target below is either:

```text
CONFIRMED finding + remediation
```

or:

```text
REJECTED with code/schema/contract evidence
```

Targets:

1. catalog soft-delete visibility and immutable-edition lifecycle;
2. normalized catalog/interface/protocol identity symmetry;
3. P4/P6 concurrent same-operation behavior under SQLite transaction mode;
4. P4 history behavior after successful P6 adoption;
5. candidate/current catalog payload-vs-row provenance integrity;
6. P5 affected-set completeness for assemblies;
7. remote endpoint changes with stable connection identity;
8. P6 same-edition no-op semantics;
9. stale/unresolved P5/P6 UI presentation;
10. restart test independence from same-process executor/cache state;
11. generated-source policy and CI guard authenticity.

No open target may simply disappear from the final audit report.

---

# 13. Test policy

For every confirmed finding:

```text
red regression
   ↓
fix
   ↓
targeted green
   ↓
full mobile/core green
```

Tests must prefer durable SQLite behavior over mocks for transaction, restart, idempotency and graph-migration defects.

Concurrency tests must have deterministic synchronization seams. Timing/sleep-based race tests are insufficient evidence.

---

# 14. Database and migration policy

Round-2 should avoid schema changes unless a confirmed defect requires one.

Current ELV2 schema baseline remains:

```text
schemaVersion = 17
```

If remediation requires schema 18:

- the need must be justified by a confirmed finding;
- migration from 17 must be tested;
- restart acceptance must run through migrated persistence;
- no unrelated schema refactor may be bundled into the remediation.

---

# 15. CI / exact-SHA gate

Round-2 acceptance requires one final branch head SHA where both normal workflows run against the exact same commit.

Required checks:

```text
Drift generation              PASS
repository hygiene guard      PASS

Mobile:
  formatting                  PASS
  analyze                     PASS
  full tests                  PASS

Engineering Core:
  formatting                  PASS
  analyze                     PASS
  full tests                  PASS
```

Required evidence recorded in the final audit:

```text
final SHA
push run id
PR run id
mobile test count
core test count
confirmed findings closed
open targets classified
schema version
```

No repository commit may be added after that exact closure gate without invalidating the recorded evidence.

---

# 16. Merge decision

Round-2 result has only three allowed outcomes:

### GREEN — ACCEPTED

- zero open BLOCKER/HIGH findings;
- all MEDIUM findings fixed or explicitly accepted with documented bounded risk;
- every open review target classified;
- four-discipline restart matrix green;
- exact-SHA push + PR CI green.

### AMBER — NOT MERGE-READY

- no BLOCKER, but one or more HIGH findings/open material targets remain;
- implementation may continue only on remediation branch;
- ELV3 remains blocked.

### RED — REJECTED

- any BLOCKER remains;
- persisted identity, atomicity, provenance or graph safety cannot be guaranteed.

---

# 17. Definition of Done

Round-2 remediation is complete only when all items below are true:

- [ ] R2-001 build/toolchain artifacts removed and guarded by CI;
- [ ] R2-002 canonical code identity unified and collision regressions green;
- [ ] R2-003 P6 validation moved to one transaction-owned graph snapshot;
- [ ] R2-004 ambiguous normalized explicit mappings reject fail-closed;
- [ ] R2-005 internal mappings visible in P5 impact API;
- [ ] P2 adversarial matrix green;
- [ ] P3 stale selection boundary green;
- [ ] P4 concurrency/history/restart targets classified and green;
- [ ] P5 assembly/remote endpoint completeness targets classified;
- [ ] P6 same-edition and concurrency semantics proven;
- [ ] CCTV/LAN/ACS/FIRE fresh restart matrix green;
- [ ] no silent latest adoption;
- [ ] no ELV3 leakage;
- [ ] all audit targets classified;
- [ ] final schema version recorded;
- [ ] full exact-SHA push workflow green;
- [ ] full exact-SHA PR workflow green;
- [ ] final Round-2 audit verdict = GREEN.

Only after this Definition of Done may ELV2 be accepted for merge and ELV3 planning resume.
