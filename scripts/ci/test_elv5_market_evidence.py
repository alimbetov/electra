"""Keep planning labels separate from measured arithmetic and runtime verdicts."""
import importlib.util
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location(
    'elv5_market', Path(__file__).with_name('check-elv5-market-simulation.py'))
MARKET = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MARKET)


class MarketEvidenceTests(unittest.TestCase):
    def test_negative_diagnostic_cannot_become_pass_from_positive_label(self):
        for code, index in [('ACS-05', 15), ('FA-06', 10), ('FA-06', 15),
                            ('LAN-02', 0), ('LAN-06', 10), ('LAN-07', 0)]:
            with self.subTest(code=code, index=index):
                diagnostic = MARKET.reference_computation(code, index, 'POSITIVE')
                result = MARKET.reference_margin_check(diagnostic)
                self.assertEqual(result['outcome'], 'NEGATIVE_MARGIN')
                self.assertEqual(result['fullProcessAssessment'], 'NOT_ASSESSED')
                self.assertTrue(result['negativeFields'])

    def test_exact_zero_and_tiny_negative_are_distinct(self):
        self.assertEqual(MARKET.reference_margin_check({'marginW': '0'})['outcome'],
                         'NONNEGATIVE_MARGINS')
        self.assertEqual(MARKET.reference_margin_check({'marginW': '-1/1000000000000'})['outcome'],
                         'NEGATIVE_MARGIN')

    def test_no_margin_is_not_pass(self):
        result = MARKET.reference_margin_check({'probeIndex': 1})
        self.assertEqual(result['outcome'], 'NO_MARGIN_COMPARISON')
        self.assertEqual(result['fullProcessAssessment'], 'NOT_ASSESSED')

    def test_invalid_margin_is_rejected(self):
        for value in [True, 1.5, 'NaN', '1/0', None]:
            with self.subTest(value=value), self.assertRaises(SystemExit):
                MARKET.reference_margin_check({'marginA': value})


if __name__ == '__main__':
    unittest.main()
