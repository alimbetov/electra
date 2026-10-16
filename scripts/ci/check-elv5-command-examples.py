#!/usr/bin/env python3
"""Validate ELV5 canonical design-time wire examples against command registry."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv5-implementation'


def load(name):
    return json.loads((BASE / name).read_text())


def main():
    registry = load('command-registry.json')
    examples = load('command-examples.json')

    assert examples['schema'] == 'electra.elv5-command-examples.v1'
    assert examples['status'] == 'DESIGN_DRAFT'
    assert examples['wireSchema'] == registry['wireSchema'] == 'electra.elv5-discipline-command.v1'
    assert examples['payloadSchemaVersion'] == registry['payloadSchemaVersion'] == 1

    envelope = examples['envelopeTemplate']
    assert list(envelope) == registry['topLevelKeys']
    assert envelope['schema'] == registry['wireSchema']
    assert envelope['payloadSchemaVersion'] == registry['payloadSchemaVersion']
    fingerprint = envelope['reviewedImpactFingerprint']
    assert isinstance(fingerprint, str) and len(fingerprint) == 64
    assert set(fingerprint) <= set('0123456789abcdef')

    commands = {row['operation']: row for row in registry['commands']}
    rows = examples['examples']
    by_operation = {row['operation']: row for row in rows}
    assert len(rows) == len(by_operation) == len(commands) == 16
    assert set(by_operation) == set(commands)

    for operation, command in commands.items():
        row = by_operation[operation]
        payload = row['validPayload']
        assert set(payload) == set(command['payloadKeys']), ('Example payload mismatch', operation)
        rejection = row['rejection']
        assert rejection['mutation'] == 'REMOVE_FIELD'
        assert rejection['field'] in command['payloadKeys']
        assert rejection['expectedCode'] == 'ELV5_PAYLOAD_FIELDS_MISMATCH'

    critical = {
        'REPLACE_CAMERA_STREAMS': 'streams',
        'REPLACE_RECORDING_ASSIGNMENTS': 'assignments',
        'REPLACE_OPTICAL_LINK_ASSIGNMENTS': 'forwardOptics',
        'REPLACE_DOOR_ROLE_ASSIGNMENTS': 'roleAssignments',
        'REPLACE_FIRE_LOOP_ASSIGNMENTS': 'deviceAssignments',
        'CALCULATE_DISCIPLINE_PROCESS': 'expectedPointerGenerations',
    }
    for operation, key in critical.items():
        assert key in by_operation[operation]['validPayload']

    print('PASS: 16 canonical ELV5 command examples match exact registry payload keys and rejection cases')


if __name__ == '__main__':
    main()
