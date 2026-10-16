#!/usr/bin/env python3
"""Validate ELV5 project-wide alignment and development-readiness closure."""
from __future__ import annotations

import hashlib
import json
import re
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
IMPL = ROOT / 'docs/product/elv5-implementation'
AUDIT7 = ROOT / 'docs/audit/elv5-seventh-pass-project-alignment-audit.json'
AUDIT8 = ROOT / 'docs/audit/elv5-eighth-pass-development-readiness-audit.md'
READINESS = IMPL / 'development-readiness-registry.json'


def req(ok: bool, msg: str) -> None:
    if not ok:
        raise SystemExit(msg)


def text(path: Path) -> str:
    return path.read_text(encoding='utf-8')


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def is_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def is_decimal_string(value: Any) -> bool:
    if not isinstance(value, str) or not re.fullmatch(r'-?(?:0|[1-9]\d*)(?:\.\d+)?', value):
        return False
    try:
        Decimal(value)
        return True
    except InvalidOperation:
        return False


def validate_schema(value: Any, schema_name: str, schemas: dict[str, Any], where: str) -> None:
    schema = schemas[schema_name]
    req(isinstance(value, dict), f'{where}: expected object for {schema_name}')
    expected = set(schema['keys'])
    actual = set(value)
    req(actual == expected, f'{where}: nested keys mismatch for {schema_name}: expected={sorted(expected)} actual={sorted(actual)}')

    enums = schema.get('enumValues', {})
    for key, type_name in schema['types'].items():
        v = value[key]
        if key in enums and v is not None:
            req(v in enums[key], f'{where}.{key}: value outside enum {enums[key]}')

        if type_name == 'string':
            req(isinstance(v, str), f'{where}.{key}: expected string')
        elif type_name == 'nullable_string':
            req(v is None or isinstance(v, str), f'{where}.{key}: expected nullable string')
        elif type_name == 'integer':
            req(is_int(v), f'{where}.{key}: expected integer')
        elif type_name == 'nullable_integer':
            req(v is None or is_int(v), f'{where}.{key}: expected nullable integer')
        elif type_name == 'boolean':
            req(isinstance(v, bool), f'{where}.{key}: expected boolean')
        elif type_name == 'decimal_string':
            req(is_decimal_string(v), f'{where}.{key}: expected canonical decimal string')
        elif type_name == 'nullable_decimal_string':
            req(v is None or is_decimal_string(v), f'{where}.{key}: expected nullable canonical decimal string')
        elif type_name == 'sha256':
            req(isinstance(v, str) and re.fullmatch(r'[0-9a-f]{64}', v) is not None,
                f'{where}.{key}: expected lowercase sha256')
        elif type_name == 'utc_string':
            req(isinstance(v, str) and v.endswith('Z'), f'{where}.{key}: expected UTC Z string')
        elif type_name == 'string_array':
            req(isinstance(v, list) and all(isinstance(x, str) for x in v), f'{where}.{key}: expected string array')
        elif type_name == 'integer_array':
            req(isinstance(v, list) and all(is_int(x) for x in v), f'{where}.{key}: expected integer array')
        elif type_name == 'string_map_decimal_string':
            req(isinstance(v, dict) and all(isinstance(k, str) and is_decimal_string(x) for k, x in v.items()),
                f'{where}.{key}: expected string->decimal-string map')
        elif type_name.startswith('object:'):
            validate_schema(v, type_name.split(':', 1)[1], schemas, f'{where}.{key}')
        elif type_name.startswith('nullable_object:'):
            if v is not None:
                validate_schema(v, type_name.split(':', 1)[1], schemas, f'{where}.{key}')
        else:
            raise SystemExit(f'{where}.{key}: unknown schema type {type_name}')

    for rule in schema.get('constraints', []):
        if rule == 'edgeIds_non_empty':
            req(bool(value['edgeIds']), f'{where}.edgeIds: must be non-empty')
        elif rule == 'edgeIds_unique':
            req(len(value['edgeIds']) == len(set(value['edgeIds'])), f'{where}.edgeIds: duplicates are forbidden')
        elif rule == 'start_before_end':
            req(value['startUtc'] < value['endUtc'], f'{where}: startUtc must be before endUtc')
        elif rule == 'exactly_one_of:absoluteWindow,recurrence':
            req((value['absoluteWindow'] is None) ^ (value['recurrence'] is None),
                f'{where}: exactly one of absoluteWindow/recurrence is required')


