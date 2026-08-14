---
name: tp202-instrumentation-needs-p-blank
description: Why TP-202's "assert the solver stopped after the second solution" clause cannot be proven on P-NONUNIQUE alone, and what fixture actually proves it
metadata:
  type: project
---

Recorded 2026-08-14 on issue #12 (RTVM-202, RTVM-401).

TP-202 (`docs/RTVM.md`) ties its instrumentation clause — "assert via
instrumentation that the solver stopped after finding the second solution
and did not continue searching" — to `P-NONUNIQUE` in the same sentence as
the outcome/grid assertions. Measured directly against `Solver.cpp`:
`P-NONUNIQUE` explores exactly 3 nodes (root + 2 children) whether
`SolveOptions::maxSolutions` is 2 or 1,000,000. After propagation it has
exactly one branch cell with exactly two viable candidates, so the search
tree is naturally exhausted at the same point regardless of the cap — a
node-count comparison on this fixture cannot distinguish "stopped because
two were found" from "kept going and found nothing more because there was
nothing more to find". This is unfalsifiable by construction, not a bug.

`P-BLANK` (81 empty cells) does discriminate: nodesExplored strictly grows
with the cap (49 nodes at maxSolutions=2, 51 at 3, 52 at 4, measured
`-O0`). Raising the budget by one measurably grows the search, which is
what actually proves the cap is bounding work rather than the tree running
out on its own. The issue's own design notes already pointed at `P-BLANK`
for a different reason (it must resolve instantly rather than hang, for
TP-505) — same fixture, second use.

`SolverTests.cpp::rtvm202_stoppingAtTwoSolutionsBoundsTheSearch` uses
`P-BLANK` for this instead of `P-NONUNIQUE`, with the reasoning inline in
the test's comment and flagged in the issue #12 hand-off rather than
silently substituted. If a future TP-202 rewording addresses this, update
both.

Related: [[solver-search-shape]], [[unit-tests-are-the-software-engineers-to-write]]
