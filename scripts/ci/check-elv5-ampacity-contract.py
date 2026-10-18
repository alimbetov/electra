#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REGISTRY = ROOT / "docs/product/elv5-implementation/ampacity-contract-registry.json"
PROCESS_AMENDMENT = ROOT / "docs/product/elv5-implementation/process-registry-ampacity-amendment.json"
NORM_AMENDMENT = ROOT / "docs/product/elv5-implementation/normative-requirements-ampacity-amendment.json"
CONTRACT_DOC = ROOT / "docs/product/elv5-implementation/ampacity-engineering-contract.md"
DOSSIER_AMENDMENT = ROOT / "docs/product/elv5-implementation/process-specifications/fa08-ampacity-amendment.md"
CORE = ROOT / "packages/engineering_core/lib/src/elv5/evidence/ampacity_contract.dart"
FA08 = ROOT / "packages/engineering_core/lib/src/elv5/processes/fire/fa08_cable_policy.dart"

REQUIRED_DRIVERS = {
    "CONDUCTOR_CROSS_SECTION",
    "CONDUCTOR_MATERIAL",
    "AMBIENT_TEMPERATURE",
    "INSTALLATION_METHOD",
    "CABLE_OR_CIRCUIT_GROUPING",
    "LOADED_CONDUCTOR_COUNT",
}


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"ELV5 ampacity contract guard failed: {message}")


def main() -> None:
    registry = load_json(REGISTRY)
    process_amendment = load_json(PROCESS_AMENDMENT)
    norm_amendment = load_json(NORM_AMENDMENT)

    require(registry["processInventoryChange"] == 0, "ampacity must not create process 28")
    require(registry["processInventoryRemains"] == 27, "ELV5 process inventory must remain 27")
    require(
        set(registry["requiredPhysicalDrivers"]) == REQUIRED_DRIVERS,
        "required physical drivers drifted",
    )
    require(
        registry["reservedTechnicalProperty"]
        == {"propertyCode": "AMPACITY_IZ_A", "unitCode": "A"},
        "reserved FA-08 ampacity property drifted",
    )
    require(
        registry["equation"] == "Iz = Iref * kT * kG * product(kAdditional)",
        "canonical Iz equation drifted",
    )
    require(
        process_amendment["targetProcessCode"] == "FA-08",
        "process amendment must target FA-08",
    )
    require(
        process_amendment["processCountDelta"] == 0,
        "FA-08 amendment must not add a process",
    )
    require(
        norm_amendment["baseObligationCountDelta"] == 0,
        "ampacity amendment must not silently change fixed normative inventory",
    )

    contract_text = CONTRACT_DOC.read_text(encoding="utf-8")
    dossier_text = DOSSIER_AMENDMENT.read_text(encoding="utf-8")
    core_text = CORE.read_text(encoding="utf-8")
    fa08_text = FA08.read_text(encoding="utf-8")

    for token in (
        "conductor cross-section",
        "conductor material",
        "installation/wiring method",
        "number of loaded conductors",
        "temperature correction factor",
        "grouping correction factor",
        "Iz = Iref * kT * kG * product(kAdditional[i])",
    ):
        require(token in contract_text, f"contract document missing {token!r}")

    for token in (
        "## 1. Physical meaning",
        "## 25. Cross-discipline vector",
        "AMPACITY_IZ_A",
        "FA08_COMPUTE_IZ_V1",
    ):
        require(token in dossier_text, f"FA-08 dossier amendment missing {token!r}")

    for symbol in (
        "Elv5AmpacityReferenceRow",
        "Elv5AmpacityTemperatureCorrection",
        "Elv5AmpacityGroupingCorrection",
        "Elv5AmpacityInput",
        "Elv5AmpacityResult",
        "Elv5AmpacityKernel",
    ):
        require(symbol in core_text, f"core contract missing {symbol}")

    require("AMPACITY_IZ_A" in fa08_text, "FA-08 is not bound to AMPACITY_IZ_A")
    require(
        "reserved for the shared ampacity contract" in fa08_text,
        "FA-08 must reject raw caller-supplied AMPACITY_IZ_A facts",
    )
    require(
        "Elv5AmpacityKernel" in fa08_text,
        "FA-08 must consume the shared ampacity kernel",
    )

    print("ELV5 ampacity contract: PASS")


if __name__ == "__main__":
    main()
