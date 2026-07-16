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

## Change and update workflow

Edit files under [`chezmoi/`](chezmoi/), not the installed files in `$HOME`.
Then validate the source, run the isolated fixture, review the preview, and
commit and publish the change:

```bash
scripts/validate-chezmoi-source-state.sh
CHEZMOI_BIN=chezmoi scripts/test-chezmoi-fixture.sh
chezmoi --source "$PWD/chezmoi" --destination "$HOME" apply --dry-run --verbose
git add chezmoi migration scripts docs README.md
git commit -m 'type(dotfiles): describe the change'
git push
```

To update an installed machine, pull the repository, repeat the validation and
preview, then use the guarded apply command:

```bash
git pull --ff-only
scripts/validate-chezmoi-source-state.sh
chezmoi --source "$PWD/chezmoi" --destination "$HOME" apply --dry-run --verbose
scripts/chezmoi-safe-apply.sh
```

Do not invoke `chezmoi apply --force` or a direct apply for this repository.

## New machine

Install ChezMoi through the operating system's normal package-management path;
this repository never installs packages automatically. Clone a revision that
contains the published commits, then run the source validator, the isolated
fixture, and a dry-run before the guarded apply command shown above.

The guarded command refuses any existing unmanaged target instead of adopting
or overwriting it. On a machine that already has `.bashrc`, `.config/nvim`, or
`.codex/skills`, preserve and review those paths first, then resolve each
conflict deliberately. Never bypass the refusal with a force option.
