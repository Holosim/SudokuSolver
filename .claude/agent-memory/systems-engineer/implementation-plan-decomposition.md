---
name: implementation-plan-decomposition
description: How to turn an RTVM into downstream issues — the vertical-slice ordering trap, when to group items, and when a no-work requirement still needs an issue
metadata:
  type: feedback
---

# Turning an RTVM into downstream issues

Learned 2026-08-07 (issue #4) decomposing 47 SudokuSolver RTVM items into 17
feature issues plus Generate Code Base.

## The suggested spine will usually put the UI plumbing too late

The natural priority order is data-in → core → data-out → output → UI. But
almost every *test procedure* for an output item is written as "run the program,
expect X on stdout". So the entry point, argument handling and input sourcing
have to exist before any output item can be verified — and the entry point's own
procedures expect the formatted output, so they gate each other.

**Why:** priority order is about value; the dependency graph is about
testability. They disagree exactly here, and the RTVM's TP column is the
authority on which one binds.

**How to apply:** sequence a **first vertical slice** — entry point + input
sourcing + the primary output format — as one issue, immediately after the core
algorithm. Everything downstream then tests against a program that actually
runs. Check for this by reading the TP text of the output items, not the
requirement text: if the procedure says "run", it needs a runnable program.

## The result/report type precedes the core, not follows it

Filing `DATA-OUT` after `CORE` reads naturally but is backwards: the report type
is the core function's *return type*, and the structured-fault type gates every
diagnostic message in `DATA-IN` validation. It belongs immediately after the
input representation.

## Group by shared code path, not by category block

Items were grouped where they share one class or one call chain — validation +
precedence + diagnostic stream in one issue; the prompt timer, the abort, the
non-blocking stdin read and their three timing NFRs in one issue (nine items).
Splitting a single mechanism across issues produces two issues editing the same
two classes in a forced sequence: no concurrency gained, a merge added.

**How to apply:** ask "would these two issues touch the same file?" If yes and
neither can be tested without the other, they are one issue regardless of how
many RTVM IDs that makes.

## A requirement with no build work still needs an issue

Deliverable/inspection items (`DELIV`) are mostly satisfied by the scaffolding
issue. The instinct is to skip creating issues for them. Don't: acceptance
requires every line item to reach `Verified`, and an inspection nobody is
assigned never runs.

**How to apply:** create them as **verification issues** — grouped, late in the
order, with fixes attached if the inspection fails — rather than as re-builds.
Sequence them after the code they inspect exists (a "grep the core for stream
usage" inspection is meaningless before there is a core).

## Aggregate assertions go last, and only once

Requirements phrased "across every outcome…", "no other value is reachable",
"stdout never contains…" cannot be closed by the issue that produces any one
outcome. File them as their own late issue that converges on all the outcome
issues. That convergence point is genuinely serial and should be the only one.

See [[rtvm-conventions]], [[requirements-traps]],
[[sudoku-solver-project-context]].
