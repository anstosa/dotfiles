#!/usr/bin/env bash
# Validate that the ChezMoi source state remains declarative and migration-safe.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo_root/chezmoi"
manifest="$repo_root/migration/chezmoi-manifest.json"
encrypted_inventory="$repo_root/migration/encrypted-file-inventory.json"
safe_apply="$repo_root/scripts/chezmoi-safe-apply.sh"

test -d "$source_root"
test -f "$manifest"
test -f "$encrypted_inventory"
test -x "$safe_apply"
bash -n "$safe_apply"

if grep -Eq -- '--force|--interactive|--less-interactive' "$safe_apply"; then
    echo "the guarded apply wrapper must not accept ChezMoi overwrite overrides" >&2
    exit 1
fi

grep -q -- '--error-on-conflict apply' "$safe_apply"

if find "$source_root" -name 'run_*' -print -quit | grep -q .; then
    echo "ChezMoi run_ files are forbidden in G003" >&2
    exit 1
fi

if find "$source_root" -type d -name '.chezmoihooks' -print -quit | grep -q .; then
    echo "ChezMoi hooks are forbidden in G003" >&2
    exit 1
fi

if find "$source_root" -name private -print -quit | grep -q .; then
    echo "a target literally named private must not enter the ChezMoi source tree" >&2
    exit 1
fi

# Parse managed Bash scripts without executing them.
bash -n "$source_root/dot_bashrc"
while IFS= read -r -d '' path; do
    if head -n 1 "$path" | grep -q 'bash'; then
        bash -n "$path"
    fi
done < <(find "$source_root" -type f -print0)

python3 - "$repo_root" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
source_root = root / "chezmoi"
manifest = json.loads((root / "migration/chezmoi-manifest.json").read_text())
encrypted_inventory = json.loads(
    (root / "migration/encrypted-file-inventory.json").read_text()
)
assert manifest["schema_version"] == 1
assert encrypted_inventory["schema_version"] == 1
assert encrypted_inventory["encryption"] == "age"
assert isinstance(encrypted_inventory["approved_entries"], list)
assert encrypted_inventory["key_recovery_policy"].strip()
private_gitlink = encrypted_inventory["private_gitlink"]
assert private_gitlink["disposition"] == "deleted-by-owner-without-inspection"
assert private_gitlink["reason"].strip()

for entry in encrypted_inventory["approved_entries"]:
    assert entry["source"].startswith("chezmoi/"), "encrypted source is outside ChezMoi state"
    assert entry["source"].split("/")[-1].startswith("encrypted_"), (
        "approved encrypted source must use ChezMoi encrypted_ attribute"
    )
    assert entry["recipient"].startswith("age1"), "invalid age recipient"

entries = manifest["entries"]
assert any(
    entry["legacy_path"] == "private"
    and entry["disposition"] == "dropped-by-owner-without-inspection"
    for entry in entries
), "private deletion must remain explicitly owner-authorized and uninspected"
assert all(
    child.name == ".chezmoiignore" or not child.name.startswith(".")
    for child in source_root.iterdir()
), "home dotfiles must use ChezMoi dot_ source names"

mapped_sources = []
for entry in entries:
    source = entry.get("chezmoi_source")
    if not source:
        continue
    assert source.startswith("chezmoi/"), f"source is outside source state: {source}"
    path = root / source
    assert path.exists(), f"missing manifest source: {source}"
    assert entry["target"].startswith("~/"), f"non-home target: {entry['target']}"
    if entry.get("executable"):
        assert path.name.startswith(("executable_", "private_executable_")), (
            f"executable source needs ChezMoi executable_ attribute: {source}"
        )
    expected = entry.get("source_sha256")
    if expected:
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        assert actual == expected, f"source hash mismatch: {source}"
    mapped_sources.append(path.relative_to(source_root))

assert len(mapped_sources) == len(set(mapped_sources)), "duplicate ChezMoi source mapping"

# Each source artifact must be covered by exactly one declared source tree or
# individual source entry. .chezmoiignore is policy, not a target mapping.
for source_file in source_root.rglob("*"):
    if not source_file.is_file() or source_file.name == ".chezmoiignore":
        continue
    relative = source_file.relative_to(source_root)
    covering = [
        mapped for mapped in mapped_sources
        if relative == mapped or mapped in relative.parents
    ]
    assert len(covering) == 1, f"unmapped or ambiguously mapped source: {relative}"

print(f"validated {len(mapped_sources)} manifest mappings and source parity")
PY
