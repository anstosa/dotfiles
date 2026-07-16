---
name: fixup
description: Inspect and repair the GitHub pull request for the current branch. Use when invoking `$fixup`, when asked to fix up PR issues, or when Ansel asks to batch-handle merge conflicts, failing GitHub Actions CI tasks, and unresolved PR review comments before pushing once at the end.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Fix up PR issues

## Purpose

Use this skill to inspect the PR attached to the current branch, fix applicable known blockers in a fixed order, and push only once after all local fixes are complete.

The required order is:

1. Merge conflicts: use `$merge` when the PR is conflicted with its base branch.
2. CI failures: use `$pr-ci-fix` when GitHub Actions checks are failing.
3. Review comments: use `$address` when unresolved actionable review threads exist.
4. Batch push: push all resulting commits together after the above tasks are complete.

## Batch-push rule

`$fixup` overrides push timing in subordinate skills. Load and follow `$merge`, `$pr-ci-fix`, and `$address` when applicable, but do not push from inside `$pr-ci-fix` or `$address`. Defer all pushes until the final batch-push step.

For `$address`, also defer review-thread resolution until after the final push. Resolve only the threads that `$address` actually addressed with local changes and that were included in the pushed commits.

## Workflow

### 1. Verify repository and PR

Run:

```bash
gh auth status
git status --short --branch
git remote -v
git branch --show-current
gh pr view --json number,url,baseRefName,headRefName,headRepository,headRepositoryOwner,isCrossRepository,maintainerCanModify,mergeStateStatus,statusCheckRollup,reviewDecision
```

If `gh pr view` cannot find a PR for the current branch, stop and ask for a PR URL. If the working tree has unrelated dirty work, preserve it and do not stage it; stop only when unrelated changes overlap files that must be edited and cannot be safely isolated.

Record the PR number, URL, base branch, current branch, upstream push target, starting dirty files, and current commit SHA before making changes.

### 2. Decide applicable tasks

Inspect the PR state before acting:

- Treat merge conflicts as applicable when GitHub reports a conflicted merge state, when the PR UI/API indicates the branch cannot be merged because of conflicts, or when a local merge of the PR base into the current branch produces conflicts.
- Treat CI as applicable when `statusCheckRollup` includes failing, timed-out, cancelled, or action-required GitHub Actions checks. Treat non-GitHub-Actions checks as report-only unless the user explicitly asks to fix them.
- Treat review comments as applicable when GraphQL review-thread data contains unresolved, non-outdated threads that request clear code, test, documentation, or behavior changes.

If an inspection command is inconclusive, gather the narrower source of truth before skipping the task. For review threads, use `$address`'s GraphQL review-thread query before deciding that no unresolved actionable comments exist.

### 3. Fix merge conflicts first

If merge conflicts are applicable, load and follow `$merge`.

- If the PR base branch is `main`, `$merge` may use its default target after fetching.
- If the PR base branch is not `main`, pass `origin/<baseRefName>` as the merge target after fetching.
- If a merge or rebase is already in progress, follow `$merge`'s instruction to invoke `$resolve` instead of starting another merge.
- After the merge or resolution, run `git status --short --branch` and record whether a merge commit or conflict-resolution commit was created.

Do not push after the merge step.

### 4. Fix failing GitHub Actions CI second

If failing GitHub Actions checks are applicable, load and follow `$pr-ci-fix` with this skill's batch-push override:

- Use `$pr-ci-fix` for check discovery, log retrieval, root-cause analysis, implementation, validation, and commit creation.
- Skip `$pr-ci-fix`'s push step.
- Stage and commit only the CI fix, preserving unrelated dirty work.
- Stop if local validation fails or if the fix would require broad rewrites, secret/config changes, migrations, dependency upgrades with lockfile churn, or behavior changes not required by the observed CI failure.

Record failing check names inspected, root cause, validation commands, commit SHA, and any residual failing or external checks.

### 5. Address unresolved review threads third

If unresolved actionable review threads are applicable, load and follow `$address` with this skill's batch-push override:

- Use `$address` for PR identification, thread-aware GraphQL review data, classification, local fixes, validation, and commit creation.
- Skip `$address`'s push step until final batch push.
- Skip `$address`'s thread-resolution step until after final batch push.
- Stage and commit only changes for addressed review threads, preserving unrelated dirty work.
- Do not resolve ambiguous, contradictory, outdated, already-resolved, response-only, or not-current threads.

Record addressed thread IDs or summaries, skipped thread reasons, validation commands, commit SHA, and thread IDs eligible for resolution after push.

### 6. Reinspect before pushing

Before any push, run:

```bash
git status --short --branch
git log --oneline --decorate -5
gh pr view --json number,url,mergeStateStatus,statusCheckRollup,reviewDecision
```

Confirm all of the following before pushing:

- No merge, rebase, cherry-pick, or conflict-resolution operation is still in progress.
- All local validation required by the applicable tasks passed, or an environment blocker is clearly recorded.
- No known applicable merge-conflict, CI-failure, or actionable-review-comment task remains locally fixable.
- The push target is the current branch's configured upstream, or `origin HEAD` only when the PR head repository and branch clearly match the current branch.
- Unrelated dirty work is not staged.

If these conditions are not met, continue fixing or stop with the blocker. Do not push a known-failing or partially fixed state unless the user explicitly asks.

### 7. Push once and resolve addressed threads

Push all local commits in one batch:

```bash
git push
```

If no upstream is configured, inspect branch and PR metadata. Use `git push -u origin HEAD` only when it clearly targets the PR head branch. Stop if push permissions or target branch ownership are unclear.

After a successful push, resolve only the review thread IDs recorded as actually addressed by `$address` and included in the pushed commits. Use `$address`'s GraphQL `resolveReviewThread` mutation for those IDs.

### 8. Final report

Report:

- PR URL and branch.
- Whether `$merge`, `$pr-ci-fix`, and `$address` were applicable, skipped, or completed.
- Merge target and whether conflicts occurred.
- CI checks inspected, root cause, changed files, validation commands, and results.
- Review threads addressed, skipped threads with reasons, and resolved-thread count.
- Commit SHAs created during the workflow.
- Push target and push result.
- Any residual checks, comments, external blockers, or risks.

## Guardrails

- Do not push until all applicable local fixes are complete.
- Do not resolve review threads before the final push succeeds.
- Do not stage unrelated local work.
- Do not start a new merge on top of an unresolved merge, rebase, or cherry-pick.
- Do not guess through conflicts or ambiguous review requests; use `$resolve` or ask only when intent is truly unclear.
- Do not claim remote CI is green unless checks were re-run and observed passing after the final push.
