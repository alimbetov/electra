#!/usr/bin/env python3
"""Verify the 450-case market simulation is explicitly bound to every ELV5 P0-P9 package."""
from __future__ import annotations

from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"


def load(name: str):
    return json.loads((IMPL / name).read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    bindings = load("market-simulation-p0-p9-bindings.json")
    base = load("requirements.json")
    market = load("market-simulation-requirements.json")
    catalog = load("market-simulation-catalog.json")

    require(bindings.get("schema") == "electra.elv5-market-simulation-p0-p9-bindings.v1", "unexpected market P0-P9 bindings schema")
    require(bindings.get("scenarioMatrixTarget") == 450, "P0-P9 bindings must target the exact 450-case matrix")
    packages = bindings.get("packages", [])
    require(len(packages) == 10, "expected exactly 10 P0-P9 market binding rows")
    require({row.get("package") for row in packages} == {f"P{i}" for i in range(10)}, "P0-P9 package set mismatch")

    base_rows = base.get("requirements", [])
    base_ids = {row["requirementId"] for row in base_rows}
    require(len(base_rows) == 80 and Counter(row["package"] for row in base_rows) == {f"P{i}": 8 for i in range(10)}, "stable base requirement inventory drift")
    market_rows = market.get("requirements", [])
    market_ids = {row["id"] for row in market_rows}
    require(len(market_ids) == 12, "expected 12 market-simulation requirements")

    seen_base: list[str] = []
    seen_market: set[str] = set()
    for row in packages:
        package = row["package"]
        requirement_ids = row.get("baseRequirementIds", [])
        require(len(requirement_ids) == 8, f"{package} must bind its exact eight stable requirements")
        require(all(req_id in base_ids and req_id.startswith(f"ELV5-{package}-") for req_id in requirement_ids), f"{package} contains invalid base requirement binding")
        seen_base.extend(requirement_ids)
        market_requirement_ids = row.get("marketRequirementIds", [])
        require(market_requirement_ids, f"{package} must bind at least one market-simulation requirement")
        require(all(req_id in market_ids for req_id in market_requirement_ids), f"{package} references unknown market requirement")
        seen_market.update(market_requirement_ids)
        require(row.get("purpose") and row.get("checks") and row.get("errorClasses") and row.get("evidence"), f"{package} market binding is incomplete")

    require(len(seen_base) == 80 and len(set(seen_base)) == 80 and set(seen_base) == base_ids, "P0-P9 binding must cover every stable base requirement exactly once")
    require(seen_market == market_ids, f"market requirements not covered by P0-P9 binding: {sorted(market_ids - seen_market)}")

    catalog_paths = catalog.get("packagePaths", {})
    all_packages = {package for path in catalog_paths.values() for package in path}
    require(all_packages == {f"P{i}" for i in range(10)}, "catalog package paths do not cover P0-P9 in aggregate")

    p8 = next(row for row in packages if row["package"] == "P8")
    p9 = next(row for row in packages if row["package"] == "P9")
    require("exactly 450 generated cases" in p8["checks"], "P8 must explicitly own exact 450-case verification")
    require(any("design-simulation-as-runtime" in check for check in p9["checks"]), "P9 must prohibit design simulation from masquerading as runtime acceptance")

    print("ELV5 market simulation P0-P9 bindings PASS")
    print("packages=10 baseRequirements=80 marketRequirements=12 scenarioMatrix=450")


if __name__ == "__main__":
    main()
