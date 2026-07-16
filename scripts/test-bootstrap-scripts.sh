#!/usr/bin/env bash
# Static policy checks for the explicit Homebrew bootstrap scripts.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for script in "$repo_root/install.sh" "$repo_root/update.sh"; do
    test -x "$script"
    bash -n "$script"
done

grep -q 'Homebrew/install/HEAD/install.sh' "$repo_root/install.sh"
grep -q 'brew install chezmoi' "$repo_root/install.sh"
grep -q 'scripts/chezmoi-safe-apply.sh' "$repo_root/install.sh"
grep -q 'git -C .* pull --ff-only' "$repo_root/update.sh"
grep -q 'brew upgrade chezmoi' "$repo_root/update.sh"

if grep -Eq -- 'chezmoi .*apply .*--force|chezmoi .*--force .*apply' "$repo_root/install.sh" "$repo_root/update.sh"; then
    echo "bootstrap scripts must not force ChezMoi overwrites" >&2
    exit 1
fi

printf 'PASS: bootstrap scripts use Homebrew and guarded ChezMoi apply\n'
