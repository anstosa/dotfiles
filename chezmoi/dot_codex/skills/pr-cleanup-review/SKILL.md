---
name: pr-cleanup-review
description: Review current branch changes from the merge base to HEAD for cleanup-oriented code review findings, including automated test quality. Use when Codex should inspect a PR or branch diff and report up to three high-confidence cleanup issues for each applicable checklist category in changed code or tests.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# PR Cleanup Review

Review the merge base `origin/main` and `HEAD` (unless the user specifies a different base) with a narrow cleanup lens. Focus on real issues in touched code, not general style advice or whole-repo refactors.

Run the review as two focused passes, then aggregate the findings:

- Backend review agent: inspect backend-relevant changed files with the common checks and backend checks.
- UI review agent: inspect UI-relevant changed files with the common checks and frontend checks.
- Parent aggregator: merge, deduplicate, and rank the findings from both agents.

If sub-agents are unavailable in the active environment, run the same two scoped passes locally and then aggregate the results.

## Workflow

1. Determine the review range and touched files.
    - Use `git merge-base HEAD origin/main` as the default base unless the user specifies another base or range.
    - Start with `git diff --name-only $(git merge-base HEAD origin/main)..HEAD` or the user-specified range.
    - For migration reviews, record the files that already existed at the review base with `git ls-tree -r --name-only <base> components/db/migrations/`.
    - For migration reviews, audit changed migration versions against Flyway history already applied to `dev` when that evidence is available.
    - Treat a green application build on `main` as evidence that the included migrations deployed successfully to `dev`.
    - Treat every `dev`-applied migration's version, script filename, and checksum/content as immutable; flag any branch edit, rename, renumber, deletion, or replacement of that deployed migration as blocking.
    - If `dev` history is unavailable, treat review-base migrations as potentially deployed and require explicit evidence before allowing their version, filename, or content to change.
    - Treat changes, renames, renumbers, or deletions of migrations that pre-existed the current branch as prohibited unless the user explicitly requested that exact migration edit.
    - When a migration edit or rename is requested to resolve duplicate Flyway versions, preserve any version/name/checksum already applied to `dev` first, then use original commit chronology only for conflicting migrations that have not deployed to `dev`.
    - Classify touched files into backend-relevant and UI-relevant paths.
    - Treat `components/ui/`, UI tests, UI styles, generated-client consumers, and frontend build files as UI-relevant.
    - Treat Python services, workers, migrations, shared Python libraries, service tests, infrastructure code that feeds backend behavior, and API schema code as backend-relevant.
    - Treat automated test files as first-class review targets, not only as supporting evidence for production-code findings.
    - If a file affects both surfaces, include it in both reviews.

2. Split the review into two sub-agents.
    - Spawn one backend review agent. Give it the review range, backend-relevant changed files, the Common Cleanup Checks, the Backend Cleanup Checks, the Automated Testing Checks when backend tests or high-risk legacy backend code are touched, and the shared evidence rules.
    - Spawn one UI review agent. Give it the review range, UI-relevant changed files, the Common Cleanup Checks, the Frontend Cleanup Checks, the Automated Testing Checks when UI tests or high-risk legacy UI code are touched, and the shared evidence rules.
    - Each sub-agent should inspect patches with `git diff <range> -- <path>` and pull only the minimum surrounding context needed to understand contracts and call sites.
    - Each sub-agent should return only findings from its assigned check groups, with no more than three findings per checklist category.
    - Each sub-agent should say clearly when it found no credible issues.

3. Apply the shared evidence rules in each review pass.
    - Tie every finding to changed lines or directly affected neighboring code.
    - Verify the current contract from callers, types, tests, schemas, or comments before calling a check unnecessary.
    - Verify repetition by finding all copies with `rg`.
    - Treat test deletions or consolidation as valid only when coverage remains explicit.
    - For test findings, verify whether the asserted detail is a real product/API contract before calling it brittle.
    - Prefer high-confidence findings over broad architectural opinions.
    - Do not pad a category with weak nits. If no credible issues exist in any category, say so.

4. Aggregate the sub-agent results.
    - Combine findings from the backend and UI agents.
    - Deduplicate findings that point to the same cleanup issue from shared or cross-surface files.
    - Keep the stronger explanation when duplicate findings disagree, and mention uncertainty if the evidence is incomplete.
    - Order categories by severity, then confidence.
    - Do not show categories where there are no findings.
    - Return the final answer in the Output Format below.

## Check Groups

### Common Cleanup Checks

Run these checks on both backend-relevant and UI-relevant changed code:

