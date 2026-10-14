# ELV3 command contract matrix

Status: LIVE P9 AUDIT MATRIX / NOT FINAL CLOSURE  
Branch: `feat/flutter-elv3-physical-routing-design`

This matrix tracks public mutation commands from P1-P8. `Implementation` is deliberately explicit: `implemented` means production code exists; `contract` means the authoritative command contract exists but the production persistence path is not complete yet.

| Phase | Command | Required state / revision | Core write set | Idempotency | Rollback / undo class | Implementation |
|---|---|---|---|---|---|---|
| P1 | CreateCableCommand | project exists; exact definition ref | Cable + command ledger | replayable | atomic / irreversible create history | implemented |
| P1 | ChangeCableDefinitionRefCommand | ACTIVE Cable; expected revision; no selection history | Cable definition ref + revision + ledger | replayable | atomic / reversible before physical history | implemented |
| P1 | ArchiveCableCommand | ACTIVE Cable; expected revision; no blockers | Cable lifecycle + revision + ledger | replayable | atomic / history-forward | implemented |
| P2 | CreateCableAllocationDraftCommand | wired Connection + ACTIVE Cable | CableAllocation DRAFT + ledger | replayable | atomic / reversible while draft | implemented |
| P2 | ReserveCableResourcesCommand | DRAFT + expected revision | immutable selection evidence + atomic claims + state | replayable | exact rollback / irreversible selection evidence once committed | implemented |
| P2 | ReplaceCableTerminationSetCommand | RESERVED/ACTIVE + expected revision | complete termination set + allocation revision | replayable | exact rollback / reversible with prior-set fingerprint | implemented |
| P2 | ActivateCableAllocationCommand | RESERVED + complete obligations | allocation state ACTIVE | replayable | exact rollback / history-forward | implemented |
| P2 | ReleaseCableResourcesCommand | RESERVED/ACTIVE + expected revision; run guard | delete claims + RELEASED state | replayable | exact rollback / irreversible history | implemented |
| P2 | ArchiveCableAllocationCommand | DRAFT/RELEASED + expected revision | ARCHIVED state | replayable | exact rollback / irreversible history | implemented |
| P3 | BootstrapProjectDesignRevisionCommand | no WORKING revision | ProjectDesignRevision WORKING | replayable | atomic / irreversible history | contract |
| P3 | FreezeProjectDesignRevisionCommand | WORKING + expected revision | immutable snapshot + FROZEN transition | replayable | exact rollback / irreversible history | contract |
| P3 | CreateNextWorkingDesignRevisionCommand | latest FROZEN, no WORKING | new WORKING revision + materialized run fork | replayable | exact rollback / irreversible history | contract |
| P3 | SupersedeProjectDesignRevisionCommand | FROZEN + expected revision | SUPERSEDED transition | replayable | atomic / irreversible history | contract |
| P3 | ArchiveProjectDesignRevisionCommand | allowed historical state | ARCHIVED transition | replayable | atomic / irreversible history | contract |
| P3 | CreateCanonicalCableRunCommand | WORKING; ACTIVE Cable; consuming allocation | CanonicalCableRun + traversal chain | replayable | atomic / reversible before downstream history | contract |
| P3 | RerouteCableRunCommand | WORKING; ACTIVE run; expected revision | replace traversal chain + run revision | replayable | exact rollback / reversible | contract |
| P3 | SupersedeCableRunCommand | ACTIVE run + expected revision | SUPERSEDED state | replayable | atomic / history-forward | contract |
| P3 | ArchiveCableRunCommand | superseded/allowed state | ARCHIVED state | replayable | atomic / history-forward | contract |
| P3 | EditReusableRouteGeometryCommand | expected route revision + impact fingerprint | shared route graph + affected invalidation | replayable | exact rollback / reversible only if impact fingerprint matches | contract |
| P3 | AdoptLegacyElectricalRouteCommand | explicit evidence + idempotency key | adoption record + canonical physical identities | replayable | exact rollback / irreversible history | contract |
| P4 | CreatePathwayContextCommand | WORKING | PathwayContext | replayable | atomic / reversible if unused | contract |
| P4 | UpdatePathwayContextCommand | WORKING + expected revision + impact fingerprint | context facts + affected invalidation | replayable | exact rollback / reversible if impact set matches | contract |
| P4 | ArchivePathwayContextCommand | no active child/carrier dependencies | ARCHIVED state | replayable | atomic / history-forward | contract |
| P4 | CreatePhysicalCarrierCommand | WORKING + active context | PhysicalCarrier | replayable | atomic / reversible if unused | contract |
| P4 | UpdatePhysicalCarrierCommand | WORKING + expected revision + impact fingerprint | carrier facts + invalidation | replayable | exact rollback / reversible if impact set matches | contract |
| P4 | ArchivePhysicalCarrierCommand | no current WORKING traversal use | ARCHIVED state | replayable | atomic / history-forward | contract |
| P4 | CreateCarrierCompartmentCommand | active carrier | compartment | replayable | atomic / reversible if unused | contract |
| P4 | UpdateCarrierCompartmentCommand | expected revision + impact fingerprint | compartment facts + invalidation | replayable | exact rollback / reversible if impact set matches | contract |
| P4 | ArchiveCarrierCompartmentCommand | no current traversal use | ARCHIVED state | replayable | atomic / history-forward | contract |
| P4 | AttachTraversalToCarrierCommand | WORKING run + expected run revision | traversal carrier refs + run revision | replayable | exact rollback / reversible | contract |
| P4 | DetachTraversalFromCarrierCommand | WORKING run + expected run revision | clear carrier refs + run revision | replayable | exact rollback / reversible | contract |
| P5 | CreatePhysicalCompatibilityProfileSetCommand | WORKING revision | profile set + exact refs | replayable | atomic / history-forward | contract |
| P5 | ReplaceActivePhysicalCompatibilityProfileSetCommand | WORKING revision + exact refs | archive old set + activate new + invalidate P5/P6 | replayable | exact rollback / history-forward | contract |
| P5 | ArchivePhysicalCompatibilityProfileSetCommand | expected revision | ARCHIVED set | replayable | atomic / history-forward | contract |
| P6 | PersistRouteSeparationEvidenceCommand | WORKING revision + expected subject revisions | active separation evidence row + invalidation | replayable | exact rollback / reversible while WORKING | contract |
| P7 | workspace reversible commands | delegated to P1-P6 commands | no direct domain writes in widgets | inherits underlying command | logical inverse command | foundation |
| P7 | undo/redo | top history entry reversible + precondition fingerprint | inverse/forward command + history cursor | deterministic | exact rollback | foundation |
| P8 | failure probe execution | configured stable point | no business write by probe itself | n/a | command transaction must rollback | foundation |

## Audit rules

P9 fails when:

- a public P1-P8 mutation is absent from this matrix;
- widgets perform canonical multi-table writes directly;
- a command bypasses expected-revision or lifecycle guards defined by its phase;
- an idempotent command persists domain rows without its `CommandExecutionRecord` in the same transaction;
- a reversible command lacks persisted prior state/precondition evidence;
- an irreversible-history command is exposed as normal UI Undo;
- failure injection can leave partial canonical rows after reopen.

## Remaining matrix work

Before final P9 closure, replace every `contract`/`foundation` status with the actual implementation file and test file, and add stable error codes plus concrete dependency node keys for each command.
