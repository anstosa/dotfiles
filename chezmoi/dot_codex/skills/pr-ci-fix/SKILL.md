---
name: pr-ci-fix
description: Fix failing GitHub Actions CI for the current PR or a specified PR, then validate, commit, and push the focused fix. Use when the user invokes `$pr-ci-fix`, asks to inspect PR CI failures and fix them, or asks to run `$github:gh-fix-ci` followed by `$commit` and push.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# CI And Fix

Run an end-to-end CI repair workflow for a GitHub pull request. The goal is to turn a failing GitHub Actions check into a focused local fix, validated commit, and pushed branch while protecting unrelated work.

## Workflow

1. Inspect repository state.
   - Run `git status --short --branch` and identify the branch, upstream, dirty files, and untracked files.
   - Treat unrelated local work as user-owned. Do not revert it, reformat it, or include it in the final commit.
   - If unrelated work overlaps files that must be edited, preserve the unrelated changes and stage only the CI fix at commit time.

2. Inspect failing GitHub Actions checks.
   - Load and follow `$github:gh-fix-ci` for GitHub authentication, PR resolution, Actions check discovery, log retrieval, and root-cause summary.
   - If the user supplied a PR number or URL, use it. Otherwise use the current branch PR.
   - Treat non-GitHub-Actions checks as report-only unless the user explicitly asks for a separate investigation path.
   - Stop if `gh` is unauthenticated, the PR cannot be resolved, logs are unavailable and the cause cannot be inferred safely, or the failure is clearly unrelated to this branch's code.

3. Implement the focused CI fix.
   - Invocation of `$pr-ci-fix` counts as the explicit approval required by `$github:gh-fix-ci` to implement a narrow, evidence-backed fix.
   - Do not pause for another approval when the fix is low-risk and directly tied to the observed failing check.
   - Stop and ask before broad rewrites, destructive operations, secrets/config changes, migrations, dependency upgrades with lockfile churn, or behavior changes not required by the CI failure.

4. Validate locally.
   - Run the narrowest meaningful test, type check, lint, or project wrapper that exercises the failure.
   - If practical, re-run the same failing command from CI or the closest local equivalent.
   - Do not commit or push if validation fails unless the user explicitly asks to publish a known failing state.

5. Commit the intended fix.
   - Load and follow `$commit`.
   - Stage only changes made for this CI repair. Do not stage unrelated local work.
   - Use `$commit` to create a new commit according to its branch-state rules; do not amend existing commits.

6. Push the result.
   - Push to the branch's configured upstream when one exists.
   - If there is no upstream, push with `git push -u origin HEAD`.
   - Do not push if commit creation failed.

7. Report completion.
   - Include the failing check names inspected, concise root cause, files changed, validation commands and results, commit hash, push target, and any residual failing/external checks or risks.

## Guardrails

- Keep fixes scoped to the observed CI failure and current branch.
- Do not include generated files, secrets, caches, or unrelated formatting unless required by the CI failure and repository conventions.
- Do not claim CI is green unless checks were re-run and observed passing; otherwise say local validation passed and remote CI should be rechecked.
- If GitHub Actions failures remain after the fix, summarize the remaining failure and stop rather than stacking speculative commits.
