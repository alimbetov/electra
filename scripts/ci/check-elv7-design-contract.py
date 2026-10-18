#!/usr/bin/env python3
"""Validate ELV7 design manifests; never emit runtime qualification evidence."""

import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "docs/product/elv7-implementation"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def unique(items, label):
    require(len(items) == len(set(items)), f"Duplicate {label}")


def load(name, schema):
    data = json.loads((PACKAGE / name).read_text())
    require(data["schema"] == schema, f"Wrong schema: {name}")
    return data


def pinned_file(sha, path):
    return subprocess.check_output(["git", "show", f"{sha}:{path}"], cwd=ROOT)


def check_component_catalogue():
    """Check the design handoff against real pinned target inventories."""
    directory = ROOT / "docs/product/component-catalog"
    manifest = json.loads((directory / "design-manifest.json").read_text())
    plan = json.loads((directory / "acceptance-plan.json").read_text())
    require(manifest["schema"] == "electra.component-catalog-design.v1" and
            plan["schema"] == "electra.component-catalog-acceptance-plan.v1",
            "Catalogue design schema drift")
    require(manifest["status"] == "DESIGN_PROPOSAL" and
            manifest["runtimeStatus"] == "NOT_STARTED" and
            manifest["productionDataLoaded"] is False and
            manifest["productionQualifiedFamilies"] == 0,
            "Catalogue design cannot imply implemented data/runtime")
    storage = manifest["storage"]
    require(storage["catalogueDatabase"] == "electra-catalog.db" and
            storage["projectDatabase"] == "EXISTING_APP_DATABASE" and
            storage["crossDatabaseAtomicityAssumed"] is False and
            storage["projectSnapshotsSelfContained"] is True and
            storage["pricesInTechnicalHash"] is False and
            storage["migrationVersionReserved"] is False,
            "Catalogue/project/price ownership boundary drift")
    families = manifest["families"]
    unique([f["code"] for f in families], "catalogue family codes")
    unique([f["technicalSchema"] for f in families], "catalogue technical schemas")
    require(len(families) == 22, "Expected 22 planned product families")
    for family in families:
        require(family["requiredFacets"] and family["implementation"] == "NOT_STARTED" and
                family["qualified"] is False, "Unsubstantiated family support")

    upstreams = manifest["upstreams"]
    unique([u["branch"] for u in upstreams], "catalogue handoff branches")
    require({u["branch"] for u in upstreams} == {
        "target/electra-professional-electrical-platform",
        "feat/flutter-elv6-enclosure-layout-design", "feat/flutter-elv8-deliverables-design"},
        "Missing catalogue upstream contract")
    artifacts = {}
    for upstream in upstreams:
        require(re.fullmatch(r"[0-9a-f]{40}", upstream["sourceSha"]) and
                upstream["authority"] == "DESIGN_ONLY_NOT_RUNTIME_ACCEPTANCE",
                "Invalid catalogue source pin/authority")
        unique([a["path"] for a in upstream["artifacts"]], "catalogue source paths")
        for artifact in upstream["artifacts"]:
            require(artifact["path"].startswith("docs/product/") and
                    ".." not in Path(artifact["path"]).parts, "Unsafe catalogue upstream path")
            raw = pinned_file(upstream["sourceSha"], artifact["path"])
            require(hashlib.sha256(raw).hexdigest() == artifact["sha256"],
                    f"Catalogue source fingerprint mismatch: {artifact['path']}")
            artifacts[artifact["path"]] = raw
    required_sources = {
        "platformMappings": ("electra-professional-electrical-platform-target.json", "code", 21),
        "killerMappings": ("electra-killer-capability-layer.json", "id", 14),
        "smartBuildingMappings": ("electra-smart-building-home-automation-target.json", "id", 10),
    }
    for field, (filename, code_key, count) in required_sources.items():
        source = json.loads(artifacts[f"docs/product/{filename}"])
        mappings = manifest[field]
        unique([m["code"] for m in mappings], field)
        require(len(mappings) == count and {m["code"] for m in mappings} ==
                {c[code_key] for c in source["capabilities"]}, f"Incomplete target mapping: {field}")
        for mapping in mappings:
            require(mapping["contribution"] and mapping["implementation"] == "NOT_STARTED",
                    f"Missing design contribution or false runtime claim: {mapping['code']}")
    smart = json.loads(artifacts["docs/product/electra-smart-building-home-automation-target.json"])
    require(manifest["smartBuildingProtocolFamilies"] == smart["protocolFamilies"],
            "Dropped or conflated smart-building protocol/transport family")
    require(manifest["knownSourceDiscrepancies"], "Record target prose/machine inventory discrepancy")
    require({"NO_CROSS_DATABASE_TRANSACTION_ASSUMPTION", "SELF_CONTAINED_PROJECT_ADOPTION",
             "HARD_CONSTRAINTS_BEFORE_COST", "PRICE_ONLY_CHANGE_NO_TECHNICAL_MUTATION",
             "ELV6_OWNS_REAL_LAYOUT", "ELV7_OWNS_NORMATIVE_CLAIMS", "ELV8_OWNS_SELECTION",
             "NO_FALSE_OPTIMUM", "PROTOCOL_SEPARATE_FROM_TRANSPORT",
             "POWER_CONTROL_COMMUNICATION_SEPARATE", "NO_SECRET_CREDENTIALS",
             "NO_TARGET_ACCEPTANCE_INFERENCE"} <= set(manifest["requiredInvariants"]),
            "Catalogue/configuration safety boundary missing")
    require({p["code"] for p in manifest["implementationPackages"]} ==
            {f"C{i}" for i in range(8)} and all(p["status"] == "NOT_STARTED"
            for p in manifest["implementationPackages"]), "Catalogue package status drift")
    cases = plan["cases"]
    unique([c["id"] for c in cases], "catalogue planned case IDs")
    unique([c["scenario"] for c in cases], "catalogue planned scenarios")
    require(plan["evidenceScope"] == "DESIGN_ONLY" and plan["runtimeAccepted"] is False and
            len(cases) == plan["plannedCaseCount"] == 40, "Catalogue qualification plan drift")
    for case in cases:
        require(case["oracle"] and case["status"] == "PLANNED" and case["executed"] is False,
                "Planned catalogue case cannot certify runtime")
    require({"CHEAPEST_DOES_NOT_FIT", "OWNER_TRANSACTION_FAULT", "PRICE_ONLY_REFRESH",
             "PACK_MOQ_TIERS", "SMART_PROTOCOL_TRANSPORT", "BROWNFIELD_UNCERTAIN_IDENTITY",
             "HISTORY_WITHOUT_CATALOGUE"} <= {c["scenario"] for c in cases},
            "Missing critical catalogue acceptance objective")
    for doc in directory.glob("*.md"):
        for link in re.findall(r"\]\(([^)]+)\)", doc.read_text()):
            if "://" not in link and not link.startswith("#"):
                require((doc.parent / link.split("#")[0]).exists(), f"Broken catalogue link: {link}")
    print("CATALOGUE DESIGN CONSISTENCY PASS: 22 planned families; "
          "21 CAP / 14 K / 10 SH mappings; 40 PLANNED cases; no runtime acceptance.")


