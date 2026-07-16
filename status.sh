#!/usr/bin/env bash
# Report the repository cutover gate and current ChezMoi drift without writing.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
    echo "status.sh: $*" >&2
    exit 1
}

find_brew() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi

    local candidate
    for candidate in \
        /home/linuxbrew/.linuxbrew/bin/brew \
        "$HOME/.linuxbrew/bin/brew"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

if [[ "$(uname -s)" != "Linux" ]]; then
    die "only Linux and WSL are supported"
fi

brew_bin="$(find_brew || true)"
if [[ -n "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
fi

chezmoi_bin="$(command -v chezmoi || true)"
[[ -n "$chezmoi_bin" ]] || die "chezmoi is required; run ./install.sh first"

"$repo_root/scripts/check-cutover-readiness.py"

status_file="$(mktemp "${TMPDIR:-/tmp}/dotfiles-status.XXXXXX")"
trap 'rm -f "$status_file"' EXIT
"$chezmoi_bin" --source "$repo_root/chezmoi" --destination "$HOME" --no-tty --color=false status >"$status_file"

if [[ -s "$status_file" ]]; then
    echo "ChezMoi drift:"
    cat "$status_file"
else
    echo "ChezMoi status: clean"
fi