- Unnecessarily complex control flow that can be simplified without changing behavior.
- Checks inside helpers that contradict trusted internal contracts.
- Legacy data format support or format-detection branches that can be removed.
- Pure passthrough functions or orphaned code left behind by the change.
- Utility logic repeated 3 or more times that should move to one helper.
- Redundant tests that should collapse into smaller targeted tests.
- "Optional" fields that are actually required and only survive through fallback values.

### Automated Testing Checks

Run these checks on changed automated tests, changed test helpers, and high-risk legacy refactors that should have explicit test protection:

- Tests that assert implementation details instead of observable behavior or stable contracts.
- UI tests that rely on exact copy, raw text content, test-only `data-*` probes, CSS classes, private helper names, or route wiring internals when those details are not the contract under test.
- Backend tests that assert exact error messages, log lines, tracebacks, email bodies, or other human-readable text when status codes, structured response fields, machine-readable error codes, persisted rows, emitted jobs, or external command payloads would prove the behavior more stably.
- Tests that mock ordinary collaborators, shared UI controls, or local implementation details instead of mocking real nondeterministic or external boundaries such as network calls, model providers, subprocesses, time, randomness, or storage.
- Page-local UI control mocks that duplicate shared test doubles already available under `components/ui/src/ts/test/`.
- Large or heavily edited test files that mix unrelated behavior regions, hide preconditions behind fixture mazes, or extract helpers that obscure rather than clarify setup.
- High-risk legacy refactors that changed behavior without characterization tests for existing edge cases, error paths, or business invariants.
- Coverage-only or line-count-driven tests that do not assert a meaningful behavior, contract, or regression risk.

### Backend Cleanup Checks

Run these checks on backend-relevant changed code:

- Dataclasses that should use both `kw_only=True` and `slots=True`.
- Dict-shaped internal data that should become dataclass objects to simplify typing and validation.
- Prefer the use of `asdict` and `dacite` to custom functions on dataclasses.
- OpenAPI-facing Python `Literal` types that should be shared `Enum` types.
- New DB tables with `created` and `modified` columns that are missing the standard insert/update timestamp triggers in the migration or canonical table DDL.
- Flyway migrations that include unnecessary transaction wrappers such as `begin` at the beginning or `commit`/`end` at the end.
- Flyway migrations already applied to `dev` whose version, script filename, or checksum/content changed in the branch.
- Flyway migrations that were edited, renamed, renumbered, or deleted after already existing at the review base, unless the user explicitly requested that exact migration edit.
- Requested duplicate-version migration fixes that fail to preserve the version/name/checksum already applied to `dev`, or that assign the disputed version to a later-committed migration when no conflicting migration has deployed to `dev` and an earlier-committed conflicting migration should keep it.

### Frontend Cleanup Checks

Run these checks on UI-relevant changed code:

- Exports that are not consumed outside the file where they are used.
- One-off code that closely mirrors an existing component or function instead of using it.
- Orphaned code that is not used anywhere, including routes that are never linked to.
- React: Elements visually hidden to non-admins should use the `useMode()` hook, not `self.admin`.
- React: Changed routes without redirects from the old route to the new route.
- React: Grid etiquette
  - Use utilities in columns.tsx if relevant when declaring columns.
  - Do not set absolute widths on columns unnecessarily.
  - Declare columns one at a time as strongly typed column definitions based on the column value instead of in one big array.
  - Do not disable sorting unless it actually doesn't make sense for that datatype
  - Do not use empty or loading components outside the Grid when data is empty or loading. use `emptyMessage`, `loading`, and `loadingMessage`
