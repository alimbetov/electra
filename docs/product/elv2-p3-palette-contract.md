# ELV2-P3 — discipline-aware pre-placement palette

Branch: `feat/flutter-elv2-profile-constraints`  
Parent: [ELV2 technical specification](elv2-profile-constraints-technical-specification.md)  
Engine: [P2 decision contract](elv2-p2-placement-compatibility-contract.md)

## Scope

P3 lets the engineer select an active project engineering system, inspect an exact
canonical profile edition and evaluate a candidate surface location before
placement. It creates no components, memberships, reference bindings, ports or
history entries. Atomic canonical placement remains P4; revision impact and
adoption remain P5/P6.

## Selection and inspection

In the room editor, choose **equipment → ELV profiles**. The system selector uses
the project's active systems. Discipline resolves from the exact family ID and
version, using the canonical CCTV/LAN/ACS/FIRE family codes, never display names.
An unresolved family edition produces no selectable profiles.

Profiles can be searched and filtered by engineering class. Each card opens
capabilities, port/interface templates, exact catalog identity/version/source,
mounting pairs, enclosure/clearance requirements, environment limits and topology
rules. Deprecated profiles remain inspectable but cannot start a new preview.
Legacy unspecified constraints remain explicitly unresolved. Inspecting a port
template resolves its interface provenance without instantiating a port.

## Candidate evaluation

**Preview on surface** activates a transient selection. Hover shows a candidate;
tapping fixes the point for editing its conditions. A second point or surface
resets all manually supplied conditions. **Done**, a different tool/discipline,
room change, or removal/change of the selected system/catalog clears the preview.
Geometry and topology snapshot changes reset candidate conditions as well.

The surface patch supplies project/room/surface identity only. Its orientation,
label and profile's allowed values are not evidence of installation surface,
mounting, exposure, IP protection, clearance or temperature. These facts start
unknown and can be explicitly entered in **Candidate conditions**. Empty values
stay unknown; non-finite numbers, negative clearance and invalid IP values cannot
be applied. Conditions are session state and are never saved to the project.

A pinned system topology resolves by exact project/ID/version. Its shape is
read-only; a missing edition stays unresolved and cannot be replaced by a manual
shape. Systems without a pinned topology may declare candidate shape and role.
Loop closure, actual degree, branching and ordering still require graph validation.

Every result comes from the existing `PlacementCompatibilityEngine`. The UI does
not reproduce engineering rules. Text, icon and marker color distinguish
COMPATIBLE, WARNING, FORBIDDEN and UNRESOLVED. The review panel renders the exact
profile/catalog provenance and structured expected/actual/remediation findings.
A compatible result proves only the declared candidate checks, not atomic
placement or whole-graph validity. P2 currently emits no warning rules; the UI
supports warning findings without manufacturing warnings.

## Acceptance evidence

- Application tests cover exact family/discipline filtering, stale selections,
  exact topology resolution and unknown defaults.
- Compact widget tests inspect constraints and interfaces for CCTV, LAN, ACS and
  Fire; candidate form tests pass explicit facts through the same P2 engine.
- Editor tests exercise unresolved → compatible → forbidden feedback, resetting
  facts when the surface changes, and cancellation without invoking placement.
- SQLite editor integration checks `total_changes()`, empty component/binding/
  membership/port tables and untouched undo/redo after preview and cancellation.
- Existing electrical placement and engineering-core tests remain CI gates.

This slice does not close ELV2. P4–P7 remain required before ELV3.
