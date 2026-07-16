---
name: test-urls
description: Generate a copy-pasteable list of local browser URLs for manually testing every user-visible change in the current branch. Use when the user invokes $test-urls or asks for local URLs, manual test links, browser QA targets, or fixture-backed links for changed UI/API behavior.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Test URLs

Use this skill to produce local live-app browser links that exercise the current branch's changed behavior. The output is a plain list: each item has a one-line description followed by the URL on the next line. Do not use a table. Prefer real application routes with real local fixture IDs; Storybook links do not count unless the user explicitly asks for Storybook.

## Workflow

1. Inspect the workspace instructions first: repository `AGENTS.md`, `docs/agents/local-dev.md`, `docs/agents/ui.md`, and any deeper relevant `AGENTS.md` files.
2. Identify changed behavior from the branch, not just dirty files:
   - Check status: `git status --short`.
   - Determine a merge base, usually `git merge-base HEAD origin/main` after fetching only if needed.
   - Inspect names and diffs: `git diff --name-status <merge-base>...HEAD` and targeted `git diff <merge-base>...HEAD -- <paths>`.
   - Include uncommitted changes if present.
3. Map each user-visible change to the narrowest local route that would exercise it:
   - Prefer live UI routes under `http://localhost:<POTATO_HOST_PORT_UI>` for UI or API-facing UI changes.
   - For app routes containing `/project/:projectKey`, always use the **project key**, not the tenant/workspace key. Resolve it from the app/API tenant list (`project_key` on `/tenant/list` responses), the `projects` table, or the route's existing fixture data before emitting the URL. Do not assume a tenant key can be substituted for a project key even when it appears in the source entity.
   - Verify route paths from the app router before emitting URLs. Do not infer suffixes from component names: some progress pages are mounted under non-`/progress` paths such as `/generate` or `/view`.
   - Do not use Storybook as a fallback for app UI changes unless the user explicitly requests Storybook links. If no app fixture exists, report `No URL` with the missing fixture/data reason instead of substituting Storybook.
   - For progress-page migrations or progress UI changes, enumerate every modified progress page or embedded progress surface from the branch diff, then provide one live app route per reachable page/state. Use existing fixture-backed IDs where possible; include concise `No URL` items for modified progress pages whose backing queues/entities have no live fixtures after reasonable discovery.
   - Use direct API/docs/health URLs only when browser navigation is the most useful way to verify non-UI behavior.
4. Resolve the base host and port from local config, not memory:
   - Read `.env` and Compose/docs for `POTATO_HOST_PORT_UI` and `POTATO_HOST_PORT_STORYBOOK`; default to `http://localhost:80` and `http://localhost:6006` only when unset.
   - If the current workspace is running in UI-only mode (`./potato.sh start uionly`), use this worktree's UI port for links but consider data in the primary workspace/API stack when choosing routes and fixtures. Check `POTATO_UI_API_PROXY_TARGET`, `.env` port offsets, `./potato.sh status`, and `./potato.sh db info` as needed.
5. If a route needs existing entities, find or create fixture data so the URL is testable:
   - Prefer existing seed/demo data from the active primary stack.
   - Use the running live app/API/browser session when available to discover project keys, tenant keys, and entity keys; authenticated `fetch('/api/tenant/list')` or equivalent API calls from Playwright are often the fastest way to map a tenant/workspace to the project key required by `/project/...` routes.
   - If data is missing, create the smallest safe realistic fixture in the relevant database using project wrappers such as `./potato.sh db query` / `db query-file`, existing test-data scripts, or documented app flows.
   - Do not invent unrealistic rows just to make a URL exist. If realistic fixture data cannot be safely generated for a particular route after reasonable discovery, report `No URL` for that route and include a numbered in-product setup path: the exact product steps a tester should complete to create the real data and then navigate to the page where the changed behavior can be observed.
   - Keep fixtures clearly identifiable (for example names prefixed `test-urls`), avoid destructive changes, and report what was created.
   - For UI-only worktrees, create/read fixtures in the primary workspace database/API target, not an absent secondary DB.
6. Verify URLs when practical:
   - Confirm services/ports are running with `./potato.sh status` or a lightweight HTTP check.
   - Cross-check every emitted app path against the UI route definitions or equivalent router source, especially changed progress surfaces whose visible component name may not match the URL suffix.
   - Check at least one emitted `/project/...` URL uses a key present in the active tenant list's `project_key` values or in the `projects.key` column. If only a tenant/workspace key is known, resolve the project key before returning the list.
   - If using browser tooling, open the most important route and confirm it loads enough to be useful.
   - Do not run destructive commands such as DB refresh/reset unless explicitly requested.

## Output format

Return only the useful test list plus any brief fixture note. Each URL must be on its own line immediately after its description so it can be copied into a browser.

```text
[Description of the changed behavior/state to test]
http://localhost:<port>/<path>

[Another changed behavior/state to test]
http://localhost:<port>/<path>
```

If a change cannot be tested through a live app URL even after fixture discovery/creation, include a short `No URL` item with the exact missing fixture/data reason. If the blocker is missing realistic product data, include a numbered list of in-product steps to create the real data and navigate to the page where it can be observed. Do not replace missing app routes with Storybook links unless explicitly requested.
