---
name: review-and-fix
description: Review the current branch, fix credible findings from the standard code review and cleanup review, then commit and push the intended changes. Use when the user asks to review and fix review findings, run cleanup-review, commit, and push the current branch.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Review And Fix

Run a review/fix workflow for the current repository branch. The goal is to produce a reviewed, fixed, validated, committed, and pushed branch while protecting unrelated local work.

## Workflow

1. Inspect repository state.
   - Run `git status --short --branch` and identify the current branch, upstream, and dirty files.
   - Treat unrelated dirty or untracked work as user-owned. Do not revert it, reformat it, or include it in the final commit.
   - If unrelated dirty work overlaps files that must be edited, read the file carefully and preserve the unrelated changes.

2. Run the standard review pass.
   - Use `/review` when it is available in the active environment.
   - If `/review` is unavailable, perform the closest standard code-review pass over the current branch against its merge base, prioritizing bugs, regressions, security issues, data loss, and missing validation.
   - Fix only high-confidence, actionable findings. Do not chase speculative or stylistic comments.

3. Run `$pr-cleanup-review`.
   - Load and follow the local `pr-cleanup-review` skill instructions.
   - Fix only high-confidence, actionable cleanup findings.
   - Keep fixes scoped to the current branch's changed behavior and directly affected code.

4. Repeat cleanup review only when capped.
   - Treat the previous `$pr-cleanup-review` result as capped if any checklist category returned its maximum of three findings, or if the reviewer explicitly says output was capped.
   - Stop when the cleanup review returns no credible findings, or returns fewer than three findings in every category.
   - Use a hard maximum of three cleanup-review/fix cycles. If the third cycle is still capped, continue only if validation passes, and report the residual capped findings in the final response.

5. Validate.
   - Run the narrowest meaningful tests, type checks, linters, or project wrappers for the files changed by this workflow.
   - If validation cannot run, state the exact command that should have been run and why it was skipped.

6. Commit and push.
   - Stage only changes made for this workflow. Do not stage unrelated user work.
   - Use the repository's commit skill or local commit conventions when available.
   - Use a clear message such as `Review and cleanup fixes`, adjusted when the repository convention calls for more specificity.
   - Push to the branch's upstream when it exists. If there is no upstream, push `HEAD` to `origin` and set the upstream.
   - Do not ask for another confirmation before committing or pushing; invoking this skill is the confirmation.

## Guardrails

- Do not delete behavior unless the reviewed code and contracts prove it is obsolete.
- Do not treat defensive checks at external trust boundaries as cleanup issues.
- Do not broaden the scope into unrelated refactors.
- Do not commit if validation fails, unless the user explicitly asks to commit a known failing state.
- Report the review passes run, fixes made, validation result, commit hash, push target, and any residual risks.
