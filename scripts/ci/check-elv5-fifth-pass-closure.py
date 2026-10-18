#!/usr/bin/env python3
"""Verify ELV5 fifth-pass specification-closure authorities stay synchronized."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
AUDIT = ROOT / "docs" / "audit" / "elv5-fifth-pass-specification-closure-audit.json"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def main() -> None:
    audit = load(AUDIT)
    req = load(IMPL / "combinatorial-engineering-requirements.json")
    constraints = load(IMPL / "combinatorial-legal-pair-constraints.json")
    three = load(IMPL / "combinatorial-targeted-three-wise.json")
    template = load(IMPL / "combinatorial-covering-template-v1.json")
    system = load(IMPL / "combinatorial-system-wide-inventory.json")
    plan = (IMPL / "combinatorial-engineering-1500-plan.md").read_text(encoding="utf-8")
    amendment = (IMPL / "p8-p9-combinatorial-1500-amendment.md").read_text(encoding="utf-8")
    generator = (ROOT / "scripts" / "ci" / "generate-elv5-combinatorial-1500.py").read_text(encoding="utf-8")
    manifest = (ROOT / "scripts" / "ci" / "generate-elv5-contract-manifest.py").read_text(encoding="utf-8")

    require(audit.get("schema") == "electra.elv5-fifth-pass-specification-closure-audit.v1", "unexpected fifth-pass audit schema")
    require(audit.get("status") == "SPEC_RESOLVED_RUNTIME_NOT_STARTED", "unexpected fifth-pass audit status")
    require(audit.get("counts") == {"high": 6, "medium": 2, "total": 8, "resolved": 8, "open": 0}, "fifth-pass counts must remain 6 HIGH + 2 MEDIUM = 8, open 0")
    findings = audit.get("findings", [])
    require(len(findings) == 8, "expected exactly eight fifth-pass findings")
    require([row.get("id") for row in findings] == [f"ELV5-FIFTH-{i:03d}" for i in range(1, 9)], "fifth-pass finding ID sequence drift")
    require(all(row.get("status") == "SPEC_RESOLVED" for row in findings), "every fifth-pass finding must remain SPEC_RESOLVED")
    require(sum(row.get("severity") == "HIGH" for row in findings) == 6, "expected six HIGH fifth-pass findings")
    require(sum(row.get("severity") == "MEDIUM" for row in findings) == 2, "expected two MEDIUM fifth-pass findings")

    require(req.get("scenarioTarget") == 1500, "combinatorial target drift")
    require(constraints.get("currentClosure", {}).get("excludedPairCount") == 0, "current v1 closure must not exclude factor pairs")
    require(constraints.get("currentClosure", {}).get("requiredLegalPairCountPerProcess") == 593, "legal pair count/process drift")
    require(constraints.get("currentClosure", {}).get("requiredLegalPairCountAllProcesses") == 16011, "global legal pair count drift")
    require(template.get("rowCount") == 42 and len(template.get("rows", [])) == 42, "covering template must remain exactly 42 rows")
    require(template.get("expectedLegalPairCount") == 593, "covering template pair count drift")
    require(three.get("policy", {}).get("templateCount") == 30, "targeted 3-wise template count drift")
    require(three.get("policy", {}).get("requiredGlobalTargetCount") == 330, "targeted 3-wise global count drift")
    require(sum(len(family.get("targets", [])) for family in three.get("families", [])) == 30, "targeted 3-wise inventory must contain exactly 30 tuples")
    require(system.get("requiredCount") == 36 and len(system.get("scenarios", [])) == 36, "system-wide inventory must contain exactly 36 scenarios")
    require([row.get("id") for row in system.get("scenarios", [])] == [f"SYS-{i:03d}" for i in range(1, 37)], "system-wide ID sequence drift")

    required_plan_tokens = [
        "593 factor-value pairs per process",
        "27 × 593 = 16,011 pair obligations across all processes",
        "30 targets/process × 11 priority processes = 330 targeted 3-wise obligations",
        "combinatorial-legal-pair-constraints.json",
        "combinatorial-targeted-three-wise.json",
        "combinatorial-covering-template-v1.json",
        "combinatorial-system-wide-inventory.json",
        "scripts/ci/generate-elv5-combinatorial-1500.py",
    ]
    for token in required_plan_tokens:
        require(token in plan, f"1500-case plan missing fifth-pass token: {token}")

    forbidden_stale_tokens = [
        "operatingCase × evidenceQuality × reserve/policy basis",
        "orderMode × mutationState × upstreamEvidenceState",
        "composition × transientState × sharedPhysicalSource",
        "cardinality × capacityBoundary × spare/reserve policy",
    ]
    for token in forbidden_stale_tokens:
        require(token not in plan, f"stale undeclared 3-wise factor survived fifth pass: {token}")

    require("scenarioCount == 1500" in amendment and "pairwiseCoveragePercent == 100.0" in amendment, "P8/P9 combinatorial amendment drift")
    for token in ["len(universe)==593", "legal_count==covered_count==16011", "t3_count==330", "len(scenarios)==len({x[\"caseId\"] for x in scenarios})==1500"]:
        require(token in generator, f"generator missing constructive closure assertion: {token}")
    for token in [
        "combinatorialLegalPairConstraintsSha256",
        "combinatorialTargetedThreeWiseSha256",
        "combinatorialCoveringTemplateSha256",
        "combinatorialSystemWideInventorySha256",
        "combinatorialGeneratorSha256",
        "fifthPassClosureAuditSha256",
    ]:
        require(token in manifest, f"authority manifest does not fingerprint fifth-pass authority: {token}")

    print("ELV5 fifth-pass specification closure PASS")
    print("findings=8 resolved=8 open=0 high=6 medium=2")
    print("pairwise=16011/16011 targeted3Wise=330/330 baseRows=42 systemWide=36 target=1500")
    print("runtimeStatus=NOT_STARTED")


if __name__ == "__main__":
    main()
