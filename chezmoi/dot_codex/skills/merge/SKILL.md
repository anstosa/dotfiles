---
name: merge
description: Merge another branch into the current Git branch. Use when the user invokes $merge or asks Codex to merge from a target branch; if no branch is provided, fetch origin and merge origin/main, if conflicts occur invoke $resolve, and at the end check for conflicting Flyway migration numbers and resolve them.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Merge

Use this skill to merge a target branch into the current branch and complete the merge when conflicts arise.

## Workflow

1. Inspect the repository before starting.
   - Run `git status --short --branch`.
   - If a merge is already in progress (`test -f .git/MERGE_HEAD`) or a rebase is already in progress (`test -d .git/rebase-merge || test -d .git/rebase-apply`), do not start a new merge. Invoke `$resolve` for the existing operation instead.
   - If the working tree has unstaged, staged, or untracked changes unrelated to the requested merge, stop and ask the user before proceeding. Do not stash, discard, or commit those changes unless explicitly requested.

2. Choose the merge target.
   - If the user provided a branch or ref, treat it as the target branch.
   - Run `git fetch origin` before resolving the target, whether the user provided a target or not.
   - If no target was provided, use `origin/main` as the target.
   - For a provided target, prefer the exact ref the user gave. If it is an unqualified branch name and `origin/<branch>` clearly exists after fetching, ask before substituting the remote-tracking ref for the local branch.
   - If the target cannot be resolved with `git rev-parse --verify`, stop and report the missing ref.

3. Start the merge.
   - Run `git merge <target>`.
   - Do not pass strategy options such as `--ours`, `--theirs`, or `-X` unless the user explicitly requested them.
   - Preserve Git's default merge message unless the user requested a custom message.

4. If conflicts occur, invoke `$resolve`.
   - Detect conflicts from the merge output or `git status --short --branch` showing unmerged paths.
   - Load and follow the `$resolve` skill immediately.
   - Resolve conflict markers carefully, ask the user when intent is unclear, stage resolved files, continue the merge, and fix any pre-commit issues raised by the continuation.

5. Check for conflicting Flyway migration numbers.
   - Run this check after `$resolve` completes or after a clean merge, before reporting success.
   - Find Flyway migration files with `git ls-files | rg '(^|/)(db/)?migration(s)?/.*V[0-9][0-9_.]*__.*\.sql$|(^|/)V[0-9][0-9_.]*__.*\.sql$'` and inspect the `V<number>__` prefix.
   - Compare migration numbers within the same migration directory; independent modules or directories may each have their own sequence.
   - If two or more migration files in the same sequence use the same `V<number>__` prefix, resolve the conflict by renumbering the migration file from the current branch to the next available migration number in that directory unless repository conventions clearly require a different sequence.
   - Preserve each migration description after `__`, update only filename references required by the rename, and use `git mv` for tracked migration files.
   - If the conflicting migration is not attributable to the current branch or the safe renumbering choice is unclear, invoke `$resolve` or ask the user before renaming.
   - If Git has already completed the operation and the rename must be committed, commit or amend only when that action affects the just-completed operation; otherwise ask before rewriting existing commits.

6. If the merge completes without conflicts, validate the result.
   - Run `git status --short --branch`.
   - If Git hooks or pre-commit checks fail, inspect the output, fix concrete issues, stage the fixes, and retry the merge commit or continuation command as appropriate.
   - Run only targeted validation that is practical for the touched area unless the user requested broader checks.

7. Report the outcome.
   - State the target that was merged.
   - State whether conflicts occurred and whether `$resolve` was used.
   - Mention whether the Flyway migration-number check found conflicts and how they were resolved.
   - Mention any pre-commit or validation checks that ran and their result.

## Guardrails

- Never run `git merge --abort`, `git reset`, discard files, or stash user work unless explicitly requested.
- Never start a merge on top of an unresolved merge or rebase.
- Never guess through conflicts; delegate to `$resolve` and ask the user if the intended resolution is unclear.
- Never fetch from or merge a remote other than `origin` unless the user explicitly provides or approves it.
- Never leave duplicate Flyway `V<number>__` migration prefixes after a successful merge when they can be safely resolved.
