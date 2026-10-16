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
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"

AUTHORITY_PATHS = [
    "docs/product/elv5-authoritative-spec-index.md",
    "docs/product/elv5-discipline-calculations-design-specification.md",
    "docs/product/elv5-p0-p9-delivery-plan.md",
    "docs/product/elv5-implementation/README.md",
    "docs/product/elv5-implementation/process-registry.json",
    "docs/product/elv5-implementation/command-registry.json",
    "docs/product/elv5-implementation/requirements.json",
    "docs/product/elv5-implementation/engineering-primitives-contract.md",
    "docs/product/elv5-implementation/typed-process-api.md",
    "docs/product/elv5-implementation/persistence-schema-contract.md",
    "docs/product/elv5-implementation/code-level-hardening-amendments.md",
    "docs/product/elv5-implementation/code-level-hardening-v2.md",
    "docs/product/elv5-implementation/production-source-blueprint.md",
    "docs/product/elv5-implementation/qualification-contract.md",
    "docs/audit/elv5-third-pass-production-readiness-audit.json",
]


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def deterministic_json_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def source_sha() -> str:
    env_sha = os.getenv("GITHUB_SHA")
    if env_sha:
        return env_sha
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip()
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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    process_registry_path = IMPL / "process-registry.json"
    command_registry_path = IMPL / "command-registry.json"
    requirements_path = IMPL / "requirements.json"

    process_registry = load_json(process_registry_path)
    command_registry = load_json(command_registry_path)
    requirements = load_json(requirements_path)

    processes = process_registry.get("processes", [])
    commands = command_registry.get("commands", [])
    requirement_rows = rows_from_requirements(requirements)

    if len(processes) != 27:
        raise SystemExit(f"expected 27 processes, found {len(processes)}")
    if len(commands) != 16:
        raise SystemExit(f"expected 16 commands, found {len(commands)}")
    if len(requirement_rows) != 80:
        raise SystemExit(f"expected 80 requirements, found {len(requirement_rows)}")
    if command_registry.get("wireSchema") != "electra.elv5-discipline-command.v1":
        raise SystemExit("unexpected ELV5 wire schema")
    if command_registry.get("payloadSchemaVersion") != 1:
        raise SystemExit("unexpected ELV5 payload schema version")

    process_codes = [row.get("code") for row in processes]
    if len(process_codes) != len(set(process_codes)):
        raise SystemExit("duplicate ELV5 process code")
    if any(not row.get("requiredDimensions") for row in processes):
        raise SystemExit("every ELV5 process must have requiredDimensions")

    command_ops = [row.get("operation") for row in commands]
    if len(command_ops) != len(set(command_ops)):
        raise SystemExit("duplicate ELV5 command operation")

    required_dimension_inventory = [
        {
            "code": row["code"],
            "requiredDimensions": sorted(row["requiredDimensions"]),
        }
        for row in sorted(processes, key=lambda item: item["code"])
    ]
    command_inventory = [
        {
            "operation": row["operation"],
            "payloadKeys": sorted(row.get("payloadKeys", [])),
        }
        for row in sorted(commands, key=lambda item: item["operation"])
    ]

    artifacts = []
    for relative in AUTHORITY_PATHS:
        path = ROOT / relative
        if not path.is_file():
            raise SystemExit(f"missing authority artifact: {relative}")
        artifacts.append(
            {
                "path": relative,
                "sha256": sha256_file(path),
                "byteLength": path.stat().st_size,
            }
        )

    manifest_core = {
        "manifestSchema": "electra.elv5-contract-manifest.v1",
        "manifestCanonicalization": "utf8-json-sort-keys-separators-v1",
        "hashAlgorithm": "SHA-256",
        "engineeringCanonicalJsonVersion": "electra.canonical-json.v1",
        "databaseSchemaVersion": 24,
        "wireSchema": "electra.elv5-discipline-command.v1",
        "payloadSchemaVersion": 1,
        "processCount": 27,
        "commandCount": 16,
        "requirementCount": 80,
        "primaryProcessOracleCount": 54,
        "processRegistrySha256": sha256_file(process_registry_path),
        "commandRegistrySha256": sha256_file(command_registry_path),
        "requirementsSha256": sha256_file(requirements_path),
        "requiredDimensionInventorySha256": sha256_bytes(
            deterministic_json_bytes(required_dimension_inventory)
        ),
        "commandPayloadInventorySha256": sha256_bytes(
            deterministic_json_bytes(command_inventory)
        ),
        "authorityArtifacts": artifacts,
    }
    authority_fingerprint = sha256_bytes(deterministic_json_bytes(manifest_core))

    manifest = {
        **manifest_core,
        "authorityFingerprintSha256": authority_fingerprint,
        "sourceSha": source_sha(),
        "runtimeStatus": "NOT_STARTED",
        "qualificationStatus": "NOT_EXECUTED",
        "note": (
            "Authority fingerprint/design-entry evidence only. "
            "It does not constitute ELV5 runtime implementation or engineering acceptance."
        ),
    }

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )

    print(f"ELV5 contract manifest generated: {output}")
    print(f"sourceSha={manifest['sourceSha']}")
    print(f"authorityFingerprintSha256={authority_fingerprint}")
    print("processes=27 commands=16 requirements=80 primaryOracles=54 schema=24")


if __name__ == "__main__":
    main()
