#!/usr/bin/env python3
"""Validate the frozen ELV5 discipline command registry and development-entry contract."""
import copy
import json
import re
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
EXPECTED_READINESS = {
    'reviewPass': 'EIGHTH_IMPLEMENTATION_READINESS',
    'high': 7,
    'medium': 3,
    'total': 10,
    'resolved': 10,
    'open': 0,
}


def load_registry():
    return json.loads((BASE / 'command-registry.json').read_text())


def validate(registry):
    assert registry['schema'] == 'electra.elv5-command-design-registry.v1'
    assert registry['status'] == 'DESIGN_FROZEN'
    assert registry['runtimeStatus'] == 'NOT_STARTED'
    assert registry['developmentReadiness'] == 'READY_FOR_DEVELOPMENT'
    assert re.fullmatch(r'[0-9a-f]{64}', registry['developmentReadinessRegistrySha256'])
    assert registry['wireSchema'] == 'electra.elv5-discipline-command.v1'
    assert registry['payloadSchemaVersion'] == 1
    assert registry['topLevelKeys'] == EXPECTED_TOP_LEVEL
    assert len(registry['topLevelKeys']) == len(set(registry['topLevelKeys'])) == 10
    assert registry['readinessClosure'] == EXPECTED_READINESS

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

    assert registry['nestedSchemaRegistryVersion'] == 'electra.elv5-command-nested-schema.v1'
    schemas = registry['nestedSchemas']
    assert isinstance(schemas, dict) and len(schemas) >= 30
    assert all(isinstance(name, str) and name.endswith('.v1') for name in schemas)
    for name, spec in schemas.items():
        assert set(spec) >= {'keys', 'types'}, ('nested schema shape', name)
        assert len(spec['keys']) == len(set(spec['keys'])), ('duplicate nested keys', name)
        assert set(spec['keys']) == set(spec['types']), ('nested key/type drift', name)

    bindings = registry['commandNestedBindings']
    assert set(bindings) == set(EXPECTED_PAYLOADS)
    for operation, operation_bindings in bindings.items():
        assert isinstance(operation_bindings, list), ('nested bindings must be list', operation)
        for binding in operation_bindings:
            assert set(binding) in ({'path', 'schema'}, {'path', 'schema', 'nullable'}), ('nested binding shape', operation)
            assert binding['schema'] in schemas, ('unknown nested schema', operation, binding['schema'])
            assert isinstance(binding['path'], str) and binding['path'], ('invalid nested path', operation)

    semantic = registry['semanticConstraints']
    for operation in ['REPLACE_CAMERA_STREAMS', 'REPLACE_RECORDING_ASSIGNMENTS', 'REPLACE_RECORDER_ASSIGNMENTS']:
        assert operation in semantic and semantic[operation], ('critical semantic constraints missing', operation)

    contract = (BASE / 'code-level-runtime-contract.md').read_text()
    amendments = (BASE / 'code-level-hardening-amendments.md').read_text()
    alignment = (BASE / 'project-alignment-hardening-v1.md').read_text()
    index = (ROOT / 'docs/product/elv5-authoritative-spec-index.md').read_text()
    assert registry['wireSchema'] in contract
    assert 'command-registry.json' in index
    assert 'development-readiness-registry.json' in index
    assert 'READY FOR DEVELOPMENT' in alignment
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
    except (AssertionError, KeyError):
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

    draft_regression = copy.deepcopy(registry)
    draft_regression['status'] = 'DESIGN_DRAFT'
    must_reject(draft_regression)

    no_nested = copy.deepcopy(registry)
    del no_nested['commandNestedBindings']['REPLACE_CAMERA_STREAMS']
    must_reject(no_nested)

    reopened = copy.deepcopy(registry)
    reopened['readinessClosure']['open'] = 1
    must_reject(reopened)

    print(
        'PASS: frozen ELV5 command schema, 16 operations, machine nested schemas, '
        '10/10 readiness closure and accepted ELV4 revision boundary'
    )


if __name__ == '__main__':
    main()
