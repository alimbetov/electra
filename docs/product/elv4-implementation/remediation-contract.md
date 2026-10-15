# ELV4 — Resolved implementation contracts (audit remediation)

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Date: 2026-10-15. Resolves findings ELV4-AUD-01…15 from the [audit](../../audit/elv4-technical-audit/report.md).
Parent: [implementation index](README.md). The corresponding governing/shared/package statements are updated with these decisions; this document does not authorize bypassing ELV1–ELV3 invariants.

## RM01 — Storage ownership and existing consumers

ProjectDerivedResults gains explicit `resultOwner` (LEGACY, ELV3, ELV4, UNCLASSIFIED) and `recordKind` (NODE, POINTER, EVALUATION). Add index `(projectId,resultOwner,recordKind,nodeKey)`. Existing PK projectId/nodeKey remains. Migration classifies existing rows using the existing registered node-key encoders: known ELV3 keys -> ELV3/NODE, known legacy nodes -> LEGACY/NODE. Unknown existing keys are preserved as UNCLASSIFIED/NODE, cause a reported migration reconciliation item and remain outside every automatic decode/recalculation/retirement path; they are not guessed to be legacy. Do not classify by substring inside user IDs.

All current readers/writers must include ownership: DriftDependencyRecalculationRepository.load/decode/recalculate/removedKeys/retired/manual operate only on LEGACY/NODE; DriftElvPhysicalCalculationResultStore only ELV3/NODE; new power adapter only ELV4/POINTER or ELV4/EVALUATION as explicitly requested. Decode state only after owner/kind filtering. SQL pointer states are `CURRENT`/`STALE`; immutable ELV4 evaluation rows use SQL state `CAPTURED` with completion/assessment/execution inside their typed payload. Legacy and ELV3 state codecs remain unchanged.

Immutable EVALUATION rows cannot be updated/tombstoned by recalculation/manual/invalidation paths. POINTER generation uses existing revision column and CAS. Cleanup is prohibited for evidence referenced by a frozen manifest, replay receipt or history. Mixed-owner regression is a P2 gate, not deferred UI work.

Proof RM01-T: populate all owners/kinds, run old load/recalculate/manual/retirement, new invalidation and reopen; assert byte-identical foreign evaluation rows and no cross-owner decoder calls.

## RM02 — Explicit zero without invalid canonical projection

ELV4 state demand permits exact zero, stored solely in PowerLoadBindings. Unknown demand is a missing binding/input marker, never zero. Canonical EngineeringPort.powerDemandW and powerLimitW retain their existing null-or-positive validation. Do not project a scenario's zero into either field and do not relax the shared validator as an incidental ELV4 change.

A new power binding may populate an explicit positive static `nameplateDemandW`/`nameplateLimitW` supplied by its definition; absent static nameplate remains null. A zero-capacity operational availability is a scenario fact, not a zero canonical nameplate. Numerical zero therefore remains distinguishable from unknown without invalidating existing port graphs.

Proof RM02-T: bind static nameplate 10W, STANDBY=0W and ALARM=8W; reopen and verify canonical 10W unchanged, two exact state demands, and a separately missing state is unresolved.

## RM03 — Static/scenario separation and guarded projection writer

Static canonical projection is exactly: connector/protocol/interface/template provenance, physical port kind/capacity, fixed physical direction, union electrical envelope applicable across declared supported modes, optional positive nameplate values. Direction-reversing feeds use canonical bidirectional interfaces/powerDirection at both ends and an explicit bidirectional compatibility edition. Scenario resolution selects active power direction/source without rewriting these fields. Profiles whose union envelope cannot satisfy existing canonical compatibility require explicit port/interface redesign, not a silent weakening of checks.

Existing ELV2-owned values remain pinned. A power definition may share a field only when its resolved static value and exact ownership agreement match; otherwise reviewed adoption/rebinding must resolve conflict before commit. Static nameplate power comparison remains a canonical guard; scenario demand does not create permission to violate a rejected static connection.

