---
name: pr-draft
description: Create or update a GitHub draft pull request for the current branch. Use when the user invokes $pr-draft, asks to open/create/update a draft PR for the current branch, or wants local work committed, pushed, and represented in a draft PR. This workflow must use $commit when creating or updating PR title/body, must summarize the whole branch relative to the PR base rather than only uncommitted changes or the latest commit, and for frontend changes must capture user-mode screenshots unless the UI only exists in admin mode, save screenshot files to /mnt/c/Users/ansel/Downloads, and add screenshot placeholders to the PR body.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Draft PR

Use this skill to turn the current branch into a GitHub draft pull request, or update the existing draft PR for the branch, with a clear title, useful description, commit-style manual testing guidance, and local frontend screenshot files when applicable. All summaries, screenshot decisions, and PR body content must consider the entire branch relative to the PR base, not only uncommitted changes or the latest commit. When updating an existing PR, still use `$commit` to rewrite the PR title and description from all changes in the branch instead of preserving stale PR text. Do not upload or publicly host screenshots; save them for manual upload from `/mnt/c/Users/ansel/Downloads`. Capture screenshots in normal user mode by default; use admin mode only when the UI being captured exists only in an admin surface.

## Prerequisites

- Require a GitHub remote for the current repository.
- Require GitHub CLI `gh`; run `gh --version` and `gh auth status` before creating the PR.
- Prefer repo-local instructions and existing project wrappers for validation.
- If the worktree has conflicts, unmerged paths, detached work that cannot be pushed safely, or unrelated dirty changes outside the requested scope, stop and report the blocker.
- If a draft PR already exists for the current branch, update that PR. Do not create a duplicate PR for the same branch.

## Workflow

1. Inspect local and PR state.
   - Run `git status --short --branch`, `git remote -v`, and inspect relevant diffs.
   - Determine the current branch with `git branch --show-current`.
   - If there is no branch name, ask the user to create or choose a branch before pushing.
   - Determine the base branch from the user request when provided; otherwise use the remote default branch from `gh repo view --json defaultBranchRef`.
   - Check for an existing PR for the current branch with `gh pr list --head <branch> --state all` or equivalent. If an open draft PR already exists for this branch, plan to update it instead of creating a new PR and use that PR's base branch unless the user explicitly requested a different base. If an open non-draft PR exists, ask before converting or editing unless the user explicitly requested that PR.
   - Determine the branch comparison range with `git merge-base <base> HEAD` and inspect the full branch diff with commands such as `git diff --stat <merge-base>...HEAD`, `git diff <merge-base>...HEAD`, and `git log --oneline <merge-base>..HEAD`.
   - If the branch touches `components/db/migrations/`, audit the changed migration versions against the Flyway history already applied to `dev` before creating or updating the PR. A green application build on `main` means the included migrations deployed to `dev` successfully. For every `dev`-applied migration, the version, script filename, and checksum/content are immutable: do not edit, rename, renumber, delete, or replace it. If the branch changed a `dev`-applied migration, stop and restore the deployed version/name/content exactly, then move the intended schema/data change into a new higher-numbered migration.
   - When `dev` Flyway history is unavailable, be conservative: treat any migration that already exists on the PR base as potentially deployed and block edits, renames, renumbers, or deletions unless explicit evidence proves it has not deployed to `dev`.

2. Use `$commit` first, including existing-PR updates.
   - Always load and apply the `$commit` workflow before creating or updating PR title/body.
   - If there are unstaged or staged changes, run `$commit` normally as a prerequisite to PR creation or update. When doing so, treat the intended PR scope as the full branch range, not just uncommitted changes. If `$commit` has narrower commit-message guardrails, follow them for the new commit message only, then continue with branch-wide PR synthesis below.
   - Whether or not `$commit` creates a new commit, use `$commit`'s structured message rules to rewrite a branch-wide PR message from `<merge-base>..HEAD` and `<merge-base>...HEAD`. This rewritten message is the source for the PR title and description and must take all changes in the branch into account.
   - If `$commit` stops because there is nothing to commit, continue to the branch-wide PR message rewrite when the branch already contains commits or an existing draft PR. Do not create an empty commit.
   - After `$commit` creates a commit or stops with nothing to commit, recompute the merge base and branch range, then read the branch with `git log --format=fuller --stat <merge-base>..HEAD`, `git diff --stat <merge-base>...HEAD`, and targeted diffs as needed.

