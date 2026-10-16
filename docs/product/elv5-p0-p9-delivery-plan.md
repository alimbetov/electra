# ELV5 — P0–P9 delivery plan

Status: DESIGN HARDENED / ALL RUNTIME PACKAGES NOT STARTED
Branch: `feat/flutter-elv5-power-topology-design`
Parent: ELV4 `31581aa6c396d5ebd6cdf1985c53719d9d05e12a`.
Authority: [authoritative design index](elv5-authoritative-spec-index.md); [governing design](elv5-discipline-calculations-design-specification.md); [implementation contracts](elv5-implementation/README.md).

The implementation must also obey the explicit precedence in [third-pass code-level hardening](elv5-implementation/code-level-hardening-v2.md). Runtime is deliberately still NOT_STARTED: the design is hardened, but Dart/Drift implementation and executable P8/P9 evidence do not yet exist.

| Package | Scope | Depends on |
|---|---|---|
| P0 | [Baseline and stage integration](elv5-implementation/p0-baseline.md) | Existing ELV1–ELV4 source/design/evidence; authority manifest/ownership reconciliation |
| P1 | [Typed discipline profiles and process registry](elv5-implementation/p1-profiles-registry.md) | P0 ownership/scope map; strongly typed identities/fields/quantities and bounded exact arithmetic |
| P2 | [Persistence, command boundaries and revision evidence](elv5-implementation/p2-persistence-commands.md) | P1 contracts plus shared command/history/revision platform; additive schema 24 |
| P3 | [CCTV calculation implementation](elv5-implementation/p3-cctv.md) | P1/P2, ELV3 routes, exact ELV4 evidence, captured temporal/frame rules |
| P4 | [LAN and structured-cabling implementation](elv5-implementation/p4-lan.md) | P1/P2, ELV3 lengths/resources, exact PWR-06, immutable cable/optic capabilities |
| P5 | [Access-control implementation](elv5-implementation/p5-acs.md) | P1/P2, canonical assemblies, shared power kernels and transient/release policies |
| P6 | [Fire-alarm implementation](elv5-implementation/p6-fire.md) | P1/P2, signal topology, supported electrical and selected supervision/fault models |
| P7 | [Incremental dependencies and engineer workspace](elv5-implementation/p7-dependencies-workspace.md) | Design begins P1/P2; integrates P3–P6; selector-aware invalidation and bounded coherent publication |
| P8 | [Integrated verification and qualification](elv5-implementation/p8-acceptance.md) | P0–P7 implemented prerequisites; 54 primary verticals plus hardening suites |
| P9 | [Architecture reconciliation and stage handoff](elv5-implementation/p9-closure.md) | P8 plus exact-head requirement/source/test/manifest evidence |

## 1. Frozen inventories

The following are design-frozen implementation inventories, not developer choices:

```text
80 stable package requirements
27 process codes = CCTV-01..06 + LAN-01..07 + ACS-01..06 + FA-01..08
16 public ELV5 discipline command operations
schema 23 inherited -> additive schema 24 target
engineering-node-v3 / owner ELV5 result identity
canonical encoder electra.canonical-json.v1
54 primary P8 process entries = POS + NEG/unsupported for every process
shared ELV4 freeze/create-next command boundary
shared command ledger/history/UoW platform
```

The third-pass hardening adds mandatory focused suites for typed identity safety, explicit field resolution, resource bounds, quantity algebra, captured timezone rules, measurement quality, requirement composition, transient simultaneity, selector invalidation, supervision/fault behavior, bounded atomic publication, review separation and finding cardinality. These suites supplement the 54 process entries rather than replacing them.

## 2. Sequencing

Recommended implementation sequence is deliberately foundation-first:

```text
P0 baseline/contract manifest
  -> P1 engineering primitives + typed identities/registry
  -> P2 schema 24 + repositories/UoW + strict 16-command infrastructure
  -> early scalar/resource verticals
  -> P3/P4/P5/P6 discipline completion
  -> P7 dependency/workspace integration
  -> P8 executable qualification
  -> P9 exact-head closure
```

The [production source blueprint](elv5-implementation/production-source-blueprint.md) defines the recommended code decomposition and implementation slices. UI-first or formula-by-formula development that bypasses P1/P2 is rejected because it would recreate wire/storage/numeric semantics independently in each discipline.

P7 consumed-input/invalidation design and P8 fixture design begin with P1/P2. Discipline packages may be developed in parallel only where their actual shared primitives, repositories and upstream kernels are already accepted. No package may copy a power/length formula to bypass a missing dependency.

## 3. P0 implementation-entry gate

Before production ELV5 classes are considered stable, P0 establishes:

- exact accepted ELV4 source/merge/runtime evidence and schema 23 baseline;
- supported historical migration origins;
- result-owner/read-dispatch map across legacy/ELV3/ELV4/ELV5;
- canonical ownership map for revisions/components/ports/cables/sources/batteries/capability definitions;
- actual shared command ledger/history/UoW/freeze/create-next owners;
- generated `contract-manifest.json` and authority fingerprint/CI consistency test required by the third-pass contract;
- explicit ELV6/ELV7/ELV8 claim boundaries.

If a required inherited platform capability is missing, it becomes an explicit shared-platform delta. ELV5 does not invent a second platform locally.

## 4. P1 implementation gate

P1 is the non-negotiable engineering foundation. It must provide before broad process coding:

