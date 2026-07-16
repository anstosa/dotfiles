#!/usr/bin/env python3
"""Refuse a legacy-layout cutover until its recorded safety gates are complete."""

from __future__ import annotations

import hashlib
import json
import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent


def load_json(path: Path) -> object:
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"invalid JSON at {path.relative_to(ROOT)}: {error}") from error


def filesystem_paths() -> set[str]:
    paths: set[str] = set()
    for directory, directories, files in os.walk(ROOT, topdown=True, followlinks=False):
        relative_directory = Path(directory).relative_to(ROOT)
        directories[:] = [
            name for name in directories
            if relative_directory / name not in {Path('.git'), Path('.omx')}
        ]
        for name in directories + files:
            relative = relative_directory / name
            if relative == Path('.'):
                continue
            paths.add(relative.as_posix())
    return paths


def main() -> int:
    blockers: list[str] = []

    manifest = load_json(ROOT / 'migration/chezmoi-manifest.json')
    assert isinstance(manifest, dict)
    entries = manifest.get('entries')
    if manifest.get('schema_version') != 1 or not isinstance(entries, list):
        blockers.append('migration manifest is not schema version 1 with an entries array')
        entries = []

    tracked = load_json(ROOT / '.omx/evidence/tracked-inventory.json')
    assert isinstance(tracked, dict)
    tracked_paths = [entry.get('path') for entry in tracked.get('entries', []) if isinstance(entry, dict)]
    rules = [entry.get('legacy_path', '').rstrip('/') for entry in entries if isinstance(entry, dict)]
    for path in tracked_paths:
        if not isinstance(path, str):
            blockers.append('tracked inventory contains an entry without a path')
            continue
        exact = [rule for rule in rules if rule == path]
        matches = exact or [rule for rule in rules if rule and path.startswith(rule + '/')]
        if len(matches) != 1:
            blockers.append(f'baseline path {path!r} has {len(matches)} manifest dispositions')

    remote_path = ROOT / '.omx/evidence/baseline-remote.json'
    remote_hash_path = ROOT / '.omx/evidence/baseline-remote.sha256'
    if not remote_path.is_file() or not remote_hash_path.is_file():
        blockers.append('SHA-bound remote baseline evidence is missing')
    else:
        remote = load_json(remote_path)
        assert isinstance(remote, dict)
        if remote.get('branch_sha') != remote.get('tag_peeled_commit_sha'):
            blockers.append('baseline branch and peeled annotated tag do not match')
        expected_hash = hashlib.sha256(remote_path.read_bytes()).hexdigest()
        recorded_hash = remote_hash_path.read_text().split(maxsplit=1)
        if not recorded_hash or recorded_hash[0] != expected_hash:
            blockers.append('remote baseline evidence hash is missing or mismatched')

    inventory_path = ROOT / '.omx/evidence/filesystem-inventory.json'
    inventory = load_json(inventory_path)
    assert isinstance(inventory, dict)
    inventory_entries = inventory.get('entries')
    inventory_paths: set[str] = set()
    required = {'path', 'type', 'classification', 'disposition', 'size'}
    missing_metadata: list[str] = []
    unapproved: list[str] = []
    if inventory.get('schema_version') != 1 or not isinstance(inventory_entries, list):
        blockers.append('filesystem inventory is not schema version 1 with an entries array')
        inventory_entries = []
    for entry in inventory_entries:
        if not isinstance(entry, dict):
            blockers.append('filesystem inventory contains a non-object entry')
            continue
        path = entry.get('path')
        if isinstance(path, str):
            inventory_paths.add(path)
        missing = sorted(required - set(entry))
        if missing:
            missing_metadata.append(str(path))
        if entry.get('disposition') in {None, '', 'unknown'}:
            unapproved.append(str(path))

    if missing_metadata:
        blockers.append(
            'filesystem inventory entries lack required metadata: ' + ', '.join(missing_metadata[:8])
            + (' ...' if len(missing_metadata) > 8 else '')
        )
    if unapproved:
        blockers.append(
            'filesystem inventory entries have no approved disposition: ' + ', '.join(unapproved[:8])
            + (' ...' if len(unapproved) > 8 else '')
        )

    missing_paths = sorted(filesystem_paths() - inventory_paths)
    if missing_paths:
        blockers.append(
            'filesystem inventory is stale; unrecorded paths include: ' + ', '.join(missing_paths[:8])
            + (' ...' if len(missing_paths) > 8 else '')
        )

    unresolved = [
        entry.get('legacy_path') for entry in entries
        if isinstance(entry, dict) and entry.get('disposition') in {'gitlink-deferred', 'blocked-not-inspected'}
    ]
    if unresolved:
        blockers.append('legacy paths still need an explicit cutover disposition: ' + ', '.join(unresolved))

    approval = ROOT / 'migration/cutover-approval.json'
    if not approval.is_file():
        blockers.append('cutover approval record is absent')

    if blockers:
        print('CUTOVER NOT READY:')
        for blocker in blockers:
            print(f'- {blocker}')
        return 1

    print('CUTOVER READY: every recorded gate passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
