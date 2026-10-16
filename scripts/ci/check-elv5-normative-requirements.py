#!/usr/bin/env python3
"""Verify ELV5 base requirements and all post-audit normative obligations stay synchronized."""
from __future__ import annotations

from collections import Counter
from fractions import Fraction as Q
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
REGISTRY_PATH = IMPL / "normative-requirements-registry.json"

DOSSIERS = [
    IMPL / "process-specifications" / "cctv-processes.md",
    IMPL / "process-specifications" / "lan-processes.md",
    IMPL / "process-specifications" / "acs-processes.md",
    IMPL / "process-specifications" / "fire-processes.md",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def resolve_from_impl(relative: str) -> Path:
    return (IMPL / relative).resolve()


def main() -> None:
    registry = load(REGISTRY_PATH)
    ledger = load(IMPL / "requirements.json")
    process_registry = load(IMPL / "process-registry.json")
    algorithm_registry = load(IMPL / "algorithm-registry.json")
    command_registry = load(IMPL / "command-registry.json")

    require(registry.get("schema") == "electra.elv5-normative-requirements.v1", "unexpected normative requirements schema")
    require(registry.get("status") == "DESIGN_HARDENED_RUNTIME_NOT_STARTED", "unexpected normative requirements status")

    requirements = ledger.get("requirements", [])
    requirement_ids = [row.get("requirementId") for row in requirements]
    require(len(requirements) == 80, f"expected 80 base requirements, found {len(requirements)}")
    require(len(set(requirement_ids)) == 80, "base requirement IDs must be unique")
    require(Counter(row.get("package") for row in requirements) == {f"P{i}": 8 for i in range(10)}, "base requirement package distribution must remain 8 per P0-P9")

    fixed = registry.get("fixedInventories", {})
    expected_fixed = {
        "processCount": 27,
        "algorithmMappingCount": 27,
        "publicCommandCount": 16,
        "targetDatabaseSchemaVersion": 24,
        "dossierSectionsPerProcess": 25,
        "vectorClassesPerProcess": 5,
        "primaryProcessVerticalCount": 54,
        "minimumProcessVectorCount": 135,
        "designFindingsResolved": 56,
        "runtimeStatus": "NOT_STARTED",
    }
    require(fixed == expected_fixed, f"fixed inventory drift: {fixed}")

    process_codes = registry.get("processCodes", [])
    require(len(process_codes) == len(set(process_codes)) == 27, "normative registry must contain 27 unique process codes")
    require(set(process_codes) == {row.get("code") for row in process_registry.get("processes", [])}, "normative process codes differ from process registry")
    require(set(process_codes) == {row.get("code") for row in algorithm_registry.get("processes", [])}, "normative process codes differ from algorithm registry")
    require(len(command_registry.get("commands", [])) == 16, "command registry must remain exactly 16 operations")

    sections = registry.get("mandatoryDossierSections", [])
    require(len(sections) == len(set(sections)) == 25, "normative registry must contain exactly 25 unique dossier sections")
    vectors = registry.get("vectorClasses", [])
    require(vectors == ["POSITIVE", "BOUNDARY", "NEGATIVE_OR_UNSUPPORTED", "ADVERSARIAL", "CROSS_DISCIPLINE"], "unexpected vector-class inventory")

    obligations = registry.get("obligations", [])
    obligation_ids = [row.get("id") for row in obligations]
    require(len(obligations) == len(set(obligation_ids)) == 42, f"expected 42 unique normative obligations, found {len(obligations)}")
    require(all(row.get("severity") == "MUST" for row in obligations), "all normative obligations must be MUST")
    require(all(row.get("requirement") and row.get("acceptance") for row in obligations), "every normative obligation needs requirement and acceptance text")

    bindings = registry.get("packageBindings", [])
    require(len(bindings) == 10, "expected one normative package binding for every P0-P9 package")
    require({row.get("package") for row in bindings} == {f"P{i}" for i in range(10)}, "package binding inventory mismatch")

    bound_requirement_ids: list[str] = []
    bound_obligation_ids: set[str] = set()
    for binding in bindings:
        package = binding["package"]
        ids = binding.get("requirementIds", [])
        require(len(ids) == 8, f"{package} must bind exactly 8 stable requirement IDs")
        require(all(req_id.startswith(f"ELV5-{package}-") for req_id in ids), f"{package} has foreign requirement ID")
        bound_requirement_ids.extend(ids)
        for obligation_id in binding.get("obligationIds", []):
            require(obligation_id in set(obligation_ids), f"{package} references unknown obligation {obligation_id}")
            bound_obligation_ids.add(obligation_id)
        for ref in binding.get("contractRefs", []):
            path = resolve_from_impl(ref)
            require(path.is_file(), f"{package} contract ref missing: {ref}")

    require(len(bound_requirement_ids) == 80 and set(bound_requirement_ids) == set(requirement_ids), "package bindings must cover every stable requirement ID exactly once")
    require(len(bound_requirement_ids) == len(set(bound_requirement_ids)), "stable requirement ID bound more than once")
    require(bound_obligation_ids == set(obligation_ids), f"unbound normative obligations: {sorted(set(obligation_ids) - bound_obligation_ids)}")

    for ref in registry.get("authorityRefs", []):
        require(resolve_from_impl(ref).is_file(), f"missing normative authority ref: {ref}")

    # The four dossier files must contain all 27 process headings and all 25 ordered sections.
    process_heading = re.compile(r"^## (CCTV-\d{2}|LAN-\d{2}|ACS-\d{2}|FA-\d{2}) — .+$")
    section_heading = re.compile(r"^### (\d+)\. (.+)$")
    found: dict[str, list[tuple[int, str]]] = {}
    for dossier in DOSSIERS:
        require(dossier.is_file(), f"missing dossier: {dossier.relative_to(ROOT)}")
        current = None
        for line in dossier.read_text(encoding="utf-8").splitlines():
            process_match = process_heading.match(line)
            if process_match:
                current = process_match.group(1)
                require(current not in found, f"duplicate dossier process {current}")
                found[current] = []
                continue
            section_match = section_heading.match(line)
            if section_match and current is not None:
                found[current].append((int(section_match.group(1)), section_match.group(2)))
    expected_sections = list(enumerate(sections, start=1))
    require(set(found) == set(process_codes), "dossier process set differs from normative process set")
    for code, actual in found.items():
        require(actual == expected_sections, f"{code} dossier section sequence drift")

    # Priority computational core is deliberately frozen by the implementation plan.
    expected_priority = ["CCTV-02", "CCTV-03", "LAN-01", "LAN-05", "ACS-03", "ACS-04", "ACS-05", "FA-02", "FA-04", "FA-05", "FA-06"]
    require(registry.get("priorityComputationalCore") == expected_priority, "priority computational core drift")

    # Executable arithmetic oracle guard for the corrected ACS-03 reference fixture.
    source_v = Q(24)
    shared_trunk_i = Q("0.8")
    shared_trunk_r = Q("0.5")
    lock_i = Q("0.3")
    lock_branch_r = Q("0.3")
    required_min_v = Q(22)
    terminal_v = source_v - shared_trunk_i * shared_trunk_r - lock_i * lock_branch_r
    low_margin = terminal_v - required_min_v
    require(terminal_v == Q("23.51"), f"ACS-03 terminal-voltage oracle drift: {terminal_v}")
    require(low_margin == Q("1.51"), f"ACS-03 low-margin oracle drift: {low_margin}")
    errata = (IMPL / "calculation-oracle-errata-v1.md").read_text(encoding="utf-8")
    require("23.51" in errata and "+1.51" in errata, "ACS-03 corrected oracle missing from errata authority")

    fourth_audit = load(ROOT / "docs" / "audit" / "elv5-fourth-pass-algorithm-performance-audit.json")
    require(fourth_audit.get("counts", {}).get("total") == 18, "fourth-pass audit subtotal must remain 18")
    require(len(fourth_audit.get("findings", [])) == 18, "fourth-pass finding inventory must remain 18")
    require(fixed["designFindingsResolved"] == 8 + 14 + 15 + 18 + 1, "total design finding count must include oracle-integrity erratum")

    print("ELV5 normative requirements registry PASS")
    print("baseRequirements=80 packages=10 obligations=42 processes=27 sectionsPerProcess=25 vectors=135 findingsResolved=56")
    print("ACS-03 oracle terminalVoltage=23.51V lowMargin=+1.51V")


if __name__ == "__main__":
    main()
