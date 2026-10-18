# ELV8 — Marking, Printing, Panel Deliverables & Exact Equipment Amendment

Status: **DESIGN AMENDMENT / RUNTIME NOT CLAIMED / ACCEPTANCE NOT CLAIMED**

This amendment is normative for future ELV8 runtime entry. It freezes how canonical engineering identities, ELV6 panel-layout evidence, ELV7 normative findings and exact catalog equipment become deterministic professional deliverables. ELV8 does not redefine upstream identities, geometry or electrical physics.

## 1. Ownership

```text
canonical Cable/Circuit/Panel identity    -> upstream owners
panel hierarchy / 2D placement / routing -> ELV6
normative identification requirements    -> ELV7
exact product/SKU selection              -> ELV8
marker templates / print / QR projection -> ELV8
BOM / schedules / dossier                -> ELV8
fault/disturbance study results          -> shared electrical producer
```

## 2. One canonical identity, many projections

ELV8 MUST preserve one canonical engineering code across all generated views.

Example for cable `DB01-LGT-017`:

```text
project model
 -> plan / route annotation
 -> SLD annotation
 -> panel/terminal plan
 -> cable schedule
 -> source-end marker
 -> destination-end marker
 -> QR lookup
 -> commissioning record
```

ELV8 MUST NOT allow a print template to substitute an unrelated engineering identifier.

## 3. Identification and marker model

Target subjects:

- Cable;
- CableCore/conductor/pair/fiber where exposed by the media model;
- Circuit;
- ProtectiveDevice;
- Panel/switchboard/MCC;
- TerminalBlock / Terminal;
- Device/load/field component;
- Port / patch-panel port;
- PLC/remote-I/O channel;
- automation sensor/actuator/channel.

Target marker classes:

```text
CABLE_END_SOURCE
CABLE_END_DESTINATION
CABLE_INTERMEDIATE
CABLE_CORE
TERMINAL
TERMINAL_BLOCK
DEVICE
PANEL
PORT
IO_CHANNEL
QR_ASSET
```

Representative contracts:

```text
IdentificationPolicy
MarkerTemplate
MarkerProjection
MarkerBatch
QrAssetProjection
```

`MarkerProjection` SHALL reference the canonical subject, source project revision, identification policy version, template version and deterministic projection fingerprint.

## 4. Source / destination cable markers

A project policy MAY generate a marker such as:

```text
CABLE: DB01-LGT-017
FROM:  DB-01 / QF17 / X1:24
TO:    ROOM-204 / L-204-01
```

The opposite end MAY reverse FROM/TO presentation but MUST retain the same cable identity and exact termination references.

## 5. Printer-neutral output is mandatory

Initial professional outputs:

- deterministic PDF label sheet;
- CSV/XLSX marker schedule;
- printer-neutral marker dataset;
- QR payload dataset.

Brady, Phoenix Contact, Weidmüller, Brother, DYMO and other vendor adapters are optional downstream adapters. Printer/vendor semantics MUST NOT become the canonical domain model.

## 6. QR and commissioning

A QR projection SHALL resolve an exact project asset/revision context suitable for K7 / CAP-21 workflows.

Target scan context may include:

```text
asset identity
panel / feeder / circuit context
source and destination termination
selected equipment reference
installed/verified/commissioned state
field evidence references
project revision
```

The QR itself is a projection; it MUST NOT contain mutable engineering truth that can diverge from the project model.

## 7. 2D panel deliverables

ELV8 SHALL consume ELV6 `Panel2DLayout` and hierarchy evidence to generate at least:

- panel front layout;
- DIN rail layout;
- cable-entry plan;
- terminal plan;
- wiring/termination schedule;
- cable/core/device labels;
- panel schedule;
- hierarchy/feeder schedule;
- BOM references;
- deterministic PDF pages.

The output MUST preserve layout revision/fingerprint and exact source project revision.

## 8. Exact catalog/SKU physical data

When an exact product is selected, ELV8 may supply physical/catalog facts required by ELV6, including:

```text
mountingType
moduleWidthUnits?
widthMm
heightMm
depthMm
requiredClearanceMm?
heatDissipationW?
terminalLocations?
accessoryZones?
compatibleRailOrMountingSystem?
gland / gland-plate compatibility?
```

Engineering requirement comes before SKU selection. A catalog offer or price MUST NOT redefine the electrical requirement.

Missing mandatory product geometry/evidence is `UNKNOWN` and may block exact-layout acceptance.

## 9. Panel hierarchy and repeated-floor deliverables

ELV8 SHALL preserve:

```text
MDB
 -> floor panel instances
 -> local/system panels
 -> feeder bindings
 -> circuits
```

For repeated floors, reports MUST distinguish template identity, instance identity and explicit overrides. A template revision MUST NOT silently rewrite previously frozen deliverables.

Useful target reports include:

- hierarchy tree;
- main-board outgoing feeder schedule;
- floor-panel schedules;
- repeated-floor instance comparison;
- template-versus-override report;
- aggregated BOM by panel/floor/building.

## 10. Electrical-study deliverables

ELV8 MAY include qualified study summaries referenced by `ElectricalStudyRef` from `elv-integration/electrical-study-handoff-contract.md`, including:

- short-circuit study summary;
- protection/breaking-capacity evidence;
- voltage-disturbance/motor-start summary;
- source-transfer/critical-power scenario trace;
- scenario matrix.

ELV8 MUST NOT recalculate these studies during rendering. It renders exact versioned results and their provenance/freshness state.

A stale or incomplete required study MUST be visible in the dossier; rendering MUST NOT turn it into PASS.

## 11. Invalidation

The following changes SHALL invalidate dependent projections:

- cable/panel/device identifier change;
- termination change;
- cable-entry assignment change;
- ELV6 layout/hierarchy fingerprint change;
- ELV7 marking requirement/ruleset change;
- selected product/SKU revision change;
- source study result/fingerprint/freshness change;
- project revision change.

Frozen historical deliverables remain reproducible from their exact source versions.

## 12. Qualification

Future qualification SHALL prove at least:

- label identity continuity across plan/SLD/panel/schedule/print/QR;
- deterministic PDF/CSV/XLSX ordering and content;
- source/destination marker reversal without identity mutation;
- repeated-floor template/instance/override reporting;
- exact-SKU geometry provenance;
- stale study visibility;
- freeze/replay invariance;
- no vendor-printer lock-in of canonical data.
