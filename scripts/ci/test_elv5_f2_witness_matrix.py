import copy
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location('f2_matrix', Path(__file__).with_name('collect-elv5-f2-witness-matrix.py'))
m = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(m)


class ExecutionWitnessTests(unittest.TestCase):
    def setUp(self):
        self.source = '724d93919bc404bea9b133cf5b8ead7065b3d8df'
        self.witness = m.registry()[0]
        code = self.witness['processCode']
        authority = {'schema':'electra.elv5-foundation-authority-manifest.v1','rulesetVersion':'r1',
                     'processes':[{'processCode':w['processCode'],'processVersion':'v1'} for w in m.registry()]}
        observed = {'evaluationId':'eval-after','pointerGeneration':3,'inputFingerprint':'a'*64,
                    'outputSha256':'b'*64,'freshness':'CURRENT','execution':'SUCCEEDED','completion':'COMPLETE'}
        self.events = [{'type':'start'}, {'type':'suite','suite':{'id':1,'path':'/checkout/' + self.witness['path']}},
                       {'type':'testStart','test':{'id':2,'suiteID':1,'name':self.witness['testName']}}]
        for stage in sorted(m.REQUIRED | {'Q6_REPUBLISHED'}):
            value = dict(observed)
            if stage == 'Q6_INITIAL':
                value.update(evaluationId='eval-before', pointerGeneration=1,inputFingerprint='c'*64)
            if stage == 'PERSISTED_IDENTITY':
                value.update(revisionState='FROZEN',nodeKeySha256='d'*64,evidenceSha256='e'*64,
                             authorityManifest=authority,
                             qualificationIdentity={'schema':'electra.elv5-foundation-qualification-identity.v1',
                                                    'sourceSha':self.source,'processVersion':'v1','rulesetVersion':'r1',
                                                    'authorityFingerprint':m.digest(authority)})
            value.update(schema='electra.elv5-f2-lifecycle-event.v1',processCode=code,sourceSha=self.source,stage=stage)
            self.events.append({'type':'print','testID':2,'message':m.PREFIX + m.json.dumps(value)})
        self.events += [{'type':'testDone','testID':2,'result':'success','skipped':False}, {'type':'done','success':True}]

    def collect(self, events=None):
        return m.collect(self.events if events is None else events, [self.witness], self.source)

    def mutate_stage(self, stage, update):
        for event in self.events:
            if event.get('type') == 'print':
                value = m.json.loads(event['message'][len(m.PREFIX):])
                if value['stage'] == stage:
                    update(value)
                    event['message'] = m.PREFIX + m.json.dumps(value)

    def test_complete_execution_and_persisted_pin_are_required(self):
        row = self.collect()[0]
        self.assertEqual(row['lifecycleResult'], 'PASS_Q6_Q7_Q8')
        self.assertTrue(row['fullQualificationResult'].startswith('PENDING'))
        self.assertEqual(row['qualificationIdentity']['sourceSha'], self.source)

    def test_reporter_paths_may_be_mobile_relative_or_absolute(self):
        for path in [self.witness['path'], self.witness['path'].removeprefix('apps/mobile/'), '/checkout/'+self.witness['path']]:
            self.events[1]['suite']['path'] = path
            self.assertEqual(self.collect()[0]['processCode'],self.witness['processCode'])
        self.events[1]['suite']['path'] = '/unrelated/' + Path(self.witness['path']).name
        self.assertRaises(ValueError,self.collect)

    def test_registry_has_exact_27_unique_real_test_bindings(self):
        self.assertEqual(len(m.registry()), 27)

    def test_existing_filename_without_execution_is_not_evidence(self):
        self.assertRaises(ValueError, self.collect, [e for e in self.events if e['type'] != 'print'])

    def test_failed_skipped_incomplete_or_missing_test_never_passes(self):
        for change in ('failed','skipped','missing_completion','incomplete_suite','foreign_test','error'):
            with self.subTest(change=change):
                events = copy.deepcopy(self.events)
                if change == 'failed': events[-2]['result'] = 'failure'
                if change == 'skipped': events[-2]['skipped'] = True
                if change == 'missing_completion': events.pop(-2)
                if change == 'incomplete_suite': events.pop()
                if change == 'foreign_test': events[2]['test']['name'] = 'other test'
                if change == 'error': events.insert(-1, {'type':'error'})
                self.assertRaises(ValueError, self.collect, events)

    def test_wrong_source_process_authority_and_version_fail_closed(self):
        for field, value in [('sourceSha','f'*40), ('processVersion','wrong'), ('authorityFingerprint','f'*64)]:
            with self.subTest(field=field):
                events = copy.deepcopy(self.events)
                self.mutate_stage('PERSISTED_IDENTITY', lambda row: row['qualificationIdentity'].update({field:value}))
                self.assertRaises(ValueError, self.collect)
                self.events = events
        self.mutate_stage('Q7_REPLAY', lambda row: row.update(processCode='FOREIGN'))
        self.assertRaises(ValueError, self.collect)

    def test_replay_republication_and_frozen_identity_cannot_drift(self):
        for stage, field, value in [('Q8_REPLAY','outputSha256','f'*64),
                                    ('PERSISTED_IDENTITY','pointerGeneration',4),
                                    ('PERSISTED_IDENTITY','revisionState','WORKING'),
                                    ('Q6_REPUBLISHED','inputFingerprint','c'*64)]:
            with self.subTest(stage=stage,field=field):
                events = copy.deepcopy(self.events)
                self.mutate_stage(stage, lambda row: row.update({field:value}))
                self.assertRaises(ValueError, self.collect)
                self.events = events

    def add_global_events(self):
        values = {
            'GLOBAL_PUBLICATION_ROLLBACK': {'faultTables':['discipline_evaluation_records','discipline_dependency_index','discipline_evaluation_pointers','command_execution_records'],'reopenedAfterEveryFault':True},
            'GLOBAL_INDEPENDENT_CAS': {'connections':2,'committedWriters':1,'loserCode':'ELV5_POINTER_GENERATION_CONFLICT','pointerGeneration':1},
            'GLOBAL_FREEZE_MANIFEST': {'publicFreezeApi':True,'faultAfterAllSections':True,'restartReplayIdentical':True,'newCalculationRejected':True,'createNextRestoresConfiguration':True,'manifestImmutable':True,'disciplineAppendOnly':True,'physicalHashLinked':True,'powerHashLinked':True,'manifestSchema':'electra.elv4-snapshot-manifest.v1','disciplineSectionSchema':'electra.elv5-discipline-freeze-section.v1'},
        }
        for stage, evidence in values.items():
            payload = {'schema':'electra.elv5-f2-lifecycle-event.v1','processCode':self.witness['processCode'],'sourceSha':self.source,'stage':stage,**evidence}
            self.events.insert(-2, {'type':'print','testID':2,'message':m.PREFIX+m.json.dumps(payload)})

    def test_global_suite_requires_every_fault_cas_and_real_freeze_checkpoint(self):
        self.assertRaises(ValueError,m.collect,self.events,[self.witness],self.source,require_global=True)
        self.add_global_events()
        self.assertEqual(m.collect(self.events,[self.witness],self.source,require_global=True)[0]['globalReliabilityResult'],'PASS')

    def test_global_suite_rejects_weak_or_missing_failure_proof(self):
        self.add_global_events()
        for stage, field, value in [('GLOBAL_PUBLICATION_ROLLBACK','faultTables',[]),('GLOBAL_INDEPENDENT_CAS','connections',1),('GLOBAL_INDEPENDENT_CAS','committedWriters',2),('GLOBAL_FREEZE_MANIFEST','publicFreezeApi',False),('GLOBAL_FREEZE_MANIFEST','faultAfterAllSections',False),('GLOBAL_FREEZE_MANIFEST','manifestSchema','electra.elv-snapshot-manifest.v2'),('GLOBAL_FREEZE_MANIFEST','manifestImmutable',False),('GLOBAL_FREEZE_MANIFEST','disciplineAppendOnly',False),('GLOBAL_FREEZE_MANIFEST','physicalHashLinked',False),('GLOBAL_FREEZE_MANIFEST','powerHashLinked',False),('GLOBAL_FREEZE_MANIFEST','createNextRestoresConfiguration',False)]:
            with self.subTest(stage=stage,field=field):
                before=copy.deepcopy(self.events)
                self.mutate_stage(stage,lambda row:row.update({field:value}))
                self.assertRaises(ValueError,m.collect,self.events,[self.witness],self.source,require_global=True)
                self.events=before

    def test_exact_global_regression_must_execute_and_succeed(self):
        binding={'path':self.witness['path'],'testName':self.witness['testName']}
        self.assertEqual(len(m.verify_regressions(self.events,[binding])),1)
        self.assertRaises(ValueError,m.verify_regressions,self.events,[{**binding,'testName':'missing regression'}])
        self.events[-2]['skipped']=True
        self.assertRaises(ValueError,m.verify_regressions,self.events,[binding])

    def test_missing_or_duplicate_checkpoint_fails(self):
        self.assertRaises(ValueError, self.collect, self.events[:3] + self.events[4:])
        self.assertRaises(ValueError, self.collect, self.events[:4] + [self.events[3]] + self.events[4:])


if __name__ == '__main__':
    unittest.main()
