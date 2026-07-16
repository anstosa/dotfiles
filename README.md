# Ansel's dotfiles

This repository is transitioning from a destructive symlink installer to a
ChezMoi-managed source state for Linux and WSL.

## Current migration status

The legacy dotfiles are preserved as the migration baseline. The root
[`install.sh`](install.sh) is now the explicit bootstrap entry point: it
installs Homebrew and ChezMoi when absent, validates the source, runs the
isolated fixture, previews the change, and invokes the guarded apply wrapper.
It does not force or silently overwrite a target. The former `private` Gitlink
was removed without inspection at the repository owner's direction.

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

To update an installed machine, use the update wrapper. It fast-forwards this
checkout, updates Homebrew and ChezMoi when available, then runs the same
validated, guarded installation flow:

```bash
./update.sh
```

Do not invoke `chezmoi apply --force` or a direct apply for this repository.

## New machine

Clone a revision that contains the published commits, then run:

```bash
./install.sh
```

When Homebrew is absent, the script downloads and runs Homebrew's official
installer, initializes its shell environment for the script, and installs
ChezMoi through Homebrew. It then performs source validation, an isolated
fixture test, and a dry-run before the guarded apply. Package installation is
therefore explicit to `install.sh`/`update.sh`; ordinary ChezMoi applies and
the guarded apply wrapper never install packages.

The guarded command refuses any existing unmanaged target instead of adopting
or overwriting it. On a machine that already has `.bashrc`, `.config/nvim`, or
`.codex/skills`, preserve and review those paths first, then resolve each
conflict deliberately. Never bypass the refusal with a force option.
