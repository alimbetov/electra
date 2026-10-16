#!/usr/bin/env python3
"""Validate ELV5 second-pass engineering/architecture design hardening.

This is a structural design guard. It deliberately does not claim Dart/Flutter/
Drift runtime implementation or engineering compliance.
"""
from collections import Counter
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv5-implementation'
AUDIT = ROOT / 'docs/audit/elv5-engineering-architecture-hardening-audit.json'


def load(path: Path):
    return json.loads(path.read_text())


def require_text(path: Path, tokens):
    text = path.read_text()
    for token in tokens:
        assert token in text, (path, token)
    return text


def main():
    required_files = [
        BASE / 'engineering-primitives-contract.md',
        BASE / 'typed-process-api.md',
        BASE / 'persistence-schema-contract.md',
        BASE / 'qualification-contract.md',
        BASE / 'code-level-hardening-amendments.md',
        ROOT / 'docs/audit/elv5-engineering-architecture-hardening-audit.md',
        AUDIT,
    ]
    for path in required_files:
        assert path.is_file(), path

    audit = load(AUDIT)
    assert audit['schema'] == 'electra.elv5-engineering-architecture-hardening-audit.v1'
    assert audit['runtimeStatus'] == 'NOT_STARTED'
    findings = audit['findings']
    assert len(findings) == len({f['id'] for f in findings}) == 14
    assert Counter(f['severity'] for f in findings) == {'HIGH': 10, 'MEDIUM': 4}
    assert all(f['specificationStatus'] == 'SPEC_RESOLVED' for f in findings)
    assert all(f['runtimeStatus'] == 'NOT_IMPLEMENTED' for f in findings)
    assert audit['findingSummary'] == {
        'HIGH': 10,
        'MEDIUM': 4,
        'total': 14,
        'specResolved': 14,
        'runtimeImplemented': 0,
    }
    for finding in findings:
        assert finding['resolutionRefs']
        for ref in finding['resolutionRefs']:
            assert (ROOT / ref).is_file(), (finding['id'], ref)

    primitives = require_text(
        BASE / 'engineering-primitives-contract.md',
        [
            'Elv5Quantity<D extends Elv5Dimension>',
            'AttenuationDbDim',
            'OpticalLevelDbmDim',
            'manufacturerGuaranteed',
            'manufacturerTypical',
            'Elv5TemporalPolicy',
            'tzdbVersion',
            'Elv5FrameRef',
            'electra.canonical-json.v1',
            'Request hash',
            'Input fingerprint',
            'Output hash',
            'Snapshot discipline hash',
        ],
    )
    assert 'evaluationId' in primitives and 'completedAtUtc' in primitives
    assert 'excludes `evaluationId`' in primitives

    typed = require_text(
        BASE / 'typed-process-api.md',
        [
            'Elv5TypedProcessDefinition<I, O>',
            'Elv5InputHeader',
            'AcsLockSafetyMode',
            'AcsReleaseTruthRow',
            'CctvTransportOverheadModel',
            'Elv5OpticalReachProfile',
        ],
    )
    expected_codes = {
        f'{prefix}-{i:02d}'
        for prefix, maximum in [('CCTV', 6), ('LAN', 7), ('ACS', 6), ('FA', 8)]
        for i in range(1, maximum + 1)
    }
    heading_codes = set(re.findall(r'^## \d+\. (CCTV-\d\d|LAN-\d\d|ACS-\d\d|FA-\d\d)\b', typed, re.M))
    assert heading_codes == expected_codes, (len(heading_codes), sorted(expected_codes - heading_codes))

    persistence = require_text(
        BASE / 'persistence-schema-contract.md',
        [
            'Required ELV5 additive target: **24**',
            'int get schemaVersion => 24;',
            'DisciplineEvaluationRecords',
            'DisciplineEvaluationPointers',
            'DisciplineDependencyIndex',
            'DesignRevisionDisciplineSnapshots',
            'Do not create `DisciplineCommandLedger`',
            'all-or-nothing',
        ],
    )
    for forbidden in [
        'DisciplineCables',
        'DisciplinePorts',
        'DisciplineComponents',
        'DisciplinePowerSources',
        'DisciplineBatteryBanks',
        'DisciplineProjectRevisions',
        'DisciplineCommandHistoryCursor',
    ]:
        assert forbidden in persistence  # documented explicitly as forbidden names

    qualification = require_text(
        BASE / 'qualification-contract.md',
        [
            'Exactly 54 primary process entries',
            'L0  primitive',
            'L6  concurrency',
            '1000 CCTV encoded streams',
            '10000 fire address claims',
            'No-false-PASS sentinels',
            'all 16 command codecs pass adversarial/replay tests',
        ],
    )
    assert qualification.count('### CCTV-') == 6
    assert qualification.count('### LAN-') == 7
    assert qualification.count('### ACS-') == 6
    assert qualification.count('### FA-') == 8

    amendments = require_text(
        BASE / 'code-level-hardening-amendments.md',
        [
            'REPLACE_CAMERA_STREAMS',
            'subscriptions',
            'transportOverheadModelRef',
            'REPLACE_RECORDING_ASSIGNMENTS',
            'temporalPolicy',
            'reserveMultiplier',
            'redundancyModel',
            'REPLACE_DOOR_ROLE_ASSIGNMENTS',
            'safetyMode',
            'releaseTruthTable',
            'Recorder capability ownership clarification',
            'all-or-nothing',
        ],
    )
    assert 'exactly 16 operations' in amendments

    registry = load(BASE / 'command-registry.json')
    examples = load(BASE / 'command-examples.json')
    commands = {row['operation']: row for row in registry['commands']}
    assert len(commands) == 16
    expected_hardened_keys = {
        'REPLACE_CAMERA_STREAMS': {
            'cameraId', 'streams', 'subscriptions', 'transportOverheadModelRef'
        },
        'REPLACE_RECORDING_ASSIGNMENTS': {
            'poolId', 'horizon', 'temporalPolicy', 'assignments',
            'scheduleSegments', 'sizingBasis', 'reserveMultiplier',
            'redundancyModel', 'policyRef'
        },
        'REPLACE_DOOR_ROLE_ASSIGNMENTS': {
            'doorAssemblyId', 'topologyProfileRef', 'safetyMode',
            'roleAssignments', 'releaseTruthTable'
        },
    }
    by_example = {row['operation']: row for row in examples['examples']}
    for operation, keys in expected_hardened_keys.items():
        assert set(commands[operation]['payloadKeys']) == keys
        assert set(by_example[operation]['validPayload']) == keys

    camera = by_example['REPLACE_CAMERA_STREAMS']['validPayload']
    assert len(camera['subscriptions']) >= 2
    assert camera['transportOverheadModelRef']['contentHash']

    recording = by_example['REPLACE_RECORDING_ASSIGNMENTS']['validPayload']
    assert recording['temporalPolicy']['timeZoneId'] == 'Asia/Almaty'
    assert recording['temporalPolicy']['tzdbVersion']
    assert recording['reserveMultiplier']
    assert recording['redundancyModel']['usableFraction']
    assert recording['policyRef']['contentHash']

    door = by_example['REPLACE_DOOR_ROLE_ASSIGNMENTS']['validPayload']
    causes = {row['causeCode'] for row in door['releaseTruthTable']}
    assert {
        'NORMAL_ACCESS', 'REQUEST_TO_EXIT', 'FIRE_RELEASE',
        'EMERGENCY_BREAK_GLASS', 'POWER_FAILURE'
    } <= causes
    assert door['safetyMode'] in {'FAIL_SAFE', 'FAIL_SECURE', 'PROJECT_DEFINED'}

    print(
        'PASS: ELV5 engineering hardening guard — '
        '14 findings SPEC_RESOLVED, 27 typed process APIs, schema 24, '
        '16 hardened command payloads and L0-L6 qualification contract; '
        'no runtime claim'
    )


if __name__ == '__main__':
    main()
