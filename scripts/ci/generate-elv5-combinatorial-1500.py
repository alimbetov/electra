#!/usr/bin/env python3
"""Generate and validate the deterministic ELV5 1500-case combinatorial matrix.

This is exact-head design/qualification evidence. Until production ELV5 runtime
exists it does not claim that Dart process kernels executed these scenarios.
"""
from __future__ import annotations

import argparse
from collections import Counter
from hashlib import sha256
from itertools import combinations, product
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
REQ_PATH = IMPL / "combinatorial-engineering-requirements.json"
CONSTRAINT_PATH = IMPL / "combinatorial-legal-pair-constraints.json"
THREE_WISE_PATH = IMPL / "combinatorial-targeted-three-wise.json"
TEMPLATE_PATH = IMPL / "combinatorial-covering-template-v1.json"
SYSTEM_PATH = IMPL / "combinatorial-system-wide-inventory.json"
PROCESS_PATH = IMPL / "process-registry.json"

PRIORITY = [
    "CCTV-02", "CCTV-03", "LAN-01", "LAN-05", "ACS-03", "ACS-04",
    "ACS-05", "FA-02", "FA-04", "FA-05", "FA-06",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def canonical_bytes(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def canonical_sha256(value: object) -> str:
    return sha256(canonical_bytes(value)).hexdigest()


def source_sha() -> str:
    env_sha = os.getenv("GITHUB_SHA")
    if env_sha:
        return env_sha
    try:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return "UNKNOWN"


def pair_key(factor_order: list[str], factor_a: str, value_a: str, factor_b: str, value_b: str) -> tuple[str, str, str, str]:
    ia = factor_order.index(factor_a)
    ib = factor_order.index(factor_b)
    if ia < ib:
        return factor_a, value_a, factor_b, value_b
    return factor_b, value_b, factor_a, value_a


def all_factor_pairs(factors: dict[str, list[str]]) -> set[tuple[str, str, str, str]]:
    factor_order = list(factors)
    result: set[tuple[str, str, str, str]] = set()
    for factor_a, factor_b in combinations(factor_order, 2):
        for value_a, value_b in product(factors[factor_a], factors[factor_b]):
            result.add((factor_a, value_a, factor_b, value_b))
    return result


def scenario_pairs(factors: dict[str, list[str]], scenario_factors: dict[str, str]) -> set[tuple[str, str, str, str]]:
    factor_order = list(factors)
    result: set[tuple[str, str, str, str]] = set()
    for factor_a, factor_b in combinations(factor_order, 2):
        result.add((factor_a, scenario_factors[factor_a], factor_b, scenario_factors[factor_b]))
    return result


def excluded_pairs_for(process_code: str, constraints: dict, factors: dict[str, list[str]]) -> set[tuple[str, str, str, str]]:
    factor_order = list(factors)
    rows = list(constraints.get("globalExcludedPairs", []))
    rows.extend(constraints.get("processOverrides", {}).get(process_code, {}).get("excludedPairs", []))
    excluded = set()
    known_reasons = {row["code"] for row in constraints.get("reasonCodes", [])}
    for row in rows:
        factor_a = row.get("factorA")
        factor_b = row.get("factorB")
        value_a = row.get("valueA")
        value_b = row.get("valueB")
        reason = row.get("reasonCode")
        require(factor_a in factors and factor_b in factors and factor_a != factor_b, f"invalid excluded-pair factors for {process_code}: {row}")
        require(value_a in factors[factor_a] and value_b in factors[factor_b], f"invalid excluded-pair values for {process_code}: {row}")
        require(reason in known_reasons, f"unknown excluded-pair reason for {process_code}: {reason}")
        excluded.add(pair_key(factor_order, factor_a, value_a, factor_b, value_b))
    return excluded


def variant_mode(vector_class: str) -> str:
    return {
        "POSITIVE": "POSITIVE_CONTROL",
        "BOUNDARY": "EXACT_BOUNDARY",
        "NEGATIVE_OR_UNSUPPORTED": "DEFECT_OR_UNSUPPORTED_ACTIVE",
        "ADVERSARIAL": "ADVERSARIAL_MUTATION",
        "CROSS_DISCIPLINE": "CROSS_DISCIPLINE_INTERACTION",
    }[vector_class]


def build_base_rows(req: dict, template: dict) -> list[dict[str, str]]:
    factors = req["factorModel"]
    columns = template["columnOrder"]
    require(set(columns) == set(factors), "covering-template factor inventory differs from requirements")
    require(template.get("rowCount") == 42 and len(template.get("rows", [])) == 42, "covering template must contain exactly 42 rows")
    require(template.get("levelCounts") == [len(factors[name]) for name in columns], "covering-template level counts drift")

    rows: list[dict[str, str]] = []
    for row_index, cells in enumerate(template["rows"], start=1):
        require(len(cells) == len(columns), f"covering template row {row_index} width mismatch")
        values: dict[str, str] = {}
        for column_index, factor in enumerate(columns):
            cell = cells[column_index]
            require(isinstance(cell, int) and 0 <= cell < len(factors[factor]), f"covering template row {row_index} invalid cell for {factor}")
            values[factor] = factors[factor][cell]
        rows.append(values)
    return rows


def flatten_targets(three_wise: dict, factors: dict[str, list[str]]) -> list[dict[str, object]]:
    targets: list[dict[str, object]] = []
    seen_ids = set()
    for family in three_wise.get("families", []):
        names = family.get("factors", [])
        require(len(names) == 3 and len(set(names)) == 3, f"3-wise family {family.get('id')} must name exactly three unique factors")
        require(all(name in factors for name in names), f"3-wise family {family.get('id')} references undeclared factor")
        for target in family.get("targets", []):
            target_id = target.get("id")
            values = target.get("values", [])
            require(target_id not in seen_ids, f"duplicate 3-wise target ID {target_id}")
            require(len(values) == 3, f"3-wise target {target_id} must have exactly three values")
            for factor, value in zip(names, values):
                require(value in factors[factor], f"3-wise target {target_id} invalid value {factor}={value}")
            seen_ids.add(target_id)
            targets.append({"id": target_id, "familyId": family["id"], "factors": names, "values": values})
    require(len(targets) == 30, f"expected exactly 30 targeted 3-wise templates, found {len(targets)}")
    return targets


def build_target_row(factors: dict[str, list[str]], target: dict[str, object], process_index: int, target_index: int) -> dict[str, str]:
    result = {
        factor: values[(process_index * 7 + target_index * 3 + len(factor)) % len(values)]
        for factor, values in factors.items()
    }
    for factor, value in zip(target["factors"], target["values"]):
        result[factor] = value
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--authority-manifest", type=Path)
    args = parser.parse_args()

    req = load(REQ_PATH)
    constraints = load(CONSTRAINT_PATH)
    three_wise = load(THREE_WISE_PATH)
    template = load(TEMPLATE_PATH)
    system_inventory = load(SYSTEM_PATH)
    process_registry = load(PROCESS_PATH)

    require(req.get("schema") == "electra.elv5-combinatorial-engineering-requirements.v1", "unexpected combinatorial requirements schema")
    require(req.get("scenarioTarget") == 1500, "scenario target must be exactly 1500")
    require(req.get("priorityProcessMinimum") == 72, "priority process target must be 72")
    require(req.get("regularProcessMinimum") == 42, "regular process target must be 42")
    require(req.get("systemWideScenarioCount") == 36, "system-wide target must be 36")
    require(req.get("priorityComputationalCore") == PRIORITY, "priority process inventory drift")
    require(constraints.get("schema") == "electra.elv5-combinatorial-legal-pairs.v1", "unexpected legal-pair constraint schema")
    require(constraints.get("policy", {}).get("silentExclusionAllowed") is False, "silent pair exclusions must be forbidden")
    require(three_wise.get("schema") == "electra.elv5-combinatorial-targeted-three-wise.v1", "unexpected targeted 3-wise schema")
    require(three_wise.get("appliesToPriorityProcesses") == PRIORITY, "targeted 3-wise priority inventory drift")
    require(system_inventory.get("schema") == "electra.elv5-combinatorial-system-wide.v1", "unexpected system-wide inventory schema")

    process_codes = [row.get("code") for row in process_registry.get("processes", [])]
    require(len(process_codes) == len(set(process_codes)) == 27, "expected exactly 27 unique ELV5 process codes")
    require(set(PRIORITY).issubset(set(process_codes)), "priority process missing from process registry")
    regular = sorted(set(process_codes) - set(PRIORITY))
    require(len(regular) == 16, "expected 16 regular processes")
    require(set(constraints.get("processOverrides", {})) == set(process_codes), "legal-pair registry must explicitly name all 27 processes")

    factors: dict[str, list[str]] = req["factorModel"]
    factor_order = list(factors)
    require(len(factors) == 8, "expected exactly eight combinatorial factors")
    all_pairs = all_factor_pairs(factors)
    require(len(all_pairs) == 593, f"expected 593 unconstrained factor-value pairs, found {len(all_pairs)}")

    base_rows = build_base_rows(req, template)
    template_coverage = set().union(*(scenario_pairs(factors, row) for row in base_rows))
    require(template_coverage == all_pairs, f"42-row template does not cover full strength-2 factor space: {len(template_coverage)}/593")
    require(template.get("expectedLegalPairCount") == 593, "covering-template expected pair count drift")

    targets = flatten_targets(three_wise, factors)
    require(three_wise.get("policy", {}).get("requiredGlobalTargetCount") == 330, "targeted 3-wise global count must be 330")

    scenarios: list[dict[str, object]] = []
    process_counts = Counter()
    pair_metrics: dict[str, dict[str, object]] = {}
    target_coverage: dict[str, list[str]] = {}

    for process_index, process_code in enumerate(sorted(process_codes)):
        excluded = excluded_pairs_for(process_code, constraints, factors)
        legal = all_pairs - excluded
        require(not (template_coverage & excluded), f"base template contains excluded pair for {process_code}; template/constraint registry must be reconciled")

        process_rows: list[dict[str, str]] = []
        for index, row in enumerate(base_rows, start=1):
            process_rows.append(row)
            scenarios.append({
                "caseId": f"COMB-{process_code}-P2-{index:03d}",
                "scenarioKind": "PAIRWISE_BASE",
                "processCode": process_code,
                "factors": row,
                "variantMode": variant_mode(row["vectorClass"]),
                "claimScope": "QUALIFICATION_DESIGN_MATRIX_RUNTIME_NOT_EXECUTED",
            })
            process_counts[process_code] += 1

        covered_targets: list[str] = []
        if process_code in PRIORITY:
            for target_index, target in enumerate(targets):
                row = build_target_row(factors, target, process_index, target_index)
                row_pairs = scenario_pairs(factors, row)
                require(not (row_pairs & excluded), f"targeted 3-wise scenario {target['id']} violates excluded pair for {process_code}")
                scenarios.append({
                    "caseId": f"COMB-{process_code}-T3-{target_index + 1:03d}",
                    "scenarioKind": "TARGETED_THREE_WISE",
                    "processCode": process_code,
                    "targetId": target["id"],
                    "targetFamilyId": target["familyId"],
                    "factors": row,
                    "variantMode": variant_mode(row["vectorClass"]),
                    "claimScope": "QUALIFICATION_DESIGN_MATRIX_RUNTIME_NOT_EXECUTED",
                })
                process_rows.append(row)
                process_counts[process_code] += 1
                covered_targets.append(target["id"])
            require(len(covered_targets) == 30, f"{process_code} must cover exactly 30 targeted 3-wise entries")
        target_coverage[process_code] = covered_targets

        covered = set().union(*(scenario_pairs(factors, row) for row in process_rows))
        require(legal <= covered, f"{process_code} pairwise coverage incomplete: {len(covered & legal)}/{len(legal)}")
        pair_metrics[process_code] = {
            "unconstrainedPairCount": len(all_pairs),
            "excludedPairCount": len(excluded),
            "legalPairCount": len(legal),
            "coveredLegalPairCount": len(covered & legal),
            "pairwiseCoveragePercent": 100.0,
        }

    for process_code in PRIORITY:
        require(process_counts[process_code] == 72, f"priority process {process_code} must have exactly 72 scenarios")
    for process_code in regular:
        require(process_counts[process_code] == 42, f"regular process {process_code} must have exactly 42 scenarios")

    system_rows = system_inventory.get("scenarios", [])
    require(system_inventory.get("requiredCount") == 36 and len(system_rows) == 36, "system-wide inventory must contain exactly 36 scenarios")
    require([row.get("id") for row in system_rows] == [f"SYS-{i:03d}" for i in range(1, 37)], "system-wide IDs must be SYS-001..SYS-036")
    for row in system_rows:
        require(row.get("title") and row.get("packages"), f"incomplete system-wide scenario {row.get('id')}")
        scenarios.append({
            "caseId": f"COMB-{row['id']}",
            "scenarioKind": "SYSTEM_WIDE",
            "systemScenarioId": row["id"],
            "title": row["title"],
            "packages": row["packages"],
            "claimScope": "QUALIFICATION_DESIGN_MATRIX_RUNTIME_NOT_EXECUTED",
        })

    require(len(scenarios) == 1500, f"generated {len(scenarios)} scenarios instead of 1500")
    require(len({row["caseId"] for row in scenarios}) == 1500, "scenario IDs must be unique")
    require(sum(process_counts.values()) == 1464, "per-process scenario subtotal must be 1464")

    global_legal = sum(metric["legalPairCount"] for metric in pair_metrics.values())
    global_covered = sum(metric["coveredLegalPairCount"] for metric in pair_metrics.values())
    global_excluded = sum(metric["excludedPairCount"] for metric in pair_metrics.values())
    require(global_legal == 16011, f"current legal-pair closure must be 16011, found {global_legal}")
    require(global_covered == global_legal, "global legal pair coverage must be 100%")
    require(global_excluded == constraints.get("currentClosure", {}).get("excludedPairCount") * 27, "excluded-pair closure drift")

    target_total = sum(len(rows) for rows in target_coverage.values())
    require(target_total == 330, f"targeted 3-wise coverage must equal 330, found {target_total}")

    manifest_binding = None
    if args.authority_manifest:
        authority_manifest = load(args.authority_manifest)
        require(authority_manifest.get("sourceSha") == source_sha(), "authority manifest source SHA differs from current source SHA")
        manifest_binding = authority_manifest.get("authorityFingerprintSha256")
        require(isinstance(manifest_binding, str) and len(manifest_binding) == 64, "authority manifest fingerprint missing/invalid")

    contract_inputs = {
        "requirements": req,
        "constraints": constraints,
        "threeWise": three_wise,
        "template": template,
        "systemWide": system_inventory,
    }
    result_core = {
        "schema": "electra.elv5-combinatorial-qualification.v1",
        "generationVersion": "electra.elv5-combinatorial-generator.v1",
        "status": "DESIGN_MATRIX_GENERATED_RUNTIME_NOT_EXECUTED",
        "sourceSha": source_sha(),
        "authorityFingerprint": manifest_binding,
        "qualificationContractFingerprintSha256": canonical_sha256(contract_inputs),
        "scenarioCount": 1500,
        "processCount": 27,
        "priorityProcessCount": 11,
        "regularProcessCount": 16,
        "priorityProcessScenarioCount": 72,
        "regularProcessScenarioCount": 42,
        "systemWideScenarioCount": 36,
        "factorInventory": {name: list(values) for name, values in factors.items()},
        "legalPairCountPerProcessCurrentClosure": 593,
        "legalPairCount": global_legal,
        "coveredLegalPairCount": global_covered,
        "pairwiseCoveragePercent": 100.0,
        "excludedPairCount": global_excluded,
        "targetedThreeWiseTemplateCount": 30,
        "targetedThreeWiseLegalCount": 330,
        "targetedThreeWiseCoveredCount": target_total,
        "processScenarioCounts": dict(sorted(process_counts.items())),
        "pairwiseMetricsByProcess": pair_metrics,
        "targetedThreeWiseCoverageByProcess": target_coverage,
        "runtimeExecuted": false,
        "claimScope": "Design matrix generation and coverage proof only; production ELV5 Dart kernels have not executed this matrix.",
    }
    result = {
        **result_core,
        "scenarioMatrixFingerprintSha256": canonical_sha256(scenarios),
        "scenarios": scenarios,
    }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")

    print("ELV5 deterministic 1500-case combinatorial matrix PASS")
    print("scenarios=1500 processSubtotal=1464 systemWide=36 priority=11x72 regular=16x42")
    print(f"pairwise={global_covered}/{global_legal}=100% targeted3Wise={target_total}/330")
    print(f"matrixFingerprintSha256={result['scenarioMatrixFingerprintSha256']}")
    print("runtimeExecuted=0")


if __name__ == "__main__":
    main()
