# Catalogue-driven automatic configuration and ELV6 layout

Status: DESIGN PROPOSAL. Selection is owned by ELV8; this contract does not
introduce product-selection logic into ELV6 or a statutory rules engine in the DB.
The external candidate designs are pinned in [manifest](design-manifest.json).

## 1. Owners and required physical facts

| Owner | Produces / consumes |
|---|---|
| ELV2 / reusable technical catalogue | Immutable exact product definition editions, electrical/interface data, physical definition bindings, source and compatibility evidence |
| ELV3/ELV4/ELV5 | Routes, loads, voltage/fault/backup and discipline requirements/evidence; AC studies are not fabricated from DC/PoE results |
| ELV6 | Arrangement and real LAY evidence for adopted host/equipment definitions; proposed layout evaluation uses the same versioned kernels |
| ELV7 | Applicable normative constraints and qualified assessments from exact sources; technical and project-policy PASS is not legal compliance |
| ELV8 | Candidate matching, whole-assembly selection and cost ranking, reviewed apply and BOM/reports |
| Supplier offer books | Observed commercial data with pinned date, currency, units and terms; no engineering authority |

A full cabinet/rack cannot be configured from `moduleWidthUnits` and nominal
width/height/depth alone. Exact ELV6 physical definition bindings include:

- local body, protrusion and terminal/accessory geometry with admissible orientation;
- mounting requirements, DIN/rack/backplate interfaces, hole/rail positioning,
  depth and fasteners, allowed surface/host relations;
- working, wiring, removal and ventilation envelopes, cable-entry/gland geometry,
  terminal locations/cable range, bend-space and installation constraints;
- mass, CoG basis, support capabilities and mounting-induced limitations;
- heat-loss-versus-operating-point evidence and airflow/derating conditions;
- openings, seals/barriers, conductive regions, insulation surfaces and material
  provenance needed by the ELV6 safety projections and later ELV7 assessment.

Use integer µm/grams and existing physical definition owner IDs/hashes, never
infer a standard module pitch or rack clearance from a commercial label. A
manufacturer-declared dimension is a fact, not proof of normative suitability.
The catalogue owns no placement coordinates or second layout writer.

## 2. Configuration is a graph, not independent cheapest-item queries

Candidates form assembly graphs: main device, upstream/downstream coordination,
busbar, terminals, auxiliary contacts, releases, mounting kits, communication
modules, power supplies, protective covers and required fasteners. Connections
carry exact interface, voltage/polarity, family, capacity and settings constraints.

Compatibility evidence states directional/symmetric semantics, exact product
editions/settings, applicability domain and source. Same brand or series does not
prove compatibility. Cascading/selectivity requires the ELV7 pair/domain evidence.
Rules can require alternatives, minimum counts, exclusions and shared capacity;
reject cycles. Prevent duplicate
accessory quantities and account for one shared supply or busbar only once.

Named configuration templates are immutable, versioned declarative graphs of
roles, required parameters and permitted alternatives. They reference supported
checker IDs and source/profile editions. Examples: a DIN distribution panel, a
PoE rack or an ACS power/control cabinet. A user-authored template is not a
certified assembly. Registering a template never allows arbitrary executable code.

## 3. Proposed orchestration APIs

```dart
abstract interface class CatalogSnapshotReader {
  Future<CatalogReadSnapshot> capture(CatalogSelectionScope scope);
}
abstract interface class ConfigurationPlanner {
  Future<ConfigurationProposal> propose(ConfigurationRequest request);
}
abstract interface class ConfigurationApplicationService {
  Future<CommandOutcome> applyReviewed(ApplyConfigurationCommand command);
}
```

Signatures are design interfaces, not implemented services. Request includes
project/revision, selected hosts/circuits/scenarios, exact requirement/normative
fingerprints, catalogue/offer/FX manifests, installed/pinned products, approved
budget/objective policy, reserve/installation constraints and solver limits.
No hidden reading of newest catalogue, network, ambient defaults or system clock.

## 4. Deterministic solve and result semantics

1. Capture immutable project requirements/generations, catalogue manifest,
   applicable normative profile and commercial snapshot.
2. Filter with typed hard constraints. Each candidate is ELIGIBLE / INELIGIBLE /
   UNRESOLVED, with per-constraint source, result and reason. Unsupported mandatory
   evidence cannot participate in a confirmed feasible solution.
3. Expand complete accessory/compatibility closure and supplier quantity rules.
4. Evaluate candidate arrangements through the real ELV6 kernels on a proposal
   snapshot. Join normative/product checks through ELV7. A catalogue dimensional
   filter alone is only a prefilter; it is not LAY PASS.
