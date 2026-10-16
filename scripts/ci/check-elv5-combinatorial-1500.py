#!/usr/bin/env python3
"""Validate the ELV5 1500-case combinatorial engineering qualification contract.

This guard validates design requirements/distribution only. It does not claim
that the 1500 runtime qualification scenarios have already been executed.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
REQ = IMPL / "combinatorial-engineering-requirements.json"
PLAN = IMPL / "combinatorial-engineering-1500-plan.md"
PROCESS = IMPL / "process-registry.json"

PRIORITY = [
    "CCTV-02", "CCTV-03", "LAN-01", "LAN-05", "ACS-03", "ACS-04",
    "ACS-05", "FA-02", "FA-04", "FA-05", "FA-06",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    req = load(REQ)
    process = load(PROCESS)
    plan = PLAN.read_text(encoding="utf-8")

    require(req.get("schema") == "electra.elv5-combinatorial-engineering-requirements.v1", "unexpected combinatorial schema")
    require(req.get("status") == "DESIGN_HARDENED_RUNTIME_NOT_STARTED", "unexpected combinatorial status")
    require(req.get("scenarioTarget") == 1500, "combinatorial target must be exactly 1500")
    require(req.get("priorityProcessMinimum") == 72, "priority minimum must be 72")
    require(req.get("regularProcessMinimum") == 42, "regular minimum must be 42")
    require(req.get("systemWideScenarioCount") == 36, "system-wide count must be exactly 36")
    require(req.get("pairwiseCoverageTarget") == "100_PERCENT_LEGAL_PAIRS", "pairwise target must be 100% legal pairs")
    require(req.get("threeWisePolicy") == "TARGETED_HIGH_RISK_ONLY", "3-wise policy must be targeted high risk")
    require(req.get("priorityComputationalCore") == PRIORITY, "priority computational core drift")

    process_codes = [row.get("code") for row in process.get("processes", [])]
    require(len(process_codes) == len(set(process_codes)) == 27, "expected exactly 27 process codes")
    require(set(PRIORITY).issubset(set(process_codes)), "priority process missing from registry")
    regular = sorted(set(process_codes) - set(PRIORITY))
    require(len(PRIORITY) == 11 and len(regular) == 16, "expected 11 priority + 16 regular processes")

    priority_total = len(PRIORITY) * req["priorityProcessMinimum"]
    regular_total = len(regular) * req["regularProcessMinimum"]
    system_total = req["systemWideScenarioCount"]
    require(priority_total == 792, f"priority subtotal drift: {priority_total}")
    require(regular_total == 672, f"regular subtotal drift: {regular_total}")
    require(priority_total + regular_total + system_total == 1500, "11x72 + 16x42 + 36 must equal 1500")

    factors = req.get("factorModel", {})
    expected_levels = {
        "vectorClass": 5,
        "cardinality": 7,
        "composition": 6,
        "orderMode": 3,
        "sharedResourceContext": 4,
        "evidenceQuality": 4,
        "mutationState": 4,
        "projectScale": 4,
    }
    require(set(factors) == set(expected_levels), "factor-model inventory drift")
    for name, count in expected_levels.items():
        values = factors[name]
        require(len(values) == len(set(values)) == count, f"{name} must contain exactly {count} unique levels")

    requirements = req.get("requirements", [])
    require(len(requirements) == 12, "expected exactly 12 combinatorial requirements")
    require(len({row.get("id") for row in requirements}) == 12, "combinatorial requirement IDs must be unique")
    require(all(row.get("severity") == "MUST" for row in requirements), "all combinatorial requirements must be MUST")
    require([row.get("id") for row in requirements] == [f"ELV5-COMB-{i:03d}" for i in range(1, 13)], "combinatorial requirement sequence drift")

    required_plan_tokens = [
        "target: exactly 1500 deterministic scenarios",
        "42 scenarios for every process",
        "72 for 11 priority computational processes",
        "36 system-wide cross-process scenarios",
        "100% legal pairwise factor coverage",
        "targeted 3-wise coverage",
        "11 priority processes × 72 = 792",
        "16 regular processes  × 42 = 672",
        "system-wide scenarios       =  36",
        "total                       = 1500",
        "pairwiseCoveragePercent == 100.0",
        "electra.elv5-combinatorial-qualification.v1",
    ]
    for token in required_plan_tokens:
        require(token in plan, f"1500-case plan missing token: {token}")

    print("ELV5 combinatorial engineering qualification contract PASS")
    print("target=1500 priority=11x72=792 regular=16x42=672 systemWide=36")
    print("factors=8 legalPairwise=100% targeted3Wise=required runtimeExecuted=0")


if __name__ == "__main__":
    main()
