"""Execute the proposed fire-claim SQL; not production Drift migration evidence."""
from pathlib import Path
import re
import sqlite3
import unittest


ROOT = Path(__file__).resolve().parents[2]
DOCUMENT = ROOT / 'docs/product/elv5-implementation/persistence-schema-contract.md'


class FireClaimContractTests(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.addCleanup(self.db.close)
        self.db.execute('PRAGMA foreign_keys=ON')
        self.db.executescript('''
            CREATE TABLE fire_loop_device_assignments (
                project_id TEXT NOT NULL, design_revision_id TEXT NOT NULL,
                binding_id TEXT NOT NULL, device_id TEXT NOT NULL,
                UNIQUE(project_id, design_revision_id, binding_id, device_id)
            );
        ''')
        ddl = re.search(r'-- ELV5_FIRE_CLAIM_DDL_BEGIN\n(.*?)-- ELV5_FIRE_CLAIM_DDL_END',
                        DOCUMENT.read_text(encoding='utf-8'), re.S)
        self.assertIsNotNone(ddl, 'Normative claim SQL must remain executable')
        self.db.executescript(ddl.group(1))
        self.db.executemany('INSERT INTO fire_loop_device_assignments VALUES (?,?,?,?)', [
            ('p1', 'r1', 'b1', 'd1'), ('p1', 'r1', 'b2', 'd2'),
            ('p1', 'r2', 'b1', 'd1'), ('p2', 'r3', 'b1', 'd1'),
        ])
        self.db.commit()

    def claim(self, binding='b1', device='d1', address=1, domain='panel1-loop1',
              project='p1', revision='r1'):
        self.db.execute('INSERT INTO fire_address_claims VALUES (?,?,?,?,?,?)',
                        (project, revision, binding, device, domain, address))

    def test_two_bindings_cannot_claim_one_physical_address(self):
        self.claim()
        with self.assertRaises(sqlite3.IntegrityError):
            self.claim(binding='b2', device='d2')

    def test_independent_domains_and_revisions_can_reuse_address(self):
        self.claim()
        self.claim(domain='panel1-loop2')
        self.claim(revision='r2')
        self.claim(project='p2', revision='r3')
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM fire_address_claims').fetchone()[0], 4)

    def test_foreign_project_revision_and_device_are_rejected(self):
        for change in [{'project': 'p2'}, {'revision': 'unknown'}, {'device': 'd2'}]:
            with self.subTest(change=change), self.assertRaises(sqlite3.IntegrityError):
                self.claim(**change)

    def test_partial_multiaddress_assignment_rolls_back(self):
        self.claim(address=3); self.db.commit()
        with self.assertRaises(sqlite3.IntegrityError), self.db:
            self.claim(binding='b2', device='d2', address=2)
            self.claim(binding='b2', device='d2', address=3)
        self.assertEqual(self.db.execute('SELECT address FROM fire_address_claims').fetchall(), [(3,)])

    def test_restore_cannot_steal_reallocated_address(self):
        self.claim(); self.db.commit()
        with self.db:
            self.db.execute("DELETE FROM fire_address_claims WHERE binding_id='b1'")
            self.claim(binding='b2', device='d2')
        with self.assertRaises(sqlite3.IntegrityError), self.db:
            self.claim(address=2)
            self.claim(address=1)
        self.assertEqual(self.db.execute('SELECT binding_id,address FROM fire_address_claims').fetchall(), [('b2', 1)])

    def test_membership_cannot_disappear_under_active_claim(self):
        self.claim()
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("DELETE FROM fire_loop_device_assignments WHERE binding_id='b1'")

    def test_fractional_and_negative_addresses_reject(self):
        for value in [-1, 1.5, 'invalid']:
            with self.subTest(value=value), self.assertRaises(sqlite3.IntegrityError):
                self.claim(address=value)


if __name__ == '__main__':
    unittest.main()
