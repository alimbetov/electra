#!/usr/bin/env python3
"""Reject implicit engineering defaults in production ELV5 code.

The guard is intentionally narrow: it targets null-coalescing defaults whose
left-hand expression carries engineering meaning, plus host-local temporal
sources. Collection plumbing and an explicit fail-closed `?? throw` are not
engineering defaults.

A reviewed exception must be placed on the same line as the expression using:
    // elv5-explicit-default: <authority/rule rationale>
The rationale is mandatory so a default cannot become invisible provenance.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
PRODUCTION_ROOTS = (
    ROOT / "apps/mobile/lib/application/elv5",
    ROOT / "apps/mobile/lib/data/repositories/elv5",
    ROOT / "packages/engineering_core/lib",
)

EXPLICIT_DEFAULT_MARKER = "elv5-explicit-default:"
SENSITIVE_NAME = re.compile(
    r"(?i)(?:medium|interface|shield|voltage|current|powerfactor|power_factor|"
    r"temperature|ambient|length|distance|bitrate|rate|capacity|timezone|"
    r"time_zone|tzdb|redundancy|conductor|material|evidence|policy|environment|"
    r"route|path|ampacity|attenuation|optical|resistance|reactance|impedance|"
    r"efficiency|diversity|reserve|demand|load|fault|battery|runtime)"
)
HOST_TEMPORAL = re.compile(
    r"(?:DateTime\.now\s*\(\)|\.toLocal\s*\(\)|Platform\.localeName)"
)


@dataclass(frozen=True)
class Finding:
    path: Path
    line: int
    text: str
    reason: str


def dart_files() -> list[Path]:
    files: list[Path] = []
    for root in PRODUCTION_ROOTS:
        if not root.exists():
            continue
        for path in root.rglob("*.dart"):
            if path.name.endswith(".g.dart") or path.name.endswith(".freezed.dart"):
                continue
            files.append(path)
    return sorted(set(files))


def _has_reviewed_exception(line: str) -> bool:
    if EXPLICIT_DEFAULT_MARKER not in line:
        return False
    rationale = line.split(EXPLICIT_DEFAULT_MARKER, 1)[1].strip()
    return len(rationale) >= 12


def _coalescing_left(line: str) -> str | None:
    if "??" not in line:
        return None
    left, right = line.split("??", 1)
    if right.lstrip().startswith("throw "):
        return None
    return left


def scan_text(path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    for number, raw in enumerate(text.splitlines(), start=1):
        line = raw.strip()
        if not line or line.startswith("//") or _has_reviewed_exception(line):
            continue

        left = _coalescing_left(line)
        if left is not None and SENSITIVE_NAME.search(left):
            findings.append(
                Finding(path, number, raw, "engineering-sensitive null fallback")
            )

        # Engineering calculations must not depend on the executing host's
        # wall clock / local timezone. UTC timestamps are supplied explicitly
        # by command/runtime boundaries elsewhere in the architecture.
        if HOST_TEMPORAL.search(line):
            findings.append(
                Finding(path, number, raw, "host-local temporal source")
            )
    return findings


def scan_repository() -> list[Finding]:
    findings: list[Finding] = []
    for path in dart_files():
        findings.extend(scan_text(path, path.read_text(encoding="utf-8")))
    return findings


def main() -> None:
    findings = scan_repository()
    if findings:
        print("ELV5 silent-default guard failed:")
        for finding in findings:
            relative = finding.path.relative_to(ROOT)
            print(
                f"  {relative}:{finding.line}: {finding.reason}\n"
                f"    {finding.text.strip()}"
            )
        raise SystemExit(
            "Replace each implicit engineering default with authoritative input, "
            "explicit authority-backed provenance, or BLOCKED/UNRESOLVED."
        )
    print(
        "PASS: ELV5 production code contains no unreviewed engineering-sensitive "
        "null defaults or host-local temporal sources."
    )


if __name__ == "__main__":
    main()
