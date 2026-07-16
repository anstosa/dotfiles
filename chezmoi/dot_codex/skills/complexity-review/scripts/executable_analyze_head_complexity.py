#!/usr/bin/env python3

from __future__ import annotations

import argparse
import ast
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

SUPPORTED_EXTENSIONS = {".py", ".js", ".jsx", ".ts", ".tsx"}
# default parent base
DEFAULT_BASE = "HEAD^"
# empty tree object
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
CONTROL_KEYWORDS = {
    "if",
    "for",
    "while",
    "switch",
    "catch",
    "function",
    "constructor",
}


@dataclass(frozen=True)
class FunctionInfo:
    path: str
    name: str
    kind: str
    start_line: int
    end_line: int
    complexity: int
    language: str


@dataclass(frozen=True)
class TouchedFunction:
    current: FunctionInfo
    previous_complexity: int
    delta: int


# changed source path
@dataclass(frozen=True)
class ChangedFile:
    path: str
    previous_path: str | None


@dataclass(frozen=True)
class DiffRanges:
    old: list[tuple[int, int]]
    new: list[tuple[int, int]]


def run_git(repo: Path, args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=repo,
        capture_output=True,
        text=True,
        check=False,
    )


def must_git(repo: Path, args: list[str]) -> str:
    result = run_git(repo, args)
    if result.returncode != 0:
        stderr = result.stderr.strip()
        raise RuntimeError(f"git {' '.join(args)} failed: {stderr}")
    return result.stdout


# parse CLI options
def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Analyze cyclomatic complexity touched by HEAD."
    )
    parser.add_argument(
        "--repo",
        default=".",
        help="Repository root or any path inside it. Defaults to the current directory.",
    )
    parser.add_argument(
        "--base",
        default=DEFAULT_BASE,
        help="Base revision used for the comparison. Defaults to HEAD^.",
    )
    parser.add_argument(
        "--rev",
        default="HEAD",
        help="Revision to inspect. Defaults to HEAD.",
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=20,
        help="Highlight functions with post-change complexity above this value.",
    )
    return parser.parse_args()


def repo_root(path: Path) -> Path:
    root = must_git(path, ["rev-parse", "--show-toplevel"]).strip()
    return Path(root)


# check git revision
def git_revision_exists(repo: Path, revision: str) -> bool:
    # verify refs quietly
    result = run_git(repo, ["rev-parse", "--verify", "--quiet", revision])
    return result.returncode == 0


# resolve comparison base
def resolve_base(repo: Path, base: str, rev: str) -> str:
    # keep valid bases
    if git_revision_exists(repo, base):
        return base

    # avoid masking bad revisions
    if not git_revision_exists(repo, rev):
        return base

    # support root commits
    if base == DEFAULT_BASE and not git_revision_exists(repo, f"{rev}^"):
        return EMPTY_TREE

    return base


# list changed source files
def changed_files(repo: Path, base: str, rev: str) -> list[ChangedFile]:
    # request machine-parseable paths
    output = must_git(
        repo,
        [
            "diff",
            "--name-status",
            "-z",
            "--find-renames",
            "--find-copies",
            "--diff-filter=ACMRT",
            base,
            rev,
        ],
    )
    files: list[ChangedFile] = []
    seen: set[str] = set()
    entries = output.split("\0")

    # drop trailing separator
    if entries and entries[-1] == "":
        entries.pop()

    index = 0
    # walk name-status records
    while index < len(entries):
        status = entries[index]
        index += 1
        previous_path: str | None = None

        # use new path for renames/copies
        if status.startswith(("R", "C")):
            previous_path = entries[index] if index < len(entries) else None
            path = entries[index + 1] if index + 1 < len(entries) else ""
            index += 2
        else:
            path = entries[index] if index < len(entries) else ""
            index += 1

        # keep supported source files
        if path and path not in seen and Path(path).suffix in SUPPORTED_EXTENSIONS:
            files.append(ChangedFile(path=path, previous_path=previous_path))
            seen.add(path)
    return files


