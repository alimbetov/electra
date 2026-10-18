#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"

ALLOWED_FAMILIES = {
    "GEOMETRY_BOUNDED",
    "FLOW_ACCOUNTING",
    "TIME_INTEGRATION",
    "RESOURCE_CAPACITY",
    "ORDERED_PATH",
    "OPTICAL_INTERVAL_BUDGET",
    "PHYSICAL_EVIDENCE_WRAPPER",
    "TOPOLOGY_CONSTRAINT",
    "POLICY_EVIDENCE_BASIS",
}


def load(name: str):
    return json.loads((IMPL / name).read_text(encoding="utf-8"))


def main() -> None:
    process_registry = load("process-registry.json")
    algorithm_registry = load("algorithm-registry.json")
    engine = (IMPL / "calculation-engine-contract.md").read_text(encoding="utf-8")

    assert algorithm_registry["schema"] == "electra.elv5-algorithm-registry.v1"
    assert algorithm_registry["status"] == "DESIGN_HARDENED_RUNTIME_NOT_STARTED"
    assert algorithm_registry["processCount"] == 27
    assert algorithm_registry["marginConvention"] == "POSITIVE_IS_ACCEPTABLE_HEADROOM"
    assert algorithm_registry["verdictPolicy"] == "CONSERVATIVE_REQUIRED_DIMENSION_COMPARISON"

    process_codes = {row["code"] for row in process_registry["processes"]}
    rows = algorithm_registry["processes"]
    by_code = {row["code"]: row for row in rows}

    assert len(rows) == len(by_code) == 27
    assert set(by_code) == process_codes

    for code, row in by_code.items():
        families = row["families"]
        assert families and set(families) <= ALLOWED_FAMILIES, (code, families)
        assert row["operatingCases"], code
        assert row["governingRule"], code
        assert row["marginPolicy"], code
        assert row["limitingFactor"], code

    expected_counts = {
        "CCTV-": 6,
        "LAN-": 7,
        "ACS-": 6,
        "FA-": 8,
    }
    for prefix, expected in expected_counts.items():
        actual = sum(1 for code in by_code if code.startswith(prefix))
        assert actual == expected, (prefix, actual)

    wrappers = {
        "CCTV-04", "LAN-03", "ACS-03", "ACS-04", "ACS-05",
        "FA-03", "FA-04", "FA-05", "FA-06",
    }
    for code in wrappers:
        assert "PHYSICAL_EVIDENCE_WRAPPER" in by_code[code]["families"], code

    assert "OPTICAL_INTERVAL_BUDGET" in by_code["LAN-05"]["families"]
    assert "GEOMETRY_BOUNDED" in by_code["CCTV-01"]["families"]
    assert "FLOW_ACCOUNTING" in by_code["CCTV-02"]["families"]
    assert "TIME_INTEGRATION" in by_code["CCTV-03"]["families"]
    assert "TOPOLOGY_CONSTRAINT" in by_code["ACS-06"]["families"]
    assert "TOPOLOGY_CONSTRAINT" in by_code["FA-07"]["families"]

    required_engine_tokens = [
        "One calculation lifecycle for all processes",
        "Conservative comparison protocol",
        "Governing case and limiting factor",
        "Margin, utilization and headroom",
        "Deterministic calculation trace",
        "Sensitivity and what-if analysis",
        "Verdict derivation",
        "Definition of done for a calculation process",
        "Monte Carlo/random simulation is NOT part of ELV5 pass/fail logic",
        "positive = acceptable headroom",
    ]
    for token in required_engine_tokens:
        assert token in engine, token

    print(
        "PASS: ELV5 unified calculation engine — 27/27 process mappings, "
        "solver families, operating cases, governing rules, margins and limiting factors"
    )


if __name__ == "__main__":
    main()
