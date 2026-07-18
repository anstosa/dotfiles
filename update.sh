#!/usr/bin/env bash
# Update Homebrew/ChezMoi and this checkout, then use the guarded installer.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

find_brew() {
    if command -v brew >/dev/null 2>&1; then
        command -v brew
        return 0
    fi

    local candidate
    for candidate in \
        /opt/homebrew/bin/brew \
        /usr/local/bin/brew \
        /home/linuxbrew/.linuxbrew/bin/brew \
        "$HOME/.linuxbrew/bin/brew"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

case "$(uname -s)" in
    Darwin|Linux) ;;
    *)
        echo "update.sh: only macOS, Linux, and WSL are supported" >&2
        exit 1
        ;;
esac

git -C "$repo_root" pull --ff-only

brew_bin="$(find_brew || true)"

if [[ -n "$brew_bin" ]]; then
    eval "$("$brew_bin" shellenv)"
    brew update
    if brew list --formula chezmoi >/dev/null 2>&1; then
        brew upgrade chezmoi
    fi
fi

exec "$repo_root/install.sh"