def file_at_revision(repo: Path, rev: str, path: str) -> str | None:
    result = run_git(repo, ["show", f"{rev}:{path}"])
    if result.returncode != 0:
        return None
    return result.stdout


# parse touched line ranges
def parse_diff_ranges(
    repo: Path,
    base: str,
    rev: str,
    path: str,
    previous_path: str | None = None,
) -> DiffRanges:
    # include rename source
    pathspecs = [path]
    if previous_path and previous_path != path:
        pathspecs = [previous_path, path]

    # parse compact hunks
    output = must_git(
        repo,
        [
            "diff",
            "--find-renames",
            "--find-copies",
            "--unified=0",
            "--no-color",
            base,
            rev,
            "--",
            *pathspecs,
        ],
    )
    old_ranges: list[tuple[int, int]] = []
    new_ranges: list[tuple[int, int]] = []
    hunk_pattern = re.compile(
        r"^@@ -(?P<old_start>\d+)(?:,(?P<old_count>\d+))? "
        r"\+(?P<new_start>\d+)(?:,(?P<new_count>\d+))? @@"
    )
    # collect changed line ranges
    for line in output.splitlines():
        match = hunk_pattern.match(line)
        # skip non-hunk lines
        if not match:
            continue
        old_start = int(match.group("old_start"))
        old_count = int(match.group("old_count") or "1")
        new_start = int(match.group("new_start"))
        new_count = int(match.group("new_count") or "1")
        old_ranges.append(to_range(old_start, old_count))
        new_ranges.append(to_range(new_start, new_count))
    return DiffRanges(old=old_ranges, new=new_ranges)


def to_range(start: int, count: int) -> tuple[int, int]:
    if count <= 0:
        return (start, start - 1)
    return (start, start + count - 1)


def overlaps(ranges: list[tuple[int, int]], start_line: int, end_line: int) -> bool:
    for range_start, range_end in ranges:
        if range_end < range_start:
            continue
        if max(range_start, start_line) <= min(range_end, end_line):
            return True
    return False


class PythonComplexityVisitor(ast.NodeVisitor):
    def __init__(self) -> None:
        self.complexity = 1

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        return None

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        return None

    def visit_Lambda(self, node: ast.Lambda) -> None:
        return None

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        return None

    def visit_If(self, node: ast.If) -> None:
        self.complexity += 1
        self.generic_visit(node)

    def visit_IfExp(self, node: ast.IfExp) -> None:
        self.complexity += 1
        self.generic_visit(node)

    def visit_For(self, node: ast.For) -> None:
        self.complexity += 1
        self.generic_visit(node)

    def visit_AsyncFor(self, node: ast.AsyncFor) -> None:
        self.complexity += 1
        self.generic_visit(node)

    def visit_While(self, node: ast.While) -> None:
        self.complexity += 1
        self.generic_visit(node)

    def visit_BoolOp(self, node: ast.BoolOp) -> None:
        self.complexity += max(0, len(node.values) - 1)
        self.generic_visit(node)

    def visit_ExceptHandler(self, node: ast.ExceptHandler) -> None:
        self.complexity += 1
        self.generic_visit(node)

    def visit_Try(self, node: ast.Try) -> None:
        self.complexity += 1 if node.orelse else 0
        self.generic_visit(node)

    def visit_comprehension(self, node: ast.comprehension) -> None:
        self.complexity += 1 + len(node.ifs)
        self.generic_visit(node)

    def visit_Match(self, node: ast.Match) -> None:
        for case in node.cases:
            if not (
                isinstance(case.pattern, ast.MatchAs)
                and case.pattern.pattern is None
                and case.pattern.name is None
            ):
                self.complexity += 1
        self.generic_visit(node)


