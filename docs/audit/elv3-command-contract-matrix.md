# ELV3 command contract matrix

Status: LIVE P9 AUDIT MATRIX / P7-P9 FOUNDATION UPDATED / NOT FINAL CLOSURE  
Branch: `feat/flutter-elv3-physical-routing-design`

`implemented` means a production persistence path exists. `foundation` means executable orchestration/model/test scaffolding exists but the required canonical persistence path is not complete. `contract` means authoritative command semantics exist without the production persistence path.

| Phase | Command / capability | Required state / revision | Core write set | Idempotency | Rollback / undo class | Status |
|---|---|---|---|---|---|---|
| P1 | CreateCableCommand | project exists; exact definition ref | Cable + command ledger | replayable | atomic / irreversible create history | implemented |
| P1 | ChangeCableDefinitionRefCommand | ACTIVE Cable; expected revision; no selection history | Cable definition ref + revision + ledger | replayable | atomic / reversible before physical history | implemented |
| P1 | ArchiveCableCommand | ACTIVE Cable; expected revision; no blockers | Cable lifecycle + revision + ledger | replayable | atomic / history-forward | implemented |
| P2 | CreateCableAllocationDraftCommand | wired Connection + ACTIVE Cable | CableAllocation DRAFT + ledger | replayable | atomic / reversible while draft | implemented |
| P2 | ReserveCableResourcesCommand | DRAFT + expected revision | immutable selection + claims + state | replayable | exact rollback / committed selection evidence irreversible | implemented |
| P2 | ReplaceCableTerminationSetCommand | RESERVED/ACTIVE + expected revision | complete termination set + allocation revision | replayable | exact rollback / reversible with prior-set fingerprint | implemented |
| P2 | ActivateCableAllocationCommand | RESERVED + complete obligations | allocation ACTIVE | replayable | exact rollback / history-forward | implemented |
| P2 | ReleaseCableResourcesCommand | RESERVED/ACTIVE + run guard | delete claims + RELEASED | replayable | exact rollback / irreversible history | implemented |
| P2 | ArchiveCableAllocationCommand | DRAFT/RELEASED | ARCHIVED | replayable | atomic / irreversible history | implemented |
| P3 | BootstrapProjectDesignRevisionCommand | no WORKING | WORKING revision | replayable | atomic / irreversible history | contract |
| P3 | FreezeProjectDesignRevisionCommand | WORKING + expected revision | snapshot + FROZEN | replayable | exact rollback / irreversible history | contract |
| P3 | CreateNextWorkingDesignRevisionCommand | latest FROZEN, no WORKING | new WORKING + materialized fork | replayable | exact rollback / irreversible history | contract |
| P3 | Supersede/Archive revision | historical lifecycle guards | historical state | replayable | atomic / irreversible history | contract |
| P3 | CreateCanonicalCableRunCommand | WORKING; ACTIVE cable/allocation | run + traversal chain | replayable | atomic / reversible before downstream history | contract |
| P3 | RerouteCableRunCommand | WORKING ACTIVE run + expected revision | traversal replacement + run revision | replayable | exact rollback / reversible | contract |
| P3 | Supersede/Archive CableRun | run lifecycle guards | run lifecycle | replayable | atomic / history-forward | contract |
| P3 | EditReusableRouteGeometryCommand | route revision + impact fingerprint | shared route graph + invalidation | replayable | exact rollback / conditionally reversible | contract |
| P3 | AdoptLegacyElectricalRouteCommand | explicit evidence | adoption + canonical identities | replayable | exact rollback / irreversible history | contract |
| P4 | Create/Update/Archive PathwayContext | WORKING + dependency guards | context facts/lifecycle | replayable | atomic or impact-aware inverse | contract |
| P4 | Create/Update/Archive PhysicalCarrier | WORKING + dependency guards | carrier facts/lifecycle | replayable | atomic or impact-aware inverse | contract |
| P4 | Create/Update/Archive CarrierCompartment | active carrier + dependencies | compartment facts/lifecycle | replayable | atomic or impact-aware inverse | contract |
| P4 | AttachTraversalToCarrierCommand | WORKING run + expected revision | traversal carrier refs + run revision | replayable | exact rollback / reversible | contract |
| P4 | DetachTraversalFromCarrierCommand | WORKING run + expected revision | clear carrier refs + run revision | replayable | exact rollback / reversible | contract |
| P5 | CreatePhysicalCompatibilityProfileSetCommand | WORKING | exact profile set refs | replayable | atomic / history-forward | contract |
| P5 | ReplaceActivePhysicalCompatibilityProfileSetCommand | WORKING + exact refs | archive old + activate new + invalidate | replayable | exact rollback / history-forward | contract |
| P5 | ArchivePhysicalCompatibilityProfileSetCommand | expected revision | ARCHIVED set | replayable | atomic / history-forward | contract |
| P6 | PersistRouteSeparationEvidenceCommand | WORKING + subject revisions | separation evidence + invalidation | replayable | exact rollback / reversible while WORKING | contract |
| P7 | workspace execute | WORKING + command authorization | delegates only to owning P1-P6 service | inherits underlying command | inherits underlying command | foundation |
| P7 | workspace stage/query | current design context + selection evidence | none | n/a | n/a | foundation |
| P7 | undo | top record reversible + precondition fingerprint | inverse domain command + history state | deterministic | exact rollback | foundation contract; persistence open |
| P7 | redo | top record UNDONE + precondition fingerprint | forward domain command + history state | deterministic | exact rollback | foundation contract; persistence open |
| P8 | failure probe execution | stable configured point | probe performs no business write | n/a | surrounding command transaction rolls back | foundation |
| P8 | vertical replay | deterministic fixture + persisted commandId | no duplicate canonical rows | mandatory | exact restart equivalence | fixture foundation; DB proof open |
| P9 | architecture guard | repository source tree | none | n/a | fail-fast CI | implemented |

## P7 foundation invariants

- workspace exposes all seven stages;
- presentation does not infer editability independently;
- command execution re-authorizes instead of trusting `canEdit`;
- widgets never multi-write canonical tables;
- reversible history persists forward hash, inverse payload and precondition fingerprint;
- irreversible history is not surfaced as normal Undo;
- history transition and inverse/forward command share one transaction.

## P8 promotion invariants

Fixture-contract coverage is not runtime closure. A vertical becomes `implemented` only when it uses the real P3-P6 Drift repositories, closes/reopens the DB and compares canonical identities/hashes.

## P9 failure rules

P9 fails when:

- a public P1-P8 mutation is absent from this matrix;
- widgets perform canonical multi-table writes;
- expected-revision/lifecycle guards are bypassed;
- an idempotent command writes canonical rows without its ledger record in the same transaction;
- reversible history lacks prior-state/precondition evidence;
- irreversible history is exposed as normal Undo;
- failure injection leaves partial canonical rows after reopen;
- fixture-contract tests are reported as restart proof;
- P3-P6 persistence is missing while runtime closure is claimed.

Before final P9 closure every `contract`/`foundation` row must be replaced by concrete implementation + test files, stable error codes and dependency keys.
