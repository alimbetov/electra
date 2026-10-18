#!/usr/bin/env python3
"""Verify fourth-pass ELV5 process dossiers and Flutter performance contract."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
AUDIT = ROOT / "docs" / "audit" / "elv5-fourth-pass-algorithm-performance-audit.json"

DOSSIERS = [
    IMPL / "process-specifications" / "cctv-processes.md",
    IMPL / "process-specifications" / "lan-processes.md",
    IMPL / "process-specifications" / "acs-processes.md",
    IMPL / "process-specifications" / "fire-processes.md",
]

SECTIONS = [
    "Physical meaning",
    "Applicability matrix",
    "Exact typed inputs",
    "Evidence requirements",
    "Operating cases",
    "Mathematical model",
    "Equations",
    "Exact/bounded arithmetic",
    "Worst-case selection",
    "Requirement composition",
    "Comparison equations",
    "Margin equation",
    "Governing-case algorithm",
    "Limiting-factor algorithm",
    "Missing/unsupported behavior",
    "Dependency set",
    "Calculation trace",
    "Complexity/resource bounds",
    "Pseudocode",
    "Dart interfaces",
    "Positive reference vector",
    "Boundary vector",
    "Negative vector",
    "Adversarial vector",
    "Cross-discipline vector",
]

EXPECTED = {
    *(f"CCTV-{n:02d}" for n in range(1, 7)),
    *(f"LAN-{n:02d}" for n in range(1, 8)),
    *(f"ACS-{n:02d}" for n in range(1, 7)),
    *(f"FA-{n:02d}" for n in range(1, 9)),
}


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def fail(message: str) -> None:
    raise SystemExit(message)


def parse_dossiers() -> dict[str, list[tuple[int, str]]]:
    found: dict[str, list[tuple[int, str]]] = {}
    process_re = re.compile(r"^## (CCTV-\d{2}|LAN-\d{2}|ACS-\d{2}|FA-\d{2}) — .+$")
    section_re = re.compile(r"^### (\d+)\. (.+)$")

    for path in DOSSIERS:
        if not path.is_file():
            fail(f"missing dossier file: {path.relative_to(ROOT)}")
        text = path.read_text(encoding="utf-8")
        if re.search(r"\b(TBD|TODO|PLACEHOLDER)\b", text, flags=re.IGNORECASE):
            fail(f"placeholder token in {path.relative_to(ROOT)}")

        current: str | None = None
        for line in text.splitlines():
            process_match = process_re.match(line)
            if process_match:
                current = process_match.group(1)
                if current in found:
                    fail(f"duplicate process dossier: {current}")
                found[current] = []
                continue
            section_match = section_re.match(line)
            if section_match and current is not None:
                found[current].append((int(section_match.group(1)), section_match.group(2)))

    return found


def main() -> None:
    found = parse_dossiers()
    codes = set(found)
    if codes != EXPECTED:
        fail(f"dossier process set mismatch missing={sorted(EXPECTED-codes)} extra={sorted(codes-EXPECTED)}")
    if len(found) != 27:
        fail(f"expected 27 dossiers, found {len(found)}")

    expected_sections = list(enumerate(SECTIONS, start=1))
    for code, sections in sorted(found.items()):
        if sections != expected_sections:
            fail(f"{code} section sequence mismatch: {sections}")

    process_registry = load_json(IMPL / "process-registry.json")
    algorithm_registry = load_json(IMPL / "algorithm-registry.json")
    process_codes = {row["code"] for row in process_registry.get("processes", [])}
    algorithm_codes = {row["code"] for row in algorithm_registry.get("processes", [])}
    if process_codes != EXPECTED:
        fail("process-registry.json does not match 27 dossier process codes")
    if algorithm_codes != EXPECTED:
        fail("algorithm-registry.json does not match 27 dossier process codes")

    entry = (IMPL / "process-code-level-specification.md").read_text(encoding="utf-8")
    for index, title in expected_sections:
        marker = f"{index}. {title}"
        if marker not in entry:
            fail(f"missing mandatory dossier marker in entry contract: {marker}")

    performance = (IMPL / "flutter-performance-contract.md").read_text(encoding="utf-8")
    required_performance_tokens = [
        "Elv5CalculationExecutor",
        "NativeElv5WorkerPool",
        "WebElv5ChunkedExecutor",
        "medium/large engineering kernel",
        "Input-fingerprint cache",
        "Incremental recomputation",
        "Deterministic parallel batch plan",
        "Cancellation and supersession",
        "Backpressure/coalescing",
        "Virtualized lists/tables",
        "Profile-mode",
        "500-node coherent calculation batch",
        "workerCount=1",
        "workerCount=N",
    ]
    for token in required_performance_tokens:
        if token.lower() not in performance.lower():
            fail(f"performance contract missing token: {token}")

    errata = (IMPL / "calculation-oracle-errata-v1.md").read_text(encoding="utf-8")
    for token in [
        "ERRATA-001 — ACS-03",
        "V_lock_terminal",
        "23.51 V",
        "+1.51 V",
        "ELV4 owns physical voltage-drop/current solution",
    ]:
        if token not in errata:
            fail(f"ACS-03 oracle errata missing token: {token}")

    audit = load_json(AUDIT)
    counts = audit.get("counts", {})
    if counts.get("high") != 15 or counts.get("medium") != 4 or counts.get("total") != 19:
        fail(f"unexpected fourth-pass audit counts: {counts}")
    findings = audit.get("findings", [])
    if len(findings) != 19:
        fail(f"expected 19 fourth-pass findings, found {len(findings)}")
    if any(row.get("status") != "SPEC_RESOLVED" for row in findings):
        fail("all fourth-pass findings must be SPEC_RESOLVED")
    oracle_finding = [row for row in findings if row.get("code") == "REFERENCE_ORACLE_ARITHMETIC_INTEGRITY"]
    if len(oracle_finding) != 1:
        fail("missing unique REFERENCE_ORACLE_ARITHMETIC_INTEGRITY finding")

    print("ELV5 process code-level specification PASS")
    print("processes=27 sectionsPerProcess=25 vectorClasses=5")
    print("fourthPassFindings=19 high=15 medium=4 runtimeImplemented=0")
    print("acs03CorrectedTerminalVoltage=23.51V")


if __name__ == "__main__":
    main()
