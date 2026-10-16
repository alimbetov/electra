#!/usr/bin/env python3
"""Validate ELV5 canonical design-time wire examples against command registry."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv5-implementation'


def load(name):
    return json.loads((BASE / name).read_text())


def validate_payload_fields(operation, payload, commands):
    """Design key-set probe only; not the nested production semantic codec."""
    if operation not in commands:
        raise ValueError('ELV5_UNSUPPORTED_OPERATION')
    if type(payload) is not dict or set(payload) != set(commands[operation]['payloadKeys']):
        raise ValueError('ELV5_PAYLOAD_FIELDS_MISMATCH')


def require_rejection(operation, payload, commands, expected_code):
    try:
        validate_payload_fields(operation, payload, commands)
    except ValueError as error:
        if str(error) != expected_code:
            raise AssertionError(('Wrong rejection code', operation, str(error))) from error
        return
    raise AssertionError(('Invalid payload accepted', operation))


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

    negative_probes = 0
    for operation, command in commands.items():
        row = by_operation[operation]
        payload = row['validPayload']
        validate_payload_fields(operation, payload, commands)
        rejection = row['rejection']
        assert rejection['mutation'] == 'REMOVE_FIELD'
        assert rejection['field'] in command['payloadKeys']
        assert rejection['expectedCode'] == 'ELV5_PAYLOAD_FIELDS_MISMATCH'
        # Execute the advertised mutation; reading its descriptor is not proof.
        invalid = copy.deepcopy(payload)
        del invalid[rejection['field']]
        require_rejection(operation, invalid, commands, rejection['expectedCode'])
        negative_probes += 1
        for field in command['payloadKeys']:
            invalid = copy.deepcopy(payload); del invalid[field]
            require_rejection(operation, invalid, commands, 'ELV5_PAYLOAD_FIELDS_MISMATCH')
            negative_probes += 1
        invalid = {**payload, 'clientComputedImpact': []}
        require_rejection(operation, invalid, commands, 'ELV5_PAYLOAD_FIELDS_MISMATCH')
        require_rejection(operation, list(payload), commands, 'ELV5_PAYLOAD_FIELDS_MISMATCH')
        negative_probes += 2
    require_rejection('UNKNOWN_OPERATION', {}, commands, 'ELV5_UNSUPPORTED_OPERATION')
    negative_probes += 1

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

    print(f'PASS: 16 ELV5 example payload key sets and {negative_probes} executed negative key-set probes; '
          'nested semantic codecs and runtime commands NOT EXECUTED')


if __name__ == '__main__':
    main()
