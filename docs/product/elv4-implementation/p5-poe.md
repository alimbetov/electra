# P5 — PoE delivery, patching and shared PSE budgets

Status: CORE RUNTIME CLOSURE IMPLEMENTED (P5-T01–P5-T08); application publication, reverse-index persistence and workspace qualification continue in P7/P8.
Consumes P1 exact profiles, P3 graph, P4 leaf demands and ELV3 physical evidence.
Shared rules: [runtime contracts](shared-contracts.md).
Resolved audit decisions: [RM01–RM15](remediation-contract.md).

## Required work and acceptance

| Requirement | Implementation obligation | Planned acceptance |
|---|---|---|
| ELV4-P5-001 | Resolve exact PSE/PD roles and supported declared delivery, never RJ45/Ethernet inference | P5-T01 profile resolution |
| ELV4-P5-002 | Validate full combined path, power-pass mappings and conducting resource evidence without new cable claims | P5-T02 patch/fiber/resource |
| ELV4-P5-003 | Implement GUARANTEED_PD allocation/guarantee accounting with loss allowance applied once | P5-T03 reserved budget golden |
| ELV4-P5-004 | Return BLOCKED for EXPLICIT_PATH_LOSS unless its exact pair/electrical model is implemented and verified | P5-T04 model boundary |
| ELV4-P5-005 | Check PD guarantee, per-port allocation and shared group budget independently | P5-T05 port/group overload |
| ELV4-P5-006 | Map PSE output demand to upstream input with own consumption/conversion exactly once | P5-T06 upstream accounting |
| ELV4-P5-007 | Model midspan/injector supply and data/power boundaries explicitly | P5-T07 injector path |
| ELV4-P5-008 | Include complete/missing path/group/scenario dependencies and restart-stable result evidence | P5-T08 invalidation/reopen |

## Core closure evidence

The pure-core implementation now closes P5-T01–P5-T08 without adding storage or Flutter dependencies:

- `poe_evaluation.dart` implements role/path/model/PD/port/group/midspan checks and PSE upstream conversion accounting.
- `power_dependency.dart` implements delimiter-safe `elv4-dep-v1` typed dependency identities, PRESENT/MISSING consumed facts, consumed-evaluation references and deterministic input diffs.
- `poe_evidence.dart` records PWR-06 consumed profile, delivery, shared-group membership/capacity, PSE loss model, scenario segment, physical path, allocation/run presence and the exact consumed PWR-01 evaluation. Its input fingerprint is enumeration-order independent and restart-stable.
- `power_bottom_up_evidence.dart` persists the parent-facing PWR-01 boundary result after P5 without reconstructing child losses.
- `poe_orchestration.dart` fixes the dependency direction as `leaf PWR-01 -> PWR-06 -> parent PWR-01 -> PWR-02`. PSE efficiency/idle belongs only to PWR-06; reserve/derating belongs only to PWR-02.
- Shared PSE demand is owned by the canonical group identity. The P4 adapter uses `POE_GROUP:<groupId>` and `P5_PSE_GROUP_TRANSFER_<groupId>`, preventing one group-wide upstream demand from being summed once per PD delivery.

Targeted core gate `38725967815` passed formatter, full `dart analyze` for `engineering_core`, P5 dependency/evidence/orchestration tests and adjacent P4/P5 regression tests. The temporary gate was removed after the successful run. This is a core-runtime closure claim only; it does not claim completion of P7 publication races/reverse indexes or P8 workspace/mobile acceptance.

## Core API and profile fields

`evaluatePoeDelivery(PoeEvaluationInput) -> PoeEvaluationResult` implements ELV-PWR-06. Input contains graph segment, PD demand, exact PSE/PD delivery definitions, selected accounting mode, path realization and group membership. Output contains pdDemandW, guaranteedPdW, reservedPseW, estimatedActualPseW when supported, pdMarginW, per-port/group utilization and upstream demand basis.

Delivery definition identifies supported profile code/edition, pair/terminal semantics, voltage/current bounds, PSE output allocation and guaranteed PD capability at its stated boundary, allowed media/path evidence and provenance. The code is an exact catalog identifier, not parsed text from a device label.

## Path validation

Walk existing external connections and explicit passive mappings from PSE output to PD input. For each wired segment require the existing allocation, reserved resources, termination mapping and canonical installed path needed by the selected model. Reserve/activate those through ELV3 commands separately; PoE bind records references and never reserves the same resources again.

Multiple patch cords are multiple existing physical cables along one delivery path; do not invent one duplicate end-to-end cable. Power/data share the same realization of each combined segment. A passive path must explicitly allow power at every stage. A data-only patch, fiber segment, unresolved polarity/pair map or unavailable PSE blocks power delivery while data behavior remains independently available.

Connection, allocation or run edits invalidate PoE even when the logical endpoints do not change. Guaranteed-PD accounting still requires applicable physical/path limits; it is not a license to ignore an arbitrarily long or unverified cable.

## Accounting mode behavior

GUARANTEED_PD: require pdDemandW <= guaranteedPdW, reservedPseW <= port allocation limit and sum distinct reservedPseW <= group reserved budget. No extra cable-loss subtraction from the already guaranteed PD value. Group input-demand basis is explicitly CONSERVATIVE_RESERVED or a separately supported actual estimate; defaulting silently between the two is forbidden.

Fictional golden: PD 10W/15W, guarantees sufficient for each, reserved allocations 12W/18W and shared budget 35W → 30W reservation, 5W margin. With PSE eta .9 idle-exclusive plus 5W idle, conservative upstream input is 38.333…W. That number enters P4 once. A 29W budget fails the group; a 17W limit on the second port fails that port even with enough group capacity.

EXPLICIT_PATH_LOSS is represented in codecs but blocked in the first supported slice until a versioned pair-resistance/load model is implemented. A generic two-wire DC drop algorithm is not automatically a valid balanced-pair PoE model. Enable only with positive/negative voltage/current/resource and loss-boundary tests plus explicit scope update.

## Midspan and failure behavior

Injector has data input, combined output and separately powered supply input. Its conversion/own load follows P4. The data uplink need not source its power. A media converter that transitions fiber to copper requires explicit powered ports and supported delivery definition; fiber itself never becomes conductive power.

Mismatched PSE/PD roles or contradictory profile hash is structural/integrity failure for binding. Missing installed path can persist as a draft; evaluation is unresolved. Known over-budget is a complete numerical result with FAIL. Unsupported delivery is BLOCKED with exact model reference and remediation.

Exit: CCTV and LAN can share a single project PSE/UPS basis, preserve one canonical path realization, explain all power boundaries and reopen identical evidence.

## Resolved qualification and identity contract

PoE evidence is per SEGMENT (RM04); guaranteedPdW, reservedPseW, per-port/group limits, pair/path applicability and complete passive passage are explicit in qualification inputs. New catalog/command wire uses RM05/RM11 schemas and RM09 decimal values. Generic injector supply/membership/compatibility is a public-command positive case. Existing data/power resources remain single claims. EXPLICIT_PATH_LOSS stays unsupported in the first scope and is a separate negative case, never a substitute for a passing guaranteed-PD qualification.
