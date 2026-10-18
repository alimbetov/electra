#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
AUDIT = ROOT / "docs" / "audit"
PRODUCT = ROOT / "docs" / "product"

errors: list[str] = []


def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)


def read_text(path: Path) -> str:
    require(path.is_file(), f"missing required file: {path.relative_to(ROOT)}")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


def read_json(path: Path):
    text = read_text(path)
    if not text:
        return {}
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        errors.append(f"invalid JSON {path.relative_to(ROOT)}: {exc}")
        return {}


hardening = read_text(IMPL / "code-level-hardening-v2.md")
index = read_text(PRODUCT / "elv5-authoritative-spec-index.md")
impl_index = read_text(IMPL / "README.md")
audit_md = read_text(AUDIT / "elv5-third-pass-production-readiness-audit.md")
audit_json = read_json(AUDIT / "elv5-third-pass-production-readiness-audit.json")
process_registry = read_json(IMPL / "process-registry.json")
command_registry = read_json(IMPL / "command-registry.json")
requirements = read_json(IMPL / "requirements.json")

processes = process_registry.get("processes", [])
commands = command_registry.get("commands", [])

require(len(processes) == 27, f"expected 27 ELV5 processes, found {len(processes)}")
require(len(commands) == 16, f"expected 16 ELV5 public commands, found {len(commands)}")
require(command_registry.get("wireSchema") == "electra.elv5-discipline-command.v1", "unexpected ELV5 wire schema")
require(command_registry.get("payloadSchemaVersion") == 1, "unexpected ELV5 payload schema version")

codes = [p.get("code") for p in processes]
require(len(codes) == len(set(codes)), "duplicate process code in process-registry.json")
expected_prefix_counts = {"CCTV-": 6, "LAN-": 7, "ACS-": 6, "FA-": 8}
for prefix, count in expected_prefix_counts.items():
    actual = sum(1 for code in codes if isinstance(code, str) and code.startswith(prefix))
    require(actual == count, f"expected {count} {prefix} processes, found {actual}")

for process in processes:
    code = process.get("code", "<unknown>")
    require(bool(process.get("requiredDimensions")), f"{code} has no requiredDimensions")
    ids = process.get("plannedAcceptanceIds", [])
    require(len(ids) == 2, f"{code} must retain exactly POS/NEG primary acceptance IDs")
    require(process.get("runtimeStatus") == "NOT_STARTED", f"{code} runtime status changed without runtime evidence")

summary = audit_json.get("summary", {})
require(summary.get("findingCount") == 15, "third-pass audit must contain 15 findings")
require(summary.get("high") == 11, "third-pass audit must contain 11 HIGH findings")
require(summary.get("medium") == 4, "third-pass audit must contain 4 MEDIUM findings")
findings = audit_json.get("findings", [])
require(len(findings) == 15, "machine-readable third-pass finding inventory must contain 15 rows")
require(len({f.get("id") for f in findings}) == 15, "third-pass finding IDs must be unique")
require(all(f.get("status") == "SPEC_RESOLVED" for f in findings), "all third-pass findings must remain SPEC_RESOLVED")

required_hardening_tokens = [
    "Strongly typed identities",
    "No semantic nullable values",
    "Exact arithmetic resource bounds",
    "Quantity algebra is code-owned",
    "captured zone rules",
    "Measurement evidence",
    "Deterministic requirement composition",
    "Simultaneity, startup/inrush",
    "ACS-06 release truth table",
    "Fire technical supervision",
    "Dependency graph and invalidation hardening",
    "Coherent batch publication",
    "Engineer review/override separation",
    "Stable finding and step cardinality",
    "Cross-discipline engineering invariants",
]
for token in required_hardening_tokens:
    require(token in hardening, f"third-pass hardening lost mandatory section/token: {token}")

# This guard proves that the third-pass authority remains present. Later audits may
# legitimately increase aggregate finding totals, so do not require the whole
# authority index/README to keep old headline wording forever.
for token in [
    "code-level-hardening-v2.md",
    "third-pass production-readiness audit",
    "exactly **16 operations**",
]:
    require(token in index, f"authoritative index lost third-pass authority token: {token}")
require(
    "Total design findings resolved across the three passes: **37**" in index
    or "third-pass" in index.lower() and "37" in index,
    "authoritative index lost historical third-pass subtotal 37",
)

for token in ["code-level-hardening-v2.md", "54", "schema 24"]:
    require(token in impl_index, f"implementation index lost third-pass token: {token}")
require(
    "37 specification resolutions" in impl_index
    or ("third-pass" in impl_index.lower() and "37" in impl_index)
    or "Historical design findings through fourth pass: **56 resolved**" in impl_index,
    "implementation index lost third-pass/fourth-pass finding history",
)

for token in [
    "15 additional findings: 11 HIGH and 4 MEDIUM",
    "ACS",
    "Fire alarm",
    "selector",
]:
    require(token in audit_md, f"third-pass audit prose lost expected token: {token}")

# Requirements schema has evolved across ELV5 design commits. Guard the known fixed
# inventory without assuming whether the JSON root is a list or an object wrapper.
if isinstance(requirements, list):
    requirement_rows = requirements
elif isinstance(requirements, dict):
    requirement_rows = requirements.get("requirements", [])
else:
    requirement_rows = []
require(len(requirement_rows) == 80, f"expected 80 ELV5 requirements, found {len(requirement_rows)}")

if errors:
    print("ELV5 third-pass hardening guard FAILED")
    for error in errors:
        print(f"- {error}")
    raise SystemExit(1)

print("ELV5 third-pass hardening guard PASS")
print(f"processes={len(processes)} commands={len(commands)} requirements={len(requirement_rows)} findings={len(findings)}")
