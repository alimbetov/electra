#!/usr/bin/env python3
"""Generate a deterministic ELV5 authority/contract manifest.

The manifest fingerprints the machine registries plus the governing authority
chain. It is design/implementation-entry evidence only; it does not claim ELV5
runtime implementation or engineering acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"

DOSSIER_PATHS = [
    "docs/product/elv5-implementation/process-specifications/cctv-processes.md",
    "docs/product/elv5-implementation/process-specifications/lan-processes.md",
    "docs/product/elv5-implementation/process-specifications/acs-processes.md",
    "docs/product/elv5-implementation/process-specifications/fire-processes.md",
]

AUTHORITY_PATHS = [
    "docs/product/elv5-authoritative-spec-index.md",
    "docs/product/elv5-discipline-calculations-design-specification.md",
    "docs/product/elv5-p0-p9-delivery-plan.md",
    "docs/product/elv5-implementation/README.md",
    "docs/product/elv5-implementation/requirements.json",
    "docs/product/elv5-implementation/normative-requirements-registry.json",
    "docs/product/elv5-implementation/market-simulation-requirements.json",
    "docs/product/elv5-implementation/market-simulation-catalog.json",
    "docs/product/elv5-implementation/market-simulation-450-plan.md",
    "docs/product/elv5-implementation/process-contracts.md",
    "docs/product/elv5-implementation/process-registry.json",
    "docs/product/elv5-implementation/algorithm-registry.json",
    "docs/product/elv5-implementation/command-registry.json",
    "docs/product/elv5-implementation/engineering-primitives-contract.md",
    "docs/product/elv5-implementation/typed-process-api.md",
    "docs/product/elv5-implementation/calculation-engine-contract.md",
    "docs/product/elv5-implementation/process-code-level-specification.md",
    *DOSSIER_PATHS,
    "docs/product/elv5-implementation/calculation-oracle-errata-v1.md",
    "docs/product/elv5-implementation/flutter-performance-contract.md",
    "docs/product/elv5-implementation/persistence-schema-contract.md",
    "docs/product/elv5-implementation/code-level-runtime-contract.md",
    "docs/product/elv5-implementation/code-level-hardening-amendments.md",
    "docs/product/elv5-implementation/code-level-hardening-v2.md",
    "docs/product/elv5-implementation/production-source-blueprint.md",
    "docs/product/elv5-implementation/qualification-contract.md",
    "docs/product/elv5-implementation/p0-baseline.md",
    "docs/product/elv5-implementation/p1-profiles-registry.md",
    "docs/product/elv5-implementation/p2-persistence-commands.md",
    "docs/product/elv5-implementation/p3-cctv.md",
    "docs/product/elv5-implementation/p4-lan.md",
    "docs/product/elv5-implementation/p5-acs.md",
    "docs/product/elv5-implementation/p6-fire.md",
    "docs/product/elv5-implementation/p7-dependencies-workspace.md",
    "docs/product/elv5-implementation/p8-acceptance.md",
    "docs/product/elv5-implementation/p9-closure.md",
    "docs/audit/elv5-third-pass-production-readiness-audit.json",
    "docs/audit/elv5-fourth-pass-algorithm-performance-audit.md",
    "docs/audit/elv5-fourth-pass-algorithm-performance-audit.json",
]


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def deterministic_json_bytes(value: object) -> bytes:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def source_sha() -> str:
    env_sha = os.getenv("GITHUB_SHA")
    if env_sha:
        return env_sha
    try:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return "UNKNOWN"


def rows_from_requirements(value):
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        rows = value.get("requirements", [])
        if isinstance(rows, list):
            return rows
    return []


def dossier_inventory() -> list[dict[str, object]]:
    process_re = re.compile(r"^## (CCTV-\d{2}|LAN-\d{2}|ACS-\d{2}|FA-\d{2}) — .+$", re.MULTILINE)
    rows = []
    codes: list[str] = []
    for relative in DOSSIER_PATHS:
        path = ROOT / relative
        text = path.read_text(encoding="utf-8")
        file_codes = process_re.findall(text)
        codes.extend(file_codes)
        rows.append({"path": relative, "sha256": sha256_file(path), "byteLength": path.stat().st_size, "processCodes": file_codes})
    if len(codes) != 27 or len(set(codes)) != 27:
        raise SystemExit(f"expected 27 unique process dossiers, found {len(codes)} / {len(set(codes))} unique")
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    process_registry_path = IMPL / "process-registry.json"
    algorithm_registry_path = IMPL / "algorithm-registry.json"
    command_registry_path = IMPL / "command-registry.json"
    requirements_path = IMPL / "requirements.json"
    normative_requirements_path = IMPL / "normative-requirements-registry.json"
    market_requirements_path = IMPL / "market-simulation-requirements.json"
    market_catalog_path = IMPL / "market-simulation-catalog.json"
    oracle_errata_path = IMPL / "calculation-oracle-errata-v1.md"

    process_registry = load_json(process_registry_path)
    algorithm_registry = load_json(algorithm_registry_path)
    command_registry = load_json(command_registry_path)
    requirements = load_json(requirements_path)
    normative_requirements = load_json(normative_requirements_path)
    market_requirements = load_json(market_requirements_path)
    market_catalog = load_json(market_catalog_path)

    processes = process_registry.get("processes", [])
    algorithms = algorithm_registry.get("processes", [])
    commands = command_registry.get("commands", [])
    requirement_rows = rows_from_requirements(requirements)
    obligations = normative_requirements.get("obligations", [])
    market_requirement_rows = market_requirements.get("requirements", [])
    fixed = normative_requirements.get("fixedInventories", {})

    if len(processes) != 27:
        raise SystemExit(f"expected 27 processes, found {len(processes)}")
    if len(algorithms) != 27:
        raise SystemExit(f"expected 27 algorithm mappings, found {len(algorithms)}")
    if {row.get('code') for row in processes} != {row.get('code') for row in algorithms}:
        raise SystemExit("algorithm registry process inventory differs from process registry")
    if len(commands) != 16:
        raise SystemExit(f"expected 16 commands, found {len(commands)}")
    if len(requirement_rows) != 80:
        raise SystemExit(f"expected 80 requirements, found {len(requirement_rows)}")
    if len(obligations) != 42 or len({row.get('id') for row in obligations}) != 42:
        raise SystemExit("expected 42 unique normative obligations")
    if len(market_requirement_rows) != 12 or len({row.get('id') for row in market_requirement_rows}) != 12:
        raise SystemExit("expected 12 unique market-simulation requirements")
    if market_requirements.get("scenarioMatrixTarget") != 450:
        raise SystemExit("market-simulation requirements must target exactly 450 scenarios")
    market_counts = market_catalog.get("processScenarioCounts", {})
    if len(market_counts) != 27 or sum(market_counts.values()) != 450:
        raise SystemExit("market-simulation catalog must allocate exactly 450 scenarios across 27 processes")
    if fixed.get("designFindingsResolved") != 56 or fixed.get("minimumProcessVectorCount") != 135:
        raise SystemExit("unexpected normative fixed inventory")
    if command_registry.get("wireSchema") != "electra.elv5-discipline-command.v1":
        raise SystemExit("unexpected ELV5 wire schema")
    if command_registry.get("payloadSchemaVersion") != 1:
        raise SystemExit("unexpected ELV5 payload schema version")

    process_codes = [row.get("code") for row in processes]
    if len(process_codes) != len(set(process_codes)):
        raise SystemExit("duplicate ELV5 process code")
    if any(not row.get("requiredDimensions") for row in processes):
        raise SystemExit("every ELV5 process must have requiredDimensions")
    if set(normative_requirements.get("processCodes", [])) != set(process_codes):
        raise SystemExit("normative requirements process inventory differs from process registry")
    if set(market_counts) != set(process_codes):
        raise SystemExit("market-simulation process inventory differs from process registry")

    command_ops = [row.get("operation") for row in commands]
    if len(command_ops) != len(set(command_ops)):
        raise SystemExit("duplicate ELV5 command operation")

    dossier_rows = dossier_inventory()
    dossier_codes = {code for row in dossier_rows for code in row["processCodes"]}
    if dossier_codes != set(process_codes):
        raise SystemExit("code-level dossier process inventory differs from process registry")

    errata_text = oracle_errata_path.read_text(encoding="utf-8")
    if "23.51 V" not in errata_text or "ERRATA-001 — ACS-03" not in errata_text:
        raise SystemExit("ACS-03 calculation oracle errata is incomplete")

    required_dimension_inventory = [
        {"code": row["code"], "requiredDimensions": sorted(row["requiredDimensions"])}
        for row in sorted(processes, key=lambda item: item["code"])
    ]
    algorithm_inventory = [
        {
            "code": row["code"],
            "families": sorted(row.get("families", [])),
            "operatingCases": row.get("operatingCases", []),
            "governingRule": row.get("governingRule"),
            "marginPolicy": row.get("marginPolicy"),
            "limitingFactor": row.get("limitingFactor"),
        }
        for row in sorted(algorithms, key=lambda item: item["code"])
    ]
    command_inventory = [
        {"operation": row["operation"], "payloadKeys": sorted(row.get("payloadKeys", []))}
        for row in sorted(commands, key=lambda item: item["operation"])
    ]
    obligation_inventory = [
        {"id": row["id"], "severity": row["severity"], "title": row["title"], "acceptance": row["acceptance"]}
        for row in sorted(obligations, key=lambda item: item["id"])
    ]
    market_requirement_inventory = [
        {"id": row["id"], "severity": row["severity"], "title": row["title"]}
        for row in sorted(market_requirement_rows, key=lambda item: item["id"])
    ]

    artifacts = []
    for relative in AUTHORITY_PATHS:
        path = ROOT / relative
        if not path.is_file():
            raise SystemExit(f"missing authority artifact: {relative}")
        artifacts.append({"path": relative, "sha256": sha256_file(path), "byteLength": path.stat().st_size})

    manifest_core = {
        "manifestSchema": "electra.elv5-contract-manifest.v1",
        "manifestCanonicalization": "utf8-json-sort-keys-separators-v1",
        "hashAlgorithm": "SHA-256",
        "engineeringCanonicalJsonVersion": "electra.canonical-json.v1",
        "databaseSchemaVersion": 24,
        "wireSchema": "electra.elv5-discipline-command.v1",
        "payloadSchemaVersion": 1,
        "processCount": 27,
        "algorithmMappingCount": 27,
        "processCodeLevelDossierCount": 27,
        "processDossierSectionCount": 25,
        "processVectorClassCount": 5,
        "minimumProcessVectorCount": 135,
        "marketSimulationScenarioCount": 450,
        "fourthPassFindingCount": 19,
        "designFindingsResolved": 56,
        "commandCount": 16,
        "requirementCount": 80,
        "normativeObligationCount": 42,
        "marketSimulationRequirementCount": 12,
        "primaryProcessOracleCount": 54,
        "authorityArtifactCount": len(AUTHORITY_PATHS),
        "processRegistrySha256": sha256_file(process_registry_path),
        "algorithmRegistrySha256": sha256_file(algorithm_registry_path),
        "processContractsSha256": sha256_file(IMPL / "process-contracts.md"),
        "processCodeLevelSpecificationSha256": sha256_file(IMPL / "process-code-level-specification.md"),
        "processDossierAggregateSha256": sha256_bytes(deterministic_json_bytes(dossier_rows)),
        "calculationOracleErrataSha256": sha256_file(oracle_errata_path),
        "flutterPerformanceContractSha256": sha256_file(IMPL / "flutter-performance-contract.md"),
        "requirementsSha256": sha256_file(requirements_path),
        "normativeRequirementsSha256": sha256_file(normative_requirements_path),
        "normativeObligationInventorySha256": sha256_bytes(deterministic_json_bytes(obligation_inventory)),
        "marketSimulationRequirementsSha256": sha256_file(market_requirements_path),
        "marketSimulationRequirementInventorySha256": sha256_bytes(deterministic_json_bytes(market_requirement_inventory)),
        "marketSimulationCatalogSha256": sha256_file(market_catalog_path),
        "marketSimulationScenarioDistributionSha256": sha256_bytes(deterministic_json_bytes(market_counts)),
        "commandRegistrySha256": sha256_file(command_registry_path),
        "requiredDimensionInventorySha256": sha256_bytes(deterministic_json_bytes(required_dimension_inventory)),
        "algorithmInventorySha256": sha256_bytes(deterministic_json_bytes(algorithm_inventory)),
        "commandPayloadInventorySha256": sha256_bytes(deterministic_json_bytes(command_inventory)),
        "authorityArtifacts": artifacts,
    }
    authority_fingerprint = sha256_bytes(deterministic_json_bytes(manifest_core))

    manifest = {
        **manifest_core,
        "authorityFingerprintSha256": authority_fingerprint,
        "sourceSha": source_sha(),
        "runtimeStatus": "NOT_STARTED",
        "qualificationStatus": "NOT_EXECUTED",
        "marketSimulationStatus": "DESIGN_SIMULATION_ONLY",
        "note": "Authority fingerprint/design-entry evidence only. It does not constitute ELV5 runtime implementation, engineering acceptance, ELV7 compliance or ELV8 procurement acceptance.",
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")

    print(f"ELV5 contract manifest generated: {output}")
    print(f"sourceSha={manifest['sourceSha']}")
    print(f"authorityFingerprintSha256={authority_fingerprint}")
    print(
        "processes=27 algorithms=27 dossiers=27 sections=25 vectors=135 marketSimulation=450 commands=16 "
        "requirements=80 obligations=42 marketRequirements=12 primaryOracles=54 fourthPassFindings=19 "
        f"designFindingsResolved=56 schema=24 authorityArtifacts={len(AUTHORITY_PATHS)}"
    )


if __name__ == "__main__":
    main()
