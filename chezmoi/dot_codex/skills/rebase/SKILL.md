---
name: rebase
description: Rebase the current Git branch onto another branch. Use when the user invokes $rebase or asks Codex to rebase from a target branch; if no branch is provided, fetch origin and rebase onto origin/main, ask before rebasing pushed commits, and at the end check for conflicting Flyway migration numbers and resolve them.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Rebase

Use this skill to rebase the current branch onto a target branch and complete the rebase when conflicts arise.

## Workflow

1. Inspect the repository before starting.
   - Run `git status --short --branch`.
   - If a merge is already in progress (`test -f .git/MERGE_HEAD`) or a rebase is already in progress (`test -d .git/rebase-merge || test -d .git/rebase-apply`), do not start a new rebase. Invoke `$resolve` for the existing operation instead.
   - If the working tree has unstaged, staged, or untracked changes unrelated to the requested rebase, stop and ask the user before proceeding. Do not stash, discard, or commit those changes unless explicitly requested.

2. Choose the rebase target.
   - If the user provided a branch or ref, treat it as the target branch.
   - Run `git fetch origin` before resolving the target, whether the user provided a target or not.
   - If no target was provided, use `origin/main` as the target.
   - For a provided target, prefer the exact ref the user gave. If it is an unqualified branch name and `origin/<branch>` clearly exists after fetching, ask before substituting the remote-tracking ref for the local branch.
   - If the target cannot be resolved with `git rev-parse --verify`, stop and report the missing ref.

3. Check whether the rebase would rewrite pushed history.
   - Look up the current branch's upstream with `git rev-parse --abbrev-ref --symbolic-full-name @{u}`.
   - If there is no upstream, continue without this confirmation gate.
   - If the upstream is an `origin/*` remote-tracking branch, run `git fetch origin` before evaluating pushed-history risk.
   - If the upstream is from another remote, ask before fetching that remote. If the user does not approve fetching it, make the pushed-history check against the local upstream ref and explain that the remote state may be stale.
   - If there is an upstream, identify the commits Git would replay with `git merge-base HEAD <target>` followed by `git rev-list <merge-base>..HEAD`.
   - If any commit in that replay range is already reachable from the upstream (`git merge-base --is-ancestor <commit> @{u}` succeeds), stop and ask the user to confirm before rebasing. Explain that the rebase will rewrite commits that have already been pushed and the branch will diverge from its upstream until it is force-pushed or otherwise reconciled.
   - If the user does not explicitly confirm, do not start the rebase.

4. Start the rebase.
   - Run `git rebase <target>`.
   - Do not pass strategy options such as `--rebase-merges`, `--autosquash`, `--onto`, `--ours`, `--theirs`, or `-X` unless the user explicitly requested them.
   - Preserve Git's default commit messages unless the user requested edits.

5. If conflicts occur, invoke `$resolve`.
   - Detect conflicts from the rebase output or `git status --short --branch` showing unmerged paths.
   - Load and follow the `$resolve` skill immediately.
   - Resolve conflict markers carefully, ask the user when intent is unclear, stage resolved files, continue the rebase, and fix any pre-commit issues raised by the continuation.

6. Check for conflicting Flyway migration numbers.
   - Run this check after `$resolve` completes or after a clean rebase, before reporting success.
   - Find Flyway migration files with `git ls-files | rg '(^|/)(db/)?migration(s)?/.*V[0-9][0-9_.]*__.*\.sql$|(^|/)V[0-9][0-9_.]*__.*\.sql$'` and inspect the `V<number>__` prefix.
   - Compare migration numbers within the same migration directory; independent modules or directories may each have their own sequence.
   - If two or more migration files in the same sequence use the same `V<number>__` prefix, resolve the conflict by renumbering the migration file from the current branch to the next available migration number in that directory unless repository conventions clearly require a different sequence.
   - Preserve each migration description after `__`, update only filename references required by the rename, and use `git mv` for tracked migration files.
   - If the conflicting migration is not attributable to the current branch or the safe renumbering choice is unclear, invoke `$resolve` or ask the user before renaming.
   - If Git has already completed the operation and the rename must be committed, commit or amend only when that action affects the just-completed operation; otherwise ask before rewriting existing commits.

7. If the rebase completes without conflicts, validate the result.
   - Run `git status --short --branch`.
   - If Git hooks or pre-commit checks fail, inspect the output, fix concrete issues, stage the fixes, and retry the rebase continuation command as appropriate.
   - Run only targeted validation that is practical for the touched area unless the user requested broader checks.

8. Report the outcome.
   - State the target used for the rebase.
   - State whether pushed-history confirmation was required and whether the user approved it.
   - State whether conflicts occurred and whether `$resolve` was used.
   - Mention whether the Flyway migration-number check found conflicts and how they were resolved.
   - Mention any pre-commit or validation checks that ran and their result.

## Guardrails

- Never run `git rebase --abort`, `git reset`, discard files, or stash user work unless explicitly requested.
- Never start a rebase on top of an unresolved merge or rebase.
- Never rewrite commits already reachable from the branch upstream without explicit user confirmation.
- Never guess through conflicts; delegate to `$resolve` and ask the user if the intended resolution is unclear.
- Never fetch from or rebase onto a remote other than `origin` unless the user explicitly provides or approves it.
- Never leave duplicate Flyway `V<number>__` migration prefixes after a successful rebase when they can be safely resolved.
