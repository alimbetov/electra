"""Adversarial checks for the closure validator, not runtime qualification."""
import copy
import importlib.util
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('closure', Path(__file__).with_name('check-elv4-closure.py'))
closure = importlib.util.module_from_spec(spec)
spec.loader.exec_module(closure)


class ClosureGateTest(unittest.TestCase):
    def setUp(self):
        self.manifest = closure.read(closure.BASE / 'qualification.json')
        self.sha = 'a' * 40
        self.report = {'sourceSha': self.sha, 'cases': []}
        for case in self.manifest['positiveCases']:
            rows = []
            for result in case['requiredResults']:
                for context in case['requiredContexts'][result['processCode']]:
                    for dimension in result['requiredDimensions']:
                        rows.append(dict(context=context, processCode=result['processCode'],
                                         dimension=dimension, evaluationId='fixture-evaluation',
                                         evidenceSha256='b' * 64, inputFingerprint='c' * 64,
                                         completion='COMPLETE', assessment='PASS', execution='SUCCEEDED'))
            self.report['cases'].append(dict(id=case['id'], fixtureKind='PUBLIC_COMMAND_FILE_SQLITE',
                                            foreignKeyViolations=0, results=rows))

    def test_complete_structural_report_is_recognized(self):
        closure.check_qualification(self.manifest, self.report, self.sha)

    def test_missing_case_or_required_dimension_is_rejected(self):
        for kind in ('case', 'dimension'):
            report = copy.deepcopy(self.report)
            if kind == 'case':
                report['cases'].pop()
            else:
                report['cases'][0]['results'].pop()
            with self.assertRaises(ValueError):
                closure.check_qualification(self.manifest, report, self.sha)

    def test_unresolved_duplicate_and_stale_results_are_rejected(self):
        for kind in ('unresolved', 'duplicate', 'stale', 'synthetic'):
            report = copy.deepcopy(self.report)
            row = report['cases'][0]['results'][0]
            if kind == 'unresolved':
                row['assessment'] = 'UNRESOLVED'
            elif kind == 'duplicate':
                report['cases'][0]['results'].append(row.copy())
            elif kind == 'stale':
                report['sourceSha'] = 'd' * 40
            else:
                report['cases'][0]['results'] = [{'qualified': True}]
            with self.assertRaises((ValueError, KeyError)):
                closure.check_qualification(self.manifest, report, self.sha)

    def test_acceptance_uses_current_run_evidence_without_source_self_reference(self):
        record = closure.read(closure.BASE / 'closure.json')
        for finding in record['findings']:
            finding['status'] = 'RESOLVED'
        ledger = closure.read(closure.BASE / 'requirements.json')
        for requirement in ledger['requirements']:
            requirement.update(runtimeStatus='IMPLEMENTED', openFindingIds=[])
            # Historical testedSha stays different from the current run SHA.
            self.assertNotEqual(requirement['testedSha'], self.sha)
        self.report['requirementResults'] = [
            dict(requirementId=r['requirementId'], status='PASS',
                 evidenceRefs=['executed-test:' + r['requirementId']])
            for r in ledger['requirements']]
        technical = dict(sourceSha=self.sha, technicalResult='PASS',
                         phases={p: 'PASS' for p in closure.PHASES})
        event = closure.check_acceptance(ledger, record, technical, self.report, self.sha)
        self.assertEqual(event['sourceSha'], self.sha)
        self.assertEqual(event['event'], 'RUNTIME_ACCEPTED')
        self.assertTrue(event['evidenceRefs'])
        self.report['requirementResults'].pop()
        with self.assertRaises(ValueError):
            closure.check_acceptance(ledger, record, technical, self.report, self.sha)

    def test_open_findings_prevent_acceptance_even_with_green_reports(self):
        record = closure.read(closure.BASE / 'closure.json')
        ledger = closure.read(closure.BASE / 'requirements.json')
        with self.assertRaises(ValueError):
            closure.check_acceptance(ledger, record, {'sourceSha':self.sha, 'technicalResult':'PASS'},
                                     self.report, self.sha)


if __name__ == '__main__':
    unittest.main()
