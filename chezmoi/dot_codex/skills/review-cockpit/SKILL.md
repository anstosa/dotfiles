---
name: review-cockpit
description: Generate local review artifacts for Ansel's guided Neovim review cockpit.
---

# Review Cockpit Skill

Use this skill to prepare deterministic, local-only review artifacts for `ReviewCockpit`.

## Command

```bash
python3 ~/.codex/skills/review-cockpit/scripts/generate_review_artifact.py --base BASE --print-json
```

`BASE` is optional. When omitted, the generator uses the same fallback order as the Neovim command: `origin/main`, `origin/master`, `main`, `master`, then `HEAD~1`.

## Output

The script writes runtime artifacts under `<git-root>/.git/review-cockpit/` by default:

- timestamped schema-version-1 JSON
- matching Markdown guide
- `latest.json` symlink, with copy fallback when symlinks fail
- progress sidecar path reserved for Neovim
- pathspec and excluded-pathspec metadata matching the working-tree Diffview command
- committed, staged, unstaged, and untracked working-tree contents
- guide-first navigation with Tab/Shift-Tab sections and F12 focused file Diffview
- per-file inline review notes and focused diff excerpts for optional Neovim virtual-line display

If `.git/review-cockpit/` is not writable, it falls back to `$XDG_STATE_HOME/review-cockpit/<repo-hash>/` or `~/.local/state/review-cockpit/<repo-hash>/`.

## Boundaries

- No GitHub writes
- No source edits
- No live AI calls from Neovim
- No Octo dependency

The generated guide is advisory. The Diffview diff remains the source of truth.
Diffview opens only when the reviewer presses F12 on a file section.
The shell `review` helper logs each step, regenerates structured data first, then opens Neovim.