Implement `PowerCanonicalProjectionWriteStore.applyReviewedProjection` inside the shared DB transaction. It verifies bound owner/provenance, old row revisions, full reviewed impact, template-to-port map, and revalidates every existing connection/internal mapping/group with candidate static values. It may update a connected port only after this validation; raw savePort remains protected. A power binding cannot call an ordinary savePort that rejects connected/bound edits and then bypass it with unchecked SQL. Typed exact static/rating checks run before legacy double projections; a lossy canonical display/index field never weakens the exact definition constraint. Domain failures roll back all changes.

Queries/scenario switches perform no writes. Demand/selected-source evaluation reads power state bindings exclusively; nameplate projection is not a fallback for a missing required state unless an explicit load profile adopts that value.

Proof RM03-T: alternate scenarios/segments without row/payload/provenance changes; reviewed compatible connected adoption succeeds atomically, incompatible/shared-owner adoption rejects with unchanged DB.

## RM04 — Segment and sequence identities

Logical pointer key v2 is canonical tuple `["elv4-node-v2", revisionId, scenarioId, scopeKind, scopeId, processCode, subjectKind, subjectId]` within project scope. `scopeKind=SEGMENT` requires exact segmentId as scopeId. PWR-01/02/03/05/06 are SEGMENT results. `scopeKind=SEQUENCE` uses scenarioId as scopeId for PWR-04's complete ordered segment sequence. No empty or optional segment identity exists in a numerical request.

Immutable evidence key is `["elv4-evaluation-v2", logicalKey, evaluationId]`. Sequence inputs include each consumed segment result logicalKey, evaluationId, fingerprint and ordered duration. Batch publication CAS-checks the entire consumed pointer generation set; a sequence cannot combine evaluations from incompatible captures. Scenario editing changes the SEQUENCE membership/duration dependency and affected segment keys.

Read workspace may omit segmentId to display the scenario summary, but must return a keyed segment collection; it must not select a last-published segment implicitly. Snapshot serializes explicit keys/scopes and all selected evidence.

Proof RM04-T: publish standby/alarm in reverse order, retrieve both by key, publish sequence energy, restart/freeze, assert no collision and coherent sequence refs.

## RM05 — Complete generic catalog-to-connection bridge

The [wire schema](schemas/power-catalog.schema.json) defines the first strict power-only catalog form: `electra.elv4-power-catalog.v1`. It is decoded into the existing immutable root catalog storage with a typed power extension; no second catalog repository or discipline is created. Existing schema-less catalogs keep their old decoder/canonical bytes. The root publication validator accepts a nonempty valid power extension even when old profiles/cableDefinitions are absent.

Generic definition contains complete canonical port template fields: code, kind, direction, capacity, connector, exact protocol ref, exact interface ref, powerDirection, static voltage envelope, optional positive nameplate demand/limit. The extension declares connector/protocol/interface definitions and ordered compatibility definitions with allowed family codes, media, layer and exact refs. Import validates all references and materializes existing compatibility-profile rows in the same catalog-import transaction. No label inference or filler cable/camera definition.

References inside the extension use registered definition codes scoped to the exact root edition; materialized IDs are deterministic from `(catalogId,version,definitionKind,code)` using a versioned tuple encoder/hash. Protocol/interface provenance uses those IDs and exact root version. Runtime project-specific compatibility identity adds projectId while retaining catalog provenance.

Generic source must explicitly participate in the owning system of each external connection. Bind/import never invents a fifth system. A source shared by CCTV/LAN gets two non-owning memberships via the existing membership writer in one reviewed setup batch, and its distinct output ports have compatible declared family profiles. Membership detachment guard sees power dependencies. Physical component ID and budget owner remain single.

