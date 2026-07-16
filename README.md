# Ansel's dotfiles

This repository is transitioning from a destructive symlink installer to a
ChezMoi-managed source state for Linux and WSL.

## Current migration status

The legacy files and `install.sh` are preserved as the migration baseline. Do
not run `install.sh`: it overwrites files and installs packages. G002 adds the
non-destructive source state in [`chezmoi/`](chezmoi/) but does not apply it,
delete remaining legacy files or bootstrap packages. The former `private`
Gitlink was removed without inspection at the repository owner's direction.

Read [the ChezMoi source-state guide](docs/chezmoi-source-state.md) for the
platform rules, preview command, exclusions, and validation command.

Read [the migration cutover and rollback guide](docs/migration-cutover-and-rollback.md)
for the evidence required before any destructive migration step and the
non-destructive rollback boundary.
