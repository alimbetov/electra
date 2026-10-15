# ELV4 — Shared runtime contracts

Status: PROPOSED IMPLEMENTATION CONTRACT
Parents: [index](README.md), [coordinated design](../elv4-coordinated-p0-p9-contract.md).

## S1. Layers and proposed files

| Layer | Proposed source units | Boundary |
|---|---|---|
| Pure core | `power_profiles.dart`, `power_scenario.dart`, `power_graph.dart`, `power_trace.dart`, `power_calculations.dart`, `power_snapshot.dart`, `power_result.dart` under engineering_core/lib/src | Immutable inputs/results; no Drift, clocks, UUID generation, file IO or Flutter |
| Application | `elv_power_command.dart`, `elv_power_command_service.dart`, `elv_power_read_service.dart`, `elv_power_calculation_service.dart`, `elv_power_dependency_inspector.dart` under mobile/lib/application | Capture/validate/orchestrate; existing ElvCommandResult and UoW conventions |
| Data | `drift_elv_power_repository.dart`, `drift_elv_power_write_unit_of_work.dart`, `drift_elv_power_result_store.dart`, `drift_elv_power_snapshot_store.dart` under mobile/lib/data/repositories | One AppDatabase, scoped SQL, transaction-bound stores |
| Presentation | Power overlay/side-card/state adapters within existing engineering editor feature | Application commands only; no direct multi-table writes |

Implement existing shared behaviors once. New application services must not create replacement ELV1 connection or ELV3 allocation/revision lifecycles.

## S2. Command and query envelopes

Proposed signatures use existing Dart conventions; names are implementation targets, not executable declarations:

```dart
Future<ElvCommandResult<PowerMutationReceipt>> execute(PowerMutation command);
Future<PowerImpactPreview> preview(PowerMutationDraft draft);
Future<PowerWorkspaceSnapshot> read(PowerReadContext context);
Future<ElvCommandResult<PowerEvaluationReceipt>> calculate(
  CalculatePowerProcessCommand command,
);
```

Mutation envelope: projectId, designRevisionId, commandId, commandType, payloadSchemaVersion, expectedDesignRowRevision, expectedRows keyed by typed scoped identity, optional reviewedImpactFingerprint, typed payload. Command identity is `(projectId, commandId)` as in CommandExecutionRecords. Normalize payload before hashing; include preconditions, exact refs and scope. Audit timestamps and transport retry counters are not payload inputs.

Receipt: changed logical IDs/row revisions, resulting design rowRevision, invalidated logical node keys, history operation ID if applicable, and provenance references. The ledger stores the complete replayable receipt. Do not return a cached success from another project or a partial reconstructed response.

Query context: projectId, designRevisionId, scenarioId, optional segmentId/subject, trace direction. Frozen query chooses its immutable reader before resolving any canonical row. WORKING read captures a consistent view. Display filtering by system is a presentation constraint, not a different calculation scope.

Preview response: canonical proposed mutation, expected design/row revisions, old/new impact keys and source hashes, findings, reviewedImpactFingerprint. Commit reloads those facts; a matching label or row count is insufficient. Preview has no durable writes.

## S3. Pure calculation input and output

`PowerInputSnapshot` contains scope, designToken, scenario/segment payloads, exact port/component/connection/internal mapping data, aspect sets, installed physical evidence, exact definition contents/hashes, policy refs and algorithm/numeric versions. Missing required inputs are represented by typed unresolved entries with dependency identities, not dropped rows.

`PowerProcessEvaluation` contains processCode, subject, scenario/segment, algorithmVersion, inputSchemaVersion, outputSchemaVersion, numericPolicyVersion, inputFingerprint, quantities, contribution records, assumptions, findings and dependency keys. Each quantity records unit and boundary. Every contribution has a unique origin `(port/load/transfer ID, segmentId, accountingKind)`.

`PowerFinding` fields: stable code, severity, entity refs, field path, segment, expected/actual typed quantities when known, dependency refs, remediation kind and message parameters. Localized text is generated outside core; fingerprint technical values and codes only.

Freshness lives on the current pointer: CURRENT or STALE. Evaluation completion: COMPLETE, PARTIAL or BLOCKED; assessment: PASS, FAIL or UNRESOLVED. Execution: SUCCEEDED or FAILED. Structural/input-domain failures prevent a result from asserting PASS. A proved violated limit can report FAIL even when other dimensions are unresolved; per-dimension status remains available. Overall PASS requires every required dimension complete and passing.

## S4. Versioned numeric policy v1