The [valid minimal catalog](examples/minimal-power-catalog.json) plus a placed source and consumer, explicit existing system membership, profile mapping and compatibility choice is the positive import/bind/connect oracle. Existing placed consumer ports may be mapped only to exact compatible templates; no duplication on second bind.

Proof RM05-T: import power-only catalog, create/map canonical ports, attach memberships, connect with materialized compatibility profile, calculate and restart using public commands. Zero fake discipline profiles and zero raw SQL setup.

## RM06 — Supported nonlinear boundary needed by backup

Initial electrical support is now (a) radial constant-current trees and (b) a **single constant-power converter terminal on one unbranched DC feeder**. General mixed/multiple constant-power trees, shared returns, meshes and parallel sources remain BLOCKED. A CP terminal may represent the evaluated input of UPS/inverter/DC-DC with explicit constant efficiency/idle and known downstream load. It is never retyped as constant current.

For source voltage Vs>0, total loop R>=0 and constant terminal power P>=0, with no intermediate taps:

- R=0: Vt=Vs, I=P/Vs; P=0: Vt=Vs, I=0.
- Otherwise solve Vt²−Vs*Vt+R*P=0; D=Vs²−4RP must be >0. Choose the high-voltage root `(Vs+sqrt(D))/2`. D<0 has no real operating solution: FAIL/ELV4_NO_FEASIBLE_ELECTRICAL_SOLUTION. D=0 is the unsupported collapse boundary: BLOCKED/ELV4_OPERATING_POINT_AT_BOUNDARY. Never clamp D or switch roots.
- Bound sqrt(D) by exact-rational bisection; at most 128 iterations, root interval width <=1e-9 V after unit normalization. All inputs are numeric policy v2 rationals. If width/residual/physical bound cannot be established, BLOCKED/ELV4_SOLVER_NOT_CONVERGED. Do not round before rating checks.
- Derive interval current P/Vt, feeder loss I²R, source power Vs*I, terminal voltage/current rating and energy at the bank boundary. Apply interval decision rules RM09. Evaluate declared source minimum/maximum; worst source current/input power is assessed at minimum Vs for constant P, terminal overvoltage at maximum Vs. Both must stay in model applicability and port envelopes.
- Topology precondition rejects branches/intermediate loads/second CP terminal rather than dropping them. Dynamic stability, protection selectivity and transient behavior are outside this static physical model and never asserted.

Exact oracle: Vs=24V,R=.5ohm,P=160W gives D=256,Vt=20V,I=8A,loss=32W,source=192W. A 24V bank with explicit flat-voltage usable-energy model may supply an explicit sequence through this supported feeder. Battery voltage/EOD and current applicability are mandatory evidence, not inferred from nominal Ah.

Proof RM06-T: exact oracle, irrational root bounded case, R=0/P=0, D<0/D=0, low-root rejection, out-of-envelope voltage/current, nonconvergence, unsupported branched CP graph, and complete UPS backup qualification. Solver versions are pinned in input and evidence.

## RM07 — Create-next identity remapping

Materialization builds and persists in its receipt an old-to-new mapping before writing dependent rows:

| Identity class | R2 operation |
|---|---|
| Project-stable component/port/connection/cable/allocation/catalog edition | Keep ID; verify current canonical projection matches captured base or explicitly restore through reviewed writer |
| Power aspect/scenario/segment logical IDs | Keep logical ID; new `(revisionId,id)` storage scope |
| ELV3 run/traversal and other revision-owned physical objects | Use IDs returned by existing physical materializer; map every operational ref to new ID |
| Dependency/logical pointer keys | Regenerate with R2 scope and mapped physical refs; new pointers absent/STALE |
| Immutable R1 evidence / basedOn lineage | Keep only in explicit provenance fields, never current operational refs |

Walk typed references including PoE physical paths, DC section evidence, installed-length source refs and reverse dependency indexes; reject unknown identity class or unmapped operational reference. Validate R2 closure contains no R1 revision-owned operational ID before commit. Source snapshot hashes are recomputed and verified, not just compared as stored columns. R1 remains immutable.

