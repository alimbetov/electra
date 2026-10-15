# P1 — Typed domain, catalog and operating scenarios

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Consumes P0 ownership map; supplies P2 schema, P3 graph and P4–P6 arithmetic.
Shared rules: [runtime contracts](shared-contracts.md).
Resolved audit decisions: [RM01–RM15](remediation-contract.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P1-001 | Implement typed validated quantities, edition refs and immutable value objects with explicit absent/zero semantics | P1-T01 domain boundaries |
| ELV4-P1-002 | Bind power roles to canonical port/component IDs with one owner per projected field | P1-T02 ownership conflict |
| ELV4-P1-003 | Define local transfers, efficiency accounting, capacity groups and unique own-load contribution identity | P1-T03 transfer/double-count validation |
| ELV4-P1-004 | Implement scenario segments, state/source selection, durations and charge/discharge interlock | P1-T04 scenario resolution |
| ELV4-P1-005 | Add versioned root-catalog power extension and generic equipment template support without changing old discipline codecs | P1-T05 legacy/new codec round-trip |
| ELV4-P1-006 | Model PoE delivery and bank/charger definitions with exact provenance and model applicability | P1-T06 PoE/bank definition checks |
| ELV4-P1-007 | Provide explicit legacy mapping/adoption preview; missing typed facts stay unresolved | P1-T07 legacy mapping |
| ELV4-P1-008 | Freeze process input/output/numeric schemas and exact canonical serialization behavior | P1-T08 deterministic fingerprints |

## Proposed value objects

| Object | Fields / constraints |
|---|---|
| PowerDefinitionRef | catalogId/version, code/version, definitionSchema, SHA-256, sourceRef; every field required and normalized according to existing rules |
| VoltageEnvelope | minV <= nominalV <= maxV, all positive; AC/DC required; frequency envelope for applicable AC; DC terminal polarity map |
| PowerPortDefinition | port template code, powerRole SOURCE/CONSUMER/BIDIRECTIONAL/PASSIVE, envelope, continuous limits and optional peak envelope |
| PowerTransferDefinition | kind, owned input/output template codes, enabled states, loss model, output-capacity-group refs and input accounting origin |
| PowerDemand | tagged DC_CONSTANT_CURRENT, DC_CONSTANT_POWER or AC_POWER union; state and own/downstream accounting origin |
| PowerCapacityDefinition | dimension W/A/VA or separate limits, member outputs, mode applicability, derating ref; no ambiguous scalar capacity |
| PowerScenarioSegment | stable segmentId, ordinal, durationSeconds when required, component states, source selections and availability set |
| PowerPolicyRef | explicit policy edition/hash and applicable purpose; absent does not imply standard reserve or hours |
| BatteryUnitDefinition | technology, unitV, ratedAh/Wh basis, compatible arrangement, rating conditions, usable-model definition |

Store exact facts; derived converted values belong to evaluation evidence. A component may have multiple auxiliary loads only with distinct input boundary/origin IDs. An own-load identifier cannot be both a consumer demand and separately added transfer idle.

Capacity-group nesting uses member port sets, not recursive budget arithmetic. Cyclic group inclusion is invalid; group members must belong to the declared owner unless an explicit supported upstream aggregate definition supplies the scope. Each limiting dimension is independent.

## Catalog extension wire contract

New catalog payloads declare a new explicit catalog schema understood by the new decoder. Proposed `power` section contains `schema: electra.elv4-power-definitions.v1`, arrays `portDefinitions`, `componentDefinitions`, `transferDefinitions`, `poeDefinitions`, `batteryDefinitions` and `policyDefinitions`. Every definition has a unique normalized code, sourceRef and typed body; definitionVersion equals its exact root catalog version in v1 (no separate wire field). The root hash and consumed definition hash preserve their distinct provenance purposes. References resolve within the exact root edition; no latest-version lookup.

A generic power component definition contains template ports and local transfers without a ReferenceDiscipline or CanonicalComponentClass requirement. Instantiation creates canonical ELV1 ports through a transaction-bound existing port writer. Existing ports require explicit template-to-port mapping, or an explicitly reviewed creation of missing ports; never match by label alone.

Absence of the extension means a legacy catalog, not an empty auto-generated extension. Old payload decode/encode and reimport retain original canonical content/hash. Unknown mandatory schema/union tag rejects import. Unknown optional metadata is preserved according to the codec's explicit policy, never silently reclassified as engineering evidence. A new writer must not emit an extended payload using an old schema identifier.

New extension definitions use immutable edition semantics. Deprecated editions remain readable for frozen/replay state; new bindings reject deprecated definitions according to the shared adoption policy. Root provenance includes the power section; technical power fingerprints isolate actually consumed definition contents and exact refs.

## Legacy projection and adoption

Preview compares current ELV1 voltage/powerDirection/demand/limit fields, existing ELV2 ownership and proposed typed fields. Output maps each field to PRESERVED, RESOLVED, UNRESOLVED or CONFLICT, with old/new exact provenance. A conflict rejects commit; unresolved engineering can remain a draft. No nominal voltage can invent a tolerance range; no powerLimitW can invent peak duration or PoE class.

Power profile release removes binding ownership, not the canonical port or ELV2 binding. The reviewed release action explicitly selects whether compatible shared-owned fields remain or power-owned fields become unspecified; it cannot restore obsolete values over a newer owner. Connected references are included in impact review.

## Acceptance details and work order

Implement quantities/ref → typed profiles → scenario resolver → extension decoder/encoder → validation → legacy mapping preview. Export public core types through engineering_core.dart only after tests.

P1-T01 includes NaN/infinity/negative and zero cases, PF/efficiency boundaries and voltage ordering. P1-T04 includes a BACKUP role containing separate standby/alarm segments and explicit unavailable mains. P1-T05 compares historical canonical bytes/hashes exactly, rejects unknown mandatory schema and checks generic PSU without a fake camera class. P1-T08 permutes unordered definitions and preserves ordered segment meaning.

Exit: P2 can derive tables and commands without inventing domain fields; P3–P6 consume the same typed unions and provenance. Solver support and national policies remain explicit rather than inferred from profile labels.

## Resolved domain/codec behavior

RM02/03 split nullable positive static nameplate from scenario demand including exact zero. Canonical projection has a field-by-field owner agreement; scenario selection is read-only. Bidirectional supply uses explicit bidirectional physical interfaces; no implicit direction rewrite. RM04 defines mandatory segment/sequence identities and RM09 exact-rational numeric v2.

RM05 and the strict [catalog schema](schemas/power-catalog.schema.json) replace an unspecified technical body with complete connector/protocol/interface/port/component/transfer/compatibility sections and power-only publication semantics. [Valid/invalid examples](examples/minimal-power-catalog.json) are supplied; invalid examples have an explicit invalid filename. Generic port instantiation must pass existing membership/family/compatibility checks.

Scenario role labels never select states/sources implicitly. Startup initially uses only RM12 ALL_SIMULTANEOUS. DC_CONSTANT_POWER is supported only in RM06's single unbranched feeder; all other such domains remain explicit model-limit cases. New wire models use decimal strings and semantic cross-field checks, not free-form maps.

Wire demand tags AC_POWER (explicit VA) and AC_POWER_PF (explicit PF) both resolve to the internal AC power-demand union with an explicit basis discriminator; no W=VA assumption. Exact new decimal parsing is separate from legacy canonical numeric projections.
