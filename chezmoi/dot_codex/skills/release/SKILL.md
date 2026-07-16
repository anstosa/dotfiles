---
name: release
description: "[Potato] Build and release a version or branch to one or more target environments through GitHub Actions. Use when the user invokes `$release`, asks to build a release branch/version and deploy it, or provides a branch/version plus environment targets such as `$release 2.1.10 rivendell`, `$release rivendell 2.1.10`, or `$release main shire rivendell`."
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# [Potato] Release

Build the application from a requested branch/version, wait for or reuse a successful build workflow run, resolve the automated tag produced by that build, then trigger the manual deploy workflow for each requested environment.

## Workflow

1. Parse the release target and environment targets.
   - Accept one branch/version/ref and one or more target environments in any order.
   - If the user supplied explicit labels such as `branch`, `ref`, `version`, `environment`, or `env`, honor those labels.
   - Resolve repository environments before resolving unlabeled Git refs.
   - If an unlabeled value resolves to a GitHub environment, always treat it as an environment, even when an origin branch or tag has the same name.
   - If an unlabeled value does not resolve as an environment, resolve it as a Git ref and try `release/<value>` before rejecting it.
   - Stop before dispatching if zero or multiple unlabeled values resolve as the build ref.

2. Confirm repository and GitHub access.
   - Run from the application repository that owns the GitHub Actions workflows.
   - Verify `gh auth status` succeeds.
   - Verify both workflows are available with `gh workflow view "Build application"` and `gh workflow view "manual deploy"`.
   - Resolve GitHub environments with `gh api repos/<owner>/<repo>/environments` so environment names take precedence over same-named branches.
   - Stop before dispatching if the branch/ref or target environments are ambiguous.

3. Reuse or run the build workflow.
   - Resolve the build ref to its latest remote commit SHA when it is a branch.
   - Before dispatching `Build application`, inspect recent build runs for the branch.
   - If a completed successful build already exists for the latest branch commit, reuse that build run and do not dispatch another build.
   - If no successful build exists for the latest branch commit, dispatch `Build application` with `--ref <resolved-build-ref>`.
   - Watch the triggered run until it completes.
   - Stop if the build run fails, is cancelled, times out, cannot be found, or has any non-success conclusion.
   - Resolve the automated Git tag created by the successful build run from build logs and/or remote tags for the build commit.
   - Stop rather than deploying when the automated build tag cannot be identified uniquely.

4. Run manual deploy only after a successful build tag is known.
   - Dispatch `manual deploy` on workflow ref `main` once per target environment.
   - Pass these inputs by default:
     - `workflow=main`
     - `ref=<automated-build-tag>`
     - `target_environment=<requested-environment>`
   - Reuse the same automated build tag for every target environment.
   - If GitHub rejects an input name, inspect `gh workflow view "manual deploy" --yaml`, map the intent to the actual input names, and retry only when the correct mapping is clear.
   - Watch each deploy run when practical. If a run waits on environment approval, report the approval URL/status instead of claiming completion.
   - After watched deploys succeed, print exactly one copy-pasteable announcement: ``Deployed `<TAG>` to <ENVIRONMENT(s)>``.

## Helper Script

Prefer the bundled helper for normal releases:

```bash
python ~/.codex/skills/release/scripts/release.py 2.1.10 rivendell
python ~/.codex/skills/release/scripts/release.py rivendell 2.1.10
python ~/.codex/skills/release/scripts/release.py main shire rivendell
```

From this repository checkout, the script path may instead be:

```bash
python /home/ubuntu/skills/.codex/skills/release/scripts/release.py 2.1.10 rivendell
```

Useful options:

- `--dry-run`: Resolve inputs and print the GitHub CLI commands without dispatching workflows.
- `--ref <branch-or-version>` and `--environment <env>`: Avoid positional inference.
- `--environment <env>` may be repeated or comma-separated for multiple deploy targets.
- `--timeout-minutes <n>`: Set the maximum wait per workflow run.
- `--no-watch-deploy`: Trigger deploy and stop after reporting the queued run.

## Reporting

Report:

- Resolved build ref, latest commit SHA when available, and target environments.
- Build workflow run URL and conclusion, including whether it was reused or newly dispatched.
- Automated build tag used as the deploy `ref`; never report a branch or commit SHA as the deployed artifact.
- Deploy workflow run URL and conclusion or queued/approval status for each environment.
- Copy-pasteable success message in the form ``Deployed `<TAG>` to <ENVIRONMENT(s)>`` after successful watched deploys.
- Any blocker with the exact command or GitHub error that blocked progress.

## Guardrails

- Treat `$release` invocation with branch/version and environment targets as approval to dispatch these two GitHub Actions workflows for those environments.
- Do not deploy if the build workflow does not complete successfully.
- Do not deploy a branch, commit hash, or input ref; deploy only the automated tag produced by the successful build.
- Do not start a new build when a successful build already exists for the latest branch commit.
- Do not classify a known environment as a branch just because a same-named branch exists.
- Do not guess when zero or multiple unlabeled inputs resolve as refs after environment matching.
- Do not change code, commit, push, tag, or edit workflow files as part of this skill.