Creating from an older frozen base may encounter different current canonical values. The explicit `canonicalRestorePlan` must list candidate captured projections, expected current revisions and reviewed impact; validate through RM03 and existing canonical writers in the same transaction. Without a compatible verified plan return ELV4_BASE_CANONICAL_STATE_CONFLICT. Do not claim a base materialization while silently retaining unrelated current ports/allocations.

Proof RM07-T: multiple run/traversal refs and an older-base restore; all operational refs use R2 IDs, R1 provenance stays unchanged; unknown mapping fails atomically.

## RM08 — Durable, revision-scoped undo/redo

Add CommandHistoryOperations and CommandHistoryCursors scoped by projectId/designRevisionId. Operation PK `(projectId,designRevisionId,sequence)`; unique originalCommandId, state APPLIED/UNDONE/REDO_ABANDONED, forwardCommandType/schema/canonicalPayloadJson/hash, inverseCommandType/schema/canonicalPayloadJson/hash, before/after aggregate evidence refs, cursor generation and affected IDs. Cursors have monotonic generation and active branch/head. Full payloads are durable; forward/inversePayloadSha256 is SHA-256 of each complete canonical stored command (original envelope included). Before/afterAggregateEvidenceRef resolves immutable aggregate evidence; a hash alone is never a replay source.

Undo/redo uses a new commandId for each authorized inverse/forward execution. Rebase only envelope preconditions to the verified current token/row revisions after checking expected before/after aggregate hash; keep original business payload and exact editions/IDs. Ledger links history operation ID and execution kind. Retry of the same undo/redo command replays its receipt without moving cursor again. New edit abandons redo suffix atomically. Power history read/write interfaces take explicit projectId AND designRevisionId; the old project-only lookup cannot be reused as implicit power scope. Candidate lookup excludes other/frozen revisions; create-next starts a new cursor while retaining base provenance.

Freeze, archive and catalog adoption remain irreversible per existing reviewed policy. Evidence/payloads referenced by history cannot be garbage-collected.

Proof RM08-T: edit → restart → undo → restart → redo; original business value restored, new ledger actions recorded, lost-response replay does not move cursor twice, intervening edit/frozen transition rejects stale inverse.

## RM09 — Numeric policy v2: exact decimal decisions, bounded solver outputs

New power wire quantities are canonical decimal strings (no exponent, at most 30 integer and 12 fractional digits). Domain parses them as arbitrary-precision reduced rational `(BigInt numerator,positive BigInt denominator)`. Normalize trailing zeros/negative zero before new power hashing. Add/subtract/multiply/divide and capacity comparisons are exact rational operations; UI doubles are display adapters only. Do not change existing historical canonical JSON/hashes.

Pure solver square roots produce conservative rational intervals. PASS for demand/rating requires demand.upper <= available.lower; FAIL when demand.lower > available.upper; otherwise UNRESOLVED with ELV4_NUMERIC_BOUNDARY_UNCERTAIN. Exact decimal equality is PASS, with no engineering epsilon. Voltage lower/upper envelope comparisons follow the corresponding conservative interval rule. Physical measurement uncertainty, if supplied, widens input intervals explicitly with provenance; representation tolerance is never a reserve policy.

Outputs persist reduced numerator/denominator strings or interval lower/upper rationals, numericPolicyVersion `elv4.exact-rational.v2`, plus display unit. Input fingerprint includes that version. Legacy finite doubles may enter only through an explicit reviewed LEGACY_DECIMAL_ADOPTION using their canonical shortest decimal text as declared input; state that interpretation/provenance. Installed integer mm converts exactly to rational metres. Unsupported/unbounded input conversions remain unresolved.

Proof RM09-T: `.1+.2` and `.15+.15` both equal `.3` exactly; `.300000000001` exceeds `.3`; decimal division and multiple transfers preserve conservation; interval straddling a limit remains UNRESOLVED rather than PASS.