class PythonFunctionCollector(ast.NodeVisitor):
    def __init__(self, path: str) -> None:
        self.path = path
        self.stack: list[str] = []
        self.functions: list[FunctionInfo] = []

    def visit_ClassDef(self, node: ast.ClassDef) -> None:
        self.stack.append(node.name)
        self.generic_visit(node)
        self.stack.pop()

    def visit_FunctionDef(self, node: ast.FunctionDef) -> None:
        self._record_function(node, "function")

    def visit_AsyncFunctionDef(self, node: ast.AsyncFunctionDef) -> None:
        self._record_function(node, "async function")

    def _record_function(
        self,
        node: ast.FunctionDef | ast.AsyncFunctionDef,
        kind: str,
    ) -> None:
        qualname = ".".join([*self.stack, node.name]) if self.stack else node.name
        visitor = PythonComplexityVisitor()
        for child in node.body:
            visitor.visit(child)
        self.functions.append(
            FunctionInfo(
                path=self.path,
                name=qualname,
                kind=kind,
                start_line=node.lineno,
                end_line=node.end_lineno or node.lineno,
                complexity=visitor.complexity,
                language="python",
            )
        )
        self.stack.append(node.name)
        self.generic_visit(node)
        self.stack.pop()


def parse_python_functions(path: str, content: str) -> list[FunctionInfo]:
    try:
        tree = ast.parse(content, filename=path)
    except SyntaxError:
        return []
    collector = PythonFunctionCollector(path)
    collector.visit(tree)
    return collector.functions


def sanitize_js_lines(content: str) -> list[str]:
    sanitized: list[str] = []
    in_block_comment = False
    in_string: str | None = None
    escape = False

    for raw_line in content.splitlines():
        line_chars: list[str] = []
        index = 0
        while index < len(raw_line):
            char = raw_line[index]
            next_char = raw_line[index + 1] if index + 1 < len(raw_line) else ""

            if in_block_comment:
                if char == "*" and next_char == "/":
                    in_block_comment = False
                    line_chars.extend("  ")
                    index += 2
                    continue
                line_chars.append(" ")
                index += 1
                continue

            if in_string:
                line_chars.append(" ")
                if escape:
                    escape = False
                elif char == "\\":
                    escape = True
                elif char == in_string:
                    in_string = None
                index += 1
                continue

            if char == "/" and next_char == "/":
                line_chars.extend(" " * (len(raw_line) - index))
                break

            if char == "/" and next_char == "*":
                in_block_comment = True
                line_chars.extend("  ")
                index += 2
                continue

            if char in {"'", '"', "`"}:
                in_string = char
                line_chars.append(" ")
                index += 1
                continue

            line_chars.append(char)
            index += 1

        sanitized.append("".join(line_chars))
    return sanitized


def window_text(lines: list[str], start_index: int, span: int = 6) -> str:
    return " ".join(line.strip() for line in lines[start_index : start_index + span])


def find_open_brace(
    lines: list[str], start_index: int, end_index: int
) -> tuple[int, int] | None:
    for line_index in range(start_index, min(len(lines), end_index + 1)):
        column = lines[line_index].find("{")
        if column != -1:
            return (line_index, column)
    return None


def find_block_end(
    lines: list[str], open_line_index: int, open_column: int
) -> tuple[int, int] | None:
    depth = 0
    for line_index in range(open_line_index, len(lines)):
        start_column = open_column if line_index == open_line_index else 0
        for column in range(start_column, len(lines[line_index])):
            char = lines[line_index][column]
            if char == "{":
                depth += 1
            elif char == "}":
                depth -= 1
                if depth == 0:
                    return (line_index, column)
    return None


def find_js_classes(lines: list[str]) -> list[tuple[str, int, int]]:
    class_pattern = re.compile(
        r"^\s*(?:export\s+)?(?:abstract\s+)?class\s+([A-Za-z_$][\w$]*)\b"
    )
    classes: list[tuple[str, int, int]] = []
    index = 0
    while index < len(lines):
        match = class_pattern.match(window_text(lines, index))
        if not match:
            index += 1
            continue
        open_brace = find_open_brace(lines, index, index + 6)
        if open_brace is None:
            index += 1
            continue
        block_end = find_block_end(lines, *open_brace)
        if block_end is None:
            index += 1
            continue
        classes.append((match.group(1), index + 1, block_end[0] + 1))
        index = block_end[0] + 1
    return classes


def innermost_class_name(
    classes: list[tuple[str, int, int]], line_number: int
) -> str | None:
    candidates = [entry for entry in classes if entry[1] <= line_number <= entry[2]]
    if not candidates:
        return None
    candidates.sort(key=lambda item: item[2] - item[1])
    return candidates[0][0]


