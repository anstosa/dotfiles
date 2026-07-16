#!/usr/bin/env python3
"""Generate deterministic local artifacts for Ansel's review cockpit."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import textwrap
from typing import Any

SCHEMA_VERSION = 1
DEFAULT_BASES = ("origin/main", "origin/master", "main", "master")
PATHSPECS = (".",)
# A review must show the full current branch state.  Do not hide tests or any
# other non-ignored path: callers can narrow the scope explicitly with Git if
# they need a focused review.
EXCLUDED_PATHSPECS: tuple[str, ...] = ()
REQUIRED_TOP_LEVEL = (
    "schema_version",
    "generated_at",
    "repo_root",
    "base_ref",
    "head_ref",
    "range",
    "git_merge_base",
    "git_head",
    "includes_worktree",
    "markdown_path",
    "files",
    "checklist",
    "questions",
    "non_goals_enforced",
    "warnings",
    "pathspecs",
    "excluded_pathspecs",
)
REQUIRED_FILE_FIELDS = (
    "path",
    "status",
    "additions",
    "deletions",
    "summary",
    "why",
    "risks",
    "diff_excerpt",
    "review_order",
)
STATUS_LABELS = {
    "A": "added",
    "C": "copied",
    "D": "deleted",
    "M": "modified",
    "R": "renamed",
    "T": "modified",
    "U": "unknown",
    "X": "unknown",
}


# write progress log
def log(message: str) -> None:
    print(f"review-cockpit: {message}", file=sys.stderr)


# build working-tree diff args
def diff_args(diff_base_ref: str) -> list[str]:
    return [diff_base_ref]


# run git command
def run_git(repo: Path, args: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    # enforce git success
    if check and result.returncode != 0:
        raise SystemExit(result.stderr.strip() or f"git {' '.join(args)} failed")
    return result


# resolve repository root
def git_root(repo: Path) -> Path:
    result = run_git(repo, ["rev-parse", "--show-toplevel"])
    return Path(result.stdout.strip()).resolve()


# test ref availability
def ref_exists(repo: Path, ref: str) -> bool:
    result = run_git(repo, ["rev-parse", "--verify", "--quiet", ref], check=False)
    return result.returncode == 0


# choose review base
def choose_base(repo: Path, requested: str | None) -> str:
    # use caller base
    if requested:
        return requested
    # scan common refs
    for ref in DEFAULT_BASES:
        # preserve current fallback order
        if ref_exists(repo, ref):
            return ref
    return "HEAD~1"


# sanitize filename component
def sanitize_ref(ref: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "-", ref).strip("-._")
    return cleaned or "base"


# create home state path
def home_state_dir(repo: Path) -> Path:
    state_home = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local" / "state"))
    digest = hashlib.sha256(str(repo).encode("utf-8")).hexdigest()[:16]
    return state_home / "review-cockpit" / digest


# choose writable output dir
def choose_output_dir(repo: Path) -> Path:
    primary = repo / ".git" / "review-cockpit"
    # prefer repo-local git state
    try:
        primary.mkdir(parents=True, exist_ok=True)
        probe = primary / ".write-test"
        probe.write_text("ok\n", encoding="utf-8")
        probe.unlink()
        return primary
    # fallback to home state
    except OSError:
        fallback = home_state_dir(repo)
        fallback.mkdir(parents=True, exist_ok=True)
        return fallback


# split status row
def parse_name_status_line(line: str) -> tuple[str, str]:
    parts = line.split("\t")
    status_code = parts[0][:1] if parts else "X"
    # handle rename/copy destination
    if status_code in {"R", "C"} and len(parts) >= 3:
        return STATUS_LABELS.get(status_code, "unknown"), parts[2]
    # handle normal path
    if len(parts) >= 2:
        return STATUS_LABELS.get(status_code, "unknown"), parts[1]
    return "unknown", ""


# collect untracked files
def collect_untracked(repo: Path) -> set[str]:
    result = run_git(repo, ["ls-files", "--others", "--exclude-standard", "-z", "--", *PATHSPECS, *EXCLUDED_PATHSPECS])
    return {path for path in result.stdout.split("\0") if path}


# collect name statuses
def collect_statuses(repo: Path, diff_base_ref: str, untracked: set[str]) -> dict[str, str]:
    result = run_git(repo, ["diff", "--name-status", *diff_args(diff_base_ref), "--", *PATHSPECS, *EXCLUDED_PATHSPECS])
    statuses: dict[str, str] = {}
    # parse status rows
    for line in result.stdout.splitlines():
        status, path = parse_name_status_line(line)
        # store nonempty path
        if path:
            statuses[path] = status
    # include untracked files
    for path in sorted(untracked):
        statuses[path] = "added"
    return statuses


# parse numstat count
def parse_numstat_count(value: str) -> int:
    # treat binary marker as zero
    if value == "-":
        return 0
    return int(value)


# count text file lines
def count_file_lines(path: Path) -> int:
    # tolerate binary files
    try:
        return len(path.read_text(encoding="utf-8").splitlines())
    except (OSError, UnicodeDecodeError):
        return 0


# collect add/delete counts
def collect_numstat(repo: Path, diff_base_ref: str, untracked: set[str]) -> dict[str, tuple[int, int]]:
    result = run_git(repo, ["diff", "--numstat", "-z", *diff_args(diff_base_ref), "--", *PATHSPECS, *EXCLUDED_PATHSPECS])
    records = result.stdout.split("\0")
    stats: dict[str, tuple[int, int]] = {}
    index = 0
    # parse nul records
    while index < len(records):
        record = records[index]
        index += 1
        # skip final empty record
        if not record:
            continue
        parts = record.split("\t", 2)
        # skip malformed rows
        if len(parts) < 3:
            continue
        additions = parse_numstat_count(parts[0])
        deletions = parse_numstat_count(parts[1])
        path = parts[2]
        # normalize rename/copy records
        if path == "" and index + 1 < len(records):
            _source_path = records[index]
            destination_path = records[index + 1]
            index += 2
            path = destination_path
        # store destination path
        if path:
            stats[path] = (additions, deletions)
    # include untracked file sizes
    for path in sorted(untracked):
        stats[path] = (count_file_lines(repo / path), 0)
    return stats


# trim prose snippet
def trim_snippet(value: str, limit: int = 88) -> str:
    cleaned = re.sub(r"\s+", " ", value.strip())
    # keep short snippet intact
    if len(cleaned) <= limit:
        return cleaned
    return cleaned[: limit - 1].rstrip() + "…"


# collect meaningful diff lines
def meaningful_diff_lines(diff_excerpt: list[str], prefix: str) -> list[str]:
    lines: list[str] = []
    # scan excerpt lines
    for line in diff_excerpt:
        # skip metadata and hunk headers
        if line.startswith(("+++", "---", "@@")):
            continue
        # keep requested changed lines
        if line.startswith(prefix):
            content = line[1:].strip()
            # skip empty-only changes
            if content:
                lines.append(trim_snippet(content))
    return lines


# describe changed line group
def describe_line_group(lines: list[str], fallback: str) -> str:
    # use fallback for empty group
    if not lines:
        return fallback
    # describe single edit
    if len(lines) == 1:
        return f"`{lines[0]}`"
    return f"`{lines[0]}` and related edits"


# summarize file change
def summarize_file(path: str, status: str, diff_excerpt: list[str]) -> str:
    name = Path(path).name
    added_lines = meaningful_diff_lines(diff_excerpt, "+")
    removed_lines = meaningful_diff_lines(diff_excerpt, "-")
    # describe added file
    if status == "added":
        return f"Adds {name} with {describe_line_group(added_lines, 'new content')}."
    # describe deleted file
    if status == "deleted":
        return f"Removes {name}, including {describe_line_group(removed_lines, 'its previous content')}."
    # describe replacement
    if added_lines and removed_lines:
        return f"Updates {name} by replacing {describe_line_group(removed_lines, 'old content')} with {describe_line_group(added_lines, 'new content')}."
    # describe insertion-only change
    if added_lines:
        return f"Updates {name} by adding {describe_line_group(added_lines, 'new content')}."
    # describe deletion-only change
    if removed_lines:
        return f"Updates {name} by removing {describe_line_group(removed_lines, 'old content')}."
    return f"Updates {name} without a small text excerpt that can be summarized deterministically."


# strip commit subject
def commit_subject(commit_line: str) -> str:
    return re.sub(r"^[0-9a-fA-F]{7,40}\s+", "", commit_line).strip()


# make goal phrase
def goal_phrase(subject: str) -> str:
    cleaned = commit_subject(subject).strip().rstrip(".")
    # handle empty subject
    if not cleaned:
        return "complete the branch intent"
    return cleaned[:1].lower() + cleaned[1:]


# make sentence fragment
def sentence_fragment(sentence: str) -> str:
    cleaned = sentence.strip().rstrip(".")
    # handle empty sentence
    if not cleaned:
        return "this file carries a necessary part of the branch"
    return cleaned[:1].lower() + cleaned[1:]


# infer rationale text
def infer_why(path: str, summary: str, commits: list[str]) -> str:
    name = Path(path).name
    subjects: list[str] = []
    # collect commit subjects
    for commit in commits:
        subject = commit_subject(commit)
        # keep nonempty subjects
        if subject:
            subjects.append(subject)
    # use branch intent when available
    if subjects:
        return f"This was necessary so the branch can {goal_phrase(subjects[0])}; {sentence_fragment(summary)}."
    return f"This was necessary to make the {name} behavior described in the summary available in the branch."


# build risk list
def risks_for_file(path: str, status: str, additions: int, deletions: int) -> list[str]:
    risks: list[str] = []
    # deleted files need call-site review
    if status == "deleted":
        risks.append("Confirm no remaining callers or docs depend on this deleted file.")
    # large files deserve focused review
    if additions + deletions >= 200:
        risks.append("Large diff: review behavior and hidden side effects carefully.")
    # config changes can affect tools globally
    if path.startswith(".") or "/config" in path or path.endswith((".json", ".yaml", ".yml", ".toml")):
        risks.append("Configuration-style change: verify local and CI/tooling impact.")
    return risks


# collect untracked file excerpt
def diff_excerpt_for_untracked(repo: Path, path: str) -> list[str]:
    file_path = repo / path
    # tolerate binary or missing files
    try:
        content_lines = file_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError):
        return ["@@ untracked binary or unreadable file @@"]
    excerpt = ["@@ untracked file @@"]
    # add file content as additions
    for line in content_lines[:23]:
        excerpt.append("+" + line)
    return excerpt


# collect focused diff excerpt
def diff_excerpt_for_file(repo: Path, diff_base_ref: str, path: str, untracked: set[str]) -> list[str]:
    # render untracked files
    if path in untracked:
        return diff_excerpt_for_untracked(repo, path)
    result = run_git(repo, ["diff", "--unified=3", *diff_args(diff_base_ref), "--", path], check=False)
    # tolerate absent file diff
    if result.returncode != 0:
        return []
    lines = result.stdout.splitlines()
    excerpt: list[str] = []
    # keep review-sized excerpt
    for line in lines:
        # skip diff metadata noise
        if line.startswith(("diff --git ", "index ", "--- ", "+++ ")):
            continue
        excerpt.append(line)
        # cap inline payload
        if len(excerpt) >= 24:
            break
    return excerpt


# collect commit summaries
def collect_commits(repo: Path, review_range: str) -> list[str]:
    result = run_git(repo, ["log", "--format=%h %s", review_range], check=False)
    # tolerate no commits
    if result.returncode != 0:
        return []
    return [line for line in result.stdout.splitlines() if line]


# build file records
def build_files(repo: Path, diff_base_ref: str, commits: list[str]) -> list[dict[str, Any]]:
    untracked = collect_untracked(repo)
    statuses = collect_statuses(repo, diff_base_ref, untracked)
    stats = collect_numstat(repo, diff_base_ref, untracked)
    paths = sorted(set(statuses) | set(stats))
    files: list[dict[str, Any]] = []
    # build deterministic order
    for index, path in enumerate(paths, start=1):
        additions, deletions = stats.get(path, (0, 0))
        status = statuses.get(path, "unknown")
        diff_excerpt = diff_excerpt_for_file(repo, diff_base_ref, path, untracked)
        summary = summarize_file(path, status, diff_excerpt)
        files.append(
            {
                "path": path,
                "status": status,
                "additions": additions,
                "deletions": deletions,
                "summary": summary,
                "why": infer_why(path, summary, commits),
                "risks": risks_for_file(path, status, additions, deletions),
                "diff_excerpt": diff_excerpt,
                "review_order": index,
            }
        )
    return files


# build common checklist
def build_checklist() -> list[dict[str, str]]:
    return [
        {"id": "intent", "label": "Diff matches the intended story", "severity": "high"},
        {"id": "tests", "label": "Tests or manual checks cover changed behavior", "severity": "medium"},
        {"id": "side-effects", "label": "No unexpected writes, network calls, or secrets exposure", "severity": "high"},
        {"id": "fallbacks", "label": "Fallback paths remain usable", "severity": "medium"},
    ]


# build review questions
def build_questions(files: list[dict[str, Any]]) -> list[str]:
    questions = ["Does the diff solve only the approved scope?", "What failure path would be most costly if this ships?"]
    # add empty-diff prompt
    if not files:
        questions.append("There are no changed files in the selected range; is the base ref correct?")
    return questions


# append wrapped markdown line
def append_wrapped(lines: list[str], text: str, width: int = 120, subsequent_indent: str = "") -> None:
    wrapped = textwrap.wrap(
        text,
        width=width,
        subsequent_indent=subsequent_indent,
        break_long_words=False,
        break_on_hyphens=False,
    )
    # preserve explicit blank text
    if not wrapped:
        lines.append(text)
        return
    lines.extend(wrapped)


# append wrapped bullet
def append_wrapped_bullet(lines: list[str], prefix: str, text: str, width: int = 120) -> None:
    append_wrapped(lines, prefix + text, width=width, subsequent_indent=" " * len(prefix))


# render markdown guide
def render_markdown(artifact: dict[str, Any]) -> str:
    lines: list[str] = []
    lines.append(f"# Review cockpit: `{artifact['range']}`")
    lines.append("")
    lines.append(f"Generated: {artifact['generated_at']}")
    lines.append("")
    lines.append("## Navigation / keys")
    lines.append("- Guide: `Tab` / `Shift-Tab` jumps between review sections.")
    lines.append("- Guide: put the cursor on a file section and press `F12` to open its side-by-side working-tree Diffview.")
    lines.append("- Diffview after F12: use `]c` / `[c` for next/previous hunk.")
    lines.append("- Cockpit: optional inline notes appear in matching diff buffers; `i` or `:ReviewCockpitToggleInline` toggles them.")
    lines.append("- Cockpit: `mr` marks reviewed, `q` closes the review.")
    lines.append("")
    lines.append("## Review order")
    # render files or empty state
    if artifact["files"]:
        # render file order
        for file_info in artifact["files"]:
            lines.append(f"{file_info['review_order']}. `{file_info['path']}` — {file_info['status']} (+{file_info['additions']}/-{file_info['deletions']})")
    else:
        lines.append("No changed files were found for this range.")
    lines.append("")
    lines.append("## Change summary")
    lines.append(f"Base: `{artifact['base_ref']}`")
    lines.append(f"Target: `{artifact['head_ref']}` (`{artifact['git_head']}` plus working tree)")
    lines.append(f"Merge base: `{artifact['git_merge_base']}`")
    lines.append("Includes working tree: `yes`")
    append_wrapped(lines, f"Pathspecs: `{', '.join(artifact['pathspecs'])}`")
    append_wrapped(lines, f"Excluded pathspecs: `{', '.join(artifact['excluded_pathspecs'])}`")
    lines.append("")
    lines.append("## File-by-file notes")
    # render file notes
    for file_info in artifact["files"]:
        lines.append(f"### {file_info['review_order']}. `{file_info['path']}`")
        append_wrapped_bullet(lines, "- ", file_info["summary"])
        append_wrapped_bullet(lines, "- ", file_info["why"] or "Unknown from deterministic git data.")
        # render risks
        if file_info["risks"]:
            # render risk bullets
            for risk in file_info["risks"]:
                append_wrapped_bullet(lines, "- ", risk)
        else:
            lines.append("- No obvious deterministic risk flags.")
        # render inline code excerpt
        if file_info["diff_excerpt"]:
            lines.append("")
            lines.append("```diff")
            # render excerpt lines
            for diff_line in file_info["diff_excerpt"]:
                lines.append(diff_line)
            lines.append("```")
        lines.append("")
    lines.append("## Risks/questions")
    # render global questions
    for question in artifact["questions"]:
        lines.append(f"- {question}")
    lines.append("")
    lines.append("## Checklist")
    # render checklist
    for item in artifact["checklist"]:
        lines.append(f"- [ ] ({item['severity']}) {item['label']} `#{item['id']}`")
    lines.append("")
    lines.append("## Advisory disclaimer")
    lines.append("This guide is a deterministic review aid, not approval. Trust the diff over summaries.")
    lines.append("")
    return "\n".join(lines)


# validate schema contract
def validate_artifact(artifact: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    # check top-level fields
    for field in REQUIRED_TOP_LEVEL:
        # record missing field
        if field not in artifact:
            errors.append(f"missing top-level field: {field}")
    # check pathspec metadata
    if artifact.get("pathspecs") != list(PATHSPECS):
        errors.append("pathspecs must match generator pathspec contract")
    # check excluded metadata
    if artifact.get("excluded_pathspecs") != list(EXCLUDED_PATHSPECS):
        errors.append("excluded_pathspecs must match generator exclusion contract")
    # check schema version
    if artifact.get("schema_version") != SCHEMA_VERSION:
        errors.append("schema_version must be 1")
    files = artifact.get("files")
    # check files container
    if not isinstance(files, list):
        errors.append("files must be a list")
        return errors
    # check per-file fields
    for index, file_info in enumerate(files):
        # validate object shape
        if not isinstance(file_info, dict):
            errors.append(f"files[{index}] must be an object")
            continue
        # check required per-file keys
        for field in REQUIRED_FILE_FIELDS:
            # record missing per-file key
            if field not in file_info:
                errors.append(f"files[{index}] missing field: {field}")
    return errors


# atomically update latest json
def update_latest(output_dir: Path, json_path: Path) -> None:
    latest = output_dir / "latest.json"
    temp_link = output_dir / ".latest.json.tmp"
    # remove stale temp
    if temp_link.exists() or temp_link.is_symlink():
        temp_link.unlink()
    # prefer symlink
    try:
        os.symlink(json_path.name, temp_link)
        os.replace(temp_link, latest)
        return
    # fallback to copy and pointer
    except OSError:
        # clean failed link
        if temp_link.exists() or temp_link.is_symlink():
            temp_link.unlink()
        shutil.copyfile(json_path, latest)
        (output_dir / "latest.pointer").write_text(str(json_path) + "\n", encoding="utf-8")


# build artifact object
def build_artifact(repo: Path, base: str, output_dir: Path) -> tuple[dict[str, Any], Path, Path]:
    generated_at = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    review_range = f"{base}...WORKTREE"
    merge_base = run_git(repo, ["merge-base", base, "HEAD"]).stdout.strip()
    git_head = run_git(repo, ["rev-parse", "HEAD"]).stdout.strip()
    commit_range = f"{base}...HEAD"
    commits = collect_commits(repo, commit_range)
    files = build_files(repo, merge_base, commits)
    timestamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    stem = f"{timestamp}-{sanitize_ref(base)}-HEAD"
    json_path = output_dir / f"{stem}.json"
    markdown_path = output_dir / f"{stem}.md"
    artifact: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "generated_at": generated_at,
        "repo_root": str(repo),
        "base_ref": base,
        "head_ref": "HEAD",
        "range": review_range,
        "git_merge_base": merge_base,
        "git_head": git_head,
        "includes_worktree": True,
        "markdown_path": str(markdown_path),
        "files": files,
        "checklist": build_checklist(),
        "questions": build_questions(files),
        "non_goals_enforced": ["no-github-posting", "no-code-edits", "no-live-ai-from-nvim"],
        "warnings": [],
        "pathspecs": list(PATHSPECS),
        "excluded_pathspecs": list(EXCLUDED_PATHSPECS),
        "commits": commits,
        "generated_by": {"name": "review-cockpit", "schema_version": SCHEMA_VERSION},
    }
    return artifact, json_path, markdown_path


# parse cli args
def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate local review cockpit JSON and Markdown artifacts.")
    parser.add_argument("--repo", default=".", help="Git repository path, default: current directory")
    parser.add_argument("--base", default=None, help="Base ref for merge-base to working-tree diff, default: origin/main fallback chain")
    parser.add_argument("--print-json", action="store_true", help="Print generated JSON path only")
    parser.add_argument("--validate", metavar="PATH", help="Validate an artifact JSON file and exit")
    return parser.parse_args(argv)


# program entrypoint
def main(argv: list[str]) -> int:
    args = parse_args(argv)
    # validation mode
    if args.validate:
        artifact = json.loads(Path(args.validate).read_text(encoding="utf-8"))
        errors = validate_artifact(artifact)
        # report errors
        if errors:
            print("\n".join(errors), file=sys.stderr)
            return 1
        print("valid")
        return 0
    log("resolving repository")
    repo = git_root(Path(args.repo).expanduser())
    base = choose_base(repo, args.base)
    log(f"using base ref {base}")
    output_dir = choose_output_dir(repo)
    log("collecting committed, staged, unstaged, and untracked changes")
    artifact, json_path, markdown_path = build_artifact(repo, base, output_dir)
    log(f"writing guide {markdown_path}")
    markdown_path.write_text(render_markdown(artifact), encoding="utf-8")
    log(f"writing structured data {json_path}")
    json_path.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    errors = validate_artifact(artifact)
    # fail impossible invalid output
    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    update_latest(output_dir, json_path)
    log("updated latest artifact pointer")
    # print requested format
    if args.print_json:
        print(json_path)
    else:
        print(f"review-cockpit artifact: {json_path}")
        print(f"review-cockpit guide: {markdown_path}")
    return 0


# run cli
if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