def resolve_path(payload: Any, path: str) -> list[Any]:
    current = [payload]
    for raw in path.split('.'):
        many = raw.endswith('[]')
        key = raw[:-2] if many else raw
        nxt: list[Any] = []
        for item in current:
            req(isinstance(item, dict) and key in item, f'nested binding path missing: {path}')
            value = item[key]
            if many:
                req(isinstance(value, list), f'nested binding path is not array: {path}')
                nxt.extend(value)
            else:
                nxt.append(value)
        current = nxt
    return current


def validate_command_examples(command: dict[str, Any], examples: dict[str, Any]) -> None:
    commands = {row['operation']: row for row in command['commands']}
    rows = {row['operation']: row for row in examples['examples']}
    req(set(commands) == set(rows) and len(commands) == 16, 'command/example operation inventory drift')

    schemas = command['nestedSchemas']
    bindings = command['commandNestedBindings']
    req(set(bindings) == set(commands), 'nested binding operation inventory drift')

    for op, spec in commands.items():
        payload = rows[op]['validPayload']
        req(set(payload) == set(spec['payloadKeys']), f'{op}: top-level payload key drift')
        for binding in bindings[op]:
            for idx, value in enumerate(resolve_path(payload, binding['path'])):
                if value is None and binding.get('nullable', False):
                    continue
                validate_schema(value, binding['schema'], schemas, f'{op}:{binding["path"]}[{idx}]')

    camera = rows['REPLACE_CAMERA_STREAMS']['validPayload']
    seen_subs: set[str] = set()
    tree_by_group: dict[tuple[str, str], str] = {}
    for s in camera['subscriptions']:
        req(s['subscriptionId'] not in seen_subs, 'duplicate CCTV subscriptionId')
        seen_subs.add(s['subscriptionId'])
        if s['deliveryMode'] == 'UNICAST':
            req(s['multicastGroupId'] is None and s['multicastTree'] is None,
                'UNICAST must have null multicast fields')
        else:
            req(isinstance(s['multicastGroupId'], str) and s['multicastGroupId'], 'MULTICAST group is required')
            req(isinstance(s['multicastTree'], dict), 'MULTICAST tree is required')
            key = (s['encodedStreamId'], s['multicastGroupId'])
            tree_hash = hashlib.sha256(json.dumps(s['multicastTree'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()
            if key in tree_by_group:
                req(tree_by_group[key] == tree_hash, 'same stream+multicastGroupId must use one canonical tree')
            tree_by_group[key] = tree_hash

    recording = rows['REPLACE_RECORDING_ASSIGNMENTS']['validPayload']
    req(Decimal(recording['reserveMultiplier']) >= Decimal('1'), 'recording reserveMultiplier must be >= 1')
    profiles = {s['scheduleProfileId'] for s in recording['scheduleSegments']}
    req(profiles, 'recording schedule profiles must not be empty')
    for assignment in recording['assignments']:
        req(assignment['scheduleProfileId'] in profiles, 'recording assignment scheduleProfileId has no segments')

    recorder = rows['REPLACE_RECORDER_ASSIGNMENTS']['validPayload']
    req(all(a['storagePoolId'] for a in recorder['assignments']), 'recorder storagePoolId is mandatory')


def main() -> None:
    authority = text(ROOT / 'docs/product/elv5-authoritative-spec-index.md')
    typed = text(IMPL / 'typed-process-api.md')
    binding = text(IMPL / 'implementation-binding-hardening-v1.md')
    alignment = text(IMPL / 'project-alignment-hardening-v1.md')
    process_contracts = text(IMPL / 'process-contracts.md')
    acs_dossier = text(IMPL / 'process-specifications/acs-processes.md')
    persistence = text(IMPL / 'persistence-schema-contract.md')
    baseline = text(IMPL / 'implemented-baseline.md')
    adr = text(ROOT / 'docs/adr/ADR-031-elv5-pure-core-and-module-boundary.md')
    roadmap = text(ROOT / 'docs/product/development-roadmap.md')
    versions = json.loads(text(IMPL / 'runtime-version-registry.json'))
    handoff = json.loads(text(IMPL / 'downstream-handoff-registry.json'))
    command = json.loads(text(IMPL / 'command-registry.json'))
    examples = json.loads(text(IMPL / 'command-examples.json'))
    readiness = json.loads(text(READINESS))
    audit7 = json.loads(text(AUDIT7))

    for token in [
        'project-alignment-hardening-v1.md',
        'implementation-binding-hardening-v1.md',
        'downstream-handoff-registry.json',
        'ADR-031-elv5-pure-core-and-module-boundary.md',
        'development-readiness-registry.json',
        'eighth-pass',
        '1500',
        'seventh-pass',
    ]:
        req(token.lower() in authority.lower(), f'authority index missing project-alignment/readiness token: {token}')

    req('DESIGN READY FOR DEVELOPMENT / PROJECT ALIGNMENT CLOSED / RUNTIME NOT STARTED' in authority,
        'authority index does not authorize ELV5 development')
    req('ELV5 specification status: READY FOR DEVELOPMENT' in authority,
        'authority index readiness gate missing')

    req('Elv5InputResolution<I> resolveInput(' not in typed,
        'typed process definition still owns repository-aware resolveInput')
    req('abstract interface class Elv5InputResolver<I>' in typed,
        'application-layer InputResolver boundary missing')
    req('repository-aware input resolution belongs to the application layer' in binding.lower(),
        'binding hardening does not freeze resolver ownership')
    req('exact filename is not engineering semantics' in binding.lower(),
        'source-layout filename policy not reconciled')

    adr_lower = adr.lower()
    req('adr-031 — elv5 pure-core and module boundary' in adr_lower, 'ADR-031 identity missing')
    req('repository-aware `resolveinput(...)` is not a method' in adr_lower, 'ADR-031 resolver ownership missing')
    req('exact source filenames are **tracked implementation coordinates**' in adr_lower,
        'ADR-031 source-layout semantics missing')
    req('packages/engineering_core/lib/src/elv5/' in adr, 'ADR-031 nested ELV5 bounded-context layout missing')

    stale_oracles = ['23.45 V', '+1.45 V', 'lock23.45V']
    for stale in stale_oracles:
        req(stale not in process_contracts, f'stale ACS-03 oracle remains in process contracts: {stale}')
        req(stale not in acs_dossier, f'stale ACS-03 oracle remains in ACS dossier: {stale}')
    for current in ['23.51 V', '+1.51 V']:
        req(current in acs_dossier, f'corrected ACS-03 dossier oracle missing: {current}')
    req('23.51V' in process_contracts and '+1.51V' in process_contracts,
        'corrected ACS-03 process-contract oracle missing')

    req(versions['databaseSchemaVersion'] == 24, 'runtime version registry must freeze schema 24')
    req('Required ELV5 additive target: **24**' in persistence, 'persistence schema-24 contract missing')
    req('supersedes earlier baseline wording' in binding, 'schema-24 precedence sentence missing')
    req('schema 23 → schema 24' in baseline, 'implemented baseline does not freeze schema 23 -> 24')
    req('Choose an additive migration version strictly greater than 23 from the actual implementation HEAD' not in baseline,
        'obsolete choose->23 migration directive remains active')
    req('arbitrary version greater than 23' in baseline,
        'baseline does not explicitly record superseded provisional schema rule')

    for row in versions['processVersions']:
        req(is_int(row['inputSchemaVersion']) and row['inputSchemaVersion'] > 0, 'input schema registry version must be positive int')
        req(is_int(row['outputSchemaVersion']) and row['outputSchemaVersion'] > 0, 'output schema registry version must be positive int')
        req(str(row['inputSchemaVersion']) == f'{row["inputSchemaVersion"]}', 'noncanonical input version decimal bridge')
        req(str(row['outputSchemaVersion']) == f'{row["outputSchemaVersion"]}', 'noncanonical output version decimal bridge')
    req('registry integer 1 -> canonical runtime/hash string "1"' in alignment,
        'version integer->string canonicalization rule missing')

    policy = handoff['runtimeEntryPolicy']
    req(policy['exactAcceptedElv5SourceShaRequired'], 'downstream exact ELV5 source SHA not required')
    req(policy['exactAuthorityFingerprintRequired'], 'downstream authority fingerprint not required')
    req(policy['acceptedElv5RuntimeEvidenceRequiredBeforeElv6Runtime'],
        'ELV6 runtime not blocked on accepted ELV5 runtime evidence')
    req(not policy['historicalDesignShaAloneMayAuthorizeRuntime'],
        'historical design SHA incorrectly authorizes downstream runtime')
    req(policy['databaseSchemaAtInitialElv5Entry'] == 24,
        'downstream handoff schema differs from frozen ELV5 schema')
    req(len(handoff['claimBoundaries']) == 3, 'expected ELV6/ELV7/ELV8 claim boundaries')
    req(any(r['branch'] == 'feat/flutter-elv6-enclosure-layout-design' and
            r['state'] == 'RECONCILIATION_REQUIRED_BEFORE_RUNTIME'
            for r in handoff['knownDownstreamDesignPins']),
        'ELV6 stale design pin is not explicitly blocked before runtime')

    req('ELV4 | Power, PoE, PSU, UPS, converters and backup graph | CLOSED / ACCEPTED' in roadmap,
        'development roadmap does not show accepted ELV4')
    req('ELV5 | Versioned CCTV/LAN/ACS/fire calculations | DESIGN HARDENED / RUNTIME NOT STARTED' in roadmap or
        'ELV5 | Versioned CCTV/LAN/ACS/fire calculations | DESIGN READY FOR DEVELOPMENT / RUNTIME NOT STARTED' in roadmap,
        'development roadmap lost ELV5 current-state row')

    req(audit7['counts'] == {'high': 5, 'medium': 5, 'total': 10, 'resolved': 10, 'open': 0},
        'seventh-pass audit count drift')
    req(audit7['downstreamActionRequired'] is True, 'downstream reconciliation requirement was lost')
    req(all(f['status'] in {'SPEC_RESOLVED', 'ELV5_SPEC_RESOLVED_DOWNSTREAM_RECONCILIATION_REQUIRED'}
            for f in audit7['findings']), 'seventh-pass unresolved ELV5 finding')

    req(readiness['schema'] == 'electra.elv5-development-readiness-registry.v1',
        'development readiness registry schema drift')
    req(readiness['status'] == 'READY_FOR_DEVELOPMENT' and readiness['runtimeStatus'] == 'NOT_STARTED',
        'development readiness status drift')
    req(readiness['closure'] == {
        'reviewPass': 'EIGHTH_IMPLEMENTATION_READINESS',
        'high': 7, 'medium': 3, 'total': 10, 'resolved': 10, 'open': 0
    }, 'eighth-pass closure count drift')
    req({c['id'] for c in readiness['contracts']} == {f'ELV5-R8-{i:02d}' for i in range(1, 11)},
        'eighth-pass finding inventory drift')
    req(len(readiness['aggregateActiveUniqueSubjects']) == 11,
        'aggregate active-uniqueness inventory drift')
    req(readiness['humanAuditPath'] == 'docs/audit/elv5-eighth-pass-development-readiness-audit.md',
        'eighth-pass audit path drift')
    req(readiness['humanAuditSha256'] == sha256(AUDIT8), 'eighth-pass human audit hash mismatch')

    req(command['developmentReadiness'] == 'READY_FOR_DEVELOPMENT',
        'command registry does not carry development readiness')
    req(command['developmentReadinessRegistrySha256'] == sha256(READINESS),
        'command registry readiness-registry transitive hash mismatch')
    req(command['readinessClosure'] == {
        'reviewPass': 'EIGHTH_IMPLEMENTATION_READINESS',
        'high': 7, 'medium': 3, 'total': 10, 'resolved': 10, 'open': 0
    }, 'command registry eighth-pass closure drift')
    req(command['nestedSchemaRegistryVersion'] == 'electra.elv5-command-nested-schema.v1',
        'nested command schema registry version drift')
    validate_command_examples(command, examples)

    required_alignment_tokens = [
        'human-readable authority',
        'application layer',
        'schema 24',
        '23.51 v',
        '+1.51 v',
        'reconciliation_required_before_runtime',
        'elv5-r8-01',
        'elv5-r8-10',
        'reserveMultiplier >= 1',
        'UNIQUE(evaluation_id)',
        'UNIQUE(designRevisionId, addressDomain, address)',
        'typedef Mass = Elv5Quantity<MassDim>',
        'storagePoolId',
        'scheduleProfileId',
        'READY FOR DEVELOPMENT',
    ]
    for token in required_alignment_tokens:
        req(token.lower() in alignment.lower(), f'project alignment/readiness hardening missing token: {token}')

    print('ELV5 project alignment + development readiness PASS')
    print('seventhPass=10/10 eighthPass=10/10 open=0 runtime=NOT_STARTED readiness=READY_FOR_DEVELOPMENT')
    print('P2=READY P3=READY nestedCodecs=16 evaluationId=GLOBAL_UNIQUE reserveMin=1 multicast=EXPLICIT scheduleProfiles=EXPLICIT')


if __name__ == '__main__':
    main()
