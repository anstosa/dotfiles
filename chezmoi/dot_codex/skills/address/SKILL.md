---
name: address
description: Address actionable unresolved GitHub pull request review threads from a PR URL or the current branch's PR. Use when the user invokes `$address`, `$address <GitHub PR URL>`, or asks Codex to fix all unresolved PR review comments, push the fixes, and resolve only the GitHub review threads that were actually addressed.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Address PR Review Threads

## Purpose

Use this skill to handle `$address` end to end: identify the target PR, inspect unresolved GitHub PR review threads, implement clear fixes locally, validate, commit, push, and resolve only the review threads that were actually addressed by the pushed commit.

## Required Input

A GitHub PR URL is optional. If the user provides a URL, parse it into `{owner, repo, number}` and stop for a valid PR URL if parsing fails. If no URL is provided, try to find the PR for the current branch before asking the user.

## Safety Rules

- Preserve unrelated dirty work. Inspect `git status --short` before editing, avoid touching unrelated files, and stage only the files or hunks needed for addressed review threads.
- Stop before checkout, push, or thread resolution if `gh` authentication, repository identity, push permissions, or PR branch ownership are unclear.
- Do not resolve ambiguous, contradictory, outdated, already-resolved, response-only, or purely discussion threads.
- Do not resolve top-level PR comments, issue comments, commit comments, or review comments that GitHub does not expose as resolvable review threads. Report them separately if encountered.
- Stop if validation fails. Continue only when the code fix is complete but validation is blocked by environment or infrastructure, and report the exact blocker.
- Do not include unrelated local changes in the commit. Use pathspecs, patch staging, or a temporary worktree if needed.

## Workflow

### 1. Verify Tools And Repository

Verify tools and local repository state first:

```bash
gh auth status
git status --short
git remote -v
```

Then identify the target PR:

- If a PR URL was provided, parse `{owner, repo, number}` from the URL.
- If no PR URL was provided, use the current branch and checkout to discover the PR:

```bash
git branch --show-current
gh pr view --json number,url,headRefName,headRepository,headRepositoryOwner,baseRefName,isCrossRepository,maintainerCanModify
```

If `gh pr view` cannot find a PR for the current branch, stop and ask for a PR URL. If it finds a PR, derive `{owner, repo, number}` from the returned `url` and repository fields.

Confirm the current local repository matches the PR repository. If not, clone or move to the matching local checkout only when safe. If the correct checkout cannot be identified, stop and ask.

### 2. Check Out The PR Branch

Fetch PR metadata:

```bash
gh pr view <number> --repo <owner>/<repo> --json headRefName,headRepositoryOwner,headRepository,baseRefName,isCrossRepository,maintainerCanModify,url
```

Then check out or confirm the PR branch. Prefer:

```bash
gh pr checkout <number> --repo <owner>/<repo>
```

Stop if the branch is from a fork and push rights are unclear, if the working tree contains conflicting unrelated edits, or if checkout would overwrite local work.

### 3. Fetch Thread-Aware Review Data

Use GitHub GraphQL because `gh pr view --comments` is not enough for resolvable thread state. Fetch review threads with `id`, `isResolved`, `isOutdated`, file anchors, and comments:

```bash
gh api graphql -f owner='<owner>' -f repo='<repo>' -F number=<number> -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      url
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          originalLine
          diffSide
          comments(first: 50) {
            nodes {
              id
              author { login }
              body
              createdAt
              url
              path
              line
              originalLine
            }
          }
        }
      }
    }
  }
}'
```

If there may be more than 100 threads or comments, paginate before deciding what is unresolved.

Treat "all unresolved comments" as unresolved, non-outdated `reviewThreads` that GitHub can actually resolve. Ignore already-resolved threads. Ignore outdated threads unless they still identify a current failing behavior in the code after inspection.

### 4. Classify Threads

For each unresolved, non-outdated review thread:

- `actionable`: Clear code, test, documentation, or behavior change requested and the target still exists.
- `ambiguous`: Unclear request, multiple plausible interpretations, missing context, contradictory reviewer feedback, or product/API decision required.
- `response-only`: No code change requested, asks a question only, or requires reviewer discussion before implementation.
- `not-current`: The anchor or described behavior no longer applies to current code.

Proceed only with `actionable` threads. Pause and ask the user about ambiguous or contradictory threads before editing them. Report response-only, not-current, top-level, and non-resolvable comments as skipped.

### 5. Implement Fixes

Read the surrounding code before editing. Use existing local patterns, helper APIs, tests, formatting, and generated-file rules. Keep the diff scoped to the addressed threads.

After editing, verify the diff before staging:

```bash
git diff
git status --short
```

If unrelated dirty work exists in touched files, use `git diff` and `git add -p` carefully so only the intended hunks are staged.

### 6. Validate

Run the narrowest meaningful validation for the touched code. Prefer repository wrappers and PR-specific checks when available, for example:

```bash
./potato.sh test ui
./potato.sh test python <service> <pytest args>
./potato.sh lint <python|ui|css|js|ts|yaml|json>
```

Choose checks based on touched files and reviewer concerns. Broaden validation when shared contracts, generated clients, migrations, auth, billing, or cross-service behavior are affected.

### 7. Commit Only Addressed Changes

Stage only relevant changes:

```bash
git status --short
git add <relevant paths>
git diff --cached
```

Commit with:

```bash
git commit -m "Address PR review comments"
```

Use a more specific message only when the addressed change is narrow and obvious. Do not commit if validation failed, unless validation was blocked by environment and the user explicitly accepts that risk.

### 8. Push The PR Branch

Push to the PR branch:

```bash
git push
```

If the upstream is missing, inspect branch metadata and set the upstream only when it clearly points at the PR head repository and branch. Stop if push permission or target branch is unclear.

### 9. Resolve Addressed Threads

Resolve only thread IDs that meet all of these criteria:

- The thread was unresolved and non-outdated when fetched.
- A concrete local change addressed the thread.
- Validation passed, or was blocked by a reported environment issue after a complete fix.
- The addressing commit was pushed to the PR branch.

Resolve with GraphQL:

```bash
gh api graphql -f threadId='<thread-id>' -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread { id isResolved }
  }
}'
```

If resolution fails after commit or push, report the failure and leave the local commit intact. Do not mark additional threads resolved based on guesswork.

## Final Response

Report:

- Addressed review thread IDs or short summaries.
- Commit SHA.
- Push target.
- Resolved thread count.
- Skipped unresolved threads and why they were skipped.
- Validation commands and results.

If no actionable unresolved threads exist, say so, make no commit, and report any unresolved skipped items.
