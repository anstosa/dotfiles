---
name: resolve
description: Resolve an in-progress Git merge, rebase, or cherry-pick. Use when the user invokes $resolve or asks Codex to check for a merge, rebase, or cherry-pick in progress, resolve conflict markers carefully, continue the operation, fix any pre-commit issues, and check for conflicting Flyway migration numbers before finishing.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Resolve

Use this skill to complete an already-started Git merge, rebase, or cherry-pick. Prefer correctness and preserving intent over speed.

## Workflow

1. Inspect Git state before editing.
   - Run `git status --short --branch`.
   - Check for an in-progress merge with `test -f .git/MERGE_HEAD`.
   - Check for an in-progress rebase with `test -d .git/rebase-merge || test -d .git/rebase-apply`.
   - Check for an in-progress cherry-pick with `test -f .git/CHERRY_PICK_HEAD`.
   - If none of merge, rebase, or cherry-pick is in progress, stop immediately and tell the user there is no merge, rebase, or cherry-pick to resolve.
   - If more than one operation appears to be in progress, stop and report the ambiguous Git state.

2. Identify conflicts and context.
   - Use `git diff --name-only --diff-filter=U` for unmerged paths.
   - Use `rg -n "^(<<<<<<<|=======|>>>>>>>)" -- <paths>` to find conflict markers in conflicted files.
   - Inspect each conflicted file with enough surrounding context to understand both sides.
   - For rebase conflicts, inspect the current patch when useful with `git rebase --show-current-patch`.
   - For cherry-pick conflicts, inspect the picked commit when useful with `git show --stat --patch CHERRY_PICK_HEAD`.
   - Inspect relevant adjacent code, tests, docs, and commit context before choosing a resolution.

3. Resolve conservatively.
   - Remove all conflict markers and leave syntactically valid files.
   - Preserve both sides when they are complementary.
   - Prefer the surrounding codebase conventions over introducing new patterns.
   - Do not guess when the intended resolution is unclear, destructive, or semantically risky. Ask the user a concise question and wait.
   - Do not resolve by blindly choosing ours or theirs unless the evidence clearly supports that choice.
   - Leave unrelated dirty work untouched.

4. Stage resolved files.
   - After editing, run `rg -n "^(<<<<<<<|=======|>>>>>>>)"` to confirm no conflict markers remain.
   - Run `git diff` and review the resolution.
   - Stage only files resolved for the current merge, rebase, or cherry-pick unless related pre-commit fixes require additional files.
   - Re-run `git status --short --branch` and confirm there are no unmerged paths.

5. Check for conflicting Flyway migration numbers.
   - Run this check after conflict markers are gone and before continuing the merge, rebase, or cherry-pick.
   - Find Flyway migration files with `git ls-files | rg '(^|/)(db/)?migration(s)?/.*V[0-9][0-9_.]*__.*\.sql$|(^|/)V[0-9][0-9_.]*__.*\.sql$'` and inspect the `V<number>__` prefix.
   - Compare migration numbers within the same migration directory; independent modules or directories may each have their own sequence.
   - If two or more migration files in the same sequence use the same `V<number>__` prefix, identify which file came from the current operation by using `git diff --name-status ORIG_HEAD...HEAD`, `git log --name-status`, the active rebase patch, or `git show --name-status CHERRY_PICK_HEAD` when available.
   - Rename the migration introduced by the current operation to the next available number in that same sequence unless repository conventions clearly require a different gap, date, or semantic version format.
   - Preserve the description after `__`, update only filename references required by the rename, use `git mv` for tracked files, and stage the rename.
   - If both migrations came from the other side, both came from the current branch or operation, or the safe ordering is unclear, ask the user before renumbering.

6. Continue the operation.
   - For a merge, run `git commit` if Git requires a merge commit; preserve the default merge message unless a clearer message is needed.
   - For a rebase, run `git rebase --continue`.
   - For a cherry-pick, run `git cherry-pick --continue`.
   - Use non-interactive commands when a message is needed, for example `git commit --no-edit` for a merge commit.

7. Handle continuation and pre-commit failures.
   - If Git reports more conflicts, repeat the conflict-resolution workflow.
   - If pre-commit, lint, format, or test checks fail during `--continue`, inspect the output and fix the concrete issues.
   - Re-run the failing check when practical, stage the fixes, then retry the Git continuation command.
   - After the merge, rebase, or cherry-pick finishes, run the Flyway migration-number check again against the completed branch before reporting success.
   - If the final check finds a duplicate introduced by the current branch after Git has already completed the operation, resolve it with `git mv`, stage it, and commit or amend only when that action affects the just-completed operation; otherwise ask before rewriting existing commits.
   - If a failure requires user intent or external access, stop and explain the blocker.

8. Report the result.
   - State whether the merge, rebase, or cherry-pick completed.
   - Summarize the conflicts resolved and any pre-commit fixes made.
   - Mention whether the Flyway migration-number check found conflicts and how they were resolved.
   - Mention checks that were run, or say which checks were triggered by Git and whether they passed.

## Guardrails

- Never run `git merge --abort`, `git rebase --abort`, `git cherry-pick --abort`, `git reset`, or discard user changes unless the user explicitly requests it.
- Never edit generated files by hand unless the repository explicitly requires conflict resolution in them and there is no generator-backed alternative.
- Never continue with unresolved conflict markers.
- Never invent intent for unclear conflicts; ask the user instead.
- Never leave duplicate Flyway `V<number>__` migration prefixes after resolution when they can be safely resolved.