def main():
    rules = load("rule-family-registry.json", "electra.elv7-rule-family-registry.v1")
    commands = load("command-registry.json", "electra.elv7-command-registry.v1")
    plan = load("qualification-plan.json", "electra.elv7-qualification-plan.v1")
    baseline = load("baseline-and-handoff.json", "electra.elv7-baseline-handoff.v1")
    gates = {f"Q{i}" for i in range(10)}
    families = rules["families"]
    ids = [f["id"] for f in families]
    unique(ids, "family IDs")
    require(set(ids) == {f"NRM-{i:02}" for i in range(1, 46)}, "Expected 45 families")
    unique([f["checkerId"] for f in families], "checker IDs")
    unique([f["inputSchema"] for f in families], "input schemas")
    require(rules["productionVerifiedPacks"] == 0, "Design cannot certify source packs")
    require(rules["runtimeStatus"] == commands["runtimeStatus"] == "NOT_STARTED",
            "Runtime status changed: qualify runtime separately before replacing design guard")
    mapped = set()
    for f in families:
        require(f["implementation"] == "NOT_STARTED" and f["productionQualified"] is False,
                f"Unsubstantiated runtime qualification: {f['id']}")
        require(set(f["qualificationGates"]) == gates, f"Missing Q0-Q9: {f['id']}")
        require(f["requiredFacts"] and f["negativeOracle"] and f["requiredSources"],
                f"Incomplete input/source/oracle contract: {f['id']}")
        unique(f["elv5Processes"], f"process mapping in {f['id']}")
        mapped.update(f["elv5Processes"])
    expected_processes = {f"{prefix}-{i:02}" for prefix, count in
                          (("CCTV", 6), ("LAN", 7), ("ACS", 6), ("FA", 8))
                          for i in range(1, count + 1)}
    require(mapped == expected_processes == set(baseline["requiredElv5Processes"]),
            "All and only 27 ELV5 process codes must map to normative families")
    require(baseline["elv5ProcessCount"] == len(mapped), "Incorrect ELV5 count")

    expected_operations = {
        "ADOPT_NORMATIVE_PROFILE", "RELEASE_NORMATIVE_PROFILE", "REPLACE_NORMATIVE_CONTEXT",
        "RUN_NORMATIVE_VALIDATION", "RECORD_NORMATIVE_REVIEW", "APPROVE_NORMATIVE_REVIEW",
        "REJECT_NORMATIVE_REVIEW", "CREATE_NORMATIVE_DEVIATION", "APPROVE_NORMATIVE_DEVIATION",
        "REJECT_NORMATIVE_DEVIATION", "REVOKE_NORMATIVE_DISPOSITION", "ADOPT_NORMATIVE_SOURCE_UPDATE",
    }
    operations = [c["operation"] for c in commands["commands"]]
    unique(operations, "operations")
    require(set(operations) == expected_operations, "Project wire surface drift")
    require(commands["wireSchema"] == "electra.elv7-normative-command.v1" and
            commands["payloadVersion"] == 1, "Wire version drift")
    common = {"commandId", "projectId", "designRevisionId", "expectedDesignRevision",
              "expectedAggregateGeneration", "normalizedPayloadHash"}
    for c in commands["commands"]:
        require(c["replay"] == "BEFORE_PRECONDITIONS" and
                c["transaction"] == "SHARED_PROJECT_UOW", f"Lifecycle split: {c['operation']}")
        require(common <= set(c["envelopeRequired"]), f"Missing envelope fields: {c['operation']}")
        require(c["payloadRequired"] and c["invariant"] and c["aggregate"],
                f"Incomplete payload contract: {c['operation']}")
        require(c["payloadSchema"] == "electra.elv7-" + c["operation"].lower().replace("_", "-") + ".v1",
                f"Unversioned payload: {c['operation']}")
    unique(commands["catalogueAdministration"], "catalogue commands")
    require(not (set(operations) & set(commands["catalogueAdministration"])), "Governance boundary overlap")
    require(set(commands["inheritedRevisionCommands"]) == {
        "FREEZE_PROJECT_DESIGN_REVISION", "CREATE_NEXT_WORKING_DESIGN_REVISION"},
        "Use shared revision commands")
    require({"verified", "compliant", "checkerCode", "trustedDependencyClosure"} <=
            set(commands["forbiddenProjectFields"]), "Client trust boundary weakened")

    cases = plan["cases"]
    unique([c["id"] for c in cases], "planned case IDs")
    require(len(cases) == plan["plannedCaseCount"] == 364, "Qualification plan count drift")
    require(plan["evidenceScope"] == "DESIGN_ONLY" and plan["runtimeAccepted"] is False and
            plan["qualifiedFamilies"] == 0, "Planned cases cannot certify production")
    for c in cases:
        require(c["status"] == "PLANNED" and c["executed"] is False and c["gate"] in gates,
                f"Invalid planned-case claim: {c['id']}")
        require(c.get("oracle") or c.get("scenario"), f"Missing case objective: {c['id']}")
        require("family" not in c or c["family"] in ids, f"Unknown family: {c['id']}")
    for family in ids:
        actual = {c["id"] for c in cases if c.get("family") == family}
        require(actual == {f"{family}-{suffix}" for suffix in
                           ("SAT", "VIO", "NA", "MISS", "BOUND", "STALE", "HIST")},
                f"Incomplete family qualification plan: {family}")
    for prefix, count in (("PROTECTION", 24), ("LIFECYCLE", 12), ("GOVERNANCE", 13)):
        require(sum(c["id"].startswith(f"ELV7-{prefix}-") for c in cases) == count,
                f"Missing {prefix} risk cases")
    scenarios = {c.get("scenario") for c in cases}
    require({"D_14_VS_20_PRODUCT_SCOPE", "RCD_B_NOT_MCB_B", "LOWER_MAGNETIC_BOUNDARY",
             "WAIVER_CANNOT_GREEN_LEGAL_VIOLATION", "EMPTY_SCOPE_NOT_PASS",
             "INDEPENDENT_CONNECTION_CAS", "TOMBSTONED_ROOT_CREATE_NEXT",
             "SOURCE_REVOCATION_DURING_CAPTURE", "AUTHORITY_EXPIRY_BOUNDARY_OFFLINE"} <= scenarios,
            "Critical regression objectives missing")
    require({"sourceSha", "sourceTreeState", "testPath", "testName", "nonSkippedResult",
             "profileHash", "checkerVersion", "authorityHash", "persistedRunId",
             "consumedGenerations", "canonicalOutcomeHash"} <= set(plan["requiredWitnessFields"]),
            "Missing execution provenance fields")

    for field in ("mainMergeSha", "elv5RuntimeSha", "elv6DesignSha"):
        require(re.fullmatch(r"[0-9a-f]{40}", baseline[field]), f"Invalid SHA: {field}")
    require(baseline["elv5FullAcceptanceInferred"] is False and
            baseline["elv6RuntimeStatus"] == "NOT_STARTED" and
            baseline["elv6ContractStatus"] == "PROVISIONAL_DESIGN_ONLY",
            "Merge/design must not imply runtime acceptance")
    artifacts = baseline["elv6Artifacts"]
    unique([a["path"] for a in artifacts], "ELV6 pins")
    require(len(artifacts) == 4, "Expected four provisional upstream contracts")
    for artifact in artifacts:
        require(artifact["path"].startswith("docs/product/elv6-implementation/") and
                ".." not in Path(artifact["path"]).parts, "Unsafe upstream path")
        raw = pinned_file(baseline["elv6DesignSha"], artifact["path"])
        require(hashlib.sha256(raw).hexdigest() == artifact["sha256"],
                f"ELV6 contract fingerprint mismatch: {artifact['path']}")
        if artifact["path"].endswith("/process-registry.json"):
            layout = json.loads(raw)
            require(len(layout["processes"]) == baseline["elv6LayoutProcessCount"] == 24,
                    "ELV6 process coverage drift")

    for doc in PACKAGE.glob("*.md"):
        for link in re.findall(r"\]\(([^)]+)\)", doc.read_text()):
            if "://" not in link and not link.startswith("#"):
                require((doc.parent / link.split("#")[0]).exists(), f"Broken link in {doc.name}: {link}")
    protection = (PACKAGE / "protection-and-classification-contract.md").read_text()
    for namespace in ("OVERCURRENT_TRIP_CURVE", "RESIDUAL_WAVEFORM_TYPE", "FUSE_UTILIZATION",
                      "SPD_TEST_TYPE", "CABLE_REACTION_TO_FIRE", "BUILDING_FIRE_CATEGORY",
                      "SUPPLY_RELIABILITY_CATEGORY", "ENCLOSURE_PROTECTION", "CIRCUIT_PURPOSE_GROUP",
                      "RESIDUAL_TIME_BEHAVIOUR"):
        require(namespace in protection, f"Missing classification namespace: {namespace}")
    check_component_catalogue()
    print("ELV7 DESIGN CONSISTENCY PASS: 45 families; 27 mapped ELV5 processes; "
          "12 project commands; 364 PLANNED cases; 0 runtime-qualified families.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, KeyError, OSError, json.JSONDecodeError, subprocess.CalledProcessError) as exc:
        print(f"ELV7 DESIGN CONSISTENCY FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
