#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo_root/chezmoi"
manifest="$repo_root/migration/chezmoi-manifest.json"

test -d "$source_root"
test -f "$manifest"

if find "$source_root" -name 'run_*' -print -quit | grep -q .; then
    echo "ChezMoi run_ files are forbidden in G002" >&2
    exit 1
fi

if find "$source_root" -type d -name '.chezmoihooks' -print -quit | grep -q .; then
    echo "ChezMoi hooks are forbidden in G002" >&2
    exit 1
fi

if find "$source_root" -path '*/private*' -print -quit | grep -q .; then
    echo "private content must not enter the ChezMoi source tree" >&2
    exit 1
fi

python3 - "$repo_root" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
source_root = root / "chezmoi"
manifest = json.loads((root / "migration/chezmoi-manifest.json").read_text())
assert manifest["schema_version"] == 1
entries = manifest["entries"]
assert any(e["legacy_path"] == "private" and e["disposition"] == "blocked-not-inspected" for e in entries)
assert all(
    child.name == ".chezmoiignore" or not child.name.startswith(".")
    for child in source_root.iterdir()
), "home dotfiles must use ChezMoi dot_ source names"

for entry in entries:
    source = entry.get("chezmoi_source")
    if not source:
        continue
    path = root / source
    assert path.exists(), f"missing manifest source: {source}"
    assert entry["target"].startswith("~/"), f"non-home target: {entry['target']}"
    expected = entry.get("source_sha256")
    if expected:
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        assert actual == expected, f"source hash mismatch: {source}"

ignore = (root / "chezmoi/.chezmoiignore").read_text()
assert ".chezmoi.kernel.osrelease" in ignore
assert ".i3" in ignore
print(f"validated {sum('chezmoi_source' in e for e in entries)} source mappings")
PY
