---
name: full-review
description: Run the full repository review-and-remediation sequence. Use when the user invokes `$full-review`, asks for a full review workflow, or wants Codex to run `$brooks-sweep`, `$commit`, `$review-and-fix`, `$commit`, and push the current branch in order.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Full Review

## Overview

Run the high-autonomy branch cleanup pipeline:

`$brooks-sweep` → `$commit` → `$review-and-fix` → `$commit` → final push.

This skill coordinates existing skills; do not replace their detailed workflows with an improvised shortcut.

## Preconditions and Safety

- Work only inside the current Git repository/worktree.
- Treat invocation of `$full-review` as confirmation to commit and push the current branch.
- Treat invocation of `$full-review` as the user's one-time approval for the `$brooks-sweep` pre-flight consent notice; do not pause for that confirmation.
- Do not discard, reset, or overwrite user work. Preserve unrelated dirty or untracked files.
- Honor all repository `AGENTS.md` files and deeper task-specific instructions.
- Honor explicit safety gates from underlying skills other than the `$brooks-sweep` pre-flight consent notice; do not auto-confirm destructive, data-loss, force-push, secrets, credential, or out-of-scope risky changes.
- Do not force-push unless the user explicitly requested force-push behavior.
- If an underlying required skill cannot be loaded, stop and report the missing skill instead of approximating it.

## Workflow

1. Inspect current state.
   - Run `git status --short --branch`.
   - Identify the branch name, upstream, and dirty/untracked files before making changes.
   - Keep this baseline for protecting unrelated user work and for the final report.

2. Run `$brooks-sweep`.
   - Load and follow the active `brooks-sweep` skill exactly.
   - Auto-confirm the Step 0 pre-flight consent notice using the `$full-review` invocation as approval.
   - Apply safe fixes, validate as directed, and report/track any residual or unresolvable items.

3. Run the first `$commit`.
   - Load and follow the active `commit` skill exactly.
   - If there are no committable changes and no safe amend, record this as a no-op and continue.

4. Run `$review-and-fix`.
   - Load and follow the active `review-and-fix` skill exactly.
   - Let it run its review, cleanup-review, validation, commit, and push behavior.
   - Continue to the next step even if it already pushed, unless it stopped on a blocker or failed validation.

5. Run the second `$commit`.
   - Load and follow the active `commit` skill exactly for any remaining changes.
   - If there are no committable changes and no safe amend, record this as a no-op and continue.

6. Push.
   - Push the current branch to its upstream when one exists.
   - If no upstream exists, push `HEAD` to `origin` using the current branch name and set upstream.
   - Stop before pushing if validation failed, a required commit failed, the branch is detached, or the push target is ambiguous.

7. Report concisely.
   - List the skills run in order.
   - Include commit hashes created/amended by each commit-capable step, or note no-op commits.
   - Include validation commands/results from the underlying workflows.
   - Include the final push target.
   - Include residual risks, unresolved findings, or blockers.