## RM10 — Project-wide revision sequence and older-base semantics

Create-next accepts any verified FROZEN base in the same project with no active WORKING revision. It allocates `max(project.sequence)+1`, independently of basedOnRevisionId, in the same transaction as a project-scoped allocator CAS. Add DesignRevisionSequenceAllocators(projectId PK,nextSequence,generation); initialize from actual maximum during migration. Existing unique `(projectId,sequence)` and active-WORKING invariant remain mandatory. All revision creation paths, including bootstrap, use this allocator; no remaining `base.sequence+1` path.

Older base changes only provenance/materialized contents, not monotonic project sequence. Apply RM07 canonical restore preconditions. Two clients race: one commits; the other replays same command or receives a stable lifecycle/CAS conflict. Constraint errors cannot leak as raw SQL exceptions.

Proof RM10-T: R1=1,R2=2 frozen; create from R1 gives R3=3 with basedOn=R1 and verified base contents. Two-connection allocation and failed-transaction rollback preserve one WORKING and monotonic uniqueness.

## RM11 — Wire schemas and version dispatch

Normative new-wire contracts: [catalog](schemas/power-catalog.schema.json), [commands](schemas/power-command.schema.json), [evaluation](schemas/power-evaluation.schema.json), [history](schemas/power-history.schema.json). Each rejects unknown fields/tags in its strict technical body. Optional display metadata is allowed only in the explicit metadata map and never used for compatibility or numeric fingerprints.

Command schemas register operation-specific payload discriminants and required fields; Set/Replace sets contain complete typed members. Reference/scope/cross-field validators supplement schema and are listed with each operation. Quantities use RM09 decimal strings. Valid and deliberately invalid examples are under examples; negative fixtures are expected to fail validation, not import into the application.

Ledger writer receives actual payloadSchemaVersion and schema identifier; no hardcoded 1 for new freeze/create-next v2. Preserve v1 replay codec for already committed old commands. Dispatch first by registered operation+version, then canonicalize/hash through that version's codec. Unknown mandatory version rejects before mutation. For revision commands, v1 is replay-only in the new power-enabled adapter: check the old ledger first, then reject a fresh v1 request with ELV4_COMMAND_VERSION_OBSOLETE. A fresh request must use explicit v2 intent; an old replay is never rerun as v2.

Proof RM11-T: schema positive/negative cases, old/new replay dispatch, actual SQL schema version, immutable old canonical hash, and new payloads with exact decimals.

## RM12 — Initial startup model ALL_SIMULTANEOUS

First slice supports only explicit ALL_SIMULTANEOUS startup: every declared startup pulse begins at t=0; no diversity reduction or inferred stagger. Pulse demand is explicitly TOTAL or INCREMENTAL relative to steady demand. TOTAL replaces its origin's steady load while active; INCREMENTAL adds to it. Each has positive duration. On finishing, the origin returns to steady. Distinct origins are counted once; charger demand is a separate simultaneous origin.

Build event intervals from sorted unique pulse end times plus t=0. For explanation, evaluate aggregate W/A/VA in each interval. For conservative source acceptance, require the maximum aggregate startup demand to be supportable for the longest declared startup duration, then check the post-start continuous limit. Event intervals do not grant undocumented thermal/duty-cycle credit. Envelope rating lookup uses the next supported longer duration with no optimistic interpolation; unavailable duration/rate evidence is UNRESOLVED. Unsupported correlation/stagger policies decode as unsupported and cannot lower the worst case.

Proof RM12-T: source acceptance requires at least 35W for 5s in this oracle. Steady 5W plus INCREMENTAL 10W/2s and 20W/5s -> 35W [0,2),25W [2,5),5W thereafter; TOTAL replacement avoids double baseline. Recharge adds to all intervals; unknown source duration never yields PASS.

