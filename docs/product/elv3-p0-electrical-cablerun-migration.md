# Electra — ELV3 P0.6 Electrical Routing Coexistence and Adoption Contract

Status: REMEDIATED DESIGN CONTRACT / P0-R8  
Branch: `feat/flutter-elv3-physical-routing-design`  
Authoritative parent: `docs/product/elv3-p0-system-architecture-remediation.md`  
Implementation status: HOLD UNTIL P0-R10

## 1. Purpose

This document replaces the first P0.6 migration model that assumed legacy electrical `CableRun.circuitId` could be deterministically migrated to a canonical physical `Cable`.

That assumption is unsafe because a legacy electrical circuit-routing record does not prove the existence, count, construction or termination identity of one physical cable.

## 2. Core decision

Legacy electrical routing remains valid through a compatibility layer until explicit physical-cable adoption is performed.

Canonical rule:

```text
legacy ElectricalCircuit routing
  != proven physical Cable identity
```

ELV3 MUST NOT invent Cable records merely because a legacy `CableRun` references `ElectricalCircuit`.

## 3. Coexistence model

During ELV3 rollout:

```text
COMMON ROUTING/GEOMETRY FOUNDATION
        |
        +-- legacy electrical routing adapter
        |      `CableRun.circuitId` semantics preserved
        |
        +-- canonical ELV3 physical realization
               Cable -> CableRun -> CableTraversal[]
```

The common geometry kernel may be reused by both paths while their ownership semantics remain distinct until adoption/migration is proven safe.

## 4. Why automatic backfill is prohibited

A legacy `ElectricalCircuit` may represent cases such as:

- a single multicore cable;
- separate L/N/PE conductors;
- parallel cables;
- cable plus protective conductor;
- route-only design without exact cable specification;
- preliminary circuit geometry with no installation identity.

Therefore this transformation is forbidden without evidence:

```text
ElectricalCircuit -> create Cable -> replace circuitId with cableId
```

## 5. Explicit adoption

Canonical command:

```text
AdoptLegacyElectricalRoute
```

Adoption requires:

1. explicit engineer/system migration action;
2. resolved physical cable definition/binding;
3. sufficient evidence for physical cable count and identity;
4. deterministic route/traversal mapping;
5. project and design-revision context;
6. audit/provenance of source legacy records.

If any required physical fact is unknown:

```text
ADOPTION_REVIEW_REQUIRED
```

No guessed Cable is created.

## 6. Adoption outcomes

### Resolved single physical cable

```text
legacy circuit route evidence
  -> Cable C-001
  -> CableRun CR-001
  -> traversal chain referencing reused geometry
```

### Multiple physical cables proven

Create separate canonical Cable identities and runs only when source evidence proves multiplicity and their assignments.

### Ambiguous evidence

Retain legacy route unchanged and surface migration/adoption review state.

## 7. Legacy adapter responsibilities

The compatibility adapter may expose legacy routing to shared UI/trace infrastructure but MUST preserve its provenance as legacy electrical semantics.

It must not pretend that:

- `circuitId` is `cableId`;
- same circuit means same physical cable;
- floor handoff proves cable continuity;
- electrical route length automatically equals one installed cable length.

## 8. Junction and floor graph migration

Current junction/floor code uses `run.circuitId` as a continuity/fingerprint input.

During coexistence:

```text
legacy electrical path
  -> legacy circuit-aware fingerprint/validation adapter

canonical CableRun
  -> cable/run/traversal-aware physical fingerprint
```

Do not globally replace `circuitId` with `cableId` until the canonical path owns those records.

## 9. Persistence direction

Do not require every existing `CableRuns` row to gain a synthetic `cable_id`.

Implementation options may include:

- separate canonical ELV3 CableRun storage;
- discriminated legacy/canonical routing records with strong typed constraints;
- staged schema where `cable_id` is nullable and canonical records are distinguishable from legacy records.

The final implementation must avoid weak generic `ownerType/ownerId` semantics if referential integrity can be modeled explicitly.

## 10. Migration/adoption mapping

When adoption occurs, persist explicit mapping/evidence:

```text
LegacyRouteAdoption {
  legacyRunId
  legacyCircuitId
  cableId
  canonicalCableRunId
  designRevisionId
  sourceEvidenceRef?
  adoptedAt
  adoptedBy
  status
}
```

This mapping supports restart, audit and idempotent rerun.

## 11. Idempotency

Replaying adoption for the same accepted mapping must return/reuse the already-created canonical identities rather than create duplicates.

Ambiguous/rejected adoption must remain unresolved without partial canonical rows.

## 12. Electrical future direction

The long-term architecture may converge electrical and ELV onto the same canonical Cable/CableRun model, but that is a separate vertical migration decision.

ELV3 does not require full electrical-domain conversion before ELV cable functionality can ship.

This limits blast radius and preserves the accepted electrical baseline.

## 13. Regression requirements

Before any adoption implementation closes:

- all existing electrical routing tests stay green;
- legacy circuit routes render/trace as before;
- no fake Cable is created for untouched legacy records;
- adoption of a proven cable is deterministic after restart;
- ambiguous adoption produces review state;
- rollback leaves legacy routing unchanged;
- canonical ELV fixtures never require fake circuit IDs.

## 14. P0-R8 acceptance

- [x] automatic `circuitId -> cableId` backfill is rejected.
- [x] legacy electrical routing remains supported through coexistence/adapter semantics.
- [x] explicit adoption requires physical evidence.
- [x] ambiguous cases remain review-required.
- [x] migration is idempotent and auditable.
- [x] ELV3 no longer requires simultaneous full electrical routing reform.

P0-R8 is CLOSED subject to P0-R10.