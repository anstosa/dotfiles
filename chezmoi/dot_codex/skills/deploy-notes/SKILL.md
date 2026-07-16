---
name: deploy-notes
description: Generate customer changelogs, internal changelogs, and business-readable testing plans from two git tags or deploy tags. Use when the user invokes $deploy-notes, asks for deploy notes, release notes, customer changelogs, internal changelogs, or non-developer testing steps for a tag range.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Deploy Notes

Use this skill to turn an old deployed git tag and a new target git tag into concise deploy notes for customers, internal teams, and business testers. Keep the repository unchanged; this workflow is evidence gathering and writing only.

## Inputs

Require two refs from the user:

- Old tag: the currently deployed tag or previous release boundary.
- New tag: the target tag or release boundary.

If either tag is missing, ask for only the missing tag or tags before generating notes. If the user says "latest tag" or similar, resolve it from git tags using repository naming conventions first, then tag creation date or sequence as a fallback. When practical, compare local tags with remote tags using a read-only command such as `git ls-remote --tags --refs origin`.

## Workflow

1. Inspect the repository state.
   - Run `git status --short --branch` so the final response can distinguish pre-existing local changes from skill activity.
   - Do not edit repository files, stage changes, commit, push, run destructive commands, or fetch unless needed for tag evidence.
   - If temporary analysis files are unavoidable, create them outside the repository or remove them before responding.

2. Resolve the comparison range.
   - Use `OLD_TAG..NEW_TAG` as the canonical range name in notes and evidence.
   - Confirm both refs resolve with `git rev-parse OLD_TAG^{}` and `git rev-parse NEW_TAG^{}`.
   - If either ref is ambiguous or missing, stop and ask for a corrected tag instead of guessing.

3. Inspect release evidence.
   - List commits with `git log --reverse --date=short --pretty=format:'%h %ad %an %s' OLD_TAG..NEW_TAG`.
   - Read relevant commit bodies with `git show -s --format='%h %s%n%b' <commit>`.
   - Inspect changed files with `git diff --name-status --find-renames OLD_TAG..NEW_TAG`.
   - Inspect hotspots with `git diff --stat --find-renames OLD_TAG..NEW_TAG`.
   - Read source diffs only where commit messages and file names are not enough to identify user-visible behavior, rollout risk, access tier, or testing needs.

4. Synthesize changes by behavior.
   - Group related commits into coherent product or operational changes.
   - Do not output one changelog bullet per commit unless each commit is truly a separate user-visible change.
   - Separate evidence from inference. If access tier, gating, or impact is inferred from routes, flags, settings, docs, or product names, word the bullet as the best-supported conclusion and avoid overclaiming.

5. Write the deploy notes.
   - Use the output shape below exactly.
   - Prefer repository product names, plan names, feature names, and UI wording found in the evidence.
   - Keep customer-facing notes free of implementation details.
   - Keep internal notes business-readable while including operational details that support rollout and support work.
   - Keep business testing as manual product or admin steps, not developer validation.

## Access Tags

Prefix every internal-facing bullet with one bracketed access tag. Use the lowest-level audience or plan that has default access to the changed area. Prefer repository-specific tier names when the code or docs prove them; otherwise use the standard tags below.

- `[Open Access]` — public or unauthenticated flows such as signup, login, MFA, password reset, public pages, public docs, and email delivery before workspace access.
- `[Free]` — authenticated baseline workspace or product areas available to free users by default.
- `[Plus]` — paid self-service user areas or features restricted to Plus-like plans.
- `[Enterprise]` — enterprise workspace features, tenant management, SSO, security settings, admin settings, managed content, or functionality normally available only to enterprise workspaces.
- `[Optimizer]` — optimizer, DOE, protocol, or robotics workflows gated by an optimizer product area or feature flag. If the repository evidence shows this surface is enterprise-only for the deployment, use `[Enterprise]` instead.
- `[Internal]` — developer, operator, infrastructure, CI, observability, migration, build tooling, dependency, background-worker, or operational systems not exposed as normal customer product surface.
- `[Unknown]` — use only when the changed area is significant and no access tier can be supported after reasonable inspection; include the reason in the bullet.

## Output Format

Start with a short preface confirming the old tag, new tag, compared range, commit count, and whether the working tree remained unchanged by this workflow.

Then produce exactly these top-level sections in this order.

### 1. Customer changelog

Audience: customers and end users. Keep this concise, descriptive, and implementation-free.

Use these subsections in this order:

1. `Breaking changes`
   - Include only user-visible removals, incompatible workflow changes, or actions users must take.
   - Hide this subsection when there are no breaking changes.
2. `New features`
   - Include new user-facing features and meaningful feature improvements.
   - Describe what users can now do or what they will notice.
   - Do not mention migrations, schemas, refactors, internal queues, implementation classes, or PR numbers unless the user explicitly asks.
3. `Bug fixes`
   - List major user-visible bug fixes individually.
   - If fixes are routine or numerous but not individually notable, write one bullet: `Bug fixes and performance improvements.`

If no customer-facing changes are identified, write one bullet under `New features`: `No customer-facing changes identified.`

### 2. Internal changelog

Audience: non-developer internal teams such as support, success, product, sales, and operations.

Use these subsections in this order:

1. `Breaking changes`
2. `New features`
3. `Bug fixes`

Rules:

- Enumerate every significant change, including changes that were grouped or omitted from the customer changelog.
- Prefix every bullet with one access tag, such as `[Open Access]`, `[Free]`, `[Enterprise]`, `[Optimizer]`, or `[Internal]`.
- Include implementation details only when they help internal teams understand rollout, support impact, operations, risk, data effects, gating, notifications, migrations, or troubleshooting.
- Avoid raw code jargon unless it is operationally relevant.
- If a subsection has no items, write `None identified.` under that subsection.

### 3. Business testing

Audience: non-developers. Provide step-by-step manual testing instructions.

Rules:

- Group tests by feature or workflow, not by commit.
- Prioritize high-risk, user-visible, revenue-impacting, support-impacting, and recently changed workflows.
- Write steps that can be followed in the product, browser, or admin UI.
- Include expected results in the steps.
- Mention required account type, workspace type, feature flag, fixture, or setup when relevant.
- Avoid commands, SQL, logs, unit tests, automated checks, or developer-only validation unless the user explicitly asks for technical validation.

Recommended test item format:

```markdown
#### Feature or workflow name
Access/setup: <account, workspace, feature flag, fixture, or other setup>
1. Do the first action.
2. Do the second action.
3. Confirm <expected result>.
```

## Guardrails

- Do not make repository code changes for this skill.
- Do not invent tags, commits, release impact, access tiers, or test coverage.
- Do not expose implementation details in the customer changelog.
- Do not omit internal access tags.
- Do not include developer commands in business testing.
- Do not claim the working tree is unchanged unless the final status supports it.