5. Search globally across product and host alternatives. A different cabinet,
   breaker width, PSU heat loss, busbar or cable termination can change feasibility.
   Respect existing fixed positions/products and prohibited substitutions.
6. Rank only proven feasible complete configurations using an explicit objective
   policy. Default economic comparison uses comparable full-BOM cost within the
   required quality/availability constraints; alternative policies can prioritize
   fewer changes, lead time, reserve or service cost. Brand preference is a soft
   preference unless the project explicitly makes an allowlist a hard constraint.
7. Return alternatives, limiting constraints, exact BOM, price coverage, layout
   evidence, assumptions and a reproducible solver/capture fingerprint.

Numeric scores cannot compensate for a failed electrical/normative/layout
constraint. Unknown mandatory physical data produces UNRESOLVED, never "fits".
A candidate can be technically feasible but UNPRICED. If the objective requires
a comparable complete price, such a candidate cannot win a cheapest-proof claim;
show it in a separate unresolved-commercial set. Budget may be an explicit hard
constraint only when the cost scope is complete and comparable.

Search termination is explicit: OPTIMAL_PROVEN, FEASIBLE_BOUNDED_SEARCH,
NO_FEASIBLE_SOLUTION_PROVEN, INCOMPLETE_SEARCH or BLOCKED_INPUT. A timeout is
not infeasibility and a first feasible result is not proof of cheapest. Deterministic
canonical ordering/tie-breaks and fixed node/iteration budgets reproduce bounded
results; elapsed timeout/cancellation is recorded and cannot masquerade as a
repeatable optimum. Record solver version, objective, bounds/gap, visited nodes,
input hash, result hash and every candidate exclusion. Do not claim an AI model
can substitute for evidence. A future learned ranking may propose search order;
all hard eligibility and final validation stay deterministic and auditable.

## 5. Price and engineering invalidation

A price/stock/FX change invalidates the economic proposal and commercial report
only if they consumed it. It does not change existing selected technical facts,
geometry or normative results. It may propose a cheaper alternative; applying
that alternative is a separate reviewed engineering mutation.

A technical edition adoption, accessory, release setting or host change invalidates
all affected owner closures, including ELV6 geometry/thermal and ELV7 constraints.
A newly appearing product affects a proposal that searched that catalogue scope;
selector generations include empty search results. A historical frozen estimate
keeps its exact offer/FX/rounding manifest; a fresh quotation creates a new result.

## 6. Reviewed atomic application, freeze and restart

Before apply show exact products/hosts added, removed or changed, price coverage,
all impacted circuits/ports/placements and required recalculations. No procurement
or external messages occur. Apply uses the shared project command ledger, replay
before frozen/revision preconditions, durable deterministic rejection and one
project UoW. Expected design/owner/pointer/profile/trust/selection generations and
reviewed impact/proposal hash are server-checked; stale previews are rejected.
Copy the complete immutable catalogue/price/definition closure before writing
selection/placement changes. Catalogue deletion during apply cannot create a
dangling project reference or partial command success.

Coordinate existing canonical owner writers without nested independent commits.
If any affected owner cannot participate in the shared transaction, the full
configuration apply remains blocked pending that integration; do not use compensating
writes and call them atomic. Mark dependent results stale in the same transaction.
Long-running recalculations publish afterward through capture/CAS. The proposal's
trial LAY/ELV7 results are not automatically CURRENT facts of the actual design;
after apply require real owner results before claiming validated configuration.

Preserve catalogue/product/offer references and snapshots in the shared freeze
extension; never update existing ELV4 manifests. No independent freeze command.
Create-next restores selected mutable configuration under the existing typed
remapping protocol, then requalifies CURRENT evidence. It does not copy current
compliance, quote freshness or historical project receipt IDs as valid new results.
A reopened historical revision needs neither catalogue file nor remote supplier.

## 7. Shared projection and report ordering

Use the [integration registry](../elv-integration/interface-registry.json) for
exact proposed snapshot/requirement/evidence schemas. Preselection requirements
do not depend on actual selected-product PASS. Candidate trial results remain
in a separate evaluation space; same-UoW owner participants apply reviewed
changes before committed owner revalidation. Freeze selection/adoption first,
then assemble reports referencing the frozen root; never hash a future report
into the source root or rewrite frozen sections after rendering.


## 8. Generator / PV / storage configuration

Use [the source-system amendment](../elv-integration/source-systems-contract.md)
for all-mode source/ATS/inverter/battery/host/accessory eligibility. A low-cost
normal-grid candidate that cannot prove required generator/island/UPS-bypass/fault
behavior is not a validated configuration. Missing qualified source/energy/transfer
producer or required site authority is an explicit blocker. The configuration
planner does not implement a hidden AC-fault, PV-yield or battery-SoC simulator.
