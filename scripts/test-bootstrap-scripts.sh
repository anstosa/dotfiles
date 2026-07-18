#!/usr/bin/env bash
# Static policy checks for the explicit Homebrew bootstrap scripts.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for script in "$repo_root/install.sh" "$repo_root/update.sh" "$repo_root/status.sh"; do
    test -x "$script"
    bash -n "$script"
done

grep -q 'Homebrew/install/HEAD/install.sh' "$repo_root/install.sh"
grep -q 'brew install chezmoi' "$repo_root/install.sh"
grep -q 'scripts/chezmoi-safe-apply.sh' "$repo_root/install.sh"
grep -q 'git -C .* pull --ff-only' "$repo_root/update.sh"
grep -q 'brew upgrade chezmoi' "$repo_root/update.sh"
grep -q 'check-cutover-readiness.py' "$repo_root/status.sh"
grep -q 'ChezMoi status: clean' "$repo_root/status.sh"

for script in "$repo_root/install.sh" "$repo_root/update.sh" "$repo_root/status.sh"; do
    grep -Eq 'Darwin\|Linux|Linux\|Darwin' "$script"
    grep -q '/opt/homebrew/bin/brew' "$script"
    grep -q '/usr/local/bin/brew' "$script"
done

if grep -Eq -- 'chezmoi .*apply .*--force|chezmoi .*--force .*apply' "$repo_root/install.sh" "$repo_root/update.sh" "$repo_root/status.sh"; then
    echo "bootstrap scripts must not force ChezMoi overwrites" >&2
    exit 1
fi

printf 'PASS: macOS/Linux bootstrap scripts use Homebrew and guarded ChezMoi apply\n'
