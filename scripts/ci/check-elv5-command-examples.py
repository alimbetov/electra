#!/usr/bin/env python3
"""Validate ELV5 canonical frozen wire examples against command registry."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv5-implementation'


def load(name):
    return json.loads((BASE / name).read_text())


def validate_payload_fields(operation, payload, commands):
    """Top-level exact-key probe; nested schemas are enforced by the project-alignment guard."""
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

    assert registry['status'] == 'DESIGN_FROZEN'
    assert registry['developmentReadiness'] == 'READY_FOR_DEVELOPMENT'
    assert registry['nestedSchemaRegistryVersion'] == 'electra.elv5-command-nested-schema.v1'
    assert examples['schema'] == 'electra.elv5-command-examples.v1'
    assert examples['status'] == 'DESIGN_FROZEN'
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
    assert set(registry['commandNestedBindings']) == set(commands)

    negative_probes = 0
    for operation, command in commands.items():
        row = by_operation[operation]
        payload = row['validPayload']
        validate_payload_fields(operation, payload, commands)
        rejection = row['rejection']
        assert rejection['mutation'] == 'REMOVE_FIELD'
        assert rejection['field'] in command['payloadKeys']
        assert rejection['expectedCode'] == 'ELV5_PAYLOAD_FIELDS_MISMATCH'
        invalid = copy.deepcopy(payload)
        del invalid[rejection['field']]
        require_rejection(operation, invalid, commands, rejection['expectedCode'])
        negative_probes += 1
        for field in command['payloadKeys']:
            invalid = copy.deepcopy(payload)
            del invalid[field]
            require_rejection(operation, invalid, commands, 'ELV5_PAYLOAD_FIELDS_MISMATCH')
            negative_probes += 1
        invalid = {**payload, 'clientComputedImpact': []}
        require_rejection(operation, invalid, commands, 'ELV5_PAYLOAD_FIELDS_MISMATCH')
        require_rejection(operation, list(payload), commands, 'ELV5_PAYLOAD_FIELDS_MISMATCH')
        negative_probes += 2
    require_rejection('UNKNOWN_OPERATION', {}, commands, 'ELV5_UNSUPPORTED_OPERATION')
    negative_probes += 1

    critical = {
        'REPLACE_CAMERA_STREAMS': ['streams', 'subscriptions', 'transportOverheadModelRef'],
        'REPLACE_RECORDING_ASSIGNMENTS': ['assignments', 'scheduleSegments', 'reserveMultiplier'],
        'REPLACE_RECORDER_ASSIGNMENTS': ['assignments'],
        'REPLACE_OPTICAL_LINK_ASSIGNMENTS': ['forwardOptics'],
        'REPLACE_DOOR_ROLE_ASSIGNMENTS': ['roleAssignments'],
        'REPLACE_FIRE_LOOP_ASSIGNMENTS': ['deviceAssignments'],
        'CALCULATE_DISCIPLINE_PROCESS': ['expectedPointerGenerations'],
    }
    for operation, keys in critical.items():
        for key in keys:
            assert key in by_operation[operation]['validPayload']

    camera = by_operation['REPLACE_CAMERA_STREAMS']['validPayload']
    assert all('subscriptionId' in row and 'multicastGroupId' in row and 'multicastTree' in row
               for row in camera['subscriptions'])
    assert any(row['deliveryMode'] == 'MULTICAST' and row['multicastGroupId'] and row['multicastTree']
               for row in camera['subscriptions'])

    recording = by_operation['REPLACE_RECORDING_ASSIGNMENTS']['validPayload']
    assert all(row.get('scheduleProfileId') for row in recording['assignments'])
    assert all(row.get('scheduleProfileId') for row in recording['scheduleSegments'])

    recorder = by_operation['REPLACE_RECORDER_ASSIGNMENTS']['validPayload']
    assert all(row.get('storagePoolId') for row in recorder['assignments'])

    print(
        f'PASS: 16 frozen ELV5 example payload key sets and {negative_probes} executed negative key-set probes; '
        'critical multicast/schedule/storage identities present; nested exact schemas enforced by alignment guard'
    )


if __name__ == '__main__':
    main()
