---
name: complexity-review
description: Review McCabe or cyclomatic complexity in code introduced or modified by HEAD, comparing the post-change complexity of touched functions or methods against their pre-commit versions to measure both total complexity and the delta created by the commit. Use when a user asks for a complexity review of the latest commit, wants refactoring suggestions for code changed in HEAD, or wants to know whether recent changes pushed any function past a threshold such as 20.
---

## GPT-5.6 execution guidance

- Lead with the requested outcome, material evidence, caveats, and next action; keep every required fact, decision, validation result, and stop condition.
- Use the smallest task-specific instruction and tool set that can reliably complete the workflow. Add constraints, examples, or tools only for a demonstrated need.
- Define authorization once: perform in-scope local reads, edits, and non-destructive validation automatically; require confirmation only for destructive, external, credentialed, or materially scope-expanding actions.
- Do not use generic “be concise”, “keep it short”, or “minimal text” requirements. Remove filler and repetition first without omitting required deliverables.
- For delegated work, choose the model tier by task shape: Luna for high-volume mechanical work, Terra for routine implementation or read-heavy scans, and Sol for ambiguous, high-risk, or quality-critical reasoning.
- Treat validation evidence as the completion gate, not an agent’s claim of success.


# Complexity Review

Use this skill to inspect only code introduced or modified by `HEAD`. Measure both the current complexity of touched functions and the complexity added by the commit, then turn high scores into extraction suggestions that remove a meaningful middle slice of control flow.

## Workflow

1. Run `scripts/analyze_head_complexity.py` from the target repository root.
   - Default: `python3 <skill-dir>/scripts/analyze_head_complexity.py`
   - Default threshold: `20`
2. Read the script output first, then inspect the actual diff and surrounding code before making recommendations.
3. Prioritize findings in this order:
   - Post-change complexity above the threshold
   - Large positive delta even if the final score stays below the threshold
   - Newly added functions whose full complexity came from `HEAD`
4. Suggest at most three distinct areas for reduction.

## Refactoring Rule

When a touched function exceeds the threshold, do not extract only the outer wrapper or the smallest deep leaf by default. Find a cohesive mid-level block whose removal would cut the caller's complexity by roughly half.

Choose the extraction point that best balances:
- semantic cohesion
- complexity removed
- minimal parameter churn
- a helper name that is obvious from the code's responsibility

Good extraction boundaries often align to one responsibility:
- input normalization
- branching strategy selection
- per-item processing
- state transition handling
- response assembly
- error mapping or recovery handling

## Output

Produce:
1. A short totals section with:
   - total post-change complexity across touched functions
   - total delta introduced by `HEAD`
2. Up to three findings, each including:
   - file and function
   - post-change complexity and delta
   - why the current shape is risky
   - the block you would extract
   - one or two plausible helper names
   - an estimated remaining complexity when that estimate is easy to defend
3. If nothing exceeds the threshold, say so directly and mention the highest remaining scores.

## Limits And Fallbacks

- The bundled script supports Python directly and JavaScript or TypeScript heuristically.
- For unsupported languages or parser misses, prefer repo-native analyzers when available. Otherwise compute a manual estimate from the diff and say that it is an estimate.
- Treat the script as a prioritization tool, not as the final semantic judgment.

## Reference

Read `references/review-rubric.md` when you need the detailed prioritization and helper-selection rubric.
