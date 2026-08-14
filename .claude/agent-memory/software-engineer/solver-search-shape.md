---
name: solver-search-shape
description: How the RTVM-200 search was built in Solver.cpp, what the measured margins are, and which mutations do and do not falsify TP-200
metadata:
  type: project
---

Recorded 2026-08-13 on issue #8 (RTVM-200).

`solve()` is one search that already produces all three non-abort outcomes:
zero solutions → `NoSolution`, one → `Solved`, two → `SolvedNotUnique`
(`Search::report()`). RTVM-201 (#11) and RTVM-202 (#12) therefore need tests,
not new search code — say so when handing those off so they are not re-planned
as implementation work.

**Node state carries `cells` as well as `candidates`.** `docs/SDD.md` §1.5
lists only candidates, the three used-masks and `unsolvedCount` (≈216 bytes),
but the report has to emit assigned digits, and a single-bit candidate mask
cannot distinguish "assigned" from "one candidate left, not yet propagated".
State is ~300 bytes; copy-to-undo at depth ≤ 81 is still ~50 KB of stack.

**Measured, unoptimised (`-O0`, the pessimistic proxy for a Debug build):**
P-EASY 58 µs, P-HARD17 308 µs (propagation alone finishes it — *1* node),
P-BLANK 1.5 ms, and the adversarial Inkala/Platinum-Blonde class 2–26 ms.
Four orders of magnitude inside RTVM-500's 10 s.

**Mutation results — useful for judging what TP-200 can prove:**
- Breaking row elimination in `assign` → TP-200 fails. Good, it is falsifiable.
- Removing hidden singles entirely → still passes, just slower. Hidden singles
  are a speed feature, not a correctness one.
- Descending digit order, and flipping the MRV tie-break → still pass. TP-200
  *cannot* detect search order on a uniquely-solvable puzzle; only TP-202 can.
  Don't claim ascending order is verified by this issue.
- Dropping *box* elimination → still passes, because the hidden-single sweep
  over box units re-imposes the constraint. A single-constraint mutation is not
  a reliable coverage probe here.

**Confirmed on issue #11 (RTVM-201):** no solver change was needed. Added
`P-UNSOLVABLE` (`P-EASY` with `r1c3` forced to `1` — mutually consistent
givens, so RTVM-104 doesn't catch it; the search must) and two
`TEST_METHOD`s to `SolverTests.cpp`. Proved falsifiability by temporarily
making the zero-solution branch of `Search::report()` return `Solved`
instead — the new test failed as expected, then reverted.

Related: [[unit-tests-are-the-software-engineers-to-write]],
[[sudoku-module-layout]], [[output-layer-scope-per-issue]]
