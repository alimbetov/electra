"""Regression tests for false exact-head and authority-integrity claims."""
import copy
import hashlib
from pathlib import Path
import subprocess
import tempfile
import unittest

from elv5_evidence import (
    MANIFEST_METADATA, canonical_bytes, source_provenance, verify_authority_manifest,
)


class EvidenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'ELV5 fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.fact = self.root / 'authority.txt'
        self.fact.write_text('immutable specification\n', encoding='utf-8')
        self.git('add', '.')
        self.git('commit', '-qm', 'fixture')
        self.provenance = source_provenance(self.root, environment={})

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.root, text=True)

    def manifest(self):
        data = self.fact.read_bytes()
        result = {
            'manifestSchema': 'electra.elv5-contract-manifest.v1',
            'manifestCanonicalization': 'utf8-json-sort-keys-separators-v1',
            'hashAlgorithm': 'SHA-256',
            'authorityArtifactCount': 1,
            'authorityArtifacts': [{'path': 'authority.txt', 'byteLength': len(data),
                                    'sha256': hashlib.sha256(data).hexdigest()}],
            **self.provenance,
            'runtimeStatus': 'NOT_STARTED', 'qualificationStatus': 'NOT_EXECUTED',
        }
        self.rehash(result)
        return result

    @staticmethod
    def rehash(manifest):
        core = {k: v for k, v in manifest.items() if k not in MANIFEST_METADATA}
        manifest['authorityFingerprintSha256'] = hashlib.sha256(canonical_bytes(core)).hexdigest()

    def verify(self, manifest):
        return verify_authority_manifest(manifest, self.root, ['authority.txt'], self.provenance)

    def test_clean_exact_head(self):
        self.assertEqual(self.provenance['evidenceScope'], 'EXACT_HEAD')
        self.assertEqual(self.verify(self.manifest()), self.manifest()['authorityFingerprintSha256'])

    def test_environment_cannot_impersonate_another_commit(self):
        with self.assertRaisesRegex(SystemExit, 'GITHUB_SHA'):
            source_provenance(self.root, environment={'GITHUB_SHA': '0' * 40})

    def test_dirty_tracked_source_is_not_exact_head(self):
        self.fact.write_text('changed')
        with self.assertRaisesRegex(SystemExit, 'Dirty worktree'):
            source_provenance(self.root, environment={})
        preview = source_provenance(self.root, allow_dirty=True, environment={})
        self.assertEqual(preview['evidenceScope'], 'WORKTREE_PREVIEW')
        self.assertEqual(preview['sourceTreeState'], 'DIRTY')

    def test_untracked_source_is_not_exact_head(self):
        (self.root / 'new-code.py').write_text('pass\n')
        with self.assertRaisesRegex(SystemExit, 'Dirty worktree'):
            source_provenance(self.root, environment={})

    def test_fingerprint_alphabet_and_content(self):
        for value in ['z' * 64, '0' * 64, 'ab', None]:
            with self.subTest(value=value):
                manifest = self.manifest(); manifest['authorityFingerprintSha256'] = value
                with self.assertRaises(SystemExit):
                    self.verify(manifest)

    def test_changed_core_rejected(self):
        manifest = self.manifest(); manifest['authorityArtifactCount'] = 27
        with self.assertRaisesRegex(SystemExit, 'contents'):
            self.verify(manifest)

    def test_changed_file_rejected_even_with_unchanged_manifest(self):
        manifest = self.manifest(); self.fact.write_text('different specification\n')
        with self.assertRaisesRegex(SystemExit, 'content mismatch'):
            self.verify(manifest)

    def test_inventory_cannot_omit_duplicate_or_escape(self):
        for rows in [[], [self.manifest()['authorityArtifacts'][0]] * 2,
                     [{'path': '../outside', 'sha256': 'a' * 64, 'byteLength': 1}]]:
            with self.subTest(rows=rows):
                manifest = self.manifest(); manifest['authorityArtifacts'] = rows
                manifest['authorityArtifactCount'] = len(rows); self.rehash(manifest)
                with self.assertRaisesRegex(SystemExit, 'inventory'):
                    self.verify(manifest)

    def test_provenance_and_runtime_metadata_cannot_be_forged(self):
        mutations = {'sourceSha': '0' * 40, 'sourceTreeState': 'DIRTY',
                     'evidenceScope': 'WORKTREE_PREVIEW', 'runtimeStatus': 'ACCEPTED',
                     'qualificationStatus': 'PASS'}
        for field, value in mutations.items():
            with self.subTest(field=field):
                manifest = copy.deepcopy(self.manifest()); manifest[field] = value
                with self.assertRaises(SystemExit):
                    self.verify(manifest)

    def test_deterministic_encoding(self):
        self.assertEqual(canonical_bytes({'б': 2, 'a': 1}),
                         canonical_bytes({'a': 1, 'б': 2}))


if __name__ == '__main__':
    unittest.main()
