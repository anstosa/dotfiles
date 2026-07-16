---
name: query
description: Answer the user's prompt through read-only investigation, reasoning, and concise reporting without making lasting code changes. Use when the user invokes $query, asks a question that should be answered rather than implemented, requests analysis only, or explicitly requires that the repository working tree remain exactly unchanged including pre-existing modified and untracked files.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Query

## Operating Rule

Answer the user's question. Do not implement requested product or code changes in the active working tree. Treat the repository and filesystem as evidence sources, not as targets for lasting modification.

## Workflow

1. Capture the starting state before investigation:
   - Run `git status --short --untracked-files=all --ignored` from each relevant repository root.
   - Note any pre-existing modified, staged, untracked, or ignored files that must be preserved.
2. Prefer read-only techniques:
   - Inspect files, configs, docs, logs, schemas, tests, git history, and command output.
   - Run tests, builds, type checks, or dry-run commands only when they are needed to answer the question.
   - Avoid commands whose purpose is to edit, format, migrate, generate, commit, push, or otherwise implement a change.
3. If a code change is needed to answer the question:
   - Do the experiment outside the active working tree whenever possible, such as in a temporary copy or disposable worktree.
   - If the active working tree must be touched, first create a restorable checkpoint that preserves tracked edits, staged edits, untracked files, ignored files that matter, permissions, and file contents.
   - Keep a precise list of every temporary file and command used.
   - Restore the active working tree to the exact captured state before finalizing the answer.
4. Before answering, clean up and verify restoration:
   - Remove disposable temp directories created for the investigation unless the user explicitly asked to keep them.
   - Re-run `git status --short --untracked-files=all --ignored` after cleanup and compare it to the starting status.
   - If any non-disposable state differs, fix it before responding. Do not hide restoration failures.

## Temporary Experiment Guidance

Use the least invasive option that can answer the question:

- For static reasoning, do not edit anything.
- For compile or test experiments requiring a patch, use a temporary directory and leave the source checkout untouched.
- For small active-tree experiments that cannot be moved elsewhere, restore with exact reverse edits or saved snapshots, then verify status equality.
- Never use destructive cleanup commands such as `git reset --hard`, `git clean`, stash drops, database resets, or secret resets unless the user explicitly approved that exact operation and it is safe for the pre-existing state.

## Final Response

Include:

- The direct answer to the user's prompt.
- The key evidence used, with file paths, commands, or observed outputs when relevant.
- Whether any temporary code changes were made and where.
- Confirmation that the active git working tree is unchanged/restored, or an explicit warning if restoration could not be completed.
