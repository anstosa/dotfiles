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
The required evidence and rollback boundary are documented in
[the migration cutover and rollback guide](migration-cutover-and-rollback.md).

## Explicit exclusions

G002 contains no `run_` scripts, hooks, package installation, bootstrap
commands, or encrypted private content. The `private` Gitlink is not inspected
or migrated. Plugin Gitlinks and the old destructive `install.sh` remain in the
legacy tree and are recorded as deferred in the migration manifest.

Run the static policy check without touching `$HOME`:

```bash
scripts/validate-chezmoi-source-state.sh
```

Run the isolated fixture suite only after installing ChezMoi separately. It creates a
temporary home, all XDG directories, ChezMoi state, and `TMPDIR`; it never reads or
writes your actual home directory. Set `CHEZMOI_BIN` to test a non-default binary.

```bash
CHEZMOI_BIN=chezmoi scripts/test-chezmoi-fixture.sh
```

The fixture requires the preview to leave the temporary destination unchanged, tests
an empty-home apply and rerun, and proves that both unmanaged and externally modified
`.bashrc` targets remain unchanged when ChezMoi is run noninteractively with conflict
errors. It also checks the actual platform predicate: i3 is omitted on WSL and
included on ordinary Linux. Run it on both platforms before cutover.

## Private data and recovery

`migration/encrypted-file-inventory.json` is the approved encrypted-file inventory.
It is deliberately empty for this release: no private material is in the source tree.
When a future entry is approved, it must be age-encrypted and its recipient recorded
in that inventory; age identities and recovery material must stay outside Git. The
orphan `private` Gitlink remains blocked until its provenance and disposition are
recorded.
