#!/usr/bin/env bash
# Apply this repository's ChezMoi source without replacing differing targets.
set -euo pipefail

if (( $# != 0 )); then
    echo "usage: $0" >&2
    echo "configure CHEZMOI_{BIN,SOURCE,DESTINATION,CONFIG,STATE} with the environment" >&2
    exit 64
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
chezmoi_bin="${CHEZMOI_BIN:-chezmoi}"
source_root="${CHEZMOI_SOURCE:-$repo_root/chezmoi}"
destination="${CHEZMOI_DESTINATION:-$HOME}"

if ! command -v "$chezmoi_bin" >/dev/null 2>&1; then
    echo "chezmoi is required; install it separately or set CHEZMOI_BIN" >&2
    exit 127
fi

if [[ ! -d "$source_root" ]]; then
    echo "ChezMoi source directory does not exist: $source_root" >&2
    exit 66
fi

common=(--source "$source_root" --destination "$destination" --no-tty --color=false)
if [[ -n "${CHEZMOI_CONFIG:-}" ]]; then
    common+=(--config "$CHEZMOI_CONFIG")
fi
if [[ -n "${CHEZMOI_STATE:-}" ]]; then
    common+=(--persistent-state "$CHEZMOI_STATE")
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-safe-apply.XXXXXX")"
cleanup() { rm -rf "$work_dir"; }
trap cleanup EXIT

# `state dump` records precisely the targets ChezMoi has previously written.
# On a first apply, accept existing files only when their bytes already match
# this source state. This permits an explicit, no-content-change migration of
# the current machine while refusing every differing target.
"$chezmoi_bin" "${common[@]}" managed >"$work_dir/managed"
"$chezmoi_bin" "${common[@]}" state dump >"$work_dir/state.json"

python3 - "$destination" "$source_root" "$work_dir/state.json" <<'PY'
import json
import os
import sys
from pathlib import Path

destination = Path(sys.argv[1]).expanduser().resolve(strict=False)
source_root = Path(sys.argv[2]).resolve()
state = json.loads(Path(sys.argv[3]).read_text())
managed_state = {Path(path).absolute() for path in state.get("entryState", {})}


def target_name(name: str) -> str:
    for prefix in ("private_", "executable_", "dot_"):
        if name.startswith(prefix):
            return target_name(name[len(prefix):]) if prefix != "dot_" else "." + name[len(prefix):]
    return name


def target_path(source: Path) -> Path:
    relative = source.relative_to(source_root)
    target = destination.joinpath(*(target_name(part) for part in relative.parts))
    try:
        target.relative_to(destination)
    except ValueError as error:
        raise SystemExit(f"managed target escapes destination: {relative}") from error
    return target


expected_files = [path for path in source_root.rglob("*") if path.is_file()]
conflicts: set[Path] = set()

for source in expected_files:
    target = target_path(source)
    if not os.path.lexists(target) or target.absolute() in managed_state:
        continue
    if not target.is_file() or source.read_bytes() != target.read_bytes():
        conflicts.add(target)

# A directory symlink would be replaced by ChezMoi. Accept it only when its
# complete visible file tree is exactly the managed source tree, so no extra
# active configuration disappears during the structural migration.
for source_dir in [path for path in source_root.rglob("*") if path.is_dir()]:
    target_dir = target_path(source_dir)
    if not target_dir.is_symlink() or not target_dir.is_dir():
        continue
    expected = {
        target_path(source).relative_to(target_dir).as_posix()
        for source in expected_files
        if target_dir in target_path(source).parents
    }
    actual = {
        relative.as_posix()
        for directory, _, files in os.walk(target_dir, followlinks=True)
        for name in files
        for relative in [(Path(directory) / name).relative_to(target_dir)]
        if not relative.parts or relative.parts[0] != ".omx"
    }
    if actual != expected:
        conflicts.add(target_dir)

if conflicts:
    print(
        "refusing existing ChezMoi target(s) that differ from the source; "
        "review or migrate them explicitly before applying:",
        file=sys.stderr,
    )
    for target in sorted(conflicts):
        print(f"  {target}", file=sys.stderr)
    raise SystemExit(3)
PY

# Never accept force or interactive overrides in this wrapper. Targets that
# ChezMoi previously wrote still use its conflict detector, so local changes
# remain untouched and produce a non-zero result instead of an overwrite.
exec "$chezmoi_bin" "${common[@]}" --error-on-conflict apply
