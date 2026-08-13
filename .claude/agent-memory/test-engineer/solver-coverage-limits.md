---
name: solver-coverage-limits
description: TP-200's two fixtures both solve by propagation alone (nodesExplored == 1), so it never exercises the DFS; what mutants it cannot see, and the randomised-oracle technique that covers the gap.
metadata:
  type: project
---

Established testing issue #8 (RTVM-200, 2026-08-13) against
`src/SudokuCore/Solver.cpp`.

**Both TP-200 fixtures are solved by constraint propagation alone.**
`P-EASY` and `P-HARD17` each report `nodesExplored == 1` — the root node.
TP-200 therefore verifies the propagator and never enters the MRV
branch/backtrack path. `rtvm200_theReportedSolutionComesFromASearchThatRan`
asserts `nodesExplored() > 0`, which the root node satisfies by itself, so it
is not the search-happened check its name suggests.

Mutants TP-200 **cannot** detect (verified by mutating a `/tmp` copy of
`Solver.cpp` and re-running the suite):

- candidates tried in **descending** digit order — normative ascending order
  (`docs/SDD.md` §1.5) is only provable via TP-202 / RTVM-401;
- **hidden singles removed** entirely — a speed feature, still ~5× slower but
  green.

It *does* die on breaking row elimination in `assign`, so it is genuinely
falsifiable, just narrow.

**Why:** a green TP-200 on its own would leave the whole search unevidenced,
and the later solver issues (#11 RTVM-201, #12 RTVM-202, #15/#16 RTVM-203/204,
#15 RTVM-500) all sit on that same untested path.

**How to apply:** on any solver issue, run the randomised cross-check as well
as the named procedure — a from-scratch Python brute-force solver generates
random uniquely-solvable puzzles *and* their solutions, then a small
`/tmp` harness feeds the compact strings to `solve()` and diffs. 60 puzzles
took seconds and 33 of them forced real backtracking. Keep the oracle
independent of repo code; that is the whole point. Same trick answers "is this
fixture actually unique / actually a solution" without trusting anyone's
header. See [[no-windows-runner]] and [[cppunittest-shim-gotchas]] for the
harness itself.

Also worth re-deriving every time: fixtures in
`tests/SudokuSolver.Tests/TestFixtures.h` should be compared byte for byte
against `docs/RTVM.md` §6.1 by extraction, never read side by side.