- React: Don't pass constant `true` into boolean props. Just declare the prop.
- API: Direct endpoint calls where the built API client should be used instead.
- API: Code that duplicates generated OpenAPI models instead of using the built types.
- UI: Data-table/list views that need built-in grid affordances should use the shared `controls/grid/Grid` component and `controls/grid/columns` helpers instead of hand-rolled table, toolbar, filtering, pagination, export, row-action, or empty-state code.
- UI: Progress `Work`/`WorkDef[]` lists should define every possible item inline and use `show` for visibility and `active` for currently-running state, instead of `if` statements, helper callbacks, loops, or other control flow that conditionally adds items to the array.
- UI: Font Awesome usage must not add or import the all-inclusive `@fortawesome/fontawesome-pro` package, or import from a style package root such as `@fortawesome/pro-regular-svg-icons`; use direct icon imports from individual style packages instead.
- TypeScript: Nested ternary operators instead of if/else or switch statements.
- TypeScript: Imports that are only used as types but are imported as values.
- TypeScript: Abbreviations in functions or variables other than allowlisted terms: `props`, `config`, or `elem`.
- TypeScript: non-null assertions instead of optional chaining or type guards.
- TypeScript: use of `as` instead of type assertions, narrowing, or type guards.
- TypeScript: use of `any` or `unknown` outside of narrowing utility functions.
- TypeScript: use of `bind`.
- TypeScript: use of literal string types instead of `Enum`s.
- CSS: prefer flex over CSS Grid for ordinary one-dimensional layout.
- CSS: equal-specificity overrides across generic and page/component classes that can depend on dev vs production stylesheet order.
- UI: Buttons that kick off destructive actions that don't use a confirmation modal.
- Analytics: Segment or product analytics calls that can block product workflows,
  navigation, saves, submits, or render paths. Analytics must be best-effort and
  must never be awaited on product paths, including delivery, client setup,
  dynamic imports, flushes, callbacks, or network requests. The affected
  workflow must still work when a client ad blocker blocks Segment scripts or
  requests.

## Review Heuristics

### Complex Control Flow

Prefer collapsing nested conditionals, duplicate early returns, boolean ladders, and branch pairs that compute the same outcome.

### Contract-Violating Checks

Flag checks that re-validate trusted internal shapes from database rows, generated clients, or typed internal helpers. Ignore trust-boundary validation for user input or third-party data.

### Legacy Format Support

Flag compatibility branches, version sniffing, migration shims, or explicit old-format rejection paths when the codebase can assume the new format only.

### Passthrough and Orphan Code

Flag wrappers that only rename arguments or forward results unchanged, plus dead helpers, tests, or types left unused after the commit.

### Duplicated Utility Logic

Flag the third copy and beyond of the same parsing, normalization, fallback, or mapping logic. Prefer a shared helper at the narrowest useful scope.

### Redundant Tests

Prefer focused unit tests around the extracted helper or branch logic. Flag broad end-to-end tests that merely restate covered behavior without adding scenario value.

### Automated Test Contract Focus

Flag automated tests that prove implementation details rather than behavior. Prefer assertions over returned values, accessible UI structure, form state, navigation targets, persisted state, emitted events or jobs, boundary payloads, status codes, structured JSON fields, and machine-readable error codes. Skip this finding when the exact private detail, copy, route dependency, CSS class, or mock interaction is explicitly the product/API contract being protected.

### Stable UI Test Assertions

Flag changed UI tests that use `getByText`, `queryByText`, `toHaveTextContent`, raw `textContent`, CSS classes, private helper names, route wiring internals, exact mock call order, or test-only `data-*` attributes when the same behavior can be asserted through roles, accessible names, control state, visibility, navigation targets, emitted payloads, or visible/hidden regions. Exact copy assertions are acceptable only when the wording itself is the contract under test.

### Stable Backend Test Assertions

Flag changed backend tests that depend on exact error-message, log-line, traceback, email-body, or other human-readable response text when structured behavior is available. Prefer status codes, response fields, machine-readable error codes, persisted rows, emitted queue or job payloads, and external command payloads. Exact text assertions are acceptable only when that text is the product/API contract.

### Test Boundary Mocking

Flag tests that mock normal in-process collaborators just to observe wiring or force implementation details. Prefer real collaborators, fakes, or small contract tests unless the dependency is a true nondeterministic or external boundary such as network, time, randomness, model providers, subprocesses, or storage. For UI tests, prefer shared test doubles under `components/ui/src/ts/test/` before adding page-local Button, ButtonMenu, Tab, or similar control mocks.

### Test Fixture Shape

Flag large or heavily edited test files when unrelated behavior areas share sprawling fixtures, setup hides the preconditions under test, or helpers make the scenario harder to read. Prefer splitting by behavior area, keeping setup near the tests that need it, and extracting helpers only when they clarify repeated behavior.

### Characterization Tests

Flag high-risk legacy refactors that change behavior without automated characterization tests around existing edge cases, error paths, or business invariants. Do not require broad line coverage; require risk-based assertions that would catch the likely regression.

### Fake-Optional Fields

Flag fallback defaults for fields that are effectively required by all call sites, type definitions, schema expectations, or tests.

### Dataclass Structure

Flag dataclasses introduced or touched by the commit that do not use both `kw_only=True` and `slots=True`, unless a nearby constraint proves they cannot.

### Dicts vs Dataclasses

Flag internal dictionary-shaped data flows that would become clearer and safer as dataclass objects, especially when the change already repeats field-name validation, shape checks, or string-key access.

