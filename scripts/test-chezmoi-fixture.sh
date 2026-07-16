#!/usr/bin/env bash
# Exercise the managed source state without reading or writing the caller's home.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo_root/chezmoi"
chezmoi_bin="${CHEZMOI_BIN:-chezmoi}"
safe_apply="$repo_root/scripts/chezmoi-safe-apply.sh"

if ! command -v "$chezmoi_bin" >/dev/null 2>&1; then
    echo "chezmoi is required; install it separately or set CHEZMOI_BIN" >&2
    exit 127
fi

fixture="$(mktemp -d "${TMPDIR:-/tmp}/chezmoi-fixture.XXXXXX")"
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT

export HOME="$fixture/home"
export XDG_CONFIG_HOME="$fixture/config"
export XDG_DATA_HOME="$fixture/data"
export XDG_CACHE_HOME="$fixture/cache"
export TMPDIR="$fixture/tmp"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$TMPDIR"

state="$fixture/chezmoi-state.boltdb"
config="$fixture/chezmoi.toml"
common=(--source "$source_root" --destination "$HOME" --config "$config" --persistent-state "$state" --no-tty --color=false)
run_chezmoi() { "$chezmoi_bin" "${common[@]}" "$@"; }
run_safe_apply() {
    CHEZMOI_BIN="$chezmoi_bin" \
    CHEZMOI_SOURCE="$source_root" \
    CHEZMOI_DESTINATION="$HOME" \
    CHEZMOI_CONFIG="$config" \
    CHEZMOI_STATE="$state" \
    "$safe_apply"
}

# Preview is required before application and must not mutate the destination.
run_chezmoi --dry-run --verbose apply >"$fixture/dry-run.log"
test ! -e "$HOME/.bashrc"

audit_apply() {
    run_safe_apply >"$fixture/apply.log"
    test -f "$HOME/.bashrc"
    test -f "$HOME/.config/powerline/config.json"
    test -x "$HOME/.local/bin/diff-highlight"
    test -L "$HOME/.vim/init.vim"

    if grep -qi microsoft /proc/sys/kernel/osrelease; then
        test ! -e "$HOME/.i3"
    else
        test -f "$HOME/.i3/config"
    fi
}

audit_apply

# A second application must be idempotent and must not run automation.
run_chezmoi --dry-run --verbose apply >"$fixture/rerun.log"
if grep -Eq '^(A|M|D|R|C|\?) ' "$fixture/rerun.log"; then
    echo "unexpected changes after second apply" >&2
    cat "$fixture/rerun.log" >&2
    exit 1
fi

# An unmanaged target must be rejected before ChezMoi attempts to apply it.
rm -rf "$HOME" "$state"
mkdir -p "$HOME"
printf 'unmanaged target\n' >"$HOME/.bashrc"
unmanaged_hash="$(sha256sum "$HOME/.bashrc" | awk '{print $1}')"
if run_safe_apply >"$fixture/unmanaged-conflict.log" 2>&1; then
    echo "unmanaged target was unexpectedly accepted by the safety wrapper" >&2
    exit 1
fi
grep -q 'refusing existing unmanaged ChezMoi target' "$fixture/unmanaged-conflict.log"
test "$unmanaged_hash" = "$(sha256sum "$HOME/.bashrc" | awk '{print $1}')"

# A target changed after management must reach ChezMoi's conflict detector and
# remain untouched. It is not treated as an unmanaged first-apply target.
rm -rf "$HOME" "$state"
mkdir -p "$HOME"
audit_apply
printf '\nexternal change\n' >>"$HOME/.bashrc"
modified_hash="$(sha256sum "$HOME/.bashrc" | awk '{print $1}')"
if run_safe_apply >"$fixture/modified-conflict.log" 2>&1; then
    echo "externally modified target was unexpectedly accepted" >&2
    exit 1
fi
if grep -q 'refusing existing unmanaged ChezMoi target' "$fixture/modified-conflict.log"; then
    echo "a previously managed target was mistaken for an unmanaged target" >&2
    exit 1
fi
test "$modified_hash" = "$(sha256sum "$HOME/.bashrc" | awk '{print $1}')"

printf 'PASS: isolated chezmoi dry-run, guarded apply, conflict, idempotency, and platform checks\n'
