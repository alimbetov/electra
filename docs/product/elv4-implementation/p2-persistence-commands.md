# P2 — Persistence, commands, history and frozen evidence

Status: IMPLEMENTATION DESIGN DRAFT
Consumes P1 types and P0 integration map. Supplies all runtime packages.
Shared rules: [runtime contracts](shared-contracts.md).
Resolved audit decisions: [RM01–RM15](remediation-contract.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P2-001 | Add scoped aspect/child tables, uniqueness, checks, foreign keys and indexes with additive migration | P2-T01 migration/scope constraints |
| ELV4-P2-002 | Implement transaction-bound power stores and integrate canonical port writers without independent commits | P2-T02 rollback all writes |
| ELV4-P2-003 | Implement every mutation family with replay-first ledger, aggregate CAS and complete receipts | P2-T03 replay/conflict/restart |
| ELV4-P2-004 | Advance coordinated design token and invalidate old/new dependency closures atomically | P2-T04 edit/freeze and invalidation |
| ELV4-P2-005 | Extend ProjectDerivedResults with explicit owner/kind isolation across existing consumers, immutable evaluation rows and guarded pointers | P2-T05 evaluation immutability/publication |
| ELV4-P2-006 | Add coordinated power companion snapshot and manifest; preserve old physical hashes | P2-T06 freeze/history/create-next |
| ELV4-P2-007 | Persist reversible history and validate ordinary inverse/forward commands atomically | P2-T07 undo/intervening edit |
| ELV4-P2-008 | Integrate adoption/deletion/membership guards and stable storage/error translation | P2-T08 canonical guard coverage |

## Proposed schema: scoped roots and children

Editable aspect roots use storage PK `(designRevisionId, id)`; projectId is explicit and checked against ProjectDesignRevisions. `id` is a stable logical ID across create-next, not an FK by itself. Common columns: projectId, designRevisionId, id, revision, createdAt, updatedAt, originDeviceId, deletedAt; typed bindings additionally store exact definition ref/hash. Where Drift cannot express composite FKs directly, use reviewed SQL constraints or transactional guards plus negative tests; never create an FK to the nonunique logical id alone.

| Root / child | Additional columns / constraints |
|---|---|
| PowerPortBindings | portId, resolvedProfileJson, profile schema/hash; unique active `(designRevisionId, portId)` |
| PowerComponentBindings | componentId, capability payload, definition ref; unique active revision/component |
| PowerTransferBindings / PowerTransferOutputs | componentId, inputPortId, kind, model ref; child outputPortId + ordinal, unique scoped transfer/output |
| PowerLoadBindings | inputPortId, stateCode, accountingKind, originId, typedDemandJson; unique active scoped input/state/kind/origin |
| PowerCapacityGroups / PowerCapacityGroupMembers | owner component, typed limits; member outputPortId unique within group |
| PowerSupplyRequirements / PowerSupplyRequirementInputs | consumer component, SINGLE/ALTERNATIVE policy; inputPortId members and allowed selections |
| PowerOperatingScenarios / PowerScenarioSegments | scenario role; child segmentId, ordinal, duration, unique ordinal and segmentId per scenario |
| PowerScenarioStates / PowerScenarioSourceSelections | scoped scenario/segment/component state; requirementId, selected source/transfer; exact scoped uniqueness |
| PowerScenarioUnavailableSources | segment/source identity, unique per segment/source |
| PoeDeliveryBindings / PoeDeliveryPathMembers | PSE/PD IDs, accounting mode, definition ref; ordered existing connection/allocation IDs, no cable ownership |
| BackupAssemblies / BackupProtectedOutputs | existing UPS/charger/bank refs, policy; protected output IDs unique within assembly |
| BatteryBankBindings | bankComponentId, unit ref, series/parallel counts > 0, typed usable model; unique active revision/bank component |
| DesignRevisionPowerSnapshots | PK designRevisionId, projectId, section schema, capture kind, canonical payload/hash and physicalHash |
| DesignRevisionSnapshotManifests | PK designRevisionId, projectId, manifest schema/hash, physicalHash, powerHash |

Profile/model JSON is schema-validated immutable content. FK-bearing project IDs, port IDs, member identities and revision references stay explicit columns/children. Scenario state enum codes and typed payloads are validated before writes. Active uniqueness uses partial indexes on deletedAt IS NULL where historical tombstones coexist.

Indexes: scoped bindings by port/component; transfers by input/output; membership reverse lookups; scenario rows by scenario/segment; delivery path by connection/allocation; protected-output lookup; dependency/current-pointer lookup by project and key. Benchmark plans before adding broad redundant indexes.

## Command schemas and handler steps

Proposed command schema names: `electra.command.elv4.<operation>.v1`; operation is a fixed registered name, not arbitrary user text. Families are bind/adopt/release-power-profile, set-power-load-profile, replace-power-transfers, replace-power-capacity-group, replace-power-supply-requirement, create/replace/archive-power-scenario, bind/replace-poe-delivery, configure-backup-assembly, replace-battery-bank and calculate-power-process. Freeze/create-next new requests use explicit v2 schemas, with actual version passed to ledger writer; old replay decoding must remain available.

Set replacement payloads include complete new members and expected old aggregate revision. An empty set is explicit and allowed only when referential dependencies permit draft incompleteness. Old child deletions and new insertions share the same transaction. Replacement does not change stable aggregate ID.

Handler steps: validate envelope syntax → begin transaction → ledger exact replay/conflict → reload revision/scope/expected rows → resolve immutable refs and reviewed preview → capture old dependencies/inverse → apply all root/child/projection changes → validate new invariants → CAS design token → invalidate union → history transition → record receipt → commit. A failure after any write throws through the transaction rollback; do not catch and return a failure inside the transaction after partial writes without rollback.

### BindPowerProfile payload

Contains componentId, definitionRef, bindingId, explicit map `templatePortCode -> existingPortId` and an explicit list of missing template ports to create. Existing port mapping must match ownership/type and existing connected uses. New port IDs are generated once before first execution and included in canonical payload, so retry never creates different ports. No template-to-label search. New ports and aspects roll back together.

### Supply requirements and explicit empty initialization

ReplacePowerSupplyRequirement replaces the owned consumer input set and SINGLE/ALTERNATIVE selection policy with exact scoped input IDs, expected requirement revision and reviewed impact. It never creates external connections. Scenario source selections must reference an existing requirement and permitted selected source; replacing a requirement rejects dangling selections or replaces them in the same reviewed aggregate command. This command applies to normal consumers as well as backup assemblies.

New freeze command version explicitly selects `powerSectionIntent = CAPTURE_CURRENT` or `CAPTURE_EMPTY`. CAPTURE_EMPTY is accepted only with an empty active power aspect set; CAPTURE_CURRENT captures all active aspects and unresolved findings. No omission silently chooses a power initialization mode. Old command versions remain replayable using their old payload/result codec. Create-next from a pre-power revision requires explicit `initializePowerAsEmpty`; otherwise return NOT_CAPTURED guidance. These intents avoid an additional independent power revision lifecycle.

### Impact and deletion policy

Archive/delete of a referenced source, port, profile or bank is rejected with typed dependencyImpact and concrete references unless the public command explicitly performs a reviewed supported detach/replacement. Draft disconnection may leave unresolved requirements but must invalidate old paths; it cannot erase the requirement and turn a missing load into a passing design. Catalog adoption previews include all systems sharing the component.

## Result storage and pointer transitions

Follow RM01 owner/kind isolation and RM04 mandatory SEGMENT/SEQUENCE same-table keys. Legacy consumers filter LEGACY/NODE before decode, retirement and manual writes; new power consumers filter ELV4/kind. Evaluation rows use immutable insert; pointer rows use CAS generation and supported state transitions: ABSENT → CURRENT; CURRENT → STALE after input mutation; STALE → CURRENT only after successful guarded publish. Execution failure records evidence where requested but cannot advance a passing pointer. A complete failed-capacity evaluation may be CURRENT.

`dependenciesJson` contains full sorted typed keys including absent dependencies. Existing ELV3 rows remain decodable. Do not route evaluation rows through existing blanket `invalidate` logic. Frozen snapshots embed selected pointer/evaluation content or immutable verifiable references captured in the same transaction. References must remain resolvable after archive and cleanup; no GC of referenced frozen/replay evidence.

## Freeze and create-next

Freeze uses RM14 nonblocking capture of committed facts/evidence, checks WORKING and exact token, captures current physical v1 snapshot plus complete power section, writes companion/manifest, transitions FROZEN and records replay receipt. Existing physical snapshotHash semantics remain unchanged. Any later read uses verified hashes; mismatch is integrity failure, not fallback to WORKING.

Create-next accepts a verified FROZEN base, requires no active WORKING and allocates max(project.sequence)+1 through RM10 project allocator CAS, independently of base.sequence. Materialize using RM07 identity-class mapping, including every run/traversal/operational physical ref. Keep logical power IDs in new scope and exact project-stable identities; require reviewed canonicalRestorePlan if current canonical state differs from the selected base. Unknown/unmapped refs reject the whole transaction. R1 pointers are not editable in R2. Inherited evidence remains provenance, with new current pointers STALE/absent until validated under R2 input. Pre-power source revision creates an explicitly audited empty draft only when selected by command; no silent inferred power model.

## Failure probes and history

Required probes: aspect insert; canonical port insert/projection update; old set delete; first new member; scenario selections; PoE bind; bank write; invalidation; history update; physical snapshot; power snapshot; manifest; revision CAS; before ledger commit. Register constants in existing ElvFailurePoints and exercise every affected handler boundary.

Undo/redo persists revision-scoped canonical forward AND inverse command payloads, schemas/hashes, aggregate evidence, affected IDs and cursor generation in the RM08 tables; hashes alone cannot reconstruct redo. New ordinary edit invalidates the redo suffix according to existing history policy. Irreversible freeze/archive/adoption follows reviewed existing policy; never pretend an edition adoption can be undone by replacing catalog bytes.

Exit: all mutation families survive close/reopen, replay, rollback and cross-scope rejection before graph/UI acceptance depends on them.

## Additional mandatory schema/writer integration

Add RM01 resultOwner/recordKind and filtered indexes; RM08 CommandHistoryOperations/CommandHistoryCursors; RM10 DesignRevisionSequenceAllocators. PowerCanonicalProjectionWriteStore (RM03) validates the full connected candidate graph and shared field owners in the same UoW. Generic catalog import materializes exact compatibility editions and declared memberships through existing transaction-bound writers (RM05).

New-wire schemas and command-specific payloads are under [schemas](schemas/power-command.schema.json). Freeze/create-next v2 retain historical v1 replay decoding; no v1 request silently acquires a v2 power intent. Frozen hashes are recomputed from actual canonical payload before materialization/read. Failure probes include foreign-owner retirement protection, mapped physical refs, history forward payload insert and sequence allocator CAS.
