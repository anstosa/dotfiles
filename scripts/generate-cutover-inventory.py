#!/usr/bin/env python3
"""Generate the versioned inventory used to verify the final repository layout."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / '.omx/evidence/filesystem-inventory.json'
EXCLUDED = {Path('.git'), Path('.omx')}


def run_git(*args: str) -> set[str]:
    result = subprocess.run(
        ['git', '-C', str(ROOT), *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return {line for line in result.stdout.splitlines() if line}


def classify(path: Path, tracked: set[str]) -> str:
    relative = path.as_posix()
    if relative in tracked:
        return 'tracked'
    ignored = subprocess.run(
        ['git', '-C', str(ROOT), 'check-ignore', '-q', '--no-index', relative],
        check=False,
    ).returncode == 0
    return 'ignored' if ignored else 'untracked'


def disposition(path: Path) -> str:
    parts = path.parts
    if parts[0] == 'chezmoi':
        return 'managed-source'
    if parts[0] == 'migration':
        return 'migration-metadata'
    if parts[0] == 'docs' or path.name == 'README.md':
        return 'documentation'
    if parts[0] == 'scripts':
        return 'validation-or-bootstrap'
    if path.name in {'install.sh', 'update.sh'}:
        return 'repository-bootstrap'
    if path.name == '.gitignore':
        return 'repository-metadata'
    return 'repository-supporting'


def entry(path: Path, tracked: set[str]) -> dict[str, object]:
    absolute = ROOT / path
    stat = absolute.lstat()
    record: dict[str, object] = {
        'path': path.as_posix(),
        'type': 'symlink' if absolute.is_symlink() else 'directory' if absolute.is_dir() else 'file',
        'classification': classify(path, tracked),
        'disposition': disposition(path),
        'size': stat.st_size,
        'mode': format(stat.st_mode & 0o7777, '04o'),
    }
    if absolute.is_symlink():
        record['link_target'] = os.readlink(absolute)
    elif absolute.is_file() and path != Path('migration/cutover-approval.json'):
        record['sha256'] = hashlib.sha256(absolute.read_bytes()).hexdigest()
    return record


def main() -> None:
    tracked = run_git('ls-files')
    paths: list[Path] = []
    for directory, directories, files in os.walk(ROOT, topdown=True, followlinks=False):
        relative_directory = Path(directory).relative_to(ROOT)
        directories[:] = sorted(
            name for name in directories if relative_directory / name not in EXCLUDED
        )
        paths.extend(relative_directory / name for name in directories + sorted(files))

    entries = [entry(path, tracked) for path in sorted(paths)]
    payload = {
        'schema_version': 1,
        'excluded_roots': sorted(path.as_posix() for path in EXCLUDED),
        'entries': entries,
        'summary': {
            'entries': len(entries),
            'tracked': sum(item['classification'] == 'tracked' for item in entries),
            'untracked': sum(item['classification'] == 'untracked' for item in entries),
            'ignored': sum(item['classification'] == 'ignored' for item in entries),
        },
    }
    OUTPUT.write_text(json.dumps(payload, indent=2) + '\n')


if __name__ == '__main__':
    main()
