#!/usr/bin/env python3
"""Validate closed ELV6 layout command registry. Design-only guard."""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv6-implementation'
EXPECTED_TOP_LEVEL = [
    'schema', 'operation', 'payloadSchemaVersion', 'projectId',
    'designRevisionId', 'commandId', 'expectedDesignRowRevision',
    'expectedRows', 'reviewedImpactFingerprint', 'payload',
]
EXPECTED = {
    'CREATE_RACK_ENCLOSURE': {'rackId', 'logicalId', 'kind', 'geometry', 'rackProfileRef', 'locationRef', 'technicalDefinitionRef'},
    'UPDATE_RACK_ENCLOSURE': {'rackId', 'kind', 'geometry', 'rackProfileRef', 'locationRef', 'technicalDefinitionRef'},
    'ARCHIVE_RACK_ENCLOSURE': {'rackId', 'archiveReason'},
    'REPLACE_PANEL_LAYOUT_ROOT': {'panelId', 'panelLogicalId', 'panelType', 'enclosureGeometry', 'mountingSections', 'sourceSemanticFingerprint'},
    'REPLACE_MOUNTING_SURFACES': {'hostRef', 'surfaces'},
    'REPLACE_LAYOUT_ZONES': {'hostRef', 'zones'},
    'REPLACE_CABLE_ENTRIES': {'hostRef', 'entries'},
    'PLACE_LAYOUT_SUBJECT': {'placementId', 'logicalId', 'hostRef', 'subjectRef', 'installationRole', 'mountingSurfaceId', 'pose', 'occupiedEnvelope', 'rackSpan', 'dinSpan', 'sourceProposalId'},
    'MOVE_LAYOUT_SUBJECT': {'placementId', 'hostRef', 'mountingSurfaceId', 'pose', 'occupiedEnvelope', 'rackSpan', 'dinSpan', 'sourceProposalId'},
    'REMOVE_LAYOUT_SUBJECT': {'placementId', 'hostRef', 'removalReason'},
    'LOCK_LAYOUT_PLACEMENT': {'placementId', 'hostRef', 'lockReason'},
    'UNLOCK_LAYOUT_PLACEMENT': {'placementId', 'hostRef', 'unlockReason'},
    'ASSIGN_CABLE_ENTRY': {'assignmentId', 'hostRef', 'entryId', 'cableEndRef', 'approachDirection', 'terminationTargetRef'},
    'RELEASE_CABLE_ENTRY': {'assignmentId', 'hostRef', 'releaseReason'},
    'REPLACE_PHYSICAL_BONDING_ASSIGNMENTS': {'hostRef', 'bondPoints', 'bondLinks'},
    'GENERATE_LAYOUT_PROPOSAL': {'proposalId', 'hostRef', 'subjectRefs', 'solverProfileRef', 'expectedPointerGenerations'},
    'ACCEPT_LAYOUT_PROPOSAL': {'proposalId', 'hostRef', 'expectedProposalHash', 'expectedOwnerRevisions', 'expectedPointerGenerations'},
    'REJECT_LAYOUT_PROPOSAL': {'proposalId', 'hostRef', 'rejectionReason'},
    'CALCULATE_LAYOUT_PROCESS': {'hostRef', 'processCodes', 'subjects', 'expectedPointerGenerations'},
    'REPLACE_LAYOUT_TECHNICAL_PROFILE': {'bindingId', 'hostRef', 'profileRole', 'definitionRef', 'applicability'},
    'RELEASE_LAYOUT_TECHNICAL_PROFILE': {'bindingId', 'hostRef', 'releasePolicy'},
}


def validate(registry):
    assert registry['schema'] == 'electra.elv6-command-design-registry.v1'
    assert registry['status'] == 'DESIGN_DRAFT'
    assert registry['runtimeStatus'] == 'NOT_STARTED'
    assert registry['wireSchema'] == 'electra.elv6-layout-command.v1'
    assert registry['payloadSchemaVersion'] == 1
    assert registry['topLevelKeys'] == EXPECTED_TOP_LEVEL
    assert len(registry['topLevelKeys']) == len(set(registry['topLevelKeys'])) == 10

    rows = registry['commands']
    by_op = {row['operation']: row for row in rows}
    assert len(rows) == len(by_op) == 21
    assert set(by_op) == set(EXPECTED)
    for operation, expected_keys in EXPECTED.items():
        row = by_op[operation]
        assert row['mutationKind']
        assert row['ownerTarget']
        assert len(row['payloadKeys']) == len(set(row['payloadKeys']))
        assert set(row['payloadKeys']) == expected_keys, ('payload key mismatch', operation)

    revision = registry['externalRevisionBoundary']
    assert revision['schema'] == 'electra.elv4-revision-command.v2'
    assert revision['operations'] == ['FREEZE_DESIGN_REVISION', 'CREATE_NEXT_WORKING_DESIGN_REVISION']
    dispatcher = (ROOT / 'apps/mobile/lib/application/elv4_wire_command_dispatcher.dart').read_text()
    assert revision['schema'] in dispatcher
    for operation in revision['operations']:
        assert operation in dispatcher, ('revision boundary drift', operation)

    contract = (BASE / 'code-level-runtime-contract.md').read_text()
    assert registry['wireSchema'] in contract
    for operation in EXPECTED:
        assert operation in contract, ('command absent from code contract', operation)

    panel = by_op['REPLACE_PANEL_LAYOUT_ROOT']
    assert panel['ownerTarget'] == 'PANEL_ASSEMBLY'
    assert by_op['ACCEPT_LAYOUT_PROPOSAL']['ownerTarget'] == 'MULTI_OWNER_LAYOUT_UOW'


def must_reject(registry):
    try:
        validate(registry)
    except AssertionError:
        return
    raise AssertionError('Invalid ELV6 command registry accepted')


def main():
    registry = json.loads((BASE / 'command-registry.json').read_text())
    validate(registry)

    missing = copy.deepcopy(registry)
    missing['commands'].pop()
    must_reject(missing)

    duplicate = copy.deepcopy(registry)
    duplicate['commands'].append(copy.deepcopy(duplicate['commands'][0]))
    must_reject(duplicate)

    client_impact = copy.deepcopy(registry)
    client_impact['commands'][7]['payloadKeys'].append('dependencyClosure')
    must_reject(client_impact)

    wrong_version = copy.deepcopy(registry)
    wrong_version['payloadSchemaVersion'] = 2
    must_reject(wrong_version)

    print('PASS: ELV6 exact wire schema, 21 commands, payload keys and ELV4 revision boundary')


if __name__ == '__main__':
    main()
