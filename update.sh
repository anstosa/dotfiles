#!/usr/bin/env bash
# Update Homebrew/ChezMoi and this checkout, then use the guarded installer.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" != "Linux" ]]; then
    echo "update.sh: only Linux and WSL are supported" >&2
    exit 1
fi

git -C "$repo_root" pull --ff-only

brew_bin="$(command -v brew || true)"
if [[ -z "$brew_bin" && -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    brew_bin=/home/linuxbrew/.linuxbrew/bin/brew
fi

if [[ -n "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
    brew update
    if brew list --formula chezmoi >/dev/null 2>&1; then
        brew upgrade chezmoi
    fi
fi

exec "$repo_root/install.sh"
