# ELV4 — Shared runtime contracts

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Parents: [index](README.md), [coordinated design](../elv4-coordinated-p0-p9-contract.md).

## S1. Layers and proposed files

| Layer | Proposed source units | Boundary |
|---|---|---|
| Pure core | `power_numeric.dart`, `power_profiles.dart`, `power_scenario.dart`, `power_graph.dart`, `power_trace.dart`, `power_calculations.dart`, `power_snapshot.dart`, `power_result.dart` under engineering_core/lib/src | Immutable inputs/results; no Drift, clocks, UUID generation, file IO or Flutter |
| Application | `elv_power_command.dart`, `elv_power_command_service.dart`, `elv_power_read_service.dart`, `elv_power_calculation_service.dart`, `elv_power_dependency_inspector.dart` under mobile/lib/application | Capture/validate/orchestrate; existing ElvCommandResult and UoW conventions |
| Data | `drift_elv_power_repository.dart`, `drift_elv_power_write_unit_of_work.dart`, `drift_elv_power_result_store.dart`, `drift_elv_power_snapshot_store.dart` under mobile/lib/data/repositories | One AppDatabase, scoped SQL, transaction-bound stores |
| Presentation | Power overlay/side-card/state adapters within existing engineering editor feature | Application commands only; no direct multi-table writes |

Storage owner/kind isolation applies to every existing reader/writer/retirement path (RM01), not merely the new adapter. SQL pointer states CURRENT/STALE and immutable CAPTURED are decoded only by their owners. Implement existing shared behaviors once. New application services must not create replacement ELV1 connection or ELV3 allocation/revision lifecycles.

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

Query context: projectId, designRevisionId, scenarioId, optional segmentId for scenario-summary reads and explicit subject, trace direction. Frozen query chooses its immutable reader before resolving any canonical row. WORKING read captures a consistent view. Display filtering by system is a presentation constraint, not a different calculation scope.

Preview response: canonical proposed mutation, expected design/row revisions, old/new impact keys and source hashes, findings, reviewedImpactFingerprint. Commit reloads those facts; a matching label or row count is insufficient. Preview has no durable writes.

## S3. Pure calculation input and output

`PowerInputSnapshot` is a consistent full capture container. Each evaluator consumes only a PowerConsumedInput projection whose facts map and recorded dependency keys coincide exactly (RM13); full capture is never hashed wholesale. Capture contains scope/designToken, scenario/segments, exact canonical/aspect/physical facts, definitions, policy refs and versions. Missing required inputs are represented by typed unresolved entries with dependency identities, not dropped rows.

`PowerProcessEvaluation` contains processCode, subject, scenario/segment, algorithmVersion, inputSchemaVersion, outputSchemaVersion, numericPolicyVersion, inputFingerprint, quantities, contribution records, assumptions, findings and dependency keys. Each quantity records unit and boundary. Logical keys require SEGMENT/segmentId or SEQUENCE/scenarioId (RM04). Every contribution has a unique origin `(port/load/transfer ID, segmentId, accountingKind)`.

`PowerFinding` fields: stable code, severity, entity refs, field path, segment, expected/actual typed quantities when known, dependency refs, remediation kind and message parameters. Localized text is generated outside core; fingerprint technical values and codes only.

Freshness lives on the current pointer: CURRENT or STALE. Evaluation completion: COMPLETE, PARTIAL or BLOCKED; assessment: PASS, FAIL or UNRESOLVED. Execution: SUCCEEDED or FAILED. Structural/input-domain failures prevent a result from asserting PASS. A proved violated limit can report FAIL even when other dimensions are unresolved; per-dimension status remains available. Overall PASS requires every required dimension complete and passing.

## S4. Versioned numeric policy v2

New power quantities use canonical decimal-string input parsed to reduced BigInt rational values. Arithmetic and rating decisions are exact; UI doubles never determine engineering assessment. Solver roots use conservative rational intervals. Full input/output and legacy-adoption rules are normative in [RM09](remediation-contract.md#rm09--numeric-policy-v2-exact-decimal-decisions-bounded-solver-outputs).

Capacity equality is PASS for exact rationals. For uncertain solver/input intervals: PASS only if demand.upper <= available.lower; FAIL if demand.lower > available.upper; otherwise UNRESOLVED. No engineering epsilon hides real overload. Reject nonfinite/invalid input, zero divisors and out-of-model operations. Old canonical JSON/hashes are never rewritten.

The fingerprint is computed only from the exact consumed facts map and versions (RM13), including scope, missing markers and relevant membership sets; it excludes designToken, display labels, UI selection, command/evaluation IDs and timestamps. Publication separately CAS-checks designToken/lifecycle and consumed pointer generations.

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

## S7. Resolved audit contracts

[RM01–RM15](remediation-contract.md) define mandatory storage isolation, static/nameplate projection, segment/sequence identity, generic canonical bridge, supported single-CP feeder, remapping/lineage, durable history, exact numeric/wire schemas, conservative startup model, consumed-input projection, nonblocking freeze and qualification manifest. These decisions refine the same requirements and introduce no runtime completion claim.

Additional stable findings/errors: ELV4_NO_FEASIBLE_ELECTRICAL_SOLUTION (physical FAIL), ELV4_SOLVER_NOT_CONVERGED (BLOCKED), ELV4_NUMERIC_BOUNDARY_UNCERTAIN (UNRESOLVED), ELV4_BASE_CANONICAL_STATE_CONFLICT (reviewed restoration conflict), ELV4_OPERATING_POINT_AT_BOUNDARY (unsupported collapse boundary) and ELV4_COMMAND_VERSION_OBSOLETE (fresh legacy revision request rejected after replay lookup). Persisted operation codecs reject unknown versions; actual schema version is passed to the ledger writer.