### asdict and dacite over Custom Dataclass Helpers

Flag custom dataclass conversion helpers when `dataclasses.asdict` and `dacite` would cover the touched use case with less bespoke code. Skip cases that need custom transformation, trust-boundary validation, or mapping-compatible behavior that these tools would not preserve.

### Unused UI Exports

Flag `export`ed UI values that are only used within the same file. Prefer keeping them file-local unless a real external consumer exists.

### Generated OpenAPI Types

Flag handwritten UI interfaces or type aliases that duplicate generated OpenAPI models already available to the touched code. Prefer the generated types when they fit the current payload and remove duplicate shape definitions.

### Existing UI Components

Flag one-off UI code that closely mirrors an existing component. Prefer the existing component when it fits the interaction and visual contract.

### Shared Grid Component

Flag changed UI that builds a bespoke data grid or table when it needs two or more capabilities already provided by `controls/grid/Grid`, such as sortable/filterable columns, search, pagination, row clicks, header actions, export/copy actions, loading state, or empty-state messaging. Also flag local copies of common grid cell renderers when `controls/grid/columns` already provides the same link, title/subtitle, copyable, date, action, or status cell behavior. Skip static mini-tables, approval summaries, dense scientific comparison tables, markdown-rendered tables, and genuinely bespoke layouts where the shared Grid contract would reduce clarity or semantics.

### Font Awesome Package Size

Flag changed UI dependency, lockfile, or source-import code that adds `@fortawesome/fontawesome-pro`, imports from `@fortawesome/fontawesome-pro`, or imports from a Font Awesome style package root such as `@fortawesome/pro-solid-svg-icons`. The all-inclusive package contains every asset format and style and can burn private npm bandwidth quickly; pack-root imports also make it easier to accidentally pull broader modules. Prefer direct icon imports such as `@fortawesome/pro-regular-svg-icons/faPlus` from the narrow style packages already used by the UI.

### Declarative Progress Work Lists

Flag changed progress-page code that builds `Work`/`WorkDef[]` arrays by starting with an empty array and conditionally calling `push`, by using helper callbacks such as `pushSlot`/`pushProgress`, or by returning different Work-list shapes from `if`/`else` branches. Progress Work lists should enumerate every possible item inline in one array and let each item decide presence with `show`; item progress state should use `active`, not array membership. Skip non-progress arrays and dynamic data-to-Work mapping where each array element represents genuinely unbounded server data rather than a fixed progress step.

### Orphaned UI Code

Flag UI components, helpers, tests, or routes left unused after the change. Verify route reachability and imports before calling code orphaned.

### Route Redirects

Flag changed UI routes that do not preserve user navigation through a redirect from the old route. Skip cases where the old route was internal-only and all entry points moved with the change.

### Built API Client

Flag direct endpoint calls in UI code when the generated API client already exposes the same operation. Prefer the built client unless the touched code proves a missing capability or a deliberate exception.

### TypeScript Cleanup

Flag non-null assertions, broad `as` casts, `any`, `unknown`, `bind`, nested ternaries, and literal string type sets when the touched code can use safer narrowing, optional chaining, handlers, switches, or generated/shared enums.

### Non-Blocking Analytics

Flag changed frontend analytics code when Segment delivery, flushes, dynamic
imports, analytics-client setup, callbacks, or analytics network requests are
awaited on the user workflow path. Product workflows, navigation, saves,
submits, and render paths must never fail, hang, or wait on analytics when
browser privacy tools or ad blockers block Segment scripts or requests. Prefer
fire-and-forget best-effort wrappers with swallowed analytics errors.

### Admin Visibility

Flag UI visibility gates that hide controls from non-admins through `self.admin`. Prefer `useMode()` so admin-only UI behavior follows the application mode contract.

### CSS Layout

Prefer flex over CSS Grid for ordinary one-dimensional layout such as a row of controls, a vertical stack, or icon-plus-label alignment. Do not confuse this with the React `Grid` data-table component. Skip CSS Grid when it is justified by true two-dimensional placement, named grid areas, subgrid alignment, responsive card matrices, chart/table layouts, or column/row spanning that flex would make less clear.

### Destructive Actions

Flag changed destructive UI actions that can run without a confirmation modal. Confirm that the action deletes, revokes, resets, overwrites, disables, or otherwise causes hard-to-reverse state changes before reporting.

### Type-Only Imports

Flag UI imports that are used only as types but imported as runtime values. Prefer `import type` to avoid accidental runtime dependency edges.

### CSS Order-Sensitive Overrides

