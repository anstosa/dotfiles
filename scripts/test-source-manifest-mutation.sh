#!/usr/bin/env bash
# Prove that the parity validator rejects a changed migrated source artifact.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-manifest-mutation.XXXXXX")"
cleanup() { rm -rf "$fixture"; }
trap cleanup EXIT

# Copy only the validator's inputs. The temporary copy prevents mutation of
# the repository or the caller's home while including uncommitted test edits.
cp -a "$repo_root/chezmoi" "$repo_root/migration" "$repo_root/scripts" "$fixture/"

printf '\n# mutation fixture\n' >>"$fixture/chezmoi/dot_gitconfig"
if "$fixture/scripts/validate-chezmoi-source-state.sh" >"$fixture/result.log" 2>&1; then
    echo "manifest parity validator accepted a mutated source" >&2
    exit 1
fi
grep -q 'source hash mismatch' "$fixture/result.log"

printf 'PASS: manifest parity validator rejects a mutated source artifact\n'
