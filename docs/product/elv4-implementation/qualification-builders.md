# ELV4 — Qualification fixture construction contract

Status: IMPLEMENTATION RECONCILED / RUNTIME ACCEPTANCE PENDING — see [current P9 audit](../../audit/elv4-p9-reconciliation.md).
Data: [qualification.json](qualification.json). Closure policy: [RM15](remediation-contract.md#rm15--qualification-manifest-required-dimensions-and-closure).

## Fact materialization

The manifest contains fully declared synthetic resolved engineering inputs. The named public-command builder turns them into project entities, never unchecked SQL. Prefix every logical component/port/path/aspect ID with case project ID; all exact catalog/model/policy definitions use the case edition/sourceRef. Builder records the resulting exact refs/hashes and actual public command IDs as fixture output; those are deterministic derivatives, not missing physical assumptions.

Create one fictional system for each declared system code using existing family editions. Attach each declared component membership explicitly. Generate canonical interface/compatibility definitions matching AC L/N, DC PLUS/MINUS, or declared PoE pair profile, with connector/protocol/kind/direction/capacity/envelope facts from the manifest. Reversible bank feeds use bidirectional interfaces and an exact selected-direction transfer. New root catalog wire follows the strict schema; an existing device discipline catalog may coexist as a separately pinned root edition.

Every path is an existing canonical connection plus cable/allocation/resource selection, termination and installed run/traversal IDs declared by the manifest. AC_BOUNDARY_NO_DROP_MODEL is an explicit fixture ideal AC transfer with zero model resistance and declared source/rating bounds; no AC conductor-sizing or national compliance claim is made. GUARANTEED_PD validates the declared maximum path length/stages/pair model and exact power passage, without subtracting the guarantee's loss allowance again. DC paths use exact declared loop resistance, contacts already included and 20C applicability.

Create passive mappings only from the explicit passiveMappings set. Distributor components in the ACS radial tree get explicit input-to-output DC distribution transfers, no conversion and zero declared own current as provided. For every converter, materialize distinct input/output boundaries, constant efficiency and declared idle accounting; never duplicate output load at input. PSE input is AC_POWER_PF at the manifest AC/PF values; UPS backup input is CP from declared output/efficiency. Source/group limits and reserve/derating policy are explicit facts, not guessed from labels.

Battery uses the manifest's explicit synthetic flat 24V envelope throughout its declared SOC window and rating conditions. This is a fictional model designed to make voltage/energy applicability decidable; it is not a real battery model recommendation. Both current and EOD checks must pass. Protect the stated downstream outputs, while PWR-04 energy is measured at bank source boundary including the CP feeder loss once. ExtensionPolicy NONE permits sequence margin, not extrapolated autonomy.

## Per-case command recipe

1. Create project/revision/placed components and exact immutable definitions from facts.
2. Bind/instantiate canonical templates with explicit IDs; attach each declared membership.
3. Connect and realize every listed path via ELV1/ELV3 public commands, including all terminations and traversal evidence.
4. Write component transfers, group constraints, exact state loads and source requirements; configure PoE and bank/backup aspects.
5. Replace exact ordered scenarios/segments/selections; inactive mains/charge transfers are explicitly excluded in backup.
6. Evaluate each required SEGMENT result set, then PWR-04 SEQUENCE with matching generation refs. RequiredContexts is an exact Cartesian obligation with each listed required dimension.
7. Assert COMPLETE/PASS/SUCCEEDED, all specified rational/interval oracles and power conservation. Freeze/create-next, reroute/edit in new revision and reopen as P8 requires.

Builder rejects an undeclared technical value rather than supplying a product/standards default. Identity/hash/timestamp derivation and localization are not technical engineering defaults. If a model input cannot be derived from these explicit facts, fixture construction fails and the manifest must be updated before the test is counted.

## Required supplemental positives

In addition to manifest verticals, RM08 durable redo, RM10 older-base restoration, RM12 startup envelope and RM14 freeze/publish serializations are mandatory positive integration cases with their explicit contract oracles. They cannot be replaced by negative validation tests. Runtime qualification report must include case/context/process/dimension plus actual source SHA/evidence; an empty or skipped row is not PASS.
