# Catalogue alignment with the professional electrical platform

Status: DESIGN PROPOSAL. Target branch inspected at
`9275c3546c1783055984ec7e656057f15a2bd6ec`; no target capability is marked
implemented/qualified/accepted by this dossier. See exact artifacts and hashes in
[design manifest](design-manifest.json).

## 1. Target reality and scope

The platform target has 21 CAP domains. Its killer-layer JSON currently has
14 entries K0–K13, including the separate K13 smart-building contract with ten
SH sub-capabilities. The inherited killer-layer Markdown still says K0–K12 /
thirteen; this known source discrepancy is recorded, not silently "corrected"
on the parallel target branch. This proposal maps all fourteen machine entries
and all ten SH entries; the next target reconciliation must align its prose.

The catalogue is a reusable input service for the whole electrical + ELV
platform, rather than a breaker-only lookup or a new calculation owner.
Families can be DESIGNED with no data/checker support. Electrical simulation,
reliability, photometry, room geometry and automation runtime are not provided by
registering catalogue parameters. Missing qualified producers remain explicit.

## 2. CAP-01…CAP-21 data contributions

| Capability | Catalogue contribution and owning boundary |
|---|---|
| CAP-01 Project model | Immutable adopted editions and self-contained snapshots; shared revision/command/freeze owner remains canonical |
| CAP-02 Topology | Typed terminals/ports, phase/neutral/PE semantics and internal connection capability; project topology supplies actual connections |
| CAP-03 Sources | Transformer/generator/UPS/battery/BESS/PV-inverter/ATS variant ratings, impedance/source capability evidence, transfer/control interfaces; grid study is owner input, not fabricated SKU data |
| CAP-04 Loads | Rated power/current, power factor/efficiency domains, demand/operating-mode evidence; project profiles own diversity, priority and actual demand |
| CAP-05 Boards/MCC | Bus/incomer/outgoing capacity, N/PE terminal capability, pole arrangement, kits and exact physical definitions; ELV6 owns placements |
| CAP-06 Conductors | Material, insulation, cross-section, loaded conductor basis, N/PE/PEN, resistance/thermal data, installation-domain references; no unverified ampacity from a marketing string |
| CAP-07 Calculations | Dimensioned, condition-bound parameter evidence for accepted electrical kernels; no formulas hidden in SKUs |
| CAP-08 Protection | B/C/D and typed residual/fuse classes, complete release/TCC/energy and coordination evidence, exact pair/conditions |
| CAP-09 Motors/drives | Motor/load curves, startup modes, duty, VFD/soft-starter settings and compatible starter/overload accessories; electrical owner calculates start/fault effects |
| CAP-10 Earthing/SPD | PE/PEN terminal, bonding and SPD type/system/impulse/interface evidence; actual earthing arrangement and electrode tests are project facts |
| CAP-11 Lighting/power | Luminaires, drivers, sockets, switches, multi-gang compatibility, emergency supply interfaces and physical footprints; no inferred lux coverage |
| CAP-12 ELV | CCTV/LAN/ACS/FIRE typed facets and exact power/media/mounting/accessory compatibility, shared with existing ELV2–ELV5 identities |
| CAP-13 Scenarios | Product operating-domain envelopes, ATS timing/interlock capability and source/control failure behavior; versioned project scenario engine owns execution |
| CAP-14 Reliability | Redundancy interface/independence constraints and provenance-qualified reliability data when available; no invented MTBF or uptime from a brand |
| CAP-15 Normative | Exact standards/product declaration references and applicability context; ELV7 verifies rules/claims |
| CAP-16 Selection | Candidate technical/physical/offer snapshots; AUTO_SELECTED / USER_SELECTED / USER_OVERRIDE reason, alternatives and explainable eligibility |
| CAP-17 SLD | Versioned symbol/terminal/rating bindings; diagram is a project topology view, not catalogue connectivity truth |
| CAP-18 Audit | Missing/untrusted/stale/obsolete/revoked/counterfeit-suspect identity findings; remediation candidates, never silent auto-fix |
| CAP-19 Deliverables | Equipment descriptions, quantities/units, accessories, installation pricing and selected snapshots for BOM/schedules/dossier; source model owns takeoff |
| CAP-20 Sharing | Embed exact selected technical/evidence closure in immutable shared revisions; exclude private supplier terms and restricted files under explicit export policy |
| CAP-21 Commissioning | Compare installed manufacturer/variant/serial evidence to designed edition, track inspection/test references; inspection records never mutate catalogue definitions |

Realized selection reason does not waive hard constraints. USER_OVERRIDE records
why an engineer chose an alternative; incomplete/noncompliant selections remain
flagged and cannot become a qualified configuration merely by confirmation.

## 3. K0…K13 catalogue contracts

