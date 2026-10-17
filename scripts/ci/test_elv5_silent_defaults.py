#!/usr/bin/env python3
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
import sys
import unittest

SCRIPT = Path(__file__).with_name("check-elv5-silent-defaults.py")
SPEC = spec_from_file_location("elv5_silent_defaults", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
MODULE = module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class SilentDefaultGuardTest(unittest.TestCase):
    def scan(self, source: str):
        return MODULE.scan_text(Path("fixture.dart"), source)

    def test_rejects_sensitive_null_fallback(self):
        findings = self.scan("final mediumCode = row.mediumCode ?? 'COPPER';")
        self.assertEqual(len(findings), 1)
        self.assertEqual(
            findings[0].reason,
            "engineering-sensitive null fallback",
        )

    def test_rejects_indirect_sensitive_null_fallback(self):
        findings = self.scan("final capacity = input.capacity ?? policy.defaultCapacity;")
        self.assertEqual(len(findings), 1)

    def test_allows_fail_closed_throw(self):
        findings = self.scan(
            "final mediumCode = row.mediumCode ?? throw StateError('missing medium');"
        )
        self.assertEqual(findings, [])

    def test_allows_reviewed_authority_backed_default(self):
        findings = self.scan(
            "final voltage = input.voltage ?? 230; "
            "// elv5-explicit-default: IEC profile P-230 pinned by ruleset"
        )
        self.assertEqual(findings, [])

    def test_marker_without_rationale_is_not_an_exception(self):
        findings = self.scan(
            "final voltage = input.voltage ?? 230; // elv5-explicit-default: TODO"
        )
        self.assertEqual(len(findings), 1)

    def test_ignores_non_engineering_collection_plumbing(self):
        findings = self.scan("final rows = payload['rows'] ?? const <Object>[];")
        self.assertEqual(findings, [])

    def test_allows_utc_clock_for_audit_metadata(self):
        findings = self.scan("final now = DateTime.now().toUtc();")
        self.assertEqual(findings, [])

    def test_rejects_host_local_timezone_sources(self):
        source = """
final local = capturedAt.toLocal();
final locale = Platform.localeName;
"""
        findings = self.scan(source)
        self.assertEqual(len(findings), 2)
        self.assertTrue(
            all(f.reason == "host-local temporal source" for f in findings)
        )


if __name__ == "__main__":
    unittest.main()