def count_regex(pattern: str, text: str) -> int:
    return len(re.findall(pattern, text, flags=re.MULTILINE))


def js_complexity(lines: list[str], start_line: int, end_line: int) -> int:
    text = "\n".join(lines[start_line - 1 : end_line])
    complexity = 1
    complexity += count_regex(r"\bif\b", text)
    complexity += count_regex(r"\bfor\b", text)
    complexity += count_regex(r"\bwhile\b", text)
    complexity += count_regex(r"\bcase\b", text)
    complexity += count_regex(r"\bcatch\b", text)
    complexity += count_regex(r"\?\s*(?![?.])", text)
    complexity += count_regex(r"&&", text)
    complexity += count_regex(r"\|\|", text)
    return complexity


# parse JS and TS functions
def parse_js_functions(path: str, content: str) -> list[FunctionInfo]:
    # remove comments and strings
    lines = sanitize_js_lines(content)
    classes = find_js_classes(lines)
    # match common JS/TS declarations
    patterns = [
        re.compile(
            r"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+"
            r"([A-Za-z_$][\w$]*)\s*(?:<[^>{};=]*>)?\s*\("
        ),
        re.compile(
            r"^\s*(?:export\s+)?(?:const|let|var)\s+([A-Za-z_$][\w$]*)\s*=\s*"
            r"(?:async\s*)?(?:<[^>{};=]*>\s*)?(?:\([^)]*\)|[A-Za-z_$][\w$]*)"
            r"\s*(?::\s*[^=]+)?\s*=>"
        ),
        re.compile(
            r"^\s*(?:export\s+)?([A-Za-z_$][\w$]*)\s*:\s*(?:async\s*)?function\s*\("
        ),
        re.compile(
            r"^\s*(?:public\s+|private\s+|protected\s+|static\s+|readonly\s+|async\s+|get\s+|set\s+)*"
            r"([#A-Za-z_$][\w$#]*)\s*(?:<[^>{};=]*>)?\s*\([^;=]*\)\s*(?::\s*[^=]+)?\s*\{"
        ),
    ]

    functions: list[FunctionInfo] = []
    index = 0
    # scan declarations
    while index < len(lines):
        window = window_text(lines, index)
        name: str | None = None
        # test signature patterns
        for pattern in patterns:
            match = pattern.match(window)
            # record matches
            if match:
                candidate = match.group(1)
                # skip language controls
                if candidate not in CONTROL_KEYWORDS:
                    name = candidate
                    break
        # advance without matches
        if not name:
            index += 1
            continue

        open_brace = find_open_brace(lines, index, index + 6)
        # require function body
        if open_brace is None:
            index += 1
            continue
        block_end = find_block_end(lines, *open_brace)
        # require closed body
        if block_end is None:
            index += 1
            continue

        start_line = index + 1
        end_line = block_end[0] + 1
        class_name = innermost_class_name(classes, start_line)
        qualname = f"{class_name}.{name}" if class_name else name
        functions.append(
            FunctionInfo(
                path=path,
                name=qualname,
                kind="function",
                start_line=start_line,
                end_line=end_line,
                complexity=js_complexity(lines, start_line, end_line),
                language="javascript",
            )
        )
        index = block_end[0] + 1
    return functions


def parse_functions(path: str, content: str) -> list[FunctionInfo]:
    suffix = Path(path).suffix
    if suffix == ".py":
        return parse_python_functions(path, content)
    return parse_js_functions(path, content)


def best_old_match(
    new_function: FunctionInfo, old_functions: list[FunctionInfo]
) -> FunctionInfo | None:
    same_name = [func for func in old_functions if func.name == new_function.name]
    if same_name:
        same_name.sort(key=lambda item: abs(item.start_line - new_function.start_line))
        return same_name[0]
    return None


