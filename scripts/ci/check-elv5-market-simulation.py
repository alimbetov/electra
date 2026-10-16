#!/usr/bin/env python3
"""Generate and validate the deterministic 450-case ELV5 market simulation matrix.

This is design-simulation evidence, not production Dart runtime qualification and
not an ELV7 compliance or ELV8 procurement decision.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from fractions import Fraction as Q
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / "docs" / "product" / "elv5-implementation"
CATALOG_PATH = IMPL / "market-simulation-catalog.json"
REQUIREMENTS_PATH = IMPL / "market-simulation-requirements.json"
PROCESS_REGISTRY_PATH = IMPL / "process-registry.json"
ALGORITHM_REGISTRY_PATH = IMPL / "algorithm-registry.json"
NORMATIVE_REQUIREMENTS_PATH = IMPL / "normative-requirements-registry.json"

VECTOR_CLASSES = [
    "POSITIVE",
    "BOUNDARY",
    "NEGATIVE_OR_UNSUPPORTED",
    "ADVERSARIAL",
    "CROSS_DISCIPLINE",
]

PRIORITY_CORE = [
    "CCTV-02", "CCTV-03", "LAN-01", "LAN-05", "ACS-03", "ACS-04",
    "ACS-05", "FA-02", "FA-04", "FA-05", "FA-06",
]


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def source_sha() -> str:
    env_sha = os.getenv("GITHUB_SHA")
    if env_sha:
        return env_sha
    try:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    except (OSError, subprocess.CalledProcessError):
        return "UNKNOWN"


def canonical_sha256(value: object) -> str:
    data = json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return hashlib.sha256(data).hexdigest()


def discipline_for(code: str) -> str:
    if code.startswith("CCTV-"):
        return "CCTV"
    if code.startswith("LAN-"):
        return "LAN"
    if code.startswith("ACS-"):
        return "ACS"
    if code.startswith("FA-"):
        return "FIRE"
    raise ValueError(code)


def expected_disposition(vector_class: str, stress_axis: str, index: int) -> str:
    if vector_class == "POSITIVE":
        return "SUCCEEDED_COMPLETE_PASS"
    if vector_class == "BOUNDARY":
        return "SUCCEEDED_COMPLETE_PASS_EXACT_LIMIT"
    if vector_class == "NEGATIVE_OR_UNSUPPORTED":
        blocked_tokens = ("MISSING", "UNKNOWN", "UNSUPPORTED", "FRAME_MISMATCH", "MODEL", "EVIDENCE")
        return "SUCCEEDED_BLOCKED_UNRESOLVED" if any(token in stress_axis for token in blocked_tokens) else "SUCCEEDED_COMPLETE_FAIL"
    if vector_class == "ADVERSARIAL":
        reject_tokens = ("DUPLICATE", "ALIAS", "TRUTH_TABLE", "MULTIPLICITY", "ADDRESS")
        return "REJECTED_INVALID_INPUT" if any(token in stress_axis for token in reject_tokens) else "SUCCEEDED_COMPLETE_FAIL"
    return "SUCCEEDED_COMPLETE_PASS_WITH_CROSS_DISCIPLINE_EVIDENCE" if index % 2 == 0 else "SUCCEEDED_BLOCKED_ON_UPSTREAM_EVIDENCE"


def risk_code(process_code: str, stress_axis: str) -> str:
    axis = stress_axis
    if any(token in axis for token in ("DUPLICATE", "ALIAS", "MULTIPLICITY")):
        return "DUPLICATE_PHYSICAL_RESOURCE"
    if any(token in axis for token in ("RESERVE", "DERATING", "REDUNDANCY")):
        return "DOUBLE_RESERVE_OR_DERATING"
    if "STALE" in axis:
        return "STALE_EVIDENCE_PUBLISH"
    if "MULTICAST" in axis:
        return "MULTICAST_FALSE_DEDUP"
    if process_code == "CCTV-02" and any(token in axis for token in ("BITRATE", "WIRE_OVERHEAD")):
        return "BITRATE_INFERENCE_FROM_LABEL"
    if process_code == "CCTV-03" and any(token in axis for token in ("DST", "OVERLAP", "CEIL")):
        return "STORAGE_INTERVAL_DOUBLE_COUNT"
    if any(token in axis for token in ("SHARED", "DISCIPLINE_FILTER", "GLOBAL_DEMAND", "GLOBAL_FIRE_LOAD", "NON_ACS", "NON_FIRE")):
        return "DISCIPLINE_FILTERED_SHARED_TOTAL"
    if process_code == "LAN-05" and "OVERLOAD" in axis:
        return "OPTICAL_OVERLOAD_IGNORED"
    if process_code == "LAN-05" and "REACH" in axis:
        return "OPTICAL_BUDGET_EQUALS_REACH"
    if process_code == "LAN-06" and "LAYOUT" in axis:
        return "RACK_CAPACITY_EQUALS_LAYOUT"
    if process_code == "ACS-03" and "CONTROL" in axis:
        return "CONTROL_PATH_EQUALS_POWER_FEED"
    if any(token in axis for token in ("STARTUP", "INRUSH")):
        return "STARTUP_OR_INRUSH_IGNORED"
    if process_code == "ACS-06":
        return "FAIL_SAFE_RELEASE_LOGIC_INCOMPLETE"
    if process_code in {"ACS-05", "FA-05"} and any(token in axis for token in ("AH", "BATTERY", "SEQUENCE", "ENERGY_VS_CURRENT")):
        return "BATTERY_AH_SHORTCUT"
    if process_code in {"FA-01", "FA-07"} and "ADDRESS" in axis:
        return "FIRE_ADDRESS_OVERLAP"
    if process_code == "FA-07" and "POWER_SIGNAL" in axis:
        return "SIGNAL_TOPOLOGY_EQUALS_POWER_MODEL"
    if process_code == "FA-08" and "COMPLIANCE" in axis:
        return "TECHNICAL_MATCH_EQUALS_COMPLIANCE"
    if process_code in {"LAN-02", "LAN-07", "ACS-02", "FA-01"}:
        return "PORT_OR_ADDRESS_ALIAS"
    if any(token in axis for token in ("MISSING", "UNKNOWN", "UNSUPPORTED")):
        return "TYPICAL_AS_GUARANTEED"
    return "UNIT_DIMENSION_COLLAPSE"


def remediation_for(risk: str) -> str:
    mapping = {
        "UNIT_DIMENSION_COLLAPSE": "Use typed quantity/evidence primitives; never convert engineering meaning through untyped scalar shortcuts.",
        "DUPLICATE_PHYSICAL_RESOURCE": "Resolve canonical physical identity and membership before counting demand/capacity.",
        "TYPICAL_AS_GUARANTEED": "Capture guaranteed bound or mark affected dimension UNRESOLVED/BLOCKED.",
        "DOUBLE_RESERVE_OR_DERATING": "Apply factor at its single declared ownership boundary and expose provenance in trace.",
        "DISCIPLINE_FILTERED_SHARED_TOTAL": "Recalculate/consume the complete global physical source closure; project discipline contribution only for explanation.",
        "STALE_EVIDENCE_PUBLISH": "Invalidate affected closure and reject publication if captured generations/fingerprints changed.",
        "BITRATE_INFERENCE_FROM_LABEL": "Capture explicit expected/peak encoded bitrate and optional transport overhead model.",
        "MULTICAST_FALSE_DEDUP": "Require explicit multicast group/tree evidence before edge-copy deduplication.",
        "STORAGE_INTERVAL_DOUBLE_COUNT": "Expand timezone rules, union half-open intervals, integrate exact bytes, then reserve/ceil once.",
        "PORT_OR_ADDRESS_ALIAS": "Count exact canonical port/address identities and reject overlapping claims.",
        "OPTICAL_OVERLOAD_IGNORED": "Evaluate sensitivity and overload in both optical directions using min/max loss interval.",
        "OPTICAL_BUDGET_EQUALS_REACH": "Keep power budget PASS separate from reach/dispersion applicability evidence.",
        "RACK_CAPACITY_EQUALS_LAYOUT": "Report demand/capacity basis only and hand actual fit to ELV6.",
        "CONTROL_PATH_EQUALS_POWER_FEED": "Model relay/control and conductive DC feed as independent typed paths.",
        "STARTUP_OR_INRUSH_IGNORED": "Build explicit bounded transient operating cases and select worst valid margin.",
        "FAIL_SAFE_RELEASE_LOGIC_INCOMPLETE": "Complete canonical five-cause release truth table and evaluate each path independently.",
        "BATTERY_AH_SHORTCUT": "Use supported ELV4 bank model with ordered duration/load sequence, voltage/current/EOD applicability.",
        "FIRE_ADDRESS_OVERLAP": "Expand full address claim set in loop/panel domain and reject duplicates/reserved overlap.",
        "SIGNAL_TOPOLOGY_EQUALS_POWER_MODEL": "Validate signaling topology separately; unsupported electrical mesh remains BLOCKED.",
        "TECHNICAL_MATCH_EQUALS_COMPLIANCE": "Keep project technical match separate and hand jurisdictional verification to ELV7.",
        "N_PLUS_ONE_CAPTURE": "Use indexed bulk capture/publish and query-plan evidence.",
        "UI_GLOBAL_REBUILD": "Project immutable card-sized state and virtualize large collections.",
    }
    return mapping[risk]


def reference_computation(process_code: str, idx: int, vector_class: str) -> dict[str, object]:
    """Market-shaped deterministic arithmetic probes; not production algorithm authority."""
    factor = (idx % 5) + 1
    if process_code == "CCTV-02":
        expected = Q(2 + factor * 2)
        peak = expected * 2
        copies = 1 + idx % 3
        return {"expectedBitrateMbps": str(expected), "peakBitrateMbps": str(peak), "edgeCopies": copies,
                "edgeExpectedMbps": str(expected * copies), "edgePeakMbps": str(peak * copies)}
    if process_code == "CCTV-03":
        bitrate_mbps = Q(2 + factor * 2)
        hours = [8, 12, 24][idx % 3]
        days = [7, 14, 30, 60, 90][idx % 5]
        reserve = [Q("1.0"), Q("1.1"), Q("1.2"), Q("1.3")][idx % 4]
        redundancy = [Q(1), Q("0.8"), Q("0.5")][idx % 3]
        seconds = Q(hours * 3600 * days)
        usable = bitrate_mbps * Q(1_000_000) * seconds / 8
        reserved = usable * reserve
        raw = math.ceil(reserved / redundancy)
        return {"bitrateMbps": str(bitrate_mbps), "recordingHoursPerDay": hours, "days": days,
                "reserve": str(reserve), "redundancyUsableFraction": str(redundancy), "rawRequiredBytesCeil": raw}
    if process_code == "LAN-01":
        permanent = [30, 70, 89, 90, 95][idx % 5]
        patches = [2, 5, 10][idx % 3]
        return {"permanentM": permanent, "patchM": patches, "channelM": permanent + patches}
    if process_code == "LAN-05":
        length_km = Q([1, 2, 5, 10][idx % 4])
        alpha = Q("0.38")
        connector_pairs = 2 + idx % 4
        connector_loss = Q("0.3") * connector_pairs
        splices = idx % 5
        splice_loss = Q("0.1") * splices
        loss = alpha * length_km + connector_loss + splice_loss
        tx_min, tx_max = Q(-9), Q(-3)
        sensitivity, overload = Q(-20), Q(-3)
        rx_low, rx_high = tx_min - loss, tx_max - loss
        return {"lengthKm": str(length_km), "lossDb": str(loss), "rxLowDbm": str(rx_low), "rxHighDbm": str(rx_high),
                "sensitivityMarginDb": str(rx_low - sensitivity), "overloadMarginDb": str(overload - rx_high)}
    if process_code == "ACS-03":
        source_v = Q(24)
        trunk_i = [Q("0.2"), Q("0.5"), Q("0.8"), Q("1.2")][idx % 4]
        trunk_r = [Q("0.1"), Q("0.5"), Q("1.0")][idx % 3]
        lock_i = [Q("0.088"), Q("0.1"), Q("0.37"), Q("0.56")][idx % 4]
        branch_r = [Q("0.1"), Q("0.3"), Q("0.8")][idx % 3]
        terminal = source_v - trunk_i * trunk_r - lock_i * branch_r
        return {"sourceV": str(source_v), "trunkA": str(trunk_i), "trunkOhm": str(trunk_r), "lockA": str(lock_i),
                "branchOhm": str(branch_r), "terminalV": str(terminal), "lowMarginVs22V": str(terminal - Q(22))}
    if process_code in {"ACS-04", "FA-04"}:
        demand = Q(20 + factor * 10)
        reserve = [Q("1.0"), Q("1.15"), Q("1.2"), Q("1.25")][idx % 4]
        rating = Q([40, 60, 100, 150][idx % 4])
        derating = [Q("1.0"), Q("0.9"), Q("0.8")][idx % 3]
        required = demand * reserve
        available = rating * derating
        return {"physicalDemandW": str(demand), "reserve": str(reserve), "requiredCapabilityW": str(required),
                "ratingW": str(rating), "derating": str(derating), "availableW": str(available), "marginW": str(available - required)}
    if process_code == "ACS-05":
        power = Q([10, 20, 40, 80][idx % 4])
        hours = Q([1, 2, 4, 8][idx % 4])
        usable = Q([50, 100, 200, 400][idx % 4])
        required = power * hours
        return {"loadW": str(power), "durationH": str(hours), "sequenceEnergyWh": str(required), "usableBankWh": str(usable), "marginWh": str(usable - required)}
    if process_code == "FA-02":
        devices = [10, 50, 198, 500, 954][idx % 5]
        standby_ma = Q("0.25") * devices + Q(40)
        alarm_ma = Q("2.0") * min(devices, 100) + Q(200)
        return {"deviceCount": devices, "standbyCurrentMa": str(standby_ma), "alarmCurrentMa": str(alarm_ma)}
    if process_code == "FA-05":
        standby_w = Q([6, 12, 24, 48][idx % 4])
        standby_h = Q([4, 24, 60][idx % 3])
        alarm_w = standby_w * 2
        alarm_min = Q([5, 10, 15, 30][idx % 4])
        energy = standby_w * standby_h + alarm_w * alarm_min / 60
        return {"standbyW": str(standby_w), "standbyH": str(standby_h), "alarmW": str(alarm_w),
                "alarmMinutes": str(alarm_min), "sequenceEnergyWh": str(energy)}
    if process_code == "FA-06":
        count = [4, 16, 32, 64][idx % 4]
        per_device_a = [Q("0.02"), Q("0.05"), Q("0.1")][idx % 3]
        output_limit = [Q("0.5"), Q("1.25"), Q("2.5")][idx % 3]
        total = Q(count) * per_device_a
        return {"deviceCount": count, "perDeviceA": str(per_device_a), "totalA": str(total), "outputLimitA": str(output_limit), "marginA": str(output_limit - total)}
    if process_code == "FA-01":
        panel_limit = [50, 198, 954][idx % 3]
        devices = max(1, panel_limit - (idx % 7))
        addresses = devices + (idx % 5)
        return {"panelAddressClass": panel_limit, "physicalDevices": devices, "consumedAddresses": addresses, "marginAddresses": panel_limit - addresses}
    if process_code in {"CCTV-04", "LAN-03"}:
        global_demand = Q(100 + factor * 50)
        budget = Q([315, 600, 1000][idx % 3])
        contribution = global_demand * Q("0.4")
        return {"globalDemandW": str(global_demand), "selectedDisciplineContributionW": str(contribution), "budgetClassW": str(budget), "marginW": str(budget - global_demand)}
    if process_code == "CCTV-05":
        channels = [16, 32, 64][idx % 3]
        used = channels - (idx % 5)
        ingress = Q(used * (4 + idx % 5))
        ingress_limit = Q(channels * 10)
        return {"channelLimit": channels, "assignedChannels": used, "ingressMbps": str(ingress), "ingressLimitMbps": str(ingress_limit)}
    if process_code in {"LAN-02", "LAN-07"}:
        available = [8, 24, 48][idx % 3]
        occupied = max(1, available - (idx % 7))
        spare = math.ceil(Q(occupied, 4))
        return {"availablePorts": available, "occupiedPorts": occupied, "requiredSpare": spare, "marginPorts": available - occupied - spare}
    if process_code == "LAN-06":
        available_ru = [12, 18, 42][idx % 3]
        equipment_ru = [6, 12, 24, 38][idx % 4]
        reserved_ru = [0, 2, 4][idx % 3]
        return {"availableRU": available_ru, "equipmentRU": equipment_ru, "reservedRU": reserved_ru, "basisMarginRU": available_ru - equipment_ru - reserved_ru, "layoutAssessment":"NOT_ASSESSED"}
    if process_code == "ACS-02":
        readers = [2, 4, 8][idx % 3]
        doors = [1, 2, 4, 8][idx % 4]
        relays = readers
        return {"readerChannels": readers, "relayChannels": relays, "doorAssignments": doors, "readerMargin": readers - doors, "relayMargin": relays - doors}
    if process_code == "FA-03":
        source_v = Q(24)
        current = Q(["0.2", "0.5", "1.0", "2.0"][idx % 4])
        resistance = Q(["0.1", "0.2", "0.5", "1.0"][idx % 4])
        terminal = source_v - current * resistance
        return {"sourceV": str(source_v), "currentA": str(current), "pathResistanceOhm": str(resistance), "terminalV": str(terminal)}
    return {"probeIndex": idx, "vectorClass": vector_class, "note":"Structural/topology/basis scenario; exact process equations remain governed by the 25-section dossier."}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    catalog = load(CATALOG_PATH)
    market_requirements = load(REQUIREMENTS_PATH)
    process_registry = load(PROCESS_REGISTRY_PATH)
    algorithm_registry = load(ALGORITHM_REGISTRY_PATH)
    normative = load(NORMATIVE_REQUIREMENTS_PATH)

    require(catalog.get("schema") == "electra.elv5-market-simulation-catalog.v1", "unexpected catalog schema")
    require(catalog.get("scenarioTarget") == 450, "market catalog target must be exactly 450")
    require(catalog.get("generationVersion") == "electra.elv5-market-sim.v1", "unexpected market simulation generation version")
    require(market_requirements.get("scenarioMatrixTarget") == 450, "market simulation requirements target must be 450")
    market_requirement_rows = market_requirements.get("requirements", [])
    require(len(market_requirement_rows) == 12, "expected 12 market-simulation requirements")
    require(len({row.get("id") for row in market_requirement_rows}) == 12, "market-simulation requirement IDs must be unique")
    require(all(row.get("severity") == "MUST" for row in market_requirement_rows), "all market-simulation requirements are MUST")

    process_codes = [row.get("code") for row in process_registry.get("processes", [])]
    algorithm_codes = [row.get("code") for row in algorithm_registry.get("processes", [])]
    require(len(process_codes) == len(set(process_codes)) == 27, "expected 27 unique process registry codes")
    require(set(process_codes) == set(algorithm_codes), "algorithm/process registry mismatch")

    counts = catalog.get("processScenarioCounts", {})
    require(set(counts) == set(process_codes), "market scenario count map must cover exactly the 27 process codes")
    require(sum(counts.values()) == 450, f"market scenario count sum must be 450, found {sum(counts.values())}")
    require(all(counts[code] >= 12 for code in process_codes), "every process needs at least 12 market scenarios")
    require(catalog.get("processStressAxes", {}).keys() == counts.keys(), "every process needs stress axes")

    for code in PRIORITY_CORE:
        require(counts[code] >= 23, f"priority computational core process {code} must have >=23 scenarios")
    for code in set(process_codes) - set(PRIORITY_CORE):
        require(counts[code] == 12, f"non-core process {code} must retain 12-scenario baseline density")

    sources = {row["id"]: row for row in catalog.get("sources", [])}
    require(len(sources) >= 10, "market source catalog is too small")
    official_hosts = ("axis.com", "cisco.com", "corning.com", "assaabloy.com", "hidglobal.com", "honeywell.com")
    for source in sources.values():
        require(source.get("kind") == "vendorFact", f"tracked external source {source['id']} must be labelled vendorFact")
        require(any(host in source.get("url", "") for host in official_hosts), f"source {source['id']} is not an approved manufacturer host")
        require(source.get("observedFacts"), f"source {source['id']} has no observed facts")

    archetypes = catalog.get("marketArchetypes", [])
    require(len(archetypes) >= 16, "market archetype inventory is too small")
    archetypes_by_discipline: dict[str, list[dict[str, object]]] = defaultdict(list)
    for archetype in archetypes:
        require(archetype.get("basis") in {"vendorFact", "marketEnvelope", "syntheticFixture"}, f"unknown archetype basis {archetype.get('basis')}")
        for ref in archetype.get("sourceRefs", []):
            require(ref in sources, f"archetype {archetype['id']} references unknown source {ref}")
        if archetype.get("basis") == "vendorFact":
            require(archetype.get("sourceRefs"), f"vendorFact archetype {archetype['id']} requires sourceRefs")
        archetypes_by_discipline[archetype["discipline"]].append(archetype)
    require(set(archetypes_by_discipline) == {"CCTV", "LAN", "ACS", "FIRE"}, "all four disciplines need market archetypes")

    scales = catalog.get("scales", [])
    require(len(scales) == 4, "expected four deterministic project scales")
    scale_ids = [row["id"] for row in scales]
    require(len(set(scale_ids)) == 4, "scale IDs must be unique")

    error_rows = catalog.get("errorTaxonomy", [])
    error_codes = {row["code"] for row in error_rows}
    require(len(error_codes) >= 20, "engineer error-prevention taxonomy must contain at least 20 error classes")
    for row in error_rows:
        require(row.get("preventedBy") and row.get("engineerImpact"), f"error taxonomy row incomplete: {row.get('code')}")

    package_paths = catalog.get("packagePaths", {})
    require(set(package_paths) == {"CCTV", "LAN", "ACS", "FIRE"}, "missing package path")
    for discipline, path in package_paths.items():
        require(path[0:3] == ["P0", "P1", "P2"], f"{discipline} path must start P0/P1/P2")
        require(path[-3:] == ["P7", "P8", "P9"], f"{discipline} path must end P7/P8/P9")

    scenarios: list[dict[str, object]] = []
    vector_coverage: dict[str, Counter] = defaultdict(Counter)
    stress_coverage: dict[str, Counter] = defaultdict(Counter)
    package_coverage = Counter()
    basis_coverage = Counter()
    source_coverage = Counter()
    risk_coverage = Counter()

    for code in sorted(process_codes):
        discipline = discipline_for(code)
        axes = catalog["processStressAxes"][code]
        market_profiles = archetypes_by_discipline[discipline]
        total = counts[code]
        for index in range(total):
            vector_class = VECTOR_CLASSES[index % len(VECTOR_CLASSES)]
            scale = scales[(index + len(code)) % len(scales)]
            archetype = market_profiles[(index * 3 + len(code)) % len(market_profiles)]
            # Step by one so every axis participates even when the axis count is even.
            stress_axis = axes[(index + len(code)) % len(axes)]
            risk = risk_code(code, stress_axis)
            require(risk in error_codes, f"scenario risk {risk} missing from error taxonomy")
            path = package_paths[discipline]
            disposition = expected_disposition(vector_class, stress_axis, index)
            case = {
                "caseId": f"MKT-{code}-{index + 1:03d}",
                "processCode": code,
                "discipline": discipline,
                "vectorClass": vector_class,
                "projectScale": scale["id"],
                "marketArchetypeId": archetype["id"],
                "marketBasis": archetype["basis"],
                "marketSourceRefs": archetype.get("sourceRefs", []),
                "stressAxis": stress_axis,
                "expectedDisposition": disposition,
                "primaryErrorClass": risk,
                "errorPreventionPackages": next(row["preventedBy"] for row in error_rows if row["code"] == risk),
                "remediationDirection": remediation_for(risk),
                "packagePath": path,
                "referenceComputation": reference_computation(code, index, vector_class),
                "claimScope": "DESIGN_SIMULATION_ONLY_NO_ELV7_COMPLIANCE_NO_ELV8_SELECTION",
            }
            scenarios.append(case)
            vector_coverage[code][vector_class] += 1
            stress_coverage[code][stress_axis] += 1
            for package in path:
                package_coverage[package] += 1
            basis_coverage[archetype["basis"]] += 1
            for source_ref in archetype.get("sourceRefs", []):
                source_coverage[source_ref] += 1
            risk_coverage[risk] += 1

    require(len(scenarios) == 450, f"generated {len(scenarios)} scenarios instead of 450")
    require(len({row["caseId"] for row in scenarios}) == 450, "scenario IDs must be unique")
    for code in process_codes:
        require(sum(vector_coverage[code].values()) == counts[code], f"{code} scenario count mismatch")
        for vector_class in VECTOR_CLASSES:
            require(vector_coverage[code][vector_class] > 0, f"{code} missing vector class {vector_class}")
        expected_axes = set(catalog["processStressAxes"][code])
        require(set(stress_coverage[code]) == expected_axes, f"{code} does not exercise every declared stress axis")
    require(set(package_coverage) == {f"P{i}" for i in range(10)}, f"aggregate package coverage must include P0-P9, found {sorted(package_coverage)}")
    require(basis_coverage["vendorFact"] > 0 and basis_coverage["marketEnvelope"] > 0 and basis_coverage["syntheticFixture"] > 0, "simulation must use all three evidence basis classes")
    require(len(risk_coverage) >= 18, f"error-prevention coverage too narrow: {len(risk_coverage)} classes")

    corrected = Q(24) - Q("0.8") * Q("0.5") - Q("0.3") * Q("0.3")
    require(corrected == Q("23.51"), "ACS-03 corrected reference arithmetic regressed")

    source_facts = " ".join(" ".join(source["observedFacts"]) for source in sources.values())
    for token in ["PoE Class 3", "600 W", "1000 W", "0.38", "88 mA", "370 mA", "560 mA", "198 addressable", "954-device"]:
        require(token in source_facts, f"market source snapshot lost sanity token: {token}")

    result_core = {
        "schema": "electra.elv5-market-simulation-result.v1",
        "generationVersion": catalog["generationVersion"],
        "catalogSha256": canonical_sha256(catalog),
        "requirementsSha256": canonical_sha256(market_requirements),
        "sourceSha": source_sha(),
        "status": "DESIGN_SIMULATION_ONLY_RUNTIME_NOT_EXECUTED",
        "scenarioCount": 450,
        "processCount": 27,
        "priorityCoreCount": len(PRIORITY_CORE),
        "marketRequirementCount": 12,
        "baseRequirementCount": 80,
        "normativeObligationCount": len(normative.get("obligations", [])),
        "processCoverage": dict(sorted(counts.items())),
        "packageCoverage": dict(sorted(package_coverage.items())),
        "vectorCoverage": {code: dict(vector_coverage[code]) for code in sorted(vector_coverage)},
        "stressAxisCoverage": {code: dict(stress_coverage[code]) for code in sorted(stress_coverage)},
        "basisCoverage": dict(basis_coverage),
        "sourceCoverage": dict(sorted(source_coverage.items())),
        "errorClassCoverage": dict(sorted(risk_coverage.items())),
        "acs03CorrectedReferenceV": "23.51",
        "claimScope": "Design simulation only; no production runtime, ELV7 compliance or ELV8 procurement acceptance.",
    }
    result = {**result_core, "matrixFingerprintSha256": canonical_sha256(scenarios), "scenarios": scenarios}

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")

    print("ELV5 market simulation matrix PASS")
    print("scenarios=450 processes=27 packages=P0-P9 vectorClasses=5 allStressAxes=covered marketRequirements=12")
    print(f"vendorFact={basis_coverage['vendorFact']} marketEnvelope={basis_coverage['marketEnvelope']} syntheticFixture={basis_coverage['syntheticFixture']}")
    print(f"errorClassesCovered={len(risk_coverage)} matrixFingerprintSha256={result['matrixFingerprintSha256']}")
    print("claim=DESIGN_SIMULATION_ONLY_RUNTIME_NOT_EXECUTED")


if __name__ == "__main__":
    main()
