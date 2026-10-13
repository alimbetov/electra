# Electra — ELV extension delivery plan

Source baseline: `b3f314d01f3cfdbcc78784b548fe250a0d595213` from `docs/elv-engineering-systems-spec`.
Implementation branch: `feat/flutter-engineering-systems-foundation`.

The eight source documents are adopted together: system specification, domain invariants, scenario validation, canonical disciplines, reference catalogs, calculation processes, normative matrix and standards audit. Scenario decisions and the standards audit refine the initial draft. The specification branch remains the reviewed requirements baseline; implementation takes place on a separate branch based on it, including the completed FL15 code.

| Stage | Outcome | Acceptance | Status |
|---|---|---|---|
| ELV0 | Family editions, project systems, non-owning participation of existing devices | One placed component belongs to LAN and CCTV without cloning; scope/deletion/version invariants and restart/migration tests pass | Implemented; exact-head CI gate required |
| ELV1 | Persisted ports, binary external connections, topology groups, internal connectivity and assemblies | CCTV, LAN, ACS and fire scenarios express their topology without new discipline-specific root tables | Next |
| ELV2 | Typed common and discipline catalogs, product port/capability templates and project snapshots | Catalog changes do not silently alter existing ports or project engineering data | Planned |
| ELV3 | Physical cable resources/allocations, route/run adapter and shared carriers | Two logical connections can allocate separate resources of one cable; one run occupies common route geometry | Planned |
| ELV4 | Power sources/converters, PoE, PSU, UPS/battery and enclosure aspects | Data/signal and power paths are separately traceable for the same physical device | Planned |
| ELV5 | Incremental common power/capacity/length processes with typed inputs and evidence | Source changes invalidate only dependent results; no numeric regulatory defaults | Planned |
| ELV6 | Dedicated CCTV, LAN, ACS and fire processes from approved profiles | Four independent discipline fixtures, evidence output and regression isolation | Planned |
| ELV7 | Discipline workspaces, editor filtering, connectivity and power overlays | Active system guides tools and hides passive layers while preserving physical identity | Planned |
| ELV8 | Schedules, equipment selection, shared BOM and report integration | Equipment/cable/port/power schedules drill down to the same source objects | Planned |

## ELV0 implemented slice

- Extensible, immutable family reference editions; bundled technical classifications for power, CCTV, LAN, ACS, fire, BMS and custom systems. These are classification data, not national rule packs.
- Project network instances with pinned family editions and optional versioned topology/normative profile references.
- Audited SQLite many-to-many membership of placed components. No copied geometry, no implicit system ownership and no physical-object deletion on detachment.
- Project screen for creating/editing systems and family editions, assigning/detaching existing devices, safe archival and explicit restoration.
- Additive schema 14, preservation of earlier electrical objects, restart/migration, duplicate-code, cross-project, family-version and archival tests; compact UI and failed-write draft coverage.
- System-specific palettes and room-editor visibility have not yet been implemented. References and roles are recorded without executing ELV engineering calculations.

## ELV1 contract gate

Before changing persistence for ports/topology, provide executable contracts and four scenario fixtures for:

1. component-owned persisted port instances and immutable template provenance;
2. versioned compatibility profiles: kind, direction, connector, protocol, voltage domain and capacity; unknown compatibility remains unresolved;
3. binary external connections with independent semantic layers and physical-realization state;
4. topology-group ownership, internal passive connectivity versus dynamic control behavior, and non-owning assembly membership;
5. deletion/retirement/migration commands that preserve unrelated physical and logical identities;
6. explicit legacy Circuit, room CableRun, generated panel and enclosure adapters.

## Normative work stream

Curate `KZ-ELV-BASELINE` rule by rule alongside infrastructure work. Every executable rule needs an exact verified document/edition/status, applicability, clause/provenance, typed parameters, precedence/conflict tests and an edition-upgrade workflow. International guidance is not automatically a Kazakhstan requirement. National fire rules and certification cannot be inferred from generic ELV formulas.

## Relationship to the electrical roadmap

FL16–FL20 remain electrical delivery milestones. Enclosure identity/capacity should be shared with ELV4 and FL16; ELV8 reuses FL17–FL19 BOM/estimate/report infrastructure. Do not build duplicate cabinet, route, report or recalculation subsystems. Electrical baseline closure does not imply that these ELV extensions are already delivered.