3. Build the PR title and body from the `$commit`-style branch-wide message.
   - Summarize every relevant change in `<merge-base>..HEAD` and `<merge-base>...HEAD`; do not base the PR title/body only on the final commit message, only on uncommitted changes, only on the latest commit, or only on the existing PR text.
   - When updating an existing draft PR, use the existing title/body only as stale context to replace; `$commit`-style branch-wide synthesis must rewrite the title and description from all branch changes.
   - Prefer a concise branch-wide title that reflects the complete PR and follows `$commit`'s title requirements. If the final commit message already accurately summarizes the whole branch, it may be reused; otherwise write a better title from the branch diff.
   - Preserve useful sections such as `## API Changes` and `## Testing`, updating them to cover the whole branch and obey `$commit` section rules.
   - Add a short `## Summary` with branch-wide bullets when the synthesized body lacks a clear overview.
   - Add `## Screenshots` for frontend changes, with text placeholders that are only the screenshot filename in square brackets, without a path.
   - In `## Screenshots`, do not describe how screenshots were captured, what tool was used, or where files were saved.
   - Do not invent testing. In the PR body, keep `## Testing` limited to `$commit`-style numbered manual product/workflow steps; report automated validation only in the final assistant response.

4. Decide whether screenshots are required.
   - Make this decision from the full branch diff against the PR base, not only from the latest commit.
   - Treat the change as frontend when touched files include UI source, styles, routes, Storybook stories, Playwright/UI tests, frontend generated-facing types, or user-visible copy.
   - Also treat it as frontend when the user describes UI, visual, interaction, or browser behavior even if file detection is inconclusive.
   - For backend-only, infrastructure-only, docs-only, or test-only changes, screenshots are not required unless the user requests them.

5. Capture frontend screenshot evidence.
   - For a bug fix, include exactly one before screenshot and one after screenshot that clearly show the fixed behavior.
   - Generate the before screenshot from a temporary checkout of the pre-change commit instead of relying on memory or skipping it.
   - Determine the pre-change commit after `$commit` finalizes the branch: prefer the merge base with the PR base branch (`git merge-base <base> HEAD`) for multi-commit branches; for a single-commit branch this is usually `HEAD^`.
   - Prefer `git worktree add --detach <temp-dir> <pre-change-commit>` for the before state so the current working tree stays on the PR branch. If using the current worktree instead, require a clean tree, record the original `HEAD`, check out the pre-change commit only temporarily, and always check the PR branch back out before continuing.
   - Run the same product UI surface in the before checkout and after checkout whenever practical so the screenshots are comparable.
   - Capture screenshots from the running UI in the relevant worktree. Do not screenshot tests, Storybook-only fixtures, static HTML, mocked standalone pages, or other contrived scenarios unless the user explicitly approves that fallback.
   - Capture screenshots in normal user mode by default, using non-admin routes, roles, accounts, and data whenever the changed UI is visible to normal users.
   - Use admin mode only when the UI being captured exists exclusively in an admin-only surface, and keep admin-only captures scoped to that UI.
   - If both user-mode and admin-mode paths can show the changed behavior, capture the user-mode path and do not substitute an admin screenshot for convenience.
   - Before deciding screenshots are impossible, identify the backend and database that the running UI actually uses. If the current worktree is running in `uionly` mode, do not assume the local worktree database is relevant; inspect the API/backend/database behind that UI instance and query that database instead.
   - If the existing data in the UI's actual database cannot reproduce the user-visible state, add minimal scoped fixtures so the issue or feature state can be reproduced in the running product UI. Prefer repo-supported seed/admin/API/database helpers, make fixture records clearly test/local, and document any fixture setup or cleanup in the final assistant response.
   - For a feature, include one to three screenshots demonstrating the feature's main user-visible states from the final branch state; before screenshots are optional unless the feature replaces visible existing behavior.
   - Prefer the local product app route that best shows the changed behavior. If the needed state cannot be reached in the running app, do not fabricate a visual scenario; explain the blocker in the PR body instead.
   - Prefer browser or screenshot tooling for live UI verification when practical.
   - Crop each screenshot to only the UI area necessary to communicate the change. Prefer element-level screenshots or viewport sizing before capture; otherwise crop the saved image afterward.
   - Avoid full-page, full-window, or wide-context screenshots unless the surrounding layout is necessary to understand the change.
   - Save screenshots directly under `/mnt/c/Users/ansel/Downloads`; create that directory if it is missing.
   - Name screenshots descriptively with the branch or PR context, e.g. `<branch-slug>-before.png`, `<branch-slug>-after.png`, or `<branch-slug>-state-name.png`.
   - Do not commit screenshot files to the branch and do not create remote artifact branches, gists, public links, or other hosted image URLs.
   - If before evidence is impossible even from a temporary pre-change checkout, explain the exact blocker in the `## Screenshots` text instead of adding a fake filename placeholder.

6. Push the branch.
   - Run `git push -u origin <current-branch>` after the commit is finalized and screenshot needs are known.
   - Do not force-push unless the user explicitly asks and the risk is understood.

