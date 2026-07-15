# ChezMoi source state

G002 adds a non-destructive ChezMoi source tree under `chezmoi/`. The legacy
files at the repository root remain the baseline and are not moved, deleted, or
rewritten by this change.

## Supported targets

Shared shell, Git, editor, tmux, Powerline, and helper files target Linux and
WSL. The `.i3` source tree targets Linux only. Its source is retained on WSL,
but `.chezmoiignore` excludes it when the Linux kernel release identifies WSL.

The Bash template changes only the two helper source locations to
`~/.local/share/dotfiles`, where this source state manages them. The
`diff-highlight` executable is a managed file at `~/.local/bin/diff-highlight`;
it is not an executable ChezMoi action.

## Safe preview

Install ChezMoi through your operating system separately. From a clone of this
repository, initialize the source root and review the planned changes before
applying anything:

```bash
chezmoi init --source "$PWD/chezmoi"
chezmoi apply --dry-run --verbose
```

Do not use force options during this migration. Applying is a later cutover
step after the isolated-home safety checks and approval evidence are complete.

## Explicit exclusions

G002 contains no `run_` scripts, hooks, package installation, bootstrap
commands, or encrypted private content. The `private` Gitlink is not inspected
or migrated. Plugin Gitlinks and the old destructive `install.sh` remain in the
legacy tree and are recorded as deferred in the migration manifest.

Run `scripts/validate-chezmoi-source-state.sh` to check source mappings,
platform rules, and the no-automation policy without touching `$HOME`.
