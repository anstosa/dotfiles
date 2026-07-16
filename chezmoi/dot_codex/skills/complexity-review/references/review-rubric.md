# Review Rubric

Use this rubric after running `scripts/analyze_head_complexity.py`.

## Prioritization

Rank touched areas by:
1. post-change complexity above threshold
2. positive delta introduced by the commit
3. semantic centrality of the complex block

Prefer reporting a function with `24 (+3)` over one with `11 (+8)` unless the lower-score function is clearly the main review risk.

## What Counts As "Roughly Halve It"

Aim for an extraction that removes about 40 to 60 percent of the caller's decision points.

Examples:
- `22` should usually land near `9-13`
- `28` should usually land near `11-17`

Do not force arithmetic precision. Favor a semantically clean helper over a numerically perfect split.

## Choosing The Helper Boundary

Evaluate candidate slices in this order:
1. Does the slice represent one responsibility with a clean name?
2. Does it sit near the middle of the control-flow tree rather than only at the edges?
3. Does it remove a substantial chunk of complexity?
4. Can it be extracted without introducing awkward shared mutable state?

Avoid recommending:
- pure guard-clause extraction unless that is where most branching really lives
- extraction of a tiny nested branch that barely changes the caller
- splitting purely by line count instead of behavior

## Suggested Response Shape

Use short findings. A good finding contains:
- `path:function`
- `complexity N, delta +M`
- one sentence on why the current branch structure is hard to reason about
- one sentence describing the proposed helper and why it is the best boundary
- one or two helper names

## Sanity Checks

Before finalizing a suggestion:
- verify the suggested block is actually touched or materially affected by `HEAD`
- confirm the helper boundary is semantically meaningful, not just mathematically convenient
- prefer three strong findings over a longer weak list