| Capability | Required catalogue/configuration behavior |
|---|---|
| K0 Switchboard synthesis | Whole board variant incl. incomer/bus/N/PE/protection/accessories/reserve, phase policy and verified ELV6 fit; finalized circuit requirements first |
| K1 Project Autopilot | Requirement-driven architecture candidates with explicit source/asset needs; no SKU-driven topology mutation; actual topology/scenario kernels remain prerequisites |
| K2 Audit + Auto-Fix | Alternative technical editions/kits, dependency impact and complete validation before reviewed apply |
| K3 Failure X-Ray | Control/power dependencies of supplies/gateways/accessories exposed to failure owner; no failure propagation invented by catalogue |
| K4 Revision impact | Differentiate technical, geometry, source-trust, compatibility and offer changes with affected scope and preserved historic selections |
| K5 Multi-objective optimizer | Explicit objective vectors and Pareto frontier for comparable proven-feasible alternatives; weights/units and dominance semantics visible; no false global optimum |
| K6 Critical-power simulation | Exact normal/emergency/source-transfer operating capability and setting editions; electrical state and time simulation remains owner-produced |
| K7 As-built twin | Designed/installed/verified/commissioned evidence separate; same-looking vendor label does not prove equivalent rating or installed identity |
| K8 Vendor-neutral optimizer | Requirements before products; strict eligible set then complete cost/ranking; optional brand policy never weakens physical/normative facts |
| K9 Company rules | Versioned project/company overlays, preferred patterns and allowlists; no edits to vendor edition or override of mandatory law |
| K10 Brownfield | Preserve UNKNOWN/INFERRED/OBSERVED/VERIFIED identity and parameter evidence; partial nameplate/OCR is a candidate, not an authoritative product mapping |
| K11 Copilot | Read-only grounded lookup/explanation and proposed commands tied to edition/source; AI-generated product facts never enter approved data without validation |
| K12 Smart Room layout | Family-specific footprint, mounting surface, allowed orientations, physical grouping, switch/socket compatibility and supply/control interfaces; room/door/window/guide coordinates remain geometry-owner facts |
| K13 Smart Building | Protocol-agnostic sensor/actuator/controller capabilities, distinct protocol/transport and power/control/communication dependencies; design and commissioning data only |

Candidate lifecycle is GENERATE → PREVIEW → VALIDATE → SIMULATE (when required)
→ EDIT → ACCEPT under human authority. Cost-only optimization and AUTO_SELECTED
reason never authorize unreviewed mutation of an approved revision. Critical
functions, source modes, maintenance states and declared scenarios remain hard
constraints across every relevant candidate. Candidate trial evidence includes
its input/canonical/algorithm versions and cannot be copied as actual CURRENT.

## 4. K13 / SH-01…SH-10 detailed facets

| Sub-capability | Parameter/interface evidence |
|---|---|
| SH-01 Topology | Controller/gateway/sensor/actuator roles, compatible port/segment schema, bus supply demand and declared channel capacities |
| SH-02 Load binding | Real electrical load refs, actuator contact/dimming/starting-load domain and separately versioned control capability; no double-counted smart-device load |
| SH-03 DALI | Exact DALI family/capabilities, control gear/device distinction, bus power/address/group capacity and evidence; no global hard-coded bus limits |
| SH-04 KNX | Exact transport/interface, supply/line/coupler demand/capability, typed addressing profile; no automatic equivalence of Classic/IP/Secure/IoT |
| SH-05 Other ecosystems | Separate protocol and transport editions, regional radio applicability, frequency/power/product variant and gateway/bridge dependencies; Matter is not equated to Thread |
| SH-06 Scenes | Supported control-point types/ranges, command/fallback/manual-override capability; project scenes and priorities belong to automation owner |
| SH-07 Failure | Distinct electrical, control and communication availability; gateway/cloud/local dependencies explicit, unknown fallback not assumed |
| SH-08 Wizard | Room-role matching to typed sensors/actuators/control bindings and complete accessory power/space demand; candidates before mutation |
| SH-09 Matrices | Channel, sensor/actuator/control-point and terminal definitions for I/O/KNX/DALI/commissioning schedules |
| SH-10 Audit | Missing address/channel/gateway/fallback/security/commissioning facts become visible obligations; life-safety overrides comfort policy |

All protocolFamilies in the pinned K13 target are preserved as planned typed
reference values, not a declaration that an importer/protocol checker implements
them. Certification, firmware capability and compatible hardware revisions are
separate evidence. No passwords, fabric keys, Wi-Fi PSKs, KNX keys, pairing
secrets or cloud tokens belong in catalogue/project engineering packages. Actual
control/monitoring/automation is owned by external runtime ecosystems.

## 5. Delivery order and implementation gates

Use the existing ELV6 → ELV7 → ELV8 contract boundaries and target ELEC1–ELEC9
planning coordinates without pretending every future ELEC kernel already exists.
Recommended catalogue work packages:

1. C0: exact source/owner/legacy-FK audit, typed schema and import format; confirm
   ELV6 definitions and ELV8 public commands against actual runtime acceptance.
2. C1: separate store, typed family schema/edition publication, immutable
   source/technical/definition closure and legacy adapter; reopen/migration gates.
3. C2: offline offer books, quantity/pack/FX/tax/rounding policy and honest
   commercial coverage; no live supplier integration prerequisite.
4. C3: one complete breaker + required accessories + enclosure selection vertical
   through real ELV6/ELV7 owners and reviewed atomic apply, then offline replay.
5. C4: board synthesis K0 / vendor-neutral K8; complete SKU/accessory/BOM costs,
   deterministic bounded search, alternatives and Pareto output for K5.
6. C5: room/lighting K12 and automation K13 facets/bindings; qualify exact supported
   protocols/scenarios, with no smart-home runtime or secrets.
7. C6: broader sources/motors/conductors/earthing families aligned with qualified
   ELEC owners; audit/K2, impact/K4 and failure/K3 consume the same snapshots.
8. C7: as-built/brownfield, sharing/export redaction, commissioning and whole
   reference-building qualification on an exact SHA with unchanged regressions.

This ordering is a catalogue integration proposal. It does not reorder the target
killer-layer roadmap or mark a CAP/K/SH capability accepted. Every family has
independent data completeness, implementation and qualification state.
