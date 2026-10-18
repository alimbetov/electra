"""Source and authority integrity for ELV5 design artifacts (not runtime proof)."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def require(condition, message):
    if not condition:
        raise SystemExit(message)


def canonical_bytes(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(',', ':')).encode('utf-8')


def source_provenance(root, *, allow_dirty=False, environment=None):
    environment = os.environ if environment is None else environment
    try:
        head = subprocess.check_output(
            ['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        status = subprocess.check_output(
            ['git', 'status', '--porcelain', '--untracked-files=normal'],
            cwd=root, text=True)
    except (OSError, subprocess.CalledProcessError) as error:
        raise SystemExit('Cannot establish ELV5 source provenance') from error
    require(re.fullmatch('[0-9a-f]{40}', head), 'Invalid source commit SHA')
    claimed = environment.get('GITHUB_SHA')
    require(not claimed or claimed == head, 'GITHUB_SHA does not match checked-out HEAD')
    dirty = bool(status.strip())
    require(allow_dirty or not dirty,
            'Dirty worktree: commit first, or use --allow-dirty for WORKTREE_PREVIEW only')
    return {'sourceSha': head, 'sourceTreeState': 'DIRTY' if dirty else 'CLEAN',
            'evidenceScope': 'WORKTREE_PREVIEW' if dirty else 'EXACT_HEAD'}


# These fields describe the manifest envelope, not the fingerprinted authority core.
MANIFEST_METADATA = {
    'authorityFingerprintSha256', 'sourceSha', 'sourceTreeState', 'evidenceScope',
    'runtimeStatus', 'qualificationStatus', 'marketSimulationStatus',
    'combinatorialMatrixStatus', 'implementationBindingStatus',
    'projectAlignmentStatus', 'note',
}


def verify_authority_manifest(manifest, root, expected_paths, provenance):
    require(manifest.get('manifestSchema') == 'electra.elv5-contract-manifest.v1',
            'Unexpected authority manifest schema')
    require(manifest.get('manifestCanonicalization') == 'utf8-json-sort-keys-separators-v1'
            and manifest.get('hashAlgorithm') == 'SHA-256', 'Unknown manifest encoding')
    for field, value in provenance.items():
        require(manifest.get(field) == value, 'Authority manifest provenance mismatch: ' + field)
    require(manifest.get('runtimeStatus') == 'NOT_STARTED'
            and manifest.get('qualificationStatus') == 'NOT_EXECUTED',
            'Design manifest cannot claim runtime acceptance')
    fingerprint = manifest.get('authorityFingerprintSha256')
    require(isinstance(fingerprint, str) and re.fullmatch('[0-9a-f]{64}', fingerprint),
            'Invalid authority fingerprint')
    core = {key: value for key, value in manifest.items() if key not in MANIFEST_METADATA}
    require(hashlib.sha256(canonical_bytes(core)).hexdigest() == fingerprint,
            'Authority fingerprint does not match manifest contents')
    rows = manifest.get('authorityArtifacts', [])
    paths = [row.get('path') for row in rows]
    require(len(expected_paths) == len(set(expected_paths)), 'Duplicate authority inventory path')
    require(len(paths) == len(set(paths)) == len(expected_paths)
            and set(paths) == set(expected_paths), 'Authority artifact inventory mismatch')
    require(manifest.get('authorityArtifactCount') == len(paths), 'Authority artifact count mismatch')
    for row in rows:
        # Only paths from the code-owned inventory can reach the filesystem.
        data = (Path(root) / row['path']).read_bytes()
        require(row.get('byteLength') == len(data)
                and row.get('sha256') == hashlib.sha256(data).hexdigest(),
                'Authority artifact content mismatch: ' + row['path'])
    return fingerprint
