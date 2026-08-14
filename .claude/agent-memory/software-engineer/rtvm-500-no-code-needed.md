---
name: rtvm-500-no-code-needed
description: Issue #15 (RTVM-500) required zero source changes — how to recognise a "measurement, not implementation" issue and what to still verify before handing off
metadata:
  type: project
---

Recorded 2026-08-14 on issue #15 (RTVM-500, performance budget).

The issue text itself says it: "the design ... is chosen with roughly three
orders of magnitude of margin against this budget, so this issue should be a
measurement rather than an optimisation exercise." That was true. Nothing in
`src/` changed.

**What was actually verified before concluding that:**
- `IMPLEMENTATION_PLAN.md` line 51 says #15 "needs a real process and the
  unsolvable case to time" — both are dependency-gated (#9, #11) and were
  already closed, so the precondition for "nothing to build" was real, not
  assumed.
- Release `vcxproj` already has `Optimization=MaxSpeed` + `NDEBUG` (SDD §3.2)
  — checked directly, not inferred from an earlier issue's say-so.
- The RTVM-507 hook (`SolveOptions::minSolveDuration`) is read from the env
  var by the console layer but is **unused inside `Solver.cpp`**
  (`TODO(RTVM-507)`, that TODO belongs to #13). Unconditionally inert today
  regardless of what `SUDOKU_DIAG_MIN_SOLVE_MS` is set to — even stronger
  than "inert when unset," which is all this issue's Design pointers require.
- Local proxy: compiled with `g++ -std=c++17 -O2 -DNDEBUG` (Release-equivalent
  flags per [[no-msvc-in-agent-runner]]) and ran 10 consecutive launches each
  of `P-EASY`/`P-HARD17`/`P-UNSOLVABLE`. Process-launch + shared-runner jitter
  dominates (2 ms typical, one 168 ms outlier on `hard17`), everything exits
  the RTVM-402 code for its class (0/0/2). This is *not* TP-500 — TP-500 is
  the §6.3 Windows reference machine — it's a sanity check that nothing
  regressed since [[solver-search-shape]]'s figures.

**TP-500 is process-level** (see [[output-layer-scope-per-issue]]), so no
`TEST_METHOD` belongs to this issue either. The Windows harness that runs it
(`tests/windows/run-timing.ps1`, `.github/workflows/windows-verification.yml`)
already exists on `main` — built incidentally by issue #23 (a CI
infrastructure issue, unrelated to RTVM-500 directly) before #15 was ever
worked. `docs/RTVM.md` §9 A-5 already carries real Windows evidence from that
build at SHA `3658728`: easy/hard17 max 20–30 ms, unsolvable max ~12 ms,
30/30 correct exit codes — nowhere near the 10 s ceiling.

**How to apply:** don't assume "no code to write" means "nothing to check."
Confirm the stated preconditions are actually true (deps closed, build flags
correct, the inert-hook claim actually holds by reading the source, not the
doc) before treating an issue as a pure hand-off. When it really is a
measurement-only issue and the measurement instrument already exists
elsewhere in the repo, say explicitly in the hand-off which existing
evidence/SHA answers the requirement and what's left is Test Engineer's
formal ruling (possibly against a fresh SHA tied to this issue's own branch,
so the RTVM Commit(s) column has something to point at), not new
implementation.

Related: [[solver-search-shape]], [[output-layer-scope-per-issue]],
[[no-msvc-in-agent-runner]].