Flag changed UI code when one element combines a generic class and a page/component class, and both selectors set the same layout or visual property with equal specificity. This is especially important for CSS imported through lazily loaded pages, because the Vite dev server and production build can insert extracted CSS chunks in different orders. Prefer one clear owner for the property, a shared modifier in the generic component stylesheet, or a deliberately more specific selector such as `.p-page__element.c-generic` so the intended override does not depend on stylesheet load order.

### Enums over Literal

Flag shared Python value sets expressed as `Literal[...]` when they participate in OpenAPI-facing models or cross-language contracts. Prefer a shared `Enum` so the generated TypeScript client gets stronger enum handling.

### DB Timestamp Triggers

Flag new tables that include `created` and `modified` columns without both `create_modified_insert()` and `modified_update()` triggers. Verify the triggers exist in the Flyway migration under `components/db/migrations/` and the canonical DDL under `components/db/tables/`; if only one source has the triggers, report the missing counterpart.

### Flyway Transaction Wrappers

Flag Flyway migrations that wrap the whole migration in transaction-control statements, such as a leading `begin` or trailing `commit`/`end`. Flyway manages migration execution transactions, so these wrappers are unnecessary noise and can interfere with migration tooling expectations. Only report changed migration files under `components/db/migrations/`, and avoid flagging transaction-related SQL that is part of a stored procedure, trigger body, or intentionally nested database construct rather than a top-level migration wrapper.

### Pre-existing Flyway Migrations

Flag changed migration files under `components/db/migrations/` when the file has already deployed to `dev`; a green application build on `main` proves the included migrations deployed successfully to `dev`. The deployed version, script filename, and checksum/content must never change. Restore the deployed migration exactly and put follow-up work in a new higher-numbered migration. If `dev` evidence is unavailable, also flag files that existed at the review base when the branch edits, renames, renumbers, or deletes them without explicit evidence that they have not deployed. When resolving duplicate-version conflicts, preserve the `dev`-applied version/name/checksum first; only when no conflicting migration has deployed to `dev`, identify each conflicting migration's original commit with `git log --all --follow -- <path>` or equivalent history, keep the earliest-committed migration at the disputed version, then renumber later-committed conflicting migrations forward.

## Output Format

Return findings first, grouped by checklist category. Do not show categories with no findings. For each finding include:

- Severity: `high`, `medium`, or `low`
- Location: file and line
- Rule: one checklist item from this skill
- Why it is an issue: 1-3 sentences
- Recommended change: one concrete cleanup
- Number the findings

List up to three findings per category. Keep the response concise and order categories by severity, then confidence. Status messages should not end in a period unless the message has multiple sentences.

If neither sub-agent finds credible cleanup issues, say that clearly and mention any residual review limits, such as unreviewed generated files or contracts that could not be proven locally.

## Guardrails

- Do not suggest deleting behavior unless the surrounding code proves the contract.
- Do not call defensive checks unnecessary at external trust boundaries.
- Do not recommend helper extraction for only two copies unless the abstraction is already clearly present.
- Do not require dataclass conversion when the data genuinely crosses a dynamic boundary or must stay mapping-compatible.
- Do not require `asdict` or `dacite` when the touched code needs custom serialization, trust-boundary validation, or transformations they cannot express cleanly.
- Do not require generated OpenAPI types or the built API client unless they already cover the touched use case.
- Do not turn dataclass or enum checks into a whole-repo audit; keep them tied to changed code or directly affected neighbors.
- Do not flag CSS overrides merely because they override a property; require equal specificity, a shared element or otherwise clear cascade interaction, and plausible chunk/order instability.
- Do not require test rewrites for exact copy, text, logs, or implementation details when the changed test proves that detail is an explicit product, API, accessibility, or compatibility contract.
- Do not require new characterization tests for low-risk edits, pure deletions of unreachable code, or refactors already covered by explicit behavior-level automated tests.
- Do not treat shared mocks as inherently better than local mocks when the local mock is modeling behavior that the shared double cannot represent.
- Do not recommend changing, renaming, renumbering, or deleting migrations that pre-existed the current branch unless the user explicitly requested that exact migration edit.
- When duplicate-version migration editing or renaming is explicitly requested, preserve deployed migration history first, then use original commit chronology for conflicts that have not deployed to `dev`.
- Do not recommend adding `@fortawesome/fontawesome-pro` or Font Awesome pack-root imports; prefer direct icon imports from individual style packages.
- Do not optimize for cleverness; optimize for smaller, clearer code.
- Mention uncertainty explicitly when the commit context is insufficient.
