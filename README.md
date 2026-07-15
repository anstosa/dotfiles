# Ansel's dotfiles

This repository is transitioning from a destructive symlink installer to a
ChezMoi-managed source state for Linux and WSL.

## Current migration status

The legacy files and `install.sh` are preserved as the migration baseline. Do
not run `install.sh`: it overwrites files and installs packages. G002 adds the
non-destructive source state in [`chezmoi/`](chezmoi/) but does not apply it,
delete legacy files, bootstrap packages, or inspect the `private` Gitlink.

Read [the ChezMoi source-state guide](docs/chezmoi-source-state.md) for the
platform rules, preview command, exclusions, and validation command.
