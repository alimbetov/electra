# P7 — Dependencies, safe publication and progressive workspace

Status: RUNTIME / DATA / WORKSPACE-STATE CLOSURE IMPLEMENTED; POWER-SPECIFIC UI WIRING OPEN
Dependency integration begins in P2; complete workspace follows P3–P6.
Shared rules: [runtime contracts](shared-contracts.md).
Resolved audit decisions: [RM01–RM15](remediation-contract.md).

## Implemented closure (2026-10-15)

The durable P7 runtime boundary is implemented and acceptance-tested on the feature branch.

- P7-T01: `elv4-dep-v1` typed facts, PRESENT/MISSING consumed inputs and consumed evaluation refs are persisted in the immutable evaluation envelope. Technical fingerprints contain exact consumed facts and algorithm/input/numeric-policy versions; the broad design revision token remains a CAS guard rather than a fingerprint input.
- P7-T02: a scoped additive `power_dependency_index_records` reverse index tracks only CURRENT logical pointers. It indexes both FACT and EVALUATION refs, computes transitive dependency closure, unions old/new fact closures around the canonical mutation, marks only affected WORKING pointers STALE and removes only their current-index rows in the same transaction. Immutable evaluations remain untouched.
- P7-T03: single-node and atomic multi-node publication use capture → pure calculation → guarded publish. Publish rechecks WORKING lifecycle, design revision token, recaptured technical fingerprint, target pointer baseline and consumed pointer generations. Calculate ledger, immutable evaluations, CURRENT pointers and reverse-index rows commit atomically. Late publishers and CAS losers return `ELV4_RESULT_INPUT_CHANGED` without partial publication. Operation replay is idempotent, and internal batch dependency cycles are rejected before publication.
- P7-T07: freeze now captures the committed power pointer section after the physical snapshot and before the existing WORKING → FROZEN CAS, inside the existing freeze transaction. Power snapshot and combined physical/power manifest hashes are persisted together. Frozen reads are mutation-disabled and distinguish `ELV4_POWER_NOT_CAPTURED` from a valid captured-empty power section.
- Workspace-state portions of P7-T04/P7-T05/P7-T08 are implemented: revision/scenario/segment context generation, selected component/port, progressive card order/index, overlay mode, immutable query snapshot, draft/preview state, transient operation state, findings/currentness and stale async-response suppression. Scenario switches retain compatible selection and drafts with warning; revision switches clear draft state; frozen/historical contexts reject mutation.
- The P7 work also exposed and fixed a pre-existing P2 Drift defect: parameterized `customStatement` calls passed `Variable<T>` directly to sqlite3. `drift_raw_statement.dart` now converts typed Drift variables to legal raw SQLite values (including DateTime → Unix seconds), and the P2 persistence regression is included in the P7 gate.

Final read-only targeted validation run `38733525610` passed clean checkout, Drift generation, format verification, full `flutter analyze`, P7 single publication/invalidation/race tests, atomic batch tests, freeze integration, workspace-state acceptance, P2 persistence regression and P3 runtime-closure regression. The temporary P7 workflow was removed after success.

Still intentionally open before claiming full visual P7 closure:

- P7-T04 actual editor rendering of the revision/scenario-aware power overlay and shared-source/global budget view;
- P7-T05 the concrete progressive power side-card widget and explanation presentation in the editor;
- P7-T06 route preview/review/commit/failure/undo-redo wiring from the power workspace into the existing public ELV physical-routing command service;
- P7-T08 compact-width widget acceptance, keyboard traversal, focus restoration, back handling and concrete finding-remediation navigation.

The existing editor already provides wide/compact responsive shells and the existing `DefaultElvPhysicalRoutingWorkspaceService` provides the public command/trace boundary. The remaining UI slice must reuse those contracts and must not introduce widget-owned persistence or power arithmetic.

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P7-001 | Encode typed dependency keys and persist present/missing exact inputs for every process | P7-T01 key/absent dependency |
| ELV4-P7-002 | Invalidate old/new graph closure across shared systems and disconnected paths atomically | P7-T02 affected/unaffected matrix |
| ELV4-P7-003 | Capture/calculate/publish with token/fingerprint/pointer CAS and stale-race rejection | P7-T03 late publish race |
| ELV4-P7-004 | Implement revision/scenario-aware power overlay and shared-source budget view | P7-T04 filter/global budget |
| ELV4-P7-005 | Implement one progressive side card with back/forward selection retention and explanation | P7-T05 navigation/density |
| ELV4-P7-006 | Route preview, commit, failed draft, undo/redo through public application commands | P7-T06 stale preview/write failure |
| ELV4-P7-007 | Implement frozen read-only, NOT_CAPTURED and captured-empty states distinctly | P7-T07 historical workspace |
| ELV4-P7-008 | Cover compact width, keyboard/focus/back handling and findings remediation navigation | P7-T08 compact/accessibility |

## Dependency encoding and storage

Dependency key is a canonical JSON tuple distinct from the RM04 segment/sequence result key: `["elv4-dep-v1", projectId, revisionId, kind, entityId, fieldOrPurpose]`. Include scenario/segment only for scenario-specific inputs. Never parse concatenated unrestricted IDs by colon splitting. Definition dependencies include exact edition/hash; physical keys include canonical run/resource/termination/resistance inputs.

