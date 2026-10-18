# ELV7 — Upstream handoff and ownership

Status: DESIGN CONTRACT. Pins and content hashes: [baseline manifest](baseline-and-handoff.json).

## Current source reality

ELV5 was merged into main as `29957ba9288c0bcf0d8d7ca061d46d2cdbf62fbd`.
Its audited runtime SHA is `b3dc15fe48ce1f75d6a4b737d881373d63efda30`,
CI run 39094948151. The source has 27 process adapters and exact-head executed
lifecycle/global reliability evidence. That report still has `qualified=0`
and `accepted=false`; a Git merge is not a substitute for the remaining
full qualification gates. ELV7 P0 records the actual acceptance authority,
rather than inventing accepted upstream state.

ELV6 proceeds independently. The inspected design commit is
`4778dae76a0315ab8bc04c9d63a3ac666aa9674d`, with 24 LAY process contracts and
additional normative safety projections. It is not an accepted implemented
runtime. The files inherited at ELV7 branch creation remain historical snapshots;
the pinned external files in the manifest are the reviewed handoff candidate.
No ELV6 branch/files are modified by this ELV7 design work.

On later ELV6 acceptance, update the handoff manifest with an explicit impact
review of field/unit/enum/schema changes. Do not replace hashes with `latest`.
Rules without ELV6 dependencies can be developed independently; a rule requiring
missing ELV6 runtime evidence remains NOT_EVALUABLE and blocks a formal complete
scope claim. No fake ELV6 projections to make a normative pack appear supported.

## Owners and adapters

| Facts | Canonical producer | ELV7 adapter obligation |
|---|---|---|
| AC protective device, release settings, source modes, Ik minimum/maximum and loop study | Existing electrical/protection owners, audited in P0 | Versioned complete projection or explicit gap; do not pretend ELV4 PWR supplies all AC studies |
| Actual cable/run/traversal, segregation and installed length | ELV3 | Typed physical identity, units and revision snapshots |
| Power/PoE/voltage/backup evidence | ELV4 | Exact consumed evidence hash, scenario, generation and completeness |
| CCTV/LAN/ACS/FIRE results and project-authored policy | ELV5 | Separate engineering PASS from legal applicability; map all 27 processes |
| LAY host/placement/service/mass/thermal basis | ELV6 | Exact layout schema, host, selected context and generation |
| Enclosure integrity | ELV6 | All openings/modifications and adopted seal/gland/closure definition hashes |
| Air clearance | ELV6 | Conductive regions, potentials, circuit identity, shortest distance in µm and algorithm version |
| Creepage | ELV6 | Surface-path length in µm, surface/material/CTI refs and path algorithm; unknown path is not air distance |
| Hazardous access | ELV6 | Access state, barriers and exposure evidence; never a generic touch-safe boolean |
| Partitions/separation | ELV6 | Geometry and adjacency; separation form is assessed from the adopted pack |
| Environment/insulation | Existing environment owner + ELV6 context projection | Altitude, pollution/material class, supply voltage and source edition; no ambient defaults |
| Mechanical/environmental capability | ELV2 definitions + ELV6 arrangement | Exact variant, test declaration and post-modification context |
| Bonding | Existing connectivity + ELV6 physical binding | Distinguish a geometric bond point from verified protective continuity/test evidence |

An assembly product rule, empty-enclosure rule, ICT rack requirement and machine
control requirement have different scopes. Do not apply IEC 61439 to every
rack simply because it contains equipment, or certify an assembled modified
enclosure from its empty-box declaration. An IP number is not a computed
minimum of device IP numbers. Thermal, mechanical, dielectric and test-based
verification methods need source-specific eligibility and supporting records.

## Profile vocabulary alignment

Canonical profiles remain `KZ-ELV-BASELINE` and `IEC-ISO-ELV-BASELINE` from the
standards matrix. ELV6 design labels `KZ_NATIONAL` and `IEC_BASELINE` map through
explicit aliases; they do not create new profile identities. `EU_CENELEC` and
`MACHINE_CONTROL_OPTIONAL` are separately adopted optional contexts.
`DISCIPLINE_CCTV`, `DISCIPLINE_LAN_ICT`, `DISCIPLINE_ACS`, `DISCIPLINE_FIRE` are
discipline bindings, not jurisdictions or source approval levels.

Preserve national applicability states CURRENT_NATIONAL,
ADOPTED_NOT_YET_INTRODUCED, WITHDRAWN, INTERNATIONAL_REFERENCE_ONLY and
PROJECT_EXPLICIT_OVERRIDE as reviewed relations to a source edition. They are
not equivalent to source verification status or permission to waive law.

## Revision and acceptance boundary

All adapters consume immutable owner snapshots with exact project/revision,
payload hashes and pointer generations. Source mutation, source disappearance,
new membership, same-output republish and previously missing data are separate
invalidation events. Cross-stage transactions share the accepted UoW boundary;
there is no best-effort background correction of a stale green result.

ELV7 freeze is append-only and cross-section bound. It never rewrites the
ELV4 v1 manifest or ELV5/ELV6 historical evidence. Create-next restores mutable
configuration only, using the accepted typed allocator/remapping services.
Qualification includes unchanged ELV4 regression contracts, ELV5 lifecycle,
ELV6 applicable safety projections and new ELV7 Q0–Q9 witnesses on one SHA.

## Coordinated ELV6–ELV8 agreement

The [shared agreement](../elv-integration/README.md) supplies exact proposed
requirement/evidence schemas and adapter obligations. ELV7 can derive requirements
without a completed ELV8 selection; actual assessments require committed owner
facts. Public freeze uses `FREEZE_DESIGN_REVISION` on
`electra.elv4-revision-command.v2`; `FREEZE_PROJECT_DESIGN_REVISION` is the
internal ledger type only. No new stage freeze or strict-v2 payload fields.

ELV6/ELV8 inspected source trees still have schema 23 while merged main/ELV7
has schema 24. This is a recorded runtime entry reconciliation gate, not proof
that an ELV6/ELV8 migration supports main already. Pins in earlier manifests
remain historical audit inputs; the agreement is the cross-stage amendment.
