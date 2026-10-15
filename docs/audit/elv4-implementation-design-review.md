# ELV4 — Implementation specification consistency review

Date: 2026-10-14
Branch: `feat/flutter-elv4-power-topology-design`
Inspected runtime source: `7f1c701cb4ba492589321f8f9827d20464ddaefb`
Preceding design commit: `ce8c971`
Scope: documentation, requirement traceability and fictional arithmetic; no app runtime execution.

## Result

All ten P0–P9 packages have detailed implementation specifications linked from the [implementation index](../product/elv4-implementation/README.md). There are 80 numbered requirements, eight per package, each with a planned acceptance ID. Runtime statuses are intentionally NOT_STARTED. This review is a design consistency check, not an approval or runtime closure gate.

## Design gaps resolved in this revision

| Item | Earlier ambiguity | Concrete refinement |
|---|---|---|
| DETAIL-01 | Consumer supply requirement had storage semantics but no general public mutation | ReplacePowerSupplyRequirement added to governing command inventories and P2, covering normal and backup consumers |
| DETAIL-02 | Empty initialized power versus uncaptured historical power lacked explicit command intent | New freeze schema declares CAPTURE_CURRENT/CAPTURE_EMPTY; create-next from pre-power history requires explicit empty initialization; old replay schemas retained |
| DETAIL-03 | New scoped aspect identity could conflict with globally unique canonical IDs | Composite revision/logical aspect PK defined; canonical IDs preserved; no FK to nonunique logical ID alone |
| DETAIL-04 | Current result freshness could be confused with engineering pass | Freshness, completion, assessment and execution defined separately, with per-dimension outcomes |
| DETAIL-05 | First electrical/PoE model slice was discretionary | Initial radial constant-current DC and guaranteed-PD PoE fixed; other model tags decode but evaluate BLOCKED until supported extension |
| DETAIL-06 | Missing return-resistance negative could incorrectly block a valid total-loop input | Negative switches to per-conductor mode without a known loop total; loop resistance is never doubled |
| DETAIL-07 | Numeric examples could be mistaken for complete physical verticals | Boundary oracles explicitly separated from complete FK-valid command verticals and physical feasibility |
| DETAIL-08 | Canonical edits/publish/freeze lacked one complete concurrency protocol | Design-token CAS, per-aspect CAS, pointer generation, immutable evaluations, bounded fresh-transaction retry and replay-first publication specified |

## Checks performed

- Parsed requirements.json: 80 unique IDs, exactly eight per P0–P9, each mapped to its design document and corresponding planned acceptance ID; no runtime PASS/evidence fabricated.
- Checked 53 local Markdown links across detailed implementation documents and ELV4 entry documents.
- Parsed eight design fixture records and verified PoE reserved/upstream values, DC trunk/branch voltage and power conservation, battery sequence/usable capacity, and independent UPS W/VA arithmetic using decimal calculations.
- Ran existing tracked-generated-artifact guard successfully.
- Ran git diff whitespace/error check successfully.

No Flutter/Dart analyzer, generated Drift, app tests, standards verification or actual SQLite race/migration test was executed for this documentation-only update. Planned test IDs are implementation obligations, not executed tests.

## Remaining runtime entry and review obligations

BASE-01…04 remain governed by the baseline alignment audit. Source-equivalent behavior, actual RC proof, codec compatibility and snapshot integration still require P0/P1/P2 evidence. Detailed schema/index/command changes must be implemented and validated through P8 before P9 may accept runtime closure. No ELV1–ELV3 historical status has been rewritten to manufacture acceptance.
