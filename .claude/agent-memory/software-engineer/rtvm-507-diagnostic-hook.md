---
name: rtvm-507-diagnostic-hook
description: How the SUDOKU_DIAG_MIN_SOLVE_MS long-solve hook was wired in Solver.cpp/main.cpp, and the continuity trap that would silently break it
metadata:
  type: project
---

Implemented 2026-08-14 on issue #13, per `docs/SDD.md` §3.6 (fully specified
by the Systems Engineer — no design decisions were mine to make here).

**The trap: don't rebuild the search object per extension pass.** The
diagnostic extension has to keep polling `SolveControl` and advancing
`nodesExplored` "exactly as the normal search does," and RTVM-204 requires
that counter to be monotonically increasing across the *whole* call to
`solve()`. My first instinct was a fresh `Search` per pass wrapped in a
`SolveControl` adapter that added an offset — but the poll countdown
(`m_nodesUntilPoll`) also resets on a fresh `Search`, and P-HARD17's whole
tree is ~1 node. With `pollNodeInterval` at its default 1024, a rebuilt
`Search` would never reach the threshold within one pass, so `onPoll` would
never fire at all across the entire extension — silently defeating both
RTVM-203 (abort responsiveness) and RTVM-204 (progress counter) at once,
while every existing assertion about "the hook ran for N ms" still passed.

Fixed by reusing **one** `Search` instance across the real search and every
extension pass, adding a `beginNewPass()` method that resets only the
per-pass solution bookkeeping (`m_solutionsFound`, `m_firstSolution`) and
leaves `m_nodesExplored`, `m_nodesUntilPoll` and `m_aborted` untouched. That
also makes "abort during the extension" work for free: `poll()` already
checks `m_aborted` first, so an abort mid-extension unwinds the current
`explore()` call immediately and `solve()` returns `Aborted` instead of the
result it would otherwise have returned unchanged — verified this beats
RTVM-203's 1.0 s latency even with `minSolveDuration` set to 5 s.

**Seeding is factored into `seedGivens()`** so the real search and every
extension pass build an identical scratch `SearchState` from the same code
path — was inline in `solve()` before this issue.

**Console layer parses with `std::strtol`, strict about trailing
characters** (`*end != '\0'` rejects `"500ms"` rather than silently reading
`500`), matching "positive integer... unparseable → inert" literally. The
core still never calls `getenv` (RTVM-903) — only `main.cpp` does.

**Verified by mutation** (not just written, actually run): disabling the
extension entirely, and swallowing an in-extension abort, each broke exactly
one of the four new `SolverTests.cpp` RTVM-507 tests and nothing else.

Related: [[solver-search-shape]], [[unit-tests-are-the-software-engineers-to-write]],
[[no-msvc-in-agent-runner]]
