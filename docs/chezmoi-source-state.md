# ChezMoi source state

G002 adds a non-destructive ChezMoi source tree under `chezmoi/`. The legacy
files at the repository root remain the baseline and are not moved, deleted, or
rewritten by this change.

## Supported targets

Shared shell, Git, Neovim, tmux, and helper files target Linux and WSL. The
Neovim source was imported from this machine's `~/.config/nvim` after a
credential scan. It replaces the legacy Vim configuration.

The Bash template changes only the `cdhist.sh` helper source location to
`~/.local/share/dotfiles`, where this source state manages it. Its prompt is
the current machine's Debian-style Bash prompt; it has no Powerline dependency.
The tmux source retains existing keybindings while using the current machine's
status-bar presentation.

## Safe preview

Install ChezMoi through your operating system separately. From a clone of this
repository, review the planned changes before applying anything:

```bash
chezmoi --source "$PWD/chezmoi" apply --dry-run --verbose
```

The only supported apply command for this migration is the guarded wrapper:

```bash
scripts/chezmoi-safe-apply.sh
```

It derives managed targets from `chezmoi/` and refuses any existing managed
target that does not appear in ChezMoi's persistent state. This prevents a
first apply from silently adopting an existing file, symlink, or managed
directory. For targets ChezMoi previously wrote, it delegates to
`chezmoi --error-on-conflict apply`; externally modified targets therefore
remain unchanged and fail instead of being overwritten. The wrapper accepts no
arguments and never passes force or interactive override options. Set
`CHEZMOI_BIN`, `CHEZMOI_SOURCE`, `CHEZMOI_DESTINATION`, `CHEZMOI_CONFIG`, and
`CHEZMOI_STATE` only for an isolated/recovery environment.

Applying is a later cutover step after the isolated-home safety checks and
approval evidence are complete. The required evidence and rollback boundary
are documented in [the migration cutover and rollback guide](migration-cutover-and-rollback.md).

## Explicit exclusions

The source contains no `run_` scripts, hooks, package installation, bootstrap
commands, or encrypted private content. i3, legacy Vim, tmuxinator, Powerline,
diff-highlight, Font Awesome, and the old fonts source are intentionally absent.
The `private` Gitlink is not inspected or migrated. The fzf Gitlink and old
destructive `install.sh` remain in the legacy tree pending their final cutover
dispositions.

Run the static policy check without touching `$HOME`:

```bash
scripts/validate-chezmoi-source-state.sh
```

The validator also checks the versioned age policy, including the blocked
`private` Gitlink. Its companion mutation test proves that changing a migrated
source artifact is rejected against the manifest's recorded digest:

```bash
scripts/test-source-manifest-mutation.sh
```

Run the isolated fixture suite only after installing ChezMoi separately. It creates a
temporary home, all XDG directories, ChezMoi state, and `TMPDIR`; it never reads or
writes your actual home directory. Set `CHEZMOI_BIN` to test a non-default binary.

```bash
CHEZMOI_BIN=chezmoi scripts/test-chezmoi-fixture.sh
```

The fixture requires the preview to leave the temporary destination unchanged, tests
an empty-home guarded apply and rerun, and proves that unmanaged `.bashrc` is rejected
by the wrapper before ChezMoi runs while externally modified `.bashrc` remains unchanged
through ChezMoi's conflict error. It also asserts that removed i3, Vim, Powerline, and
diff-highlight targets are not created. Run it on both platforms before cutover.

## Private data and recovery

`migration/encrypted-file-inventory.json` is the approved encrypted-file inventory.
It is deliberately empty for this release: no private material is in the source tree.
When a future entry is approved, it must be age-encrypted and its recipient recorded
in that inventory; age identities and recovery material must stay outside Git. The
orphan `private` Gitlink remains blocked until its provenance and disposition are
recorded.