```text
opaque typed identities and closed subject/scope kinds
explicit Known/Missing/NotApplicable/Unsupported/Unresolved field algebra
dimension-safe exact quantity/value objects
code-owned legal quantity operations
bounded exact decimal/rational codecs
source/evidence/applicability + measurement uncertainty/calibration semantics
operating case and transient/simultaneity policies
captured timezone-rules evidence, not host-tzdb dependence
coordinate frame/transform evidence
stable finding/comparison model
canonical request/input/output/snapshot hashing
exact 27-definition process registry
```

A plain `String`, nullable scalar, `Map<String,dynamic>` or generic arithmetic operator is not accepted where the domain contract requires a typed engineering meaning.

## 5. P2 implementation gate

P2 implements additive Drift schema 24 and the exact 16-operation wire surface. It must preserve ELV3/ELV4 ownership and reuse the existing command ledger/history/revision platform.

Every durable replacement follows replay-first, CAS/reviewed-impact, atomic root+children replacement, selector-aware `union(old,new)` invalidation, complete forward/inverse history and ledger commit in one short transaction.

Long calculation uses:

```text
short coherent capture
-> pure typed kernels outside DB write transaction
-> bounded all-or-nothing guarded publication
```

The server never silently splits one requested coherence group into independently committed subcommands.

## 6. Discipline implementation gates

### P3 CCTV

Must preserve frame/transform identity, expected/peak/wire-rate separation, explicit stream subscriptions, captured timezone rules, estimate-vs-guaranteed storage basis, single reserve/redundancy application and one shared physical PSE evidence identity.

### P4 LAN

Must preserve complete physical path accounting, unique resource identity, weakest-section compatibility, bidirectional dB/dBm optics, sensitivity/overload separation, optional reach/dispersion claim isolation and ELV6-safe rack demand handoff.

### P5 ACS

Must preserve explicit role/resource multiplicity, lock state/transient demand, one shared physical source/bank requirement, fail-safe/fail-secure/project-defined safety mode and complete technical release matrix including normal access, request-to-exit, fire release, emergency break-glass and power failure.

### P6 Fire

Must preserve full expanded address claims, state-current membership completeness, supported-vs-unsupported electrical models, ordered autonomy sequence, notification active/startup/terminal-voltage dimensions, signal topology separate from power topology and selected supervision/fault-state behavior without false normative claims.

## 7. P7 dependency/workspace gate

Dependency capture covers positive and negative knowledge:

```text
FACT
SET
POLICY
EVAL
POINTER
MISSING
selector-aware SET markers for derived membership predicates
```

Every mutation invalidates old and new direct/selector closure. Runtime graph traversal is bounded and iterative. One calculation coherence group publishes all requested nodes or none.

Workspace displays immutable engineering result/provenance and separate review/workflow state. Engineer acknowledgement/waiver must never rewrite kernel FAIL to PASS or alter `outputHash`.

## 8. P8 executable qualification gate

Planned IDs and design examples are not evidence. P8 runs against production source and file SQLite.

Required evidence includes:

- exactly 54 primary public-command process entries;
- L0 primitive/identity/quantity/hash/time/evidence suites;
- L1 typed kernel boundaries/metamorphic tests;
- L2 all 16 strict command codec/adversarial/replay/resource-limit suites;
- L3 schema-24 migration/restart/historical-owner isolation;
- L4 UoW/history/undo-redo/failure-injection atomicity;
- L5 end-to-end public process verticals;
- L6 deterministic races/freeze/create-next/selector invalidation;
- third-pass transient, requirement-composition, measurement, supervision/fault and cardinality suites;
- no-false-PASS sentinels and scale fixtures.

All evidence identifies one exact tested Git SHA and actual test names/artifacts.

## 9. P9 closure gate

P9 reconciles at one exact source SHA:

```text
80 requirements
27 production typed process definitions
16 production command codecs/handlers
schema-24 implementation/indexes/migration
contract manifest/fingerprint
54 primary qualification entries + focused hardening suites
source/test/evidence ledger
ELV6/ELV7/ELV8 handoff limits
zero open BLOCKER/HIGH findings
```

A documentation or source change after the accepted SHA invalidates exact-head closure until the gate is rerun.

Design hardening, runtime implementation, exact-head runtime acceptance, merge and stage CLOSED are separate events.

## 10. Stage boundaries

- **ELV6** owns actual rack/cabinet U-position, layout, depth/clearance, thermal/ventilation and cable-management fit.
- **ELV7** owns verified jurisdictional/normative applicability, compliance/certification and normative waiver/approval semantics.
- **ELV8** owns concrete commercial equipment/SKU selection, BOM, quote and procurement/deliverable generation.

ELV5 provides exact technical requirements, margins, provenance and unresolved/unsupported limitations to these stages; it does not pre-claim their outcomes.

## 11. Current ledger

| Package | Design | Runtime | Evidence |
|---|---|---|---|
| P0 | HARDENED | NOT_STARTED | design contracts only |
| P1 | HARDENED | NOT_STARTED | design contracts only |
| P2 | HARDENED | NOT_STARTED | design contracts only |
| P3 | HARDENED | NOT_STARTED | design contracts only |
| P4 | HARDENED | NOT_STARTED | design contracts only |
| P5 | HARDENED | NOT_STARTED | design contracts only |
| P6 | HARDENED | NOT_STARTED | design contracts only |
| P7 | HARDENED | NOT_STARTED | design contracts only |
| P8 | HARDENED | NOT_STARTED | qualification specification only |
| P9 | HARDENED | NOT_STARTED | closure specification only |

Three audit passes now resolve **37 design findings** in specification. This ledger intentionally does not convert them into runtime fixes.