# analyze one changed file
def analyze_file(
    repo: Path,
    base: str,
    rev: str,
    changed_file: ChangedFile,
) -> list[TouchedFunction]:
    # read current file
    path = changed_file.path
    current_content = file_at_revision(repo, rev, path)
    # skip deleted files
    if current_content is None:
        return []
    previous_path = changed_file.previous_path or path
    previous_content = file_at_revision(repo, base, previous_path) or ""
    ranges = parse_diff_ranges(repo, base, rev, path, changed_file.previous_path)

    current_functions = parse_functions(path, current_content)
    previous_functions = (
        parse_functions(path, previous_content) if previous_content else []
    )

    touched: list[TouchedFunction] = []
    # collect changed functions
    for function in current_functions:
        # ignore untouched functions
        if not overlaps(ranges.new, function.start_line, function.end_line):
            continue
        previous = best_old_match(function, previous_functions)
        previous_complexity = previous.complexity if previous else 0
        touched.append(
            TouchedFunction(
                current=function,
                previous_complexity=previous_complexity,
                delta=function.complexity - previous_complexity,
            )
        )
    return touched


def print_summary(
    repo: Path,
    base: str,
    rev: str,
    threshold: int,
    touched_functions: list[TouchedFunction],
    skipped_files: list[str],
) -> int:
    total_complexity = sum(item.current.complexity for item in touched_functions)
    total_delta = sum(item.delta for item in touched_functions)
    flagged = [
        item
        for item in touched_functions
        if item.current.complexity > threshold or item.delta > 0
    ]
    touched_functions.sort(
        key=lambda item: (
            item.current.complexity,
            item.delta,
            item.current.path,
            item.current.name,
        ),
        reverse=True,
    )
    flagged.sort(
        key=lambda item: (
            item.current.complexity > threshold,
            item.current.complexity,
            item.delta,
        ),
        reverse=True,
    )

    print(f"Repository: {repo}")
    print(f"Revision: {base}..{rev}")
    print(f"Threshold: {threshold}")
    print()
    print("Totals")
    print(f"- touched functions: {len(touched_functions)}")
    print(f"- post-change complexity: {total_complexity}")
    delta_prefix = "+" if total_delta >= 0 else ""
    print(f"- complexity delta: {delta_prefix}{total_delta}")

    if skipped_files:
        print(
            f"- supported files without touched parsed functions: {len(skipped_files)}"
        )

    print()
    if not touched_functions:
        print(
            "No touched Python or JavaScript/TypeScript functions were parsed from HEAD."
        )
        return 0

    print("Touched Functions")
    for item in touched_functions:
        delta_prefix = "+" if item.delta >= 0 else ""
        print(
            f"- {item.current.path}:{item.current.name} "
            f"[{item.current.language}] lines {item.current.start_line}-{item.current.end_line} "
            f"complexity {item.current.complexity} ({delta_prefix}{item.delta} from {item.previous_complexity})"
        )

    print()
    print("Flagged")
    if not flagged:
        print("- none above the threshold and no positive deltas")
        return 0

    for item in flagged:
        marker = "threshold" if item.current.complexity > threshold else "delta"
        delta_prefix = "+" if item.delta >= 0 else ""
        print(
            f"- [{marker}] {item.current.path}:{item.current.name} "
            f"complexity {item.current.complexity} ({delta_prefix}{item.delta})"
        )
    return 0


# run CLI
def main() -> int:
    args = parse_args()
    repo = repo_root(Path(args.repo).resolve())
    base = resolve_base(repo, args.base, args.rev)

    try:
        files = changed_files(repo, base, args.rev)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1

    touched_functions: list[TouchedFunction] = []
    skipped_files: list[str] = []

    # analyze each changed file
    for changed_file in files:
        try:
            touched = analyze_file(repo, base, args.rev, changed_file)
        except RuntimeError as error:
            print(f"Skipping {changed_file.path}: {error}", file=sys.stderr)
            continue
        # track parsed misses
        if not touched:
            skipped_files.append(changed_file.path)
            continue
        touched_functions.extend(touched)

    return print_summary(
        repo=repo,
        base=base,
        rev=args.rev,
        threshold=args.threshold,
        touched_functions=touched_functions,
        skipped_files=skipped_files,
    )


if __name__ == "__main__":
    raise SystemExit(main())
