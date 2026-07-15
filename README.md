# Ansel's dotfiles

This repository is transitioning from a destructive symlink installer to a
ChezMoi-managed source state for Linux and WSL.

## Current migration status

The legacy files and `install.sh` are preserved as the migration baseline. Do
not run `install.sh`: it overwrites files and installs packages. G002 adds the
non-destructive source state in [`chezmoi/`](chezmoi/) but does not apply it,
delete legacy files, bootstrap packages, or inspect the `private` Gitlink.

Read [the ChezMoi source-state guide](docs/chezmoi-source-state.md) for
initialization, the required dry-run preview, apply prerequisites, Linux/WSL behavior,
private-data policy, isolated validation, and baseline rollback. Package and plugin
installation remains separate and opt-in.

The baseline roles are recorded in
[`migration/migration-roles.json`](migration/migration-roles.json). Legacy deletion
remains blocked until the baseline, manifest, remote verification, and a matching
cutover approval artifact exist.
