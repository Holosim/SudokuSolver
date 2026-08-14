---
name: rtvm203-204-wallclock-tests
description: How TP-203/TP-204's literal wall-clock unit tests were built in SolverTests.cpp, and the mutation that reveals which code path actually answers the abort outcome
metadata:
  type: project
---

Implemented 2026-08-14 on issue #16. No production code changed — the whole
mechanism (`SolveControl::onPoll`, `nodesExplored`, the RTVM-507 hook's
`minSolveDuration`) already existed from #8/#13; this issue was pure
test-writing against `docs/SDD.md` §3.5's specified shape: the test
implements `SolveControl` itself and drives everything off
`std::chrono::steady_clock` sampled inside `onPoll` — no thread, no sleep.

**TP-203 and TP-204's numbers ("wait 2 s", "10 repetitions", "1 s intervals
for 10 s") were taken literally, not scaled down for CI speed.** They are
quoted verbatim from `docs/RTVM.md` in the issue's own design pointers, and
nothing licensed deviating from them the way I-11/I-20 license deviating from
other numbers. The honest cost: ~20 s for the TP-203 test (10 × 2 s) and
~11 s for TP-204, added once to the suite. Both use `options.pollNodeInterval
= 1` (not the 1024 default) so the wall-clock threshold check inside the
test's own `onPoll` gets fine-grained resolution regardless of how slow the
build is — same choice already made in the existing
`rtvm507_anAbortDuringTheExtensionStopsTheSolveRatherThanRunningToDuration`
test for the same reason.

**Mutation trap worth remembering: `m_aborted` is not what determines the
`Aborted` outcome when the abort happens during the RTVM-507 extension.**
`solve()`'s extension loop returns `SolveReport::aborted(search.nodesExplored())`
*directly* the moment `search.explore()` returns false — it never calls
`search.report()` for that path. So a mutation that stops `poll()` from
latching `m_aborted` (the first thing I tried) proves nothing on P-HARD17,
because P-HARD17's *initial* search finishes in 1 node — far too fast to
ever observe a mid-search abort — and every abort in these tests necessarily
lands inside the extension. The mutation that actually falsifies the test is
disabling the extension loop's own abort check (i.e. `static_cast<void>` the
`explore()` return instead of branching on it). Anyone writing a new
mutation against this code path should target that line, not `m_aborted`.

Second mutation confirmed for TP-204: resetting `m_nodesExplored` inside
`beginNewPass()` (which today only resets `m_solutionsFound`/`m_firstSolution`,
correctly) breaks the strictly-increasing assertion immediately, at sample 2.

Both mutations were applied to `src/SudokuCore/Solver.cpp`, compiled and run
against a throwaway `g++` harness (not the shimmed `CppUnitTest.h` — a real
`main()` linking the actual core `.o` files with shortened durations for a
fast sanity loop), then reverted with `git diff --stat` confirming zero
leftover diff before commit.

Related: [[rtvm-507-diagnostic-hook]], [[solver-search-shape]],
[[no-msvc-in-agent-runner]], [[unit-tests-are-the-software-engineers-to-write]]