## RM13 — Consumed-input projection equals dependencies

Capture may read a complete revision, but each evaluator receives a `PowerConsumedInput` projected from typed dependency facts. Its canonical facts map has exactly one entry per dependency key, with exact resolved value or MISSING marker. Technical fingerprint is hash of scope/versions and that sorted facts map; full capture/token/display data is excluded. Set-membership dependency facts include the complete relevant member ID set, preventing phantom additions.

| Process | Required dependency closure |
|---|---|
| PWR-01 | Active selected leaf/transfer ancestry, load states, own losses, relevant port/group membership and selected physical loss outputs |
| PWR-02 | PWR-01 evidence refs, selected source/group limits, reserve/derating policy |
| PWR-03 | Domain graph/load behavior/source bounds, conducting resource/termination/resistance/length facts and solver version |
| PWR-04 | Complete ordered segment set/durations, protected membership, consumed segment/bank-boundary evidence and bank/model/policy |
| PWR-05 | Protected membership and segment demand, output ratings, selected input/backup transfer and PF model |
| PWR-06 | PD demands, exact delivery/guarantee, complete physical pass path, per-port/shared membership/limits and own/input model |

Core technical reads go through a fact accessor which records keys; after evaluation assert recorded keys equal declared consumed keys (including all missing/set facts); undeclared access is a development error, never successful publication. Dependency cycles are rejected. Mutation invalidation and recapture use the same key encoders. Independent source/label changes do not change a subject's facts map. Broad designToken is separately checked for publication; token mismatch recaptures/retries or conflicts even when technical fingerprint is unchanged.

Proof RM13-T: independent source unchanged hash, new shared member changed hash, missing profile resolution changed hash, undeclared input access rejected, stale publish does not revive CURRENT.

## RM14 — Nonblocking freeze of committed evidence

Freeze does not wait for or persist RUNNING numerical work. It captures committed facts and pointer freshness at its transaction's validated token, recording unresolved/stale/not-calculated dimensions as such. WORKING -> FROZEN transition invalidates in-flight publishers through lifecycle/token checks. Any late publisher returns ELV4_RESULT_INPUT_CHANGED without changing frozen data or pointers. If publish commits first, freeze captures that complete committed publication.

RUNNING/CANCELLED are transient workspace operation states only; persisted evaluation execution is SUCCEEDED/FAILED. Restart drops transient runs and can start a new command; no durable lease is claimed. A successful calculate ledger exists only after atomic publish. Historical comparison is read-only and does not replace captured evidence.

Proof RM14-T: barriers before/after publish versus freeze, crash during pure compute, restart and same-command retry; one defined serialization, no perpetual RUNNING and no partial frozen batch.

## RM15 — Qualification manifest, required dimensions and closure

[qualification.json](qualification.json) is the versioned closure source for positive verticals, negative cases and complete resolved synthetic inputs. Per positive case it specifies scenario/segment/sequence, required process×dimension, expected COMPLETE/PASS, exact profile/path/bank applicability and result oracles. Builder must materialize equivalent identities/facts with public commands. An explicit N/A process is outside that case; required UNRESOLVED/BLOCKED/NOT_CALCULATED cannot qualify.

Boundary arithmetic fixtures remain useful but cannot substitute for a qualification case. Only separate negative/model-limit cases expect FAIL/BLOCKED. P8 and P9 consume the same manifest; closure fails if any required dimension is missing or if a required positive dataset uses an unsupported model. No scope waiver can turn a negative case into a positive vertical. The initial scope includes RM06's supported single-CP feeder precisely to make the stated UPS backup case fully testable.

Proof RM15-T: qualification validator accepts complete positive fixtures and rejects a copy with required physical/autonomy/power dimension changed to UNRESOLVED, missing model inputs, mixed segment captures or a skipped positive case. BASE-01…04 and runtime source/test/CI gates remain open until implemented/evidenced.
