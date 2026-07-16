---
name: finish
description: Run Ansel's finish-PR pipeline. Use when the user invokes `$finish` or asks Codex to finish a pull request by committing current work, running the full review/remediation workflow, and creating or updating the draft PR.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Finish PR

Use this skill to complete the current branch through Ansel's preferred PR-ready sequence:

`$commit` → `$full-review` → `$pr-draft`

This skill is an orchestrator. Do not replace the underlying skills with shortcuts, and do not improvise alternate commit, review, push, or PR behavior.

## Preconditions and Safety

- Work only inside the current Git repository/worktree.
- Treat invocation of `$finish` as the user's instruction to run the ordered finish-PR sequence.
- Load and follow each active underlying skill exactly: `commit`, then `full-review`, then `pr-draft`.
- Honor explicit safety gates from underlying skills for destructive, data-loss, force-push, secrets, credential, or materially out-of-scope risky actions.
- Do not force-push unless the user explicitly requested force-push behavior.
- Do not discard, reset, or overwrite user work. Preserve unrelated dirty or untracked files.
- If a required underlying skill cannot be loaded, stop and report the missing skill instead of approximating it.

## Workflow

1. Inspect the current repository state.
   - Run `git status --short --branch`.
   - Record the branch name, upstream state, and visible dirty/untracked files for the final report.
   - Stop if the worktree has conflicts, unmerged paths, or a detached/ambiguous state that an underlying skill cannot safely handle.

2. Run `$commit`.
   - Load and follow the active `commit` skill exactly.
   - Commit current uncommitted changes when the `commit` skill permits it.
   - If there are no committable changes, record this as a no-op and continue.
   - If the `commit` skill stops on a safety gate that this skill does not explicitly override, stop and report the blocker.

3. Run `$full-review`.
   - Load and follow the active `full-review` skill exactly.
   - Let `$full-review` run its review/remediation, commit, validation, and push behavior.
   - Stop if `$full-review` stops on a blocker, failed validation that prevents push, ambiguous push target, or missing required skill.

4. Run `$pr-draft`.
   - Load and follow the active `pr-draft` skill exactly.
   - Create or update the draft PR for the current branch.
   - Include screenshot handling and branch-wide PR body synthesis exactly as `$pr-draft` requires.

5. Report concisely.
   - List the skills run in order.
   - Include commit hashes created by each commit-capable step, or note no-op commits.
   - Include validation commands/results reported by the underlying workflows.
   - Include push target, PR URL, draft status, and screenshot coverage when available.
   - Include residual risks, unresolved findings, blockers, or manual follow-up.
