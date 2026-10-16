# ELV4 — Wire registry and semantic validation

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Parent: [RM11](remediation-contract.md#rm11--wire-schemas-and-version-dispatch).

## Registered new wire schemas

| Wire | Schema | Decoder / compatibility |
|---|---|---|
| Power-only root catalog v1 | [power-catalog.schema.json](schemas/power-catalog.schema.json) | Strict new root maps to existing root edition store; old schema-less catalog decoder remains unchanged |
| Power command v1 and revision command v2 | [power-command.schema.json](schemas/power-command.schema.json) | Registered operation+version union; unknown operation/version rejected |
| Evaluation v2 | [power-evaluation.schema.json](schemas/power-evaluation.schema.json) | Exact-rational output and explicit scope; SQL owner/kind selects this decoder |
| History v1 | [power-history.schema.json](schemas/power-history.schema.json) | Durable full forward/inverse commands, hashes and immutable aggregate refs |

The schemas are JSON Schema 2020-12 documents using local references and a deliberately limited keyword set. The repository specification checker validates their supported structural constraints and examples with a standard-library implementation; it is not a general JSON Schema conformance suite. Runtime must enforce the same constraints through typed codecs or a supported validator plus the semantic checks below.

New strict catalog technical bodies reject extra fields. Only metadata's explicit string map is extensible and excluded from technical compatibility calculations. Definitions inherit definitionVersion from exact root version; no contradictory separate version field is accepted. Instance exact refs include definitionKind/code/root edition/hash. New numeric wire values are decimal strings; existing schemas retain their historical numeric codecs.

## Semantic checks after structural decoding

All checks execute before durable mutation, or during pure evaluation for missing engineering applicability. Required hash/ownership/reference conflicts reject; well-formed incomplete drafts retain typed missing markers.

| Object / operation | Required semantic checks beyond JSON structure |
|---|---|
| Definition refs / root import | Canonical unique codes per kind, exact root/version, recomputed canonical definition hashes, no duplicate normalized IDs; every referenced code resolves in exact root |
| Port / interface / compatibility | Positive voltage/frequency/nameplate where present, ordered envelope, AC frequency required/DC frequency null, terminal convention fits kind, interface projections agree, connector/contact/protocol permitted kind; ordered profile endpoints match and family/media choices remain exact |
| Component / transfer definition | All referenced ports exist and are owned template roles; transfer input/output cannot alias incorrectly; efficiency in (0,1], idle accounting unambiguous; source origin explicit; no implied source from label |
| Bind/adopt/release | Existing placed component, exact field owners and expected revisions, template bijection, no extra requested port; new port IDs unique; connected candidate graph revalidated; reviewed fingerprint mandatory for impact changes |
| Load replacement | Correct input owner, unique load/state/origin, nonnegative demand, AC PF in (0,1], explicit zero not missing; duplicate physical own-load origin forbidden |
| Transfers/groups/supply requirement | Scoped owned input/output sets; group dimensions explicit and membership unique; derating (0,1], reserve>=1; alternative selection allowed and existing scenario selections remain valid or replaced atomically |
| Scenario | Unique segment IDs/ordinals, exact source/state refs, duration>0 where required; complete ordered sequence; no implicit label-driven source/state; charge/discharge exclusion |
| PoE binding | Correct PSE/PD roles, one existing path and exact resource/termination refs; compatible guarantee/pair/path provenance; no new allocation claim; unsupported explicit-loss mode cannot evaluate PASS |
| Backup/bank | Positive counts, homogeneous unit/arrangement applicability; 0<=minimumSOC<=initialSOC<=1; factor applicability explicit, source/EOD/charge voltage and current evidence compatible; protected outputs scoped and distinct |
| Calculate | PWR-04 requires SEQUENCE; other codes require SEGMENT. A single request with mixed process scopes is rejected; orchestrator creates linked segment batches and separate sequence publication with consumed generation checks. Every subject kind is supported by its process |
| Freeze v2 | Exact working token; CAPTURE_EMPTY requires empty active aspect set; no transient RUNNING predicate; recompute snapshots/manifest hashes |
| Create-next v2 | Verified frozen base; no active WORKING; allocator generation CAS; canonicalRestorePlan required on mismatch; complete typed physical remapping and no R1 operational refs |
| Evaluation | Correct logical key from scope, positive reduced denominator/gcd, interval lower<=upper, quantities/steps reference existing typed quantities, facts-map keys exactly equal dependency set, per-dimension aggregate status coherent, consumed segment refs verify sequence membership |
| History | Payload hashes match complete canonical stored commands; project/revision scope agrees; full aggregate refs resolve; operation is reversible under registered policy; cursor/branch CAS before new inverse/forward execution |

## Captured fact codec registry

`consumedFacts.valueSchema` resolves a registered codec, never arbitrary JSON interpretation. For canonical EngineeringPort/Connection/InternalConnectivity and existing cable/allocation/run evidence, use their existing versioned toMap/fromMap codec at the captured schema with immutable source ref. New current/demand/voltage/model facts use the exact typed definitions in power-command/catalog/evaluation schemas; an explicit MISSING fact records the expected codec and canonical `null`. Unknown mandatory codec blocks decoding. Pure fact access records each key; no ambient read can introduce an untracked value.

Canonical command schema ID and actual payloadSchemaVersion both enter ledger hashing/dispatch. Existing committed v1 revision commands replay through v1 decoder; a fresh v1 revision request is rejected by the new power-enabled adapter after replay lookup. New revision v2 intent cannot be executed by v1 codec. Calculate returns one scope per batch; subsequent SEQUENCE request references matching captured segment generations.

## Examples and expected validation

| File | Structural expectation |
|---|---|
| [minimal-power-catalog.json](examples/minimal-power-catalog.json) | Valid strict power-only root |
| [invalid-power-catalog.json](examples/invalid-power-catalog.json) | Reject unknown technical field |
| [set-zero-load-command.json](examples/set-zero-load-command.json) | Valid explicit state zero |
| [invalid-numeric-command.json](examples/invalid-numeric-command.json) | Reject numeric JSON value in new decimal-string field |
| [freeze-v2-command.json](examples/freeze-v2-command.json) | Valid explicit version/intent |
| [power-evaluation.json](examples/power-evaluation.json) | Valid scoped exact output with complete consumed facts |
| [invalid-missing-segment-evaluation.json](examples/invalid-missing-segment-evaluation.json) | Reject SEGMENT without segmentId |
| [persisted-history.json](examples/persisted-history.json) | Valid durable forward/inverse record |

Schema validation and these examples prove contract consistency only; public import/write/replay/migration execution still requires runtime implementation and its tests.
