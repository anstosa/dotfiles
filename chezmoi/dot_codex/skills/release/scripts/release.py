#!/usr/bin/env python3
"""Build and deploy a Potato release through GitHub Actions."""

from __future__ import annotations

import argparse
import json
import re
import shlex
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Sequence


BUILD_WORKFLOW = "Build application"
MANUAL_DEPLOY_WORKFLOW = "manual deploy"
DEFAULT_DEPLOY_REF = "main"
DEFAULT_DEPLOY_WORKFLOW_INPUT = "workflow"
DEFAULT_DEPLOY_REF_INPUT = "ref"
DEFAULT_ENVIRONMENT_INPUT = "target_environment"
UNKNOWN_BUILD_TAG = "<automated-build-tag-from-build-run>"
TAG_NAME_PATTERN = re.compile(r"refs/tags/([A-Za-z0-9][A-Za-z0-9._\/-]*)")
TAG_LINE_PATTERN = re.compile(
    r"(?:automated tag|build tag|release tag|created tag|creating tag|pushed tag|git tag|tagged)[^\n]*?[`\'\"]?([A-Za-z0-9][A-Za-z0-9._\/-]*)",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class CommandResult:
    """captured process result"""

    args: Sequence[str]
    returncode: int
    stdout: str
    stderr: str


@dataclass(frozen=True)
class ResolvedRef:
    """resolved build ref"""

    ref: str
    kind: str
    sha: str | None


@dataclass(frozen=True)
class ReleaseInputs:
    """resolved release inputs"""

    ref: str
    environments: tuple[str, ...]
    ref_kind: str
    ref_sha: str | None


@dataclass(frozen=True)
class WorkflowRun:
    """github actions run"""

    database_id: int
    url: str
    status: str
    conclusion: str | None
    head_sha: str | None = None
    created_at: str | None = None


# run external command
def run_command(args: Sequence[str], *, check: bool = False, timeout_seconds: int | None = None) -> CommandResult:
    """Run a command and capture text output."""
    completed = subprocess.run(args, text=True, capture_output=True, check=False, timeout=timeout_seconds)
    result = CommandResult(args=args, returncode=completed.returncode, stdout=completed.stdout, stderr=completed.stderr)
    # requested hard failure
    if check and result.returncode != 0:
        raise RuntimeError(format_failure(result))
    return result


# format subprocess failure
def format_failure(result: CommandResult) -> str:
    """Format a failed command for operators."""
    command = shlex.join(result.args)
    details = (result.stderr or result.stdout).strip()
    # include command context
    if details:
        return f"Command failed ({result.returncode}): {command}\n{details}"
    return f"Command failed ({result.returncode}): {command}"


# parse command line
def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    """Parse release arguments."""
    parser = argparse.ArgumentParser(description="Build an application ref and deploy it to one or more environments.")
    parser.add_argument("values", nargs="*", help="Branch/version/ref and one or more environments in any order")
    parser.add_argument("--ref", dest="explicit_ref", help="Branch, version, or ref to build")
    parser.add_argument(
        "--environment",
        "--env",
        dest="explicit_environments",
        action="append",
        help="Target environment. Repeat or comma-separate for multiple environments.",
    )
    parser.add_argument("--build-workflow", default=BUILD_WORKFLOW, help="Build workflow name")
    parser.add_argument("--deploy-workflow", default=MANUAL_DEPLOY_WORKFLOW, help="Deploy workflow name")
    parser.add_argument("--deploy-workflow-ref", default=DEFAULT_DEPLOY_REF, help="Git ref used to dispatch manual deploy")
    parser.add_argument("--deploy-workflow-input", default=DEFAULT_DEPLOY_WORKFLOW_INPUT, help="Manual deploy input key for workflow")
    parser.add_argument("--deploy-ref-input", default=DEFAULT_DEPLOY_REF_INPUT, help="Manual deploy input key for built ref")
    parser.add_argument("--environment-input", default=DEFAULT_ENVIRONMENT_INPUT, help="Manual deploy input key for target environment")
    parser.add_argument("--timeout-minutes", type=int, default=90, help="Maximum minutes to wait for each workflow")
    parser.add_argument("--poll-seconds", type=int, default=8, help="Seconds between run discovery attempts")
    parser.add_argument("--dry-run", action="store_true", help="Print planned commands without dispatching workflows")
    parser.add_argument("--no-watch-deploy", action="store_true", help="Do not wait for the deploy run to complete")
    return parser.parse_args(argv)


# check gh availability
def require_gh_auth() -> None:
    """Require authenticated gh CLI access."""
    result = run_command(["gh", "auth", "status"])
    # block unauthenticated actions
    if result.returncode != 0:
        raise RuntimeError(format_failure(result))


# ensure workflow exists
def require_workflow(name: str) -> None:
    """Require a GitHub Actions workflow by name."""
    result = run_command(["gh", "workflow", "view", name])
    # block missing workflow
    if result.returncode != 0:
        raise RuntimeError(format_failure(result))


# read repository identity
def get_repository_slug() -> str:
    """Return the GitHub owner/repository slug for the current checkout."""
    result = run_command(["gh", "repo", "view", "--json", "owner,name"], check=True)
    payload = json.loads(result.stdout)
    owner = payload.get("owner") or {}
    owner_login = owner.get("login") if isinstance(owner, dict) else None
    name = payload.get("name")
    # require complete repo identity
    if not owner_login or not name:
        raise RuntimeError("Could not determine GitHub repository owner and name.")
    return f"{owner_login}/{name}"


# list github environments
def list_environments() -> tuple[str, ...]:
    """List repository environment names from GitHub."""
    repository = get_repository_slug()
    result = run_command([
        "gh",
        "api",
        f"repos/{repository}/environments?per_page=100",
        "--paginate",
        "--jq",
        ".environments[].name",
    ], check=True)
    names = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    return tuple(dict.fromkeys(names))


# test remote ref
def remote_ref_sha(kind: str, value: str) -> str | None:
    """Return the remote SHA for an origin branch or tag."""
    ref = f"refs/{kind}/{value}"
    result = run_command(["git", "ls-remote", "--exit-code", "origin", ref])
    # skip missing refs
    if result.returncode != 0:
        return None
    first_line = result.stdout.splitlines()[0] if result.stdout.splitlines() else ""
    return first_line.split("\t", 1)[0] if first_line else None


# resolve user ref
def resolve_ref(value: str) -> ResolvedRef | None:
    """Resolve an input value to an exact branch, tag, or release branch."""
    branch_sha = remote_ref_sha("heads", value)
    # prefer exact branch
    if branch_sha:
        return ResolvedRef(ref=value, kind="branch", sha=branch_sha)
    release_value = value if value.startswith("release/") else f"release/{value}"
    release_sha = remote_ref_sha("heads", release_value)
    # fallback release branch
    if release_sha:
        return ResolvedRef(ref=release_value, kind="branch", sha=release_sha)
    tag_sha = remote_ref_sha("tags", value)
    # accept exact tag last
    if tag_sha:
        return ResolvedRef(ref=value, kind="tag", sha=tag_sha)
    return None


# expand environment inputs
def expand_environment_values(values: Sequence[str]) -> list[str]:
    """Expand repeated or comma-separated environment arguments."""
    expanded: list[str] = []
    # split each explicit value
    for value in values:
        parts = [part.strip() for part in value.split(",")]
        # keep non-empty parts
        for part in parts:
            # ignore empty comma chunks
            if part:
                expanded.append(part)
    return expanded


# dedupe environments
def dedupe_environments(values: Sequence[str]) -> tuple[str, ...]:
    """Return environments in first-seen order without duplicates."""
    unique: list[str] = []
    # preserve operator order
    for value in values:
        # skip duplicates
        if value not in unique:
            unique.append(value)
    return tuple(unique)


# resolve environment name
def resolve_environment(value: str, environments: Sequence[str]) -> str | None:
    """Resolve an input value to a known GitHub environment name."""
    # exact environment match
    if value in environments:
        return value
    lower_value = value.lower()
    matches = [environment for environment in environments if environment.lower() == lower_value]
    # unique case-insensitive match
    if len(matches) == 1:
        return matches[0]
    return None


# reject missing environments
def require_environments(values: Sequence[str]) -> None:
    """Require at least one target environment."""
    # require deploy targets
    if not values:
        raise ValueError("Provide at least one target environment.")


# resolve release inputs
def resolve_inputs(args: argparse.Namespace, environments: Sequence[str]) -> ReleaseInputs:
    """Resolve branch/ref and one or more environments from explicit or positional inputs."""
    values = list(args.values)
    explicit_ref = args.explicit_ref
    explicit_environments = expand_environment_values(args.explicit_environments or [])
    # resolve explicit ref
    if explicit_ref:
        resolved = resolve_ref(explicit_ref)
        # require explicit ref resolution
        if not resolved:
            raise ValueError(f"Could not resolve ref '{explicit_ref}' or 'release/{explicit_ref}'.")
        target_environments = dedupe_environments([*explicit_environments, *values])
        require_environments(target_environments)
        return ReleaseInputs(
            ref=resolved.ref,
            environments=target_environments,
            ref_kind=resolved.kind,
            ref_sha=resolved.sha,
        )
    # use labeled environments with one positional ref
    if explicit_environments:
        # require exactly one positional build ref
        if len(values) != 1:
            raise ValueError("Provide exactly one positional ref when --environment is supplied without --ref.")
        resolved = resolve_ref(values[0])
        # require positional ref resolution
        if not resolved:
            raise ValueError(f"Could not resolve ref '{values[0]}' or 'release/{values[0]}'.")
        target_environments = dedupe_environments(explicit_environments)
        require_environments(target_environments)
        return ReleaseInputs(
            ref=resolved.ref,
            environments=target_environments,
            ref_kind=resolved.kind,
            ref_sha=resolved.sha,
        )
    # require unlabeled ref plus environment values
    if len(values) < 2:
        raise ValueError("Provide a branch/version/ref and at least one environment, in any order.")
    ref_matches: list[ResolvedRef] = []
    target_environments: list[str] = []
    unresolved_values: list[str] = []
    # classify environments before refs
    for value in values:
        environment = resolve_environment(value, environments)
        # environment names win over same-named branches
        if environment:
            target_environments.append(environment)
            continue
        resolved = resolve_ref(value)
        # collect possible build refs
        if resolved:
            ref_matches.append(resolved)
            continue
        unresolved_values.append(value)
    # require exactly one build ref
    if len(ref_matches) != 1:
        # distinguish no ref from ambiguous refs
        if not ref_matches:
            raise ValueError("No positional value resolved as a ref, even after trying release/<value>.")
        refs = ", ".join(match.ref for match in ref_matches)
        raise ValueError(f"Multiple positional values resolve as refs ({refs}); pass --ref and --environment explicitly.")
    target_environments.extend(unresolved_values)
    resolved_ref = ref_matches[0]
    resolved_environments = dedupe_environments(target_environments)
    require_environments(resolved_environments)
    return ReleaseInputs(
        ref=resolved_ref.ref,
        environments=resolved_environments,
        ref_kind=resolved_ref.kind,
        ref_sha=resolved_ref.sha,
    )


# build gh dispatch command
def build_dispatch_command(workflow: str, ref: str) -> list[str]:
    """Build the gh command for the application build."""
    return ["gh", "workflow", "run", workflow, "--ref", ref]


# build deploy command
def deploy_dispatch_command(args: argparse.Namespace, deploy_ref: str, environment: str) -> list[str]:
    """Build the gh command for manual deploy."""
    return [
        "gh",
        "workflow",
        "run",
        args.deploy_workflow,
        "--ref",
        args.deploy_workflow_ref,
        "-f",
        f"{args.deploy_workflow_input}=main",
        "-f",
        f"{args.deploy_ref_input}={deploy_ref}",
        "-f",
        f"{args.environment_input}={environment}",
    ]


# discover reusable build run
def find_reusable_build_run(workflow: str, inputs: ReleaseInputs) -> WorkflowRun | None:
    """Find a successful build for the latest branch commit."""
    # only branch refs have a latest branch commit contract
    if inputs.ref_kind != "branch" or not inputs.ref_sha:
        return None
    result = run_command([
        "gh",
        "run",
        "list",
        "--workflow",
        workflow,
        "--branch",
        inputs.ref,
        "--limit",
        "50",
        "--json",
        "databaseId,url,status,conclusion,headSha,createdAt",
    ], check=True)
    runs = json.loads(result.stdout or "[]")
    candidates: list[dict[str, object]] = []
    # collect matching successful runs
    for run in runs:
        # require successful run on exact commit
        if run.get("headSha") == inputs.ref_sha and run.get("conclusion") == "success":
            candidates.append(run)
    # no reusable build found
    if not candidates:
        return None
    candidates.sort(key=lambda item: str(item.get("createdAt") or ""), reverse=True)
    selected = candidates[0]
    return WorkflowRun(
        database_id=int(selected["databaseId"]),
        url=str(selected["url"]),
        status=str(selected["status"]),
        conclusion=selected.get("conclusion") and str(selected.get("conclusion")),
        head_sha=selected.get("headSha") and str(selected.get("headSha")),
        created_at=selected.get("createdAt") and str(selected.get("createdAt")),
    )


# normalize tag name
def normalize_tag_name(value: str) -> str:
    """Return a clean tag name from log or ref text."""
    tag = value.strip().strip("`\'\".,;:()[]{}<>")
    # strip full ref prefix
    if tag.startswith("refs/tags/"):
        tag = tag.removeprefix("refs/tags/")
    # strip peeled suffix
    if tag.endswith("^{}"):
        tag = tag[:-3]
    return tag


# extract logged tags
def extract_tag_candidates(text: str) -> tuple[str, ...]:
    """Extract possible git tag names from build output."""
    candidates: list[str] = []
    # collect explicit refs first
    for match in TAG_NAME_PATTERN.finditer(text):
        tag = normalize_tag_name(match.group(1))
        # keep non-empty tags
        if tag:
            candidates.append(tag)
    # scan tag-looking build log lines
    for line in text.splitlines():
        # only parse lines that mention tags
        if "tag" not in line.lower():
            continue
        match = TAG_LINE_PATTERN.search(line)
        # keep matched tag token
        if match:
            tag = normalize_tag_name(match.group(1))
            # keep non-empty tags
            if tag:
                candidates.append(tag)
    return dedupe_environments(candidates)


# test remote tag
def remote_tag_exists(tag: str) -> bool:
    """Return whether an origin tag exists."""
    return remote_ref_sha("tags", tag) is not None


# list tags for commit
def remote_tags_for_sha(sha: str) -> tuple[str, ...]:
    """Return remote tags that point at a commit SHA."""
    result = run_command(["git", "ls-remote", "--tags", "origin"], check=True)
    direct: dict[str, str] = {}
    peeled: dict[str, str] = {}
    # parse remote tag refs
    for line in result.stdout.splitlines():
        parts = line.split("\t", 1)
        # skip malformed lines
        if len(parts) != 2:
            continue
        object_sha, ref = parts
        # skip non-tag refs
        if not ref.startswith("refs/tags/"):
            continue
        tag = normalize_tag_name(ref)
        # collect peeled annotated tag target
        if ref.endswith("^{}"):
            peeled[tag] = object_sha
            continue
        direct[tag] = object_sha
    matches: list[str] = []
    # compare peeled target before direct object
    for tag, direct_sha in direct.items():
        target_sha = peeled.get(tag, direct_sha)
        # include exact target matches
        if target_sha == sha:
            matches.append(tag)
    return tuple(matches)


# fetch run logs
def get_run_log(run: WorkflowRun) -> str:
    """Fetch text logs for a workflow run."""
    result = run_command(["gh", "run", "view", str(run.database_id), "--log"], check=True)
    return result.stdout


# resolve automated build tag
def resolve_build_tag(run: WorkflowRun, inputs: ReleaseInputs) -> str:
    """Resolve the automated git tag produced by a build run."""
    head_sha = run.head_sha or inputs.ref_sha
    log_text = get_run_log(run)
    log_tags = [tag for tag in extract_tag_candidates(log_text) if remote_tag_exists(tag)]
    sha_tags = remote_tags_for_sha(head_sha) if head_sha else ()
    matching_log_tags = [tag for tag in log_tags if tag in sha_tags]
    # prefer a logged tag that points at the build commit
    if len(matching_log_tags) == 1:
        return matching_log_tags[0]
    # block ambiguous logged commit tags
    if len(matching_log_tags) > 1:
        raise RuntimeError(f"Multiple automated build tags found in build logs for {head_sha}: {', '.join(matching_log_tags)}")
    # use one verified logged tag when no commit target is available
    if len(log_tags) == 1 and not sha_tags:
        return log_tags[0]
    # block ambiguous logged tags
    if len(log_tags) > 1 and not sha_tags:
        raise RuntimeError(f"Multiple automated build tags found in build logs: {', '.join(log_tags)}")
    # fallback to exactly one tag pointing at the build commit
    if len(sha_tags) == 1:
        return sha_tags[0]
    # block ambiguous commit tags
    if len(sha_tags) > 1:
        raise RuntimeError(f"Multiple tags point at build commit {head_sha}: {', '.join(sha_tags)}")
    raise RuntimeError(
        f"Could not identify the automated build tag for run {run.url}; refusing to deploy branch, commit SHA, or input ref."
    )


# discover workflow run
def find_recent_run(workflow: str, ref: str, started_at: datetime) -> WorkflowRun | None:
    """Find a recently dispatched workflow run."""
    result = run_command([
        "gh",
        "run",
        "list",
        "--workflow",
        workflow,
        "--event",
        "workflow_dispatch",
        "--limit",
        "20",
        "--json",
        "databaseId,url,status,conclusion,headBranch,headSha,createdAt",
    ], check=True)
    runs = json.loads(result.stdout or "[]")
    candidates: list[dict[str, object]] = []
    # filter recent matching runs
    for run in runs:
        created_raw = str(run.get("createdAt") or "")
        # skip malformed timestamps
        if not created_raw:
            continue
        created_at = datetime.fromisoformat(created_raw.replace("Z", "+00:00"))
        head_branch = str(run.get("headBranch") or "")
        # accept recent exact branch matches first
        if created_at >= started_at and head_branch == ref:
            candidates.append(run)
    # fallback for tag/manual-deploy branch reporting
    if not candidates:
        # scan all recent workflow-dispatch runs
        for run in runs:
            created_raw = str(run.get("createdAt") or "")
            # skip malformed timestamps
            if not created_raw:
                continue
            created_at = datetime.fromisoformat(created_raw.replace("Z", "+00:00"))
            # accept recent fallback candidate
            if created_at >= started_at:
                candidates.append(run)
    # no matching run yet
    if not candidates:
        return None
    candidates.sort(key=lambda item: str(item.get("createdAt") or ""), reverse=True)
    selected = candidates[0]
    return WorkflowRun(
        database_id=int(selected["databaseId"]),
        url=str(selected["url"]),
        status=str(selected["status"]),
        conclusion=selected.get("conclusion") and str(selected.get("conclusion")),
        head_sha=selected.get("headSha") and str(selected.get("headSha")),
        created_at=selected.get("createdAt") and str(selected.get("createdAt")),
    )


# wait for run discovery
def wait_for_run(workflow: str, ref: str, started_at: datetime, timeout_seconds: int, poll_seconds: int) -> WorkflowRun:
    """Wait until a dispatched run appears in gh run list."""
    deadline = time.monotonic() + timeout_seconds
    # poll until found
    while time.monotonic() < deadline:
        run = find_recent_run(workflow, ref, started_at)
        # return discovered run
        if run:
            return run
        time.sleep(poll_seconds)
    raise TimeoutError(f"Timed out waiting for a new '{workflow}' run for ref '{ref}'.")


# watch workflow run
def watch_run(run: WorkflowRun, timeout_seconds: int) -> WorkflowRun:
    """Watch a GitHub Actions run until terminal status."""
    try:
        watch = run_command(["gh", "run", "watch", str(run.database_id), "--exit-status", "--interval", "10"], timeout_seconds=timeout_seconds)
    except subprocess.TimeoutExpired:
        return get_run(run.database_id)
    # let caller evaluate conclusion
    if watch.returncode != 0:
        return get_run(run.database_id)
    return get_run(run.database_id)


# get workflow run
def get_run(database_id: int) -> WorkflowRun:
    """Fetch a single GitHub Actions run."""
    result = run_command([
        "gh",
        "run",
        "view",
        str(database_id),
        "--json",
        "databaseId,url,status,conclusion,headSha,createdAt",
    ], check=True)
    payload = json.loads(result.stdout)
    return WorkflowRun(
        database_id=int(payload["databaseId"]),
        url=str(payload["url"]),
        status=str(payload["status"]),
        conclusion=payload.get("conclusion") and str(payload.get("conclusion")),
        head_sha=payload.get("headSha") and str(payload.get("headSha")),
        created_at=payload.get("createdAt") and str(payload.get("createdAt")),
    )


# assert success conclusion
def require_success(run: WorkflowRun, label: str) -> None:
    """Require a completed successful workflow run."""
    # require terminal success
    if run.conclusion != "success":
        raise RuntimeError(f"{label} did not succeed: status={run.status} conclusion={run.conclusion} url={run.url}")


# dispatch and watch workflow
def dispatch_and_watch(command: list[str], workflow: str, discovery_ref: str, args: argparse.Namespace, *, watch: bool) -> WorkflowRun:
    """Dispatch a workflow and optionally wait for completion."""
    started_at = datetime.now(timezone.utc) - timedelta(seconds=10)
    result = run_command(command)
    # require dispatch success
    if result.returncode != 0:
        raise RuntimeError(format_failure(result))
    run = wait_for_run(workflow, discovery_ref, started_at, args.timeout_minutes * 60, args.poll_seconds)
    print(f"Queued {workflow}: {run.url}")
    # return queued run
    if not watch:
        return run
    return watch_run(run, args.timeout_minutes * 60)


# print dry run plan
def print_plan(
    build_command: list[str],
    deploy_commands: Sequence[list[str]],
    inputs: ReleaseInputs,
    reusable_build: WorkflowRun | None,
    deploy_ref: str,
) -> None:
    """Print the release plan without dispatching."""
    print(f"Resolved ref: {inputs.ref}")
    print(f"Resolved ref kind: {inputs.ref_kind}")
    # show commit evidence when available
    if inputs.ref_sha:
        print(f"Resolved ref SHA: {inputs.ref_sha}")
    print(f"Environments: {', '.join(inputs.environments)}")
    print(f"Deploy ref: {deploy_ref}")
    # show build reuse or dispatch command
    if reusable_build:
        print(f"Reusable build: {reusable_build.url} conclusion={reusable_build.conclusion}")
    else:
        print("Build command:")
        print(shlex.join(build_command))
    print("Deploy commands:")
    # print every deploy target
    for command in deploy_commands:
        print(shlex.join(command))


# format deploy summary
def format_deployed_message(deploy_ref: str, environments: Sequence[str]) -> str:
    """Format the copy-pasteable deployment announcement."""
    return f"Deployed `{deploy_ref}` to {', '.join(environments)}"


# main entry point
def main(argv: Sequence[str]) -> int:
    """Execute the release workflow."""
    args = parse_args(argv)
    try:
        require_gh_auth()
        require_workflow(args.build_workflow)
        require_workflow(args.deploy_workflow)
        environments = list_environments()
        inputs = resolve_inputs(args, environments)
        build_command = build_dispatch_command(args.build_workflow, inputs.ref)
        reusable_build = find_reusable_build_run(args.build_workflow, inputs)
        dry_run_deploy_ref = resolve_build_tag(reusable_build, inputs) if reusable_build else UNKNOWN_BUILD_TAG
        deploy_commands = [deploy_dispatch_command(args, dry_run_deploy_ref, environment) for environment in inputs.environments]
        # dry-run exits before external dispatch
        if args.dry_run:
            print_plan(build_command, deploy_commands, inputs, reusable_build, dry_run_deploy_ref)
            return 0
        # reuse successful latest-commit branch builds
        if reusable_build:
            build_run = reusable_build
            print(f"Reusing successful build for {inputs.ref}@{inputs.ref_sha}: {build_run.url}")
        else:
            print(f"Building {inputs.ref} for {', '.join(inputs.environments)}")
            build_run = dispatch_and_watch(build_command, args.build_workflow, inputs.ref, args, watch=True)
            print(f"Build complete: status={build_run.status} conclusion={build_run.conclusion} url={build_run.url}")
        require_success(build_run, "Build workflow")
        deploy_ref = resolve_build_tag(build_run, inputs)
        deploy_commands = [deploy_dispatch_command(args, deploy_ref, environment) for environment in inputs.environments]
        print(f"Deploying automated build tag {deploy_ref}")
        deployed_environments: list[str] = []
        # deploy same build tag to every environment
        for environment, deploy_command in zip(inputs.environments, deploy_commands, strict=True):
            print(f"Deploying {deploy_ref} to {environment}")
            deploy_run = dispatch_and_watch(
                deploy_command,
                args.deploy_workflow,
                args.deploy_workflow_ref,
                args,
                watch=not args.no_watch_deploy,
            )
            print(f"Deploy run for {environment}: status={deploy_run.status} conclusion={deploy_run.conclusion} url={deploy_run.url}")
            # queued deploy is acceptable only when caller chose not to watch
            if not args.no_watch_deploy:
                require_success(deploy_run, f"Deploy workflow for {environment}")
                deployed_environments.append(environment)
        # print copyable success announcement
        if deployed_environments:
            print(format_deployed_message(deploy_ref, deployed_environments))
        return 0
    except Exception as exc:  # report operator error
        print(f"release failed: {exc}", file=sys.stderr)
        return 1


# script entry point
if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