Use finite IEEE-754 double arithmetic consistent with existing core APIs. Canonical serialization uses existing canonicalEngineeringJsonV1; sort unordered identity sets before serialization; preserve semantically ordered segments/path traversals. Reject NaN/infinity and invalid divisors before math. Normalize negative zero in newly defined numeric payloads; never rewrite old catalog/snapshot bytes.

Validation consistency and solver residual comparisons use `abs(a-b) <= max(1e-9, 1e-9 * max(abs(a),abs(b)))` in the quantity's canonical unit. This tolerance is not permission to exceed a rating. Capacity pass uses the unrounded computed demand <= declared available capacity; near-boundary uncertainty is exposed as a finding when input precision requires it. UI rounding never changes verdict. Source min/max range checks use unrounded bounds.

Use stable identity ordering for summation and finding order; assess physically distinct voltage/state cases separately. Decimal business rounding and standards-specific tolerances may be introduced only by an explicit later version with tests and provenance.

Input fingerprint includes scope IDs, resolved technical input, missing-input markers, exact editions, selected scenario/policy, algorithm/input/output/numeric versions. It excludes calculatedAt, commandId, evaluationId, display labels and UI selection. A design token guards publication but is excluded from the technical fingerprint: unrelated edits can advance it without changing input. Revalidation may then recapture/retry safely.

## S5. Error versus finding registry

| Code / family | Command category or evaluation dimension | Meaning |
|---|---|---|
| Existing ELV project/revision/lifecycle/idempotency codes | Existing categories | Reuse baseline spelling; P0 records exact code map |
| ELV4_STALE_PRECONDITION | revisionConflict | Reviewed facts changed; reload/review required |
| ELV4_PROFILE_UNRESOLVED | Finding: input/compatibility | No exact complete required profile |
| ELV4_VOLTAGE_INCOMPATIBLE | Finding: compatibility | Guaranteed bounds do not fit consumer |
| ELV4_POWER_PATH_UNRESOLVED | Finding: topology/realization | Missing conductive/selected/physical evidence |
| ELV4_UNSUPPORTED_CYCLE | Finding: topology | Active directed power cycle |
| ELV4_MULTIPLE_SUPPLY_PATHS | Finding: topology | Unsupported reconvergence/parallel energized feed |
| ELV4_CAPACITY_EXCEEDED | Finding: capacity | Known per-port/group/source/peak limit exceeded |
| ELV4_POE_PATH_UNRESOLVED | Finding: PoE | Missing/unsupported power delivery continuity |
| ELV4_BANK_INCOMPATIBLE | Finding or validation rejection | Bank topology incompatible; reject malformed configuration before write |
| ELV4_REQUIRED_POLICY_MISSING | Finding: applicability | Required duration/reserve/model policy absent |
| ELV4_UNSUPPORTED_ELECTRICAL_MODEL | Finding: applicability | Nonlinear/mesh/rate model outside supported slice |
| ELV4_RESULT_INPUT_CHANGED | revisionConflict | Calculation publish lost input/token race; no pointer advanced |
| ELV4_POWER_NOT_CAPTURED | Read outcome | Historical revision predates power capture |

Invalid number/owner/dangling-reference commands use existing validation/referenceIntegrity categories with field/entity details. Missing engineering facts in a structurally valid draft are findings, not blanket command rejection. Catalog corruption, hash mismatch and contradictory binding ownership reject mutation/import. Raw SQL messages and stack traces are never stable error contracts.

## S6. Transaction and race policy

A transaction-bound power session extends ElvWriteSession with scoped stores, references, canonical projections, revision CAS, dependencies and history. It must share the same AppDatabase transaction as ELV1/ELV2/ELV3 writes it participates in. No inner independently committed UoW.

Every power-affecting canonical write advances ProjectDesignRevisions.revision with `WHERE state=WORKING AND revision=expected`; affected row count must be one. Per-aspect CAS remains required. Store old closure before destructive changes, new closure after validated changes, invalidate their union, then write history/ledger before commit. A zero-row CAS or deferred constraint failure rolls everything back.

SQLite BUSY retries at most three fresh transaction attempts for the same command ID. Do not retry an old partial session; reread ledger/preconditions. On exhaustion map to a stable storage failure with retryable=true. Validation/revision failures are not automatically retried as successful edits. This is a bounded runtime policy, not a performance benchmark.

Capture → pure calculation → guarded publish uses separate short transactions around the pure stage. Publish verifies WORKING lifecycle, expected token, exact input fingerprint and prior pointer generation; stores immutable evaluations, current pointer and successful calculate ledger atomically. Concurrent calculations serialize by pointer generation; a loser returns typed conflict or exact ledger replay. A replay of an old calculate command never changes pointer freshness.
