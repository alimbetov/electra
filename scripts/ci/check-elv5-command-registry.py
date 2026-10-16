#!/usr/bin/env python3
"""Validate the closed ELV5 discipline command registry design contract."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv5-implementation'
EXPECTED_TOP_LEVEL = [
    'schema', 'operation', 'payloadSchemaVersion', 'projectId',
    'designRevisionId', 'commandId', 'expectedDesignRowRevision',
    'expectedRows', 'reviewedImpactFingerprint', 'payload',
]
EXPECTED_PAYLOADS = {
    'BIND_DISCIPLINE_POLICY': {'bindingId', 'subject', 'processCodes', 'definitionRef', 'applicability'},
    'ADOPT_DISCIPLINE_POLICY': {'bindingId', 'newDefinitionRef', 'applicability'},
    'RELEASE_DISCIPLINE_POLICY': {'bindingId', 'releasePolicy'},
    'REPLACE_CAMERA_STREAMS': {
        'cameraId', 'streams', 'subscriptions', 'transportOverheadModelRef'
    },
    'REPLACE_RECORDING_ASSIGNMENTS': {
        'poolId', 'horizon', 'temporalPolicy', 'assignments',
        'scheduleSegments', 'sizingBasis', 'reserveMultiplier',
        'redundancyModel', 'policyRef'
    },
    'REPLACE_RECORDER_ASSIGNMENTS': {'recorderId', 'accountingBasis', 'assignments'},
    'REPLACE_LINK_COMPOSITION': {'linkId', 'orderedSections', 'policyBindingId'},
    'REPLACE_PORT_CAPACITY_ASSIGNMENTS': {'switchId', 'assignments', 'sparePolicyRef'},
    'REPLACE_OPTICAL_LINK_ASSIGNMENTS': {'linkId', 'forwardOptics', 'reverseOptics', 'connectorEvents', 'spliceEvents'},
    'REPLACE_RACK_CAPACITY_BASIS': {'rackId', 'capacityBasis', 'equipmentIds', 'excludedCapacity', 'policyRef'},
    'REPLACE_PATCH_PANEL_ASSIGNMENTS': {'panelId', 'assignments', 'sparePolicyRef'},
    'REPLACE_DOOR_ROLE_ASSIGNMENTS': {
        'doorAssemblyId', 'topologyProfileRef', 'safetyMode',
        'roleAssignments', 'releaseTruthTable'
    },
    'REPLACE_CONTROLLER_RESOURCE_ASSIGNMENTS': {'controllerId', 'resourceAssignments', 'reservePolicyRef'},
    'REPLACE_FIRE_LOOP_ASSIGNMENTS': {'loopId', 'deviceAssignments', 'addressDomain', 'topologyProfileRef'},
    'REPLACE_NOTIFICATION_CIRCUIT_ASSIGNMENTS': {'circuitId', 'deviceAssignments', 'outputRef', 'policyRef'},
    'CALCULATE_DISCIPLINE_PROCESS': {'scope', 'processCodes', 'subjects', 'expectedPointerGenerations'},
}


def load_registry():
    return json.loads((BASE / 'command-registry.json').read_text())


def validate(registry):
    assert registry['schema'] == 'electra.elv5-command-design-registry.v1'
    assert registry['status'] == 'DESIGN_DRAFT'
    assert registry['runtimeStatus'] == 'NOT_STARTED'
    assert registry['wireSchema'] == 'electra.elv5-discipline-command.v1'
    assert registry['payloadSchemaVersion'] == 1
    assert registry['topLevelKeys'] == EXPECTED_TOP_LEVEL
    assert len(registry['topLevelKeys']) == len(set(registry['topLevelKeys'])) == 10

    revision = registry['externalRevisionBoundary']
    assert revision['schema'] == 'electra.elv4-revision-command.v2'
    assert revision['operations'] == ['FREEZE_DESIGN_REVISION', 'CREATE_NEXT_WORKING_DESIGN_REVISION']

    rows = registry['commands']
    by_operation = {row['operation']: row for row in rows}
    assert len(rows) == len(by_operation) == 16
    assert set(by_operation) == set(EXPECTED_PAYLOADS)
    for operation, expected in EXPECTED_PAYLOADS.items():
        row = by_operation[operation]
        assert row['owner'] == 'ELV5'
        assert row['mutationKind'] in {'POLICY_BINDING', 'ASSIGNMENT_REPLACEMENT', 'EVALUATION_PUBLICATION'}
        assert len(row['payloadKeys']) == len(set(row['payloadKeys']))
        assert set(row['payloadKeys']) == expected, ('payload key mismatch', operation)

    contract = (BASE / 'code-level-runtime-contract.md').read_text()
    amendments = (BASE / 'code-level-hardening-amendments.md').read_text()
    index = (ROOT / 'docs/product/elv5-authoritative-spec-index.md').read_text()
    assert registry['wireSchema'] in contract
    assert 'command-registry.json' in index
    for operation in EXPECTED_PAYLOADS:
        assert operation in contract, ('command absent from base runtime contract', operation)
    for operation in [
        'REPLACE_CAMERA_STREAMS',
        'REPLACE_RECORDING_ASSIGNMENTS',
        'REPLACE_DOOR_ROLE_ASSIGNMENTS',
    ]:
        assert operation in amendments, ('hardened operation absent from amendment', operation)
        for key in EXPECTED_PAYLOADS[operation]:
            assert key in amendments, ('hardened key absent from amendment', operation, key)

    elv4_dispatcher = (
        ROOT / 'apps/mobile/lib/application/elv4_wire_command_dispatcher.dart'
    ).read_text()
    assert revision['schema'] in elv4_dispatcher, 'ELV4 revision schema drifted from accepted runtime'
    for operation in revision['operations']:
        assert operation in elv4_dispatcher, ('ELV4 revision operation drifted', operation)


def must_reject(registry):
    try:
        validate(registry)
    except AssertionError:
        return
    raise AssertionError('Invalid ELV5 command registry accepted')


def main():
    registry = load_registry()
    validate(registry)

    missing = copy.deepcopy(registry)
    missing['commands'].pop()
    must_reject(missing)

    extra_key = copy.deepcopy(registry)
    extra_key['commands'][0]['payloadKeys'].append('clientComputedImpact')
    must_reject(extra_key)

    wrong_schema = copy.deepcopy(registry)
    wrong_schema['wireSchema'] = 'electra.elv5-discipline-command.v2'
    must_reject(wrong_schema)

    duplicate = copy.deepcopy(registry)
    duplicate['commands'].append(copy.deepcopy(duplicate['commands'][0]))
    must_reject(duplicate)

    print(
        'PASS: exact ELV5 command schema, 16 operations, hardened payload keys '
        'and implemented ELV4 revision boundary'
    )


if __name__ == '__main__':
    main()