7. Add and verify screenshot placeholders for frontend changes.
   - Do not upload screenshots to GitHub, gists, raw repository URLs, artifact branches, or external hosting.
   - Ensure every captured screenshot file is present in `/mnt/c/Users/ansel/Downloads` before creating or updating the PR body file.
   - Under `## Screenshots`, insert text placeholders instead of image Markdown.
   - Each placeholder line must contain only the screenshot filename in square brackets, e.g. `[branch-slug-after.png]`. Do not include the local path in the placeholder. Add an extra blank line after each screenshot placeholder before the next label, note, or section heading.
   - Put only a brief note about what to look at on the line immediately before the placeholder, and only when the screenshot is not self-evident. Do not include capture notes, local file locations, upload instructions, or manual-upload guidance.
   - For bug fixes, use minimal `Before` and `After` labels with one filename placeholder under each. Add a short "what to look at" note only when the visual difference would not be obvious from the label and screenshot.
   - For features, use the filename placeholder alone when the screenshot is self-evident. Add a concise feature-state label or "what to look at" note only when the state or expected visual is not self-evident.
   - If expected evidence is missing, add an explicit explanatory line without a filename placeholder, such as `Before: not captured because the fix was already applied locally.`

8. Audit the PR body before calling `gh pr create` or `gh pr edit`.
   - Re-read the final body file exactly as it will be submitted and check it against the `## Screenshots` and `## Testing` contracts.
   - For frontend changes, require a `## Screenshots` section. If screenshots were captured, require each placeholder line to contain only a filename in square brackets and require the file to exist under `/mnt/c/Users/ansel/Downloads`.
   - Reject screenshot placeholders that include paths, Markdown images, URLs, hosted artifacts, upload instructions, saved-location notes, local capture commands, tool names, or explanations of the capture process.
   - If screenshots could not be captured, allow only a concise blocker line such as `Feature screenshot not captured because <product-state blocker>.` Do not include tool names, local paths, command output, validation notes, upload instructions, or implementation details in that blocker.
   - Inspect the `## Testing` section and reject automated validation, developer commands, logs, skipped-check notes, agent verification notes, or prose before or after the numbered manual product/workflow steps.
   - If the body fails this audit, rewrite the body file and repeat this step before creating or updating the PR.

9. Create or update the draft PR.
   - If an open draft PR already exists for the current branch, edit that PR with the newly rewritten `$commit`-style branch-wide title/body and push the branch; do not create a duplicate.
   - If no PR exists, prefer `gh pr create --draft` with explicit `--base`, `--head`, `--title`, and `--body-file` arguments.
   - Write the PR body to a temp file with real Markdown newlines before passing it to `gh`.
   - If screenshots are required, ensure the PR body file already contains the text placeholders before creating or editing the PR.
   - If `gh pr create` reports that a PR already exists, stop creating and update the reported existing PR instead.
   - Keep the PR as draft unless the user explicitly asks for ready-for-review.

10. Report the result.
   - Include PR URL, branch, base branch, commit hash, and whether the PR is draft.
   - Summarize validation commands and screenshot coverage.
   - Call out any missing evidence or manual follow-up.

## PR Body Shape

Use this Markdown shape unless the commit message already provides equivalent sections:

```markdown
## Summary

<Commit-message overview adapted for PR readers.>

<Commit-message bullets or sections.>

## Screenshots

<Only for frontend changes. Add a concise label, plus a brief note about what to look at only if it is not self-evident. Do not mention capture method, tools, local paths, saved locations, or upload instructions. Example:
`After: fold dilution uses the 1: prefix.`
`[branch-slug-after.png]`

>

## Testing

<Numbered manual product/workflow test steps only, following `$commit` rules. Do not include automated checks, developer commands, validation logs, skipped-check notes, or agent verification notes.>
```

## Guardrails

- Do not bypass `$commit` when creating or updating PR title/body. If there is nothing to commit, still use `$commit`'s message structure to rewrite the PR title/body from the whole branch.
- Do not let `$commit` narrow the PR summary to only a new commit; the PR title/body must describe the whole branch.
- Do not create a duplicate PR when an open draft PR already exists for the branch; update the existing draft PR with a fresh branch-wide `$commit`-style title/body.
- Do not push or open a PR when the intended scope is unclear.
- Do not include secrets, local-only files, generated clients, or screenshots as committed code unless the user explicitly requests it and repo rules allow it.
- Do not create or update a PR that changes the version, script filename, or checksum/content of a Flyway migration already deployed to `dev`; restore the deployed migration exactly and add a new forward migration instead.
- Do not silently create a ready-for-review PR.
- Do not upload, host, or link screenshots through public gists, public URLs, raw private-repo URLs, or remote artifact branches.
- Do not claim screenshots were uploaded or embedded; report only that screenshot placeholders were added unless the user asks for file-location details.
- Do not put automated checks, developer-only commands, validation logs, skipped-check notes, or agent verification notes in the PR body `## Testing` section; keep those details in the final assistant response.
- Do not call `gh pr create` or `gh pr edit` until the PR body has passed the explicit audit step for screenshot and testing content.
- Do not let screenshot blocker text become a validation log; keep it to the product-state reason screenshots could not be captured.
- Do not add explanatory labels or annotations inside screenshot images; screenshots should show the running product UI only.
- Do not include irrelevant surrounding UI in screenshots; crop to the smallest useful area that still communicates the change.
- Do not capture frontend screenshot evidence in admin mode when the same UI state is available in normal user mode.
