#!/usr/bin/env python3
"""Check replicated ELV6-8 design contracts; never emit runtime acceptance."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / 'docs/product/elv-integration'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def read_json(path):
    return json.loads(path.read_text())


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unique(values, label):
    require(len(values) == len(set(values)), f'Duplicate {label}')


def check_sources():
    source = read_json(BASE / 'source-systems-registry.json')
    plan = read_json(BASE / 'source-qualification-plan.json')
    readiness = read_json(BASE / 'design-readiness.json')
    require(source['schema'] == 'electra.elv-source-systems-contract.v1' and
            source['status'] == 'CONTRACT_DEFINED' and source['runtimeReady'] is False and
            source['qualifiedElectricalProducer'] is False and source['productionVerifiedSourcePacks'] == 0,
            'Source design cannot grant producer/authority qualification')
    require(source['newLayProcessesAdded'] == source['newNormativeFamiliesAdded'] == 0,
            'Source integration must not hide a new execution family')
    expected = {
        'SOURCE_CONFIGURATION': 'electra.electrical-source-configuration.v1',
        'SOURCE_STUDY': 'electra.electrical-source-study.v1',
        'TRANSFER_SEQUENCE': 'electra.electrical-transfer-sequence.v1',
        'ENERGY_BALANCE': 'electra.electrical-energy-balance.v1',
    }
    projections = source['projections']
    unique([p['id'] for p in projections], 'electrical source projection IDs')
    require({p['id']: p['schema'] for p in projections} == expected, 'Four source contracts required')
    for projection in projections:
        require(projection['logicalProducer'] == 'CANONICAL_ELECTRICAL_OWNER' and
                projection['producerBindingStatus'] == 'BLOCKED_UPSTREAM' and
                projection['qualified'] is False, 'Unqualified source owner cannot become implemented')
        require({'projectId', 'designRevisionId', 'scenarioIds', 'topologyHash', 'configurationHash',
                 'consumedRefs', 'generationTokens', 'coverage', 'missingFacts', 'payloadHash'} <=
                set(projection['requiredEnvelopeFields']), 'Source capture/context incomplete')
        require(projection['requiredPayloadFields'] and all(projection['requiredPayloadFields'].values()),
                'Source payload must have typed fields')
    expected_modes = {
        'GRID_NORMAL', 'GRID_LOSS', 'GENERATOR_START', 'GENERATOR_SUPPLY', 'GENERATOR_FAILURE',
        'RETRANSFER_TO_GRID', 'UPS_INVERTER', 'UPS_BYPASS', 'PV_GRID_CONNECTED', 'PV_UNAVAILABLE',
        'INTENTIONAL_ISLAND', 'STORAGE_CHARGE', 'STORAGE_DISCHARGE', 'STORAGE_DEPLETED',
        'MAINTENANCE_ISOLATION', 'TRANSFER_CONTROL_FAILURE',
    }
    unique([m['id'] for m in source['modes']], 'source mode classes')
    require({m['id'] for m in source['modes']} == expected_modes, 'Required source mode inventory drift')
    for mode in source['modes']:
        require(mode['applicability'] == 'DERIVED_FROM_TOPOLOGY_AND_DECLARED_PURPOSE' and
                mode['missingRequiredMode'] == 'BLOCKED_NOT_PASS' and mode['obligation'],
                'Missing mode cannot silently leave the coverage denominator')
    for field in ('unknownSourceIsUnlimited', 'scenarioLabelSetsState', 'gridFollowingImpliesIslandSupply',
                  'bidirectionalPortProvesParallelOperation', 'nameplatePvGuaranteesBackup',
                  'zeroExportSetpointIsProof', 'waiverGreensMandatoryViolation',
                  'dcPoeEvidenceProvesAcSourceStudy', 'candidateStudyMayBeCopiedCurrent',
                  'projectStudyMayUseLiveWeather', 'existingSingleSourceSelectorMayEncodeParallelSilently'):
        require(source['invariants'][field] is False, f'Unsafe source-system inference: {field}')
    for field in ('sourceAuthorityRequiresEditionAndSiteScope', 'allRequiredModesMustBeCovered',
                  'sourceStudyHashesMustMatchConfiguration', 'stateChangeInvalidatesScopedConsumers',
                  'historicalStudyIsOfflineReproducible'):
        require(source['invariants'][field] is True, f'Missing source-system gate: {field}')
    require(source['physicalBoundary'] == {'owner': 'ELV6', 'roofStructuralSolarYieldEngineIncluded': False,
            'fuelExhaustMechanicalEngineIncluded': False, 'claimsNormativeCompliance': False},
            'ELV6 source scope creep')
    normative_source = source['baselineRefs']['ELV7']
    require(re.fullmatch(r'[0-9a-f]{40}', normative_source), 'Invalid normative source pin')
    raw = subprocess.check_output(['git', 'show', normative_source +
                                  ':docs/product/elv7-implementation/rule-family-registry.json'], cwd=ROOT)
    family_ids = {f['id'] for f in json.loads(raw)['families']}
    unique([r['id'] for r in source['sourceRuleBindings']], 'source rule instance IDs')
    for rule in source['sourceRuleBindings']:
        require(rule['normativeFamilies'] and set(rule['normativeFamilies']) <= family_ids and
                rule['status'] == 'UNQUALIFIED_RULE_INSTANTIATION' and rule['obligation'],
                'Source rule must map to a real family without fabricating qualification')
    require(plan['schema'] == 'electra.elv-source-qualification-plan.v1' and
            plan['evidenceScope'] == 'DESIGN_ONLY' and plan['runtimeAccepted'] is False and
            len(plan['cases']) == plan['plannedCaseCount'] == 32, 'Source qualification plan drift')
    unique([c['id'] for c in plan['cases']], 'source oracle IDs')
    unique([c['scenario'] for c in plan['cases']], 'source oracle scenarios')
    for case in plan['cases']:
        require(case['status'] == 'PLANNED' and case['executed'] is False and case['oracle'],
                'Planned source cases cannot certify runtime')
    require(readiness['schema'] == 'electra.elv-design-readiness.v1' and
            readiness['runtimeReady'] is False and readiness['percentageClaim'] is None,
            'Readiness cannot imply runtime or invent a completeness percentage')
    unique([i['id'] for i in readiness['items']], 'source readiness gates')
    gates = {i['id']: i for i in readiness['items']}
    require(gates['ELECTRICAL_SOURCE_PRODUCER']['state'] == 'BLOCKED_UPSTREAM' and
            gates['SCHEMA_AND_OWNER_UOW']['state'] == 'BLOCKED_ENTRY' and
            gates['SOURCE_AUTHORITY']['state'] == 'SOURCE_REVIEW_REQUIRED' and
            gates['RUNTIME_QUALIFICATION']['state'] == 'NOT_STARTED', 'Source entry blockers hidden')
    require(all(i['closure'] for i in gates.values()), 'Each readiness gate needs an exact closure condition')


def check():
    registry = read_json(BASE / 'interface-registry.json')
    binding = read_json(BASE / 'stage-binding.json')
    plan = read_json(BASE / 'qualification-plan.json')
    require(registry['schema'] == 'electra.elv-integration-interface-registry.v1', 'Interface schema drift')
    require(registry['agreementId'] == binding['agreementId'] == 'electra.elv6-elv8-integration.v1', 'Agreement identity drift')
    require(registry['status'] == 'DESIGN_AGREEMENT' and registry['runtimeAccepted'] is False,
            'Design agreement cannot certify runtime')
    require(set(registry['owners']) == {'ELV6', 'ELV7', 'EQUIPMENT_CATALOG', 'ELV8'}, 'Owner boundary drift')
    require(binding['schema'] == 'electra.elv-integration-stage-binding.v1' and
            binding['stage'] in {'ELV6', 'ELV7', 'ELV8'} and binding['runtimeReady'] is False,
            'Missing local binding or false readiness claim')
    interfaces = registry['interfaces']
    unique([i['id'] for i in interfaces], 'interface IDs')
    unique([i['schema'] for i in interfaces], 'interface schemas')
    by_id = {i['id']: i for i in interfaces}
    require(set(by_id) == {'ELV6_REQUIREMENTS', 'ELV6_EVIDENCE', 'ELV7_REQUIREMENTS',
                           'ELV7_ASSESSMENT', 'CATALOGUE_TECHNICAL', 'CATALOGUE_OFFERS',
                           'ELV8_PROPOSAL', 'ELV8_SELECTION', 'ELV8_REPORT'}, 'Missing requirement/evidence split')
    for item in interfaces:
        require(item['requiredFields'] and item['consumers'] and item['producer'] in registry['owners'],
                f'Incomplete interface {item["id"]}')
        require(item['runtimeStatus'] == 'NOT_STARTED' and item['qualified'] is False,
                'Proposed interfaces cannot certify producer support')
        require(re.fullmatch(r'electra\.[a-z0-9-]+\.v1', item['schema']), 'Unversioned schema')
        unique(item['requiredFields'], 'interface fields')
    require(by_id['ELV8_PROPOSAL']['evaluationSpace'] == 'CANDIDATE', 'Candidate space must be isolated')
    require(by_id['ELV6_EVIDENCE']['evaluationSpace'] == by_id['ELV7_ASSESSMENT']['evaluationSpace'] ==
            by_id['ELV8_SELECTION']['evaluationSpace'] == 'COMMITTED', 'CURRENT evidence space drift')
    require(by_id['CATALOGUE_TECHNICAL']['scope'] == by_id['CATALOGUE_OFFERS']['scope'] == 'CATALOGUE',
            'Reusable catalogue is not a project writer')
    require('runHash' not in by_id['ELV7_REQUIREMENTS']['requiredFields'] and
            'decisionState' not in by_id['ELV6_REQUIREMENTS']['requiredFields'],
            'Preselection requirements must not depend on completed selection/assessment')
    require({'typedObligations', 'applicabilityProofs', 'coverageManifest'} <=
            set(by_id['ELV7_REQUIREMENTS']['requiredFields']), 'Requirement coverage missing')
    require({'frozenProjectHash', 'sectionHashes', 'reportModelHash', 'audiencePolicyHash',
             'completenessFlags'} <= set(by_id['ELV8_REPORT']['requiredFields']), 'Report closure incomplete')
    revision = registry['revisionBoundary']
    require(revision['wireSchema'] == 'electra.elv4-revision-command.v2' and
            revision['wireOperations'] == ['FREEZE_DESIGN_REVISION', 'CREATE_NEXT_WORKING_DESIGN_REVISION'],
            'Public wire operations differ from accepted codec')
    require(revision['ledgerMapping']['FREEZE_DESIGN_REVISION'] == 'FREEZE_PROJECT_DESIGN_REVISION' and
            revision['independentStageFreezeAllowed'] is False and revision['strictV2PayloadUnchanged'] is True,
            'Ledger/wire/freeze boundary drift')
    dispatcher = (ROOT / 'apps/mobile/lib/application/elv4_wire_command_dispatcher.dart').read_text()
    require(all(f"'{op}'" in dispatcher for op in revision['wireOperations']), 'Dispatcher contract mismatch')
    require("'FREEZE_PROJECT_DESIGN_REVISION'" not in dispatcher, 'Internal ledger name leaked onto wire')
    freeze_repo = (ROOT / 'apps/mobile/lib/data/repositories/drift_elv_design_revision_repository.dart').read_text()
    require("'FREEZE_PROJECT_DESIGN_REVISION'" in freeze_repo, 'Re-audit internal freeze receipt identity')
    require(registry['candidateEligibility'] == {'ELIGIBLE': 'ELIGIBLE', 'INELIGIBLE': 'INELIGIBLE',
                                               'UNKNOWN': 'UNRESOLVED', 'UNRESOLVED': 'UNRESOLVED'},
            'Eligibility adapter drift')
    apply = registry['projectApply']
    for field in ('sameOwnerUowRequired', 'projectAdoptionSelfContained', 'expectedGenerationsRechecked',
                  'ledgerReplayBeforePreconditions'):
        require(apply[field] is True, f'Missing project atomicity gate: {field}')
    for field in ('crossDatabaseAtomicityAssumed', 'trialEvidenceMayBecomeCurrentByCopy',
                  'rawViolationMayBecomePassByWaiver'):
        require(apply[field] is False, f'Unsafe integration claim: {field}')
    frozen = registry['freeze']
    require(frozen['baseManifestSchema'] == 'electra.elv4-snapshot-manifest.v1' and
            frozen['baseManifestImmutable'] is True and frozen['catalogueOwnsProjectFreeze'] is False,
            'Historical manifest/catalogue ownership drift')
    require(frozen['reportAssemblyOrder'] == 'AFTER_FROZEN_PROJECT' and
            frozen['frozenRootContainsFutureReportHash'] is False, 'Freeze/report hash cycle')
    require(set(frozen['sectionSchemas']) == {'ELV5', 'ELV6', 'ELV7', 'ELV8'}, 'Missing frozen sections')
    unique(list(frozen['sectionSchemas'].values()), 'section schemas')
    events = registry['invalidation']
    unique([e['event'] for e in events], 'invalidation events')
    event_map = {e['event']: e for e in events}
    price = event_map['OFFER_STOCK_FX_OR_COST_POLICY_CHANGED']
    require(price['consumerDomains'] == ['ECONOMIC'] and price['technicalEvidencePreserved'] is True,
            'Price-only change cannot stale technical facts')
    require({'TECHNICAL_EDITION_ADOPTED', 'PLACEMENT_OR_PHYSICAL_CONTEXT_CHANGED',
             'PROFILE_RULE_OR_APPLICABILITY_CHANGED', 'SOURCE_TRUST_OR_REVIEW_CHANGED',
             'MISSING_SELECTOR_OR_MEMBERSHIP_CHANGED', 'SAME_HASH_NEW_GENERATION'} <= set(event_map),
            'Missing invalidation event')
    for event in events:
        require(event['mayMutateSelectedTechnicalFacts'] is False and
                event['closurePolicy'] == 'SERVER_DERIVED_OLD_NEW_WITH_MISSING_SELECTORS',
                'Invalidation cannot silently replace equipment or trust UI closures')
    unique([a['path'] for a in binding['agreementArtifacts']], 'agreement artifact paths')
    require({a['path'] for a in binding['agreementArtifacts']} == {
        'docs/product/elv-integration/' + f for f in
        ('README.md', 'runtime-handoff-contract.md', 'interface-registry.json', 'qualification-plan.json',
         'source-systems-contract.md', 'source-systems-registry.json', 'source-qualification-plan.json',
         'source-authority-review.md', 'design-readiness.json')},
        'Agreement replica must bind all shared design artifacts')
    for artifact in binding['agreementArtifacts'] + binding['localDocuments']:
        path = artifact['path']
        require(path.startswith('docs/product/') and '..' not in Path(path).parts, 'Unsafe local fingerprint path')
        require(digest(ROOT / path) == artifact['sha256'], f'Design changed without local agreement review: {path}')
    required_docs = {
        'ELV6': {'docs/product/elv6-authoritative-spec-index.md',
                 'docs/product/elv6-implementation/code-level-runtime-contract.md'},
        'ELV7': {'docs/product/elv7-authoritative-spec-index.md',
                 'docs/product/elv7-normative-validation-design-specification.md',
                 'docs/product/component-catalog/configuration-and-layout-contract.md'},
        'ELV8': {'docs/product/elv8-authoritative-spec-index.md',
                 'docs/product/elv8-deliverables-design-specification.md'},
    }
    require(required_docs[binding['stage']] <= {a['path'] for a in binding['localDocuments']},
            'Binding omitted an authoritative stage specification')
    schema_text = (ROOT / 'apps/mobile/lib/data/database/app_database.dart').read_text()
    local_schema = int(re.search(r'int get schemaVersion => (\d+);', schema_text).group(1))
    require(local_schema == binding['observedLocalDbSchema'], 'Local DB source changed; reconcile entry baseline')
    main = registry['mainBaseline']
    require(re.fullmatch(r'[0-9a-f]{40}', main['sourceSha']) and main['mergeDoesNotInferAcceptance'] is True,
            'Invalid main source authority')
    main_db = subprocess.check_output(['git', 'show', main['sourceSha'] +
                                      ':apps/mobile/lib/data/database/app_database.dart'], cwd=ROOT, text=True)
    require(int(re.search(r'int get schemaVersion => (\d+);', main_db).group(1)) == main['observedDbSchema'],
            'Main schema/source pin mismatch')
    require(binding['schemaReconciliationRequired'] == (local_schema != main['observedDbSchema']),
            'Schema gap must remain visible')
    require(set(binding['runtimeEntryBlockers']) == set(registry['runtimeEntryBlockers']),
            'Runtime entry blockers cannot disappear through design binding')
    require(plan['schema'] == 'electra.elv-integration-qualification-plan.v1' and
            plan['status'] == 'DESIGN_ONLY' and plan['runtimeAccepted'] is False and
            len(plan['cases']) == plan['plannedCaseCount'] == 24, 'Cross-stage qualification plan drift')
    unique([c['id'] for c in plan['cases']], 'qualification IDs')
    unique([c['scenario'] for c in plan['cases']], 'qualification scenarios')
    for case in plan['cases']:
        require(case['status'] == 'PLANNED' and case['executed'] is False and case['oracle'],
                'Planned cross-stage case cannot certify runtime')
    for doc in BASE.glob('*.md'):
        for link in re.findall(r'\]\(([^)]+)\)', doc.read_text()):
            if '://' not in link and not link.startswith('#'):
                require((doc.parent / link.split('#')[0]).exists(), f'Broken shared agreement link: {link}')
    check_sources()
    print(f'PASS: {binding["stage"]} integration design; 9 stage + 4 source proposed schemas; '
          f'24 shared + 32 source PLANNED oracles; '
          f'local schema {local_schema}, pinned main {main["observedDbSchema"]}; runtime NOT READY.')


if __name__ == '__main__':
    try:
        check()
    except (ValueError, KeyError, OSError, AttributeError, subprocess.CalledProcessError) as exc:
        print(f'ELV INTEGRATION DESIGN FAIL: {exc}', file=sys.stderr)
        sys.exit(1)
