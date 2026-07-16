#!/usr/bin/env bash
# Install Homebrew and ChezMoi when needed, then apply this repository safely.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() {
    echo "install.sh: $*" >&2
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
if [[ -z "$brew_bin" ]]; then
    command -v curl >/dev/null 2>&1 || die "curl is required to install Homebrew"
    echo "Homebrew is not installed; running its official installer."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew_bin="$(find_brew || true)"
    [[ -n "$brew_bin" ]] || die "Homebrew installer completed but brew was not found"
fi

eval "$("$brew_bin" shellenv)"

if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Installing ChezMoi with Homebrew."
    brew install chezmoi
fi

chezmoi_bin="$(command -v chezmoi)"
"$repo_root/scripts/validate-chezmoi-source-state.sh"
CHEZMOI_BIN="$chezmoi_bin" "$repo_root/scripts/test-chezmoi-fixture.sh"
"$chezmoi_bin" --source "$repo_root/chezmoi" --destination "$HOME" apply --dry-run --verbose
"$repo_root/scripts/chezmoi-safe-apply.sh"