Index ELV4/POINTER rows by RM13 exact consumed facts through a scoped additive reverse-index adapter within the same DB; all existing result clients obey RM01 owner/kind filtering. If an additive dependency-index table is needed, it is an index of current nodes, not another result source of truth; update it atomically with pointer publication/invalidation. Immutable evaluations retain their own complete dependency list.

Missing-input keys use the identity/purpose that will become resolved, e.g. required profile for a specific port. Binding that profile invalidates its previously BLOCKED result. Adding/removing members in a shared group invalidates consumers of the group set, not only the old individual member keys.

## Invalidation algorithm

1. Capture old graph/membership closure before mutation.
2. Apply validated canonical/aspect edit.
3. Compute new closure and changed typed keys.
4. Union previous and new reachable source/group/protected-load/terminal dependencies.
5. Mark only affected WORKING logical pointers STALE and update reverse-index entries in the same transaction.
6. Leave immutable evaluations and frozen evidence untouched.

Changed source voltage affects downstream compatibility/DC terminal results and loss-sensitive upstream/backup basis. Changed bank usable model affects protected energy capacity and explicit charging dependencies; unrelated normal demand stays current. Changed unrelated room label is a required negative control. A broad revision token is a concurrency guard, not a fingerprint input or permission to mark all numerical results stale. RM13 facts-map keys exactly equal the recorded consumed dependency set.

## Calculation orchestration

Create request contains scope, process/subject set, command ID and expected input context. Capture under one consistent read transaction; build a dependency-complete immutable input. Run pure evaluator outside write transaction. Reopen short publish transaction and check ledger, WORKING lifecycle, token, recaptured technical fingerprint and prior pointer generation.

If token changed for unrelated reasons, return ELV4_RESULT_INPUT_CHANGED or perform a fresh bounded capture/recalculation before publish. Never publish merely because an earlier cached fingerprint looked equal. A failure or user cancellation before publish makes no partial pointer changes. A batch evaluation publishes its declared mutually dependent result set atomically so PWR-02 cannot point at a different PWR-01 input generation.

Calculate ledger is committed only with evaluation/pointer publication. Freeze follows RM14 nonblocking capture; RUNNING is transient UI state only. Frozen/history ad hoc calculation is a pure read over captured data and cannot mutate frozen rows; any new comparison must be an explicit separate read-only output, clearly distinguished from captured accepted evidence.

## Workspace state model

`PowerWorkspaceState` contains read context, selected component/port, card stack/index, overlay mode, immutable query snapshot, draft, preview fingerprint, operation state, findings and current pointer state. Async query responses carry context generation; discard responses for an obsolete revision/scenario/selection. UI selection does not enter technical fingerprints.

| State / event | Required behavior |
|---|---|
| Select component / port | Highlight supply route; open demand or path summary; keep unused cards collapsed |
| Next / previous card | Preserve editor viewport, selection and draft; explicit card order |
| Switch scenario | Retain compatible component selection, refresh context, warn about unsaved draft using existing editor policy |
| Review shared edit | Show full project budget and highlighted system contribution; commit exact reviewed fingerprint |
| Validation conflict | Retain draft and show entity/field fix target; no success toast |
| Save succeeds | Apply receipt revisions/invalidation, reload affected data, preserve viewport |
| Calculate running/stale | Label currentness; old values remain explicitly stale, never silently green |
| FROZEN / missing power capture | Disable mutation; show captured data or NOT_CAPTURED reason, respectively |

Card order: demand → upstream path → profile/scenario → realization → source/group capacity → backup → findings/how calculated. Each card loads details on demand; the summary shows only source, current state, essential quantities and findings count. Findings select the concrete referenced object/field, not a generic help page.

## Interaction acceptance

At existing desktop and compact editor breakpoints, one active card remains navigable without horizontal overflow; exact responsive breakpoint reuses editor design tokens rather than inventing a power-only size. Keyboard reaches scenario selector, trace direction, cards, review/apply and findings; focus returns to invoking control after drawer/dialog close. Back closes a card/drawer before navigating away according to editor conventions.

P7-T02 asserts exact affected node IDs plus unchanged fingerprints of independent sources/scenarios and frozen revisions. P7-T03 edits run length after capture but before publish; publish must not resurrect CURRENT. P7-T05 verifies one card visible and forward/back state preservation. P7-T06 injects command failure and verifies unchanged DB plus retained draft. P7-T07 compares frozen and legacy missing-capture UI.

Exit: place/bind → connect → realize → evaluate → trace/explain → freeze/reopen uses application contracts end to end, with no widget-owned persistence arithmetic.

## Resolved UI/history behavior

Scenario switch leaves static canonical port rows unchanged (RM02/03); display zero and unknown separately. Scenario summary returns explicit segment-keyed results (RM04). Undo/redo uses RM08 durable forward/inverse payloads and revision-local cursor. A late publisher after freeze returns the specified conflict and never changes captured results (RM14). Findings distinguish physical overload, numeric-boundary uncertainty and unsupported models; the qualification manifest controls readiness indicators rather than the presence of any numeric subtotal.
