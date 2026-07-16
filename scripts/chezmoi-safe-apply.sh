#!/usr/bin/env bash
# Apply this repository's ChezMoi source without adopting existing targets.
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

# `managed` derives the target set from the source tree. `state dump` records
# precisely the targets ChezMoi has previously written. Refuse an existing
# managed target that is absent from that state rather than silently adopting
# it during the first apply.
"$chezmoi_bin" "${common[@]}" managed >"$work_dir/managed"
"$chezmoi_bin" "${common[@]}" state dump >"$work_dir/state.json"

python3 - "$destination" "$work_dir/managed" "$work_dir/state.json" <<'PY'
import json
import os
import sys
from pathlib import Path

destination = Path(sys.argv[1]).expanduser().resolve(strict=False)
managed = Path(sys.argv[2]).read_text().splitlines()
state = json.loads(Path(sys.argv[3]).read_text())
managed_state = {Path(path).resolve(strict=False) for path in state.get("entryState", {})}
unmanaged = []

for relative in managed:
    if not relative:
        continue
    target = (destination / relative).resolve(strict=False)
    try:
        target.relative_to(destination)
    except ValueError as error:
        raise SystemExit(f"managed target escapes destination: {relative}") from error
    if os.path.lexists(target) and target not in managed_state:
        unmanaged.append(target)

if unmanaged:
    print(
        "refusing existing unmanaged ChezMoi target(s); "
        "review or migrate them explicitly before applying:",
        file=sys.stderr,
    )
    for target in unmanaged:
        print(f"  {target}", file=sys.stderr)
    raise SystemExit(3)
PY

# Never accept force or interactive overrides in this wrapper. Targets that
# ChezMoi previously wrote still use its conflict detector, so local changes
# remain untouched and produce a non-zero result instead of an overwrite.
exec "$chezmoi_bin" "${common[@]}" --error-on-conflict apply
