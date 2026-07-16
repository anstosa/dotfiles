---
name: commit
description: Commit current uncommitted repository changes with a structured message. Use when the user invokes $commit, asks Codex to commit current work, or asks to produce a user-testable commit message.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Commit

Use this skill to turn the current uncommitted working tree into a clear Git commit. Prefer safety and accurate commit messages over speed.

## Workflow

1. Inspect the repository state before changing anything.
   - Run `git status --short --branch`.
   - Run `git diff --stat`, `git diff`, and `git diff --cached`.
   - If the status shows conflicts, unmerged paths, or an unclear index state, stop and report the blocker.
   - If there are no unstaged or staged changes, stop and say there is nothing to commit.

2. Determine whether confirmation is needed before creating a new commit.
   - Always create a new commit for the current uncommitted changes; do not amend existing commits.
   - Use the branch's upstream as the target branch when it exists. Check it with `git rev-parse --abbrev-ref --symbolic-full-name @{upstream}`.
   - If there is no upstream, use the local `origin/main` ref as the target branch when it exists.
   - Do not fetch unless the user explicitly asks.
   - Count commits in front of the target branch with `git rev-list --count <target>..HEAD`.
   - If the branch is already one or more commits in front of its target branch, ask the user for confirmation before committing the additional worktree changes.
   - If the user confirms, continue and make sure the commit message is based only on the newly staged worktree changes, not earlier commits in the branch.
   - If the user does not confirm, stop without staging or committing.
   - If `HEAD` is detached or no target branch can be identified, continue without the ahead-count confirmation gate but mention that the target branch could not be classified.

3. Stage the intended changes.
   - Default to `git add -A` so tracked edits, deletions, and new files are included.
   - If the user requested a narrower scope, stage only that scope.
   - Re-run `git diff --cached --stat` and inspect the staged diff before committing.

4. Write the commit message from the staged diff.
   - Base the message only on `git diff --cached`, which represents the new commit. Do not summarize previous commits already on the branch.
   - Classify whether the overall objective of the staged diff is test-related before drafting any message text. A commit is test-related only when its primary purpose is to add or change automated tests, test fixtures, test harnesses, CI behavior, or testing documentation; incidental test coverage for a feature, bug fix, or refactor does not qualify.
   - The first line must be a meaningful summary under 80 characters. For non-test-related commits, the first line must not mention tests, test files, test coverage, fixtures, harnesses, CI, or validation.
   - A `## Summary` heading is allowed when it makes a longer commit message clearer; omit it for small changes where the body can start directly after the first blank line.
   - The body must explain what the commit does in a few concise sentences. Prefer 1 sentence if the change is small enough to allow it.
   - Include a bulleted list of specific changes, modified behavior, cleanup, or documentation updates. Do not include component API changes, REST API changes, screenshot notes, testing steps, or incidental test additions in this list.
   - Treat the first line, body, and `## Summary` bullets as the summary area. For non-test-related commits, that summary area must describe only the feature, fix, refactor, documentation, or workflow change, not any tests added alongside it.
   - For non-test-related commits, do not mention automated tests, test files, test coverage, fixtures, harnesses, CI, automated checks, automated validation, test commands, test results, skipped automated checks, or automated-check blockers anywhere in the commit message except the required manual `## Testing` section.
   - For test-related commits, mention automated testing only as the subject of the change. Describe the test, fixture, harness, CI workflow, or testing documentation that changed; never frame it as agent validation, command output, pass/fail status, or proof that the commit was verified.
   - If screenshots are relevant to the commit or PR, include a `## Screenshots` section immediately after the summary/body bullets and before `## API Changes`.
   - If there were API changes to UI components or the REST API, include a `## API Changes` section after screenshots, or after the summary/body bullets when there are no screenshots.
   - In `## API Changes`, use a bulleted list. Each bullet should describe one API contract, parameter, return value, endpoint, schema, or component prop change.
   - End with a `## Testing` section.
   - Do not add any other `##` sections. The only allowed section headings are `## Summary`, `## Screenshots`, `## API Changes`, and `## Testing`; omit `## Summary`, `## Screenshots`, and `## API Changes` when they do not apply.
   - Never include a `## Validation` section or any similarly named section for checks, commands, logs, or agent verification.
   - In `## Testing`, include only a numbered list of exactly what actions to take to test the behavior through the product or workflow. The steps must be understandable to a non-developer, but do not literally say "as an internal non-developer user" or similar.
   - Do not write any preface, summary, explanatory sentence, logs, command output, automated check, agent validation note, skipped-check note, or follow-up text before or after the numbered list in `## Testing`.
   - For non-test-related commits, keep `## Testing` focused on product or workflow behavior that a user can exercise manually; do not turn it into an automated-check or developer-command section.
   - For test-related commits, `## Testing` may describe how to exercise the changed test workflow or CI/testing surface, but it must not report what the agent ran, what passed, what failed, or what could not be run.

5. Commit.
   - Run `git commit` with the structured message.
   - Use non-interactive Git commands so the full message is supplied explicitly.
   - Preserve message formatting exactly: use a commit message file or pipe real newline-delimited text to `git commit -F -`. Do not encode paragraph or bullet breaks as literal `\n` inside a `-m` argument.
   - Quote shell-sensitive text so examples like `$commit`, backticks, and variables are committed literally instead of being expanded by the shell.

6. Report the result.
   - Show that a new commit was created.
   - Include the commit hash and first-line summary.
   - For non-test-related commits, do not mention automated testing, automated validation, whether automated checks were run, or automated check results.
   - For test-related commits, mention automated testing only when the first-line summary describes the test-focused objective.

## Message Template

```text
Short meaningful summary under 80 characters

This commit explains the user-visible or operational purpose of the change in a
few sentences. Keep the body specific to what is staged. A Summary heading is
allowed when it improves clarity.

- Change one specific behavior, file area, or component.
- Add or update another specific component or workflow.
- Remove or clean up obsolete behavior when relevant.

## Screenshots

- Before: screenshot saved to /path/to/before.png, or not applicable.
- After: screenshot saved to /path/to/after.png, or not applicable.

## API Changes

- Change one component prop, return value, endpoint, schema, or API behavior.
- Add, remove, or deprecate another API contract when relevant.

## Testing

1. Open the affected page or workflow.
2. Perform the user action that exercises the changed behavior.
3. Confirm the expected result appears and any previous broken behavior is gone.
```

## Guardrails

- Do not amend existing commits in this workflow.
- Do not commit on a branch that is already ahead of its target branch until the user confirms.
- Do not fetch, pull, push, or reset unless the user explicitly asks.
- Do not include secrets or unreviewed generated artifacts in the commit.
- Do not invent testing that was not performed.
- Do not add sections other than the allowed `## Summary`, `## Screenshots`, `## API Changes`, and `## Testing` sections.
- Do not include a `## Validation` section.
- For non-test-related commits, do not put automated checks, automated validation, skipped checks, verification blockers, developer-only commands, test files, test coverage, fixtures, harnesses, CI, or automated-testing commentary in the commit message summary area.
- For non-test-related commits, mention testing only inside the required manual `## Testing` section.
- For test-related commits, automated testing may be named only as the subject of the staged change, not as proof that validation was completed.
- Do not mention whether automated testing or automated validation was completed, what commands were run, whether they passed, or why they were not run.
- Do not use a developer-only command as a `## Testing` step unless the commit is test-related and the command is the user-facing workflow being changed.
- In `## Testing`, include only the numbered list; no prose, logs, explanations, agent validation notes, or text before or after the list.
- For non-test-related commits, do not include automated checks in `## Testing`.
