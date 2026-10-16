#!/usr/bin/env python3
"""Validate ELV6 design-time wire examples and qualification manifest."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv6-implementation'
FORBIDDEN_PLACEMENT_WIRE_FIELDS = {'occupiedEnvelope', 'rackSpan', 'dinSpan', 'sourceProposalId'}


def load(name):
    return json.loads((BASE / name).read_text())


def validate_command_examples(registry, examples):
    assert examples['schema'] == 'electra.elv6-command-examples.v1'
    assert examples['status'] == 'DESIGN_DRAFT'
    assert examples['wireSchema'] == registry['wireSchema'] == 'electra.elv6-layout-command.v1'
    assert examples['payloadSchemaVersion'] == registry['payloadSchemaVersion'] == 1
    envelope = examples['envelopeTemplate']
    assert list(envelope) == registry['topLevelKeys']
    assert envelope['schema'] == registry['wireSchema']
    assert envelope['payloadSchemaVersion'] == 1
    fingerprint = envelope['reviewedImpactFingerprint']
    assert isinstance(fingerprint, str) and len(fingerprint) == 64 and set(fingerprint) <= set('0123456789abcdef')

    commands = {row['operation']: row for row in registry['commands']}
    rows = examples['examples']
    by_op = {row['operation']: row for row in rows}
    assert len(rows) == len(by_op) == len(commands) == 21
    assert set(by_op) == set(commands)
    for operation, command in commands.items():
        row = by_op[operation]
        assert set(row['validPayload']) == set(command['payloadKeys']), ('example payload drift', operation)
        rejection = row['rejection']
        assert rejection['mutation'] == 'REMOVE_FIELD'
        assert rejection['field'] in command['payloadKeys']
        assert rejection['expectedCode'] == 'ELV6_PAYLOAD_FIELDS_MISMATCH'

    for operation in ('PLACE_LAYOUT_SUBJECT', 'MOVE_LAYOUT_SUBJECT'):
        payload = by_op[operation]['validPayload']
        assert 'placementSpec' in payload
        assert not set(payload) & FORBIDDEN_PLACEMENT_WIRE_FIELDS
        spec = payload['placementSpec']
        assert spec['kind'] in {'FREE_3D', 'RACK_U', 'DIN', 'SURFACE_2D'}

    assert set(by_op['PLACE_LAYOUT_SUBJECT']['validPayload']['placementSpec']) == {
        'kind', 'mountingSurfaceId', 'position'
    }
    assert by_op['PLACE_LAYOUT_SUBJECT']['validPayload']['placementSpec']['kind'] == 'DIN'


def validate_qualification(process_registry, manifest):
    assert manifest['schema'] == 'electra.elv6-qualification-manifest.v1'
    assert manifest['status'] == 'DESIGN_DRAFT'
    assert manifest['runtimeStatus'] == 'NOT_STARTED'
    fixture_ids = {row['id'] for row in manifest['fixtureFamilies']}
    assert len(fixture_ids) == 4

    process_codes = {row['code'] for row in process_registry['processes']}
    rows = manifest['processOracles']
    by_code = {row['code']: row for row in rows}
    assert len(rows) == len(by_code) == 24
    assert set(by_code) == process_codes

    oracle_ids = []
    valid_completion = {'COMPLETE', 'PARTIAL', 'BLOCKED'}
    valid_assessment = {'PASS', 'FAIL', 'UNRESOLVED', 'NOT_ASSESSED'}
    for code, row in by_code.items():
        assert row['fixture'] in fixture_ids
        for kind in ['POS', 'NEG', 'BLOCKED']:
            oracle = row[kind]
            assert oracle['id'] == f'{code}-{kind}'
            assert oracle['completion'] in valid_completion
            assert oracle['assessment'] in valid_assessment
            oracle_ids.append(oracle['id'])
        assert row['POS']['completion'] == 'COMPLETE'
        assert row['POS']['assessment'] == 'PASS'
        assert row['BLOCKED']['assessment'] == 'UNRESOLVED'
    assert len(oracle_ids) == len(set(oracle_ids)) == 72

    cross = manifest['crossCuttingQualifications']
    assert len(cross) == len(set(cross)) >= 22
    for required in [
        'MODULE_PASS_PHYSICAL_WIDTH_FAIL',
        'RACK_U_PASS_RAIL_DEPTH_FAIL',
        'ELECTRICAL_BATTERY_PASS_PHYSICAL_FAIL',
        'BODY_PASS_SERVICE_FAIL',
        'LOAD_NOT_EQUAL_HEAT_LOSS',
        'NO_NORMATIVE_PASS_FROM_INTRINSIC_PASS',
        'SOLVER_BYTE_STABILITY',
        'FREEZE_VS_PUBLICATION_RACE',
        'CLIENT_DERIVED_PLACEMENT_GEOMETRY_REJECTED',
        'REFERENCED_MEMBER_REMOVAL_REJECTED',
    ]:
        assert required in cross


def main():
    command_registry = load('command-registry.json')
    process_registry = load('process-registry.json')
    examples = load('command-examples.json')
    qualification = load('qualification-manifest.json')
    validate_command_examples(command_registry, examples)
    validate_qualification(process_registry, qualification)
    print('PASS: 21 ELV6 canonical command examples, strict placement intent, 72 process oracles and mutation-safety qualifications')


if __name__ == '__main__':
    main()
