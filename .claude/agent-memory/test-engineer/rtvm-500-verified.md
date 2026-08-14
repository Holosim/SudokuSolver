---
name: rtvm-500-verified
description: RTVM-500/TP-500 passed 2026-08-14 with real exit-code-gated data; what's still open for TP-501-504 and why that doesn't block TP-500
metadata:
  type: project
---

RTVM-500 (10 s performance budget) is **verified**, ruled 2026-08-14 on
issue #15, SHA `00d0c381e8bbb6bebd1540dd51185774ae38d07f` (run
`31804870214`). Worst-of-10/worst-of-3-samples: `easy` max 22.2 ms,
`hard17` max 28.6 ms, `unsolvable` max 10.7 ms — all exit-code-gated
(`anyWrongExit:false`), all ~350-1000x under the 10 s ceiling. This
issue needed **no source change** — the Software Engineer's conclusion
that this was a measurement, not an optimisation exercise, held up.

**Why worth remembering:** this is the first time I ruled PASS on
TP-500 using an in-flight run tied to the exact issue-branch tip
(see [[windows-evidence-reading]]'s "fair game" note) rather than
triggering a fresh one or reusing a stale SHA from a hand-off. Confirm
`git diff --stat origin/main issue-N` is empty of product files before
skipping the wider regression pass — that's what actually licenses
treating a "measurement only" issue as low-risk, not just the
Software Engineer's say-so.

**TP-501…504 stay open**, not a defect: `SUDOKU_DIAG_MIN_SOLVE_MS`
still has no observable effect because the RTVM-507 hook
(`SolveOptions::minSolveDuration`) is read but not yet consumed inside
`Solver.cpp`/`main.cpp` (`TODO(RTVM-507)`, scoped to #13). Re-check this
memory once #13 lands — TP-500's own inertness requirement then needs
re-confirming (the hook must stay inert *for TP-500's own four checks*
even after it's wired up for whatever consumes it).

Related: [[windows-evidence-reading]], [[false-pass-from-unchecked-exit-codes]], [[trunk-regression-scope]].
