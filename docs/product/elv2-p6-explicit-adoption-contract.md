# Electra — ELV2-P6 Explicit Catalog Adoption Contract

Status: implementation contract  
Branch: `feat/flutter-elv2-profile-constraints`  
Predecessor: ELV2-P5 exact gate `c964be40b25fa2fa7d0f3657508d0f05ae9e88ce`

## 1. Purpose

P6 is the only ELV2 phase allowed to mutate an existing frozen `ComponentReferenceBinding` from one immutable catalog edition to another.

P6 is not "select latest". Adoption is an explicit engineering operation bound to:

```text
projectId
componentId
current binding catalog/profile
candidate catalog/profile
reviewed P5 impact
explicit port migration plan
operation identity / audit evidence
```

## 2. Required preconditions

Before any write, P6 must re-read current durable state and verify:

1. the project/component/binding is still active;
2. current binding id/version/profile still equals the reviewed P5 baseline;
3. candidate catalog id/version/profile exists exactly and is publication-valid;
4. candidate profile is not removed/deprecated;
5. system membership and discipline invariants still hold;
6. P2 revalidation against current durable placement evidence is `COMPATIBLE`;
7. affected connections/topology groups have not changed since review;
8. the explicit port migration plan covers every currently bound port and every candidate template exactly once.

Any stale review causes a fail-closed conflict and zero mutation.

## 3. Port identity policy

Port identity is a persisted engineering graph identity, not a disposable row id.

### 3.1 Automatic identity preservation

P6 may preserve an existing port id automatically only when the normalized candidate template code equals the normalized frozen old template code.

Template reorder alone must therefore preserve the same port identities.

### 3.2 New template

A candidate template code absent from the current binding receives a new id inside the adoption transaction.

### 3.3 Removed template

An old template code absent from the candidate must be explicitly retired.

Retirement is forbidden while the port participates in any active:

- `EngineeringConnection`;
- internal mapping;
- topology-group endpoint;
- engineering assembly/member relation that owns or references the port.

No dependency is silently deleted by catalog adoption.

### 3.4 Renamed/replaced template

A rename is not inferred. `OLD_CODE -> NEW_CODE` requires an explicit engineer-authored mapping.

The mapping may preserve the old port id only after the candidate port is proven compatible with every live dependency of the old port. Otherwise adoption is blocked until dependencies are resolved or remapped explicitly.

## 4. Connected-port compatibility

For each reused port with live connections, P6 must validate the candidate port against each persisted remote endpoint using the exact persisted connection profile / pinned interface-protocol provenance.

Changing any of these is connection-relevant:

```text
kind
direction/capacity
connector
protocol edition
interface edition
voltage domain
power direction/limits
```

P5 tells the engineer what is affected. P6 must independently revalidate current durable graph state immediately before mutation.

## 5. Adoption transaction

One top-level Drift transaction owns the entire adoption aggregate:

```text
review + fingerprint check
        ↓
re-read exact binding/catalog/profile/graph
        ↓
P2 + connection/dependency revalidation
        ↓
BEGIN TRANSACTION
        ↓
preserve/update reusable port rows
        ↓
insert new port rows
        ↓
retire explicitly removable port rows
        ↓
replace frozen ComponentReferenceBinding snapshot
        ↓
validate aggregate postconditions
        ↓
record adoption operation/audit result
        ↓
COMMIT
```

Any error rolls back every port/binding/audit change.

## 6. Binding postconditions

After adoption:

- `catalogId`, `catalogVersion`, `profileCode`, and frozen `profile` equal the exact candidate edition;
- `portIds` equal the complete active candidate-derived port set;
- preserved ports keep their original ids;
- new ports have unique generated ids;
- retired old ports are absent from the active binding;
- every active bound port has candidate template provenance and exact candidate interface provenance;
- reviewed placement evidence is retained only after current P2 revalidation succeeds;
- no active connection references a retired port;
- no duplicate active port code exists for the component.

## 7. Idempotency and stale review

Adoption requires an operation id and deterministic command fingerprint.

- completed same-fingerprint retry returns the stored result without writes;
- same operation id with changed semantics is a conflict;
- changed current binding/graph since review is a stale-review conflict;
- adoption to the already-bound exact edition is a deterministic no-op only when the port set/provenance already satisfies candidate postconditions.

## 8. Rollback / failure injection

Tests must inject failures at minimum:

```text
after review check
after first preserved port update
after new port insert
after old port retirement
after binding replacement
before operation completion
before commit
```

Every failure must prove full aggregate equality with pre-adoption state.

## 9. Acceptance cases

P6 cannot be complete until tests prove:

1. port-template reorder preserves exact ids;
2. same-code metadata/provenance update preserves id when live graph remains compatible;
3. additive candidate creates only the new port and preserves existing ids;
4. removable unconnected old port retires atomically;
5. removed connected port blocks with zero mutation;
6. rename without explicit mapping blocks;
7. explicit rename mapping can preserve identity only when all live dependencies remain valid;
8. incompatible connector/protocol/interface/voltage change blocks connected reuse;
9. stale P5 review / changed binding / changed connection graph blocks;
10. deprecated/invalid/removed candidate blocks;
11. same-operation replay is idempotent;
12. injected failure rolls back binding + all ports + audit operation;
13. SQLite reopen restores exact adopted binding/ports and replay remains zero-write;
14. CCTV/LAN/ACS/FIRE all use the same discipline-agnostic adoption path.

## 10. Scope guard

P6 may update ELV1 port/binding provenance and validate existing ELV1 connections. It must not introduce cable routes, pathways, CableRun migration or ELV3 physical routing behavior.
