# Migration cutover and rollback

This guide describes the decision boundary between the preserved legacy
baseline and a future ChezMoi cutover. It does not authorize a cutover, remove
legacy files, inspect `private`, or change any source mapping.

## Current state

The repository is still in the preparation phase. The root-level dotfiles and
`install.sh` remain the rollback baseline. The ChezMoi source state is safe to
preview in an isolated environment, but routine application and all package or
bootstrap provisioning remain out of scope.

## Cutover readiness record

Do not delete, move, or overwrite a legacy path until a reviewer has recorded
all of the following evidence in the migration approval record:

1. A baseline branch and annotated tag resolve to the same recorded commit and
   are reachable on the configured remote.
2. The migration manifest accounts for every tracked entry, including its
   target, disposition, kind, executable bit, and parity value. Gitlinks,
   symlinks, and other non-regular entries use a documented parity method
   rather than a file-content hash.
3. A full filesystem inventory classifies tracked, untracked, ignored,
   generated, symlink, and nested-repository entries. Unknown entries block
   deletion.
4. Isolated-home tests have captured preview, apply, rerun/idempotency,
   unmanaged-target conflict, externally-modified-target conflict, Linux, and
   WSL evidence without using a real home directory.
5. The secret scan records its scanner, rule version, scope, and any reviewed
   allowlist entries. It must find no private plaintext or key material in the
   indexed migration source.
6. The named approval authority, baseline owner, and rollback custodian have
   approved the record and can retrieve the remote baseline.

The cutover record should bind the baseline commit, manifest, filesystem
inventory, test output, secret-scan result, and approval timestamp with stable
hashes. A missing or mismatched item is a stop condition, not a warning.

## Rollback procedure

If the approved cutover produces an unexpected result, stop further changes.
The rollback custodian verifies the remote baseline branch and annotated tag,
checks out the recorded baseline commit in a recovery worktree, and compares
the affected paths with the recorded manifest before restoring only the
approved repository paths.

Rollback must not run `install.sh`, use ChezMoi force options, install
packages, or write to `$HOME` automatically. Recovering a user home directory
requires a separate, reviewed operation based on the captured dry-run and
backup evidence.

## Evidence handoff

For review, provide links or stable paths to the baseline/tag verification,
manifest parity report, filesystem inventory, isolated-home test report,
secret-scan report, and signed approval record. This makes a later cutover
auditable without treating the documentation itself as approval.
