---
name: console-layer-end-to-end-now-runnable
description: Since issue #9 the whole console binary builds and runs on the Linux agent via the StdinChannel POSIX seam, so the process-level procedures (TP-001/002/003, and §9.5's deferred end-to-end clauses) are executable here.
metadata:
  type: project
---

**As of issue #9 (2026-08-13) the process-level procedures are runnable on the
Linux agent.** `src/SudokuSolver/StdinChannel.cpp` carries a three-function
platform seam (`acquireStdinHandle` / `classify` / `readSome`) with a `#else`
POSIX branch, so `g++ -std=c++17 src/SudokuCore/*.cpp src/SudokuSolver/*.cpp`
produces a binary that really reads a puzzle, solves it and prints the grid.

**Why:** this reverses the assumption in [[no-windows-runner]] that everything
process-level was inspection-only. TP-001/002/003 and the end-to-end halves of
TP-101/TP-106 all executed for real. What is still *not* executable is the
`_WIN32` branch itself — it ships, and is inspection evidence only.

**How to apply:**

- Extract the §6.2 expected block **programmatically** from `docs/RTVM.md`
  (split on the fence after `### 6.2 Normative output format`) and `cmp`
  against raw stdout redirected to a file. `$(...)` strips the trailing
  newline from *both* sides and will hide a missing final terminator —
  `formatGrid` deliberately terminates every line including the last (338
  bytes), so a byte compare is the only way to see that.
- `0<&-` is the POSIX stand-in for the procedures' "stdin closed".
- When a procedure's expected output is a *different* fixture (`S-HARD17`),
  extract that from §6.1 too rather than eyeballing the digits.
- Watch which stub messages are still absent: an exit code can be correct
  while its wording is empty. See [[stub-wording-vs-exit-codes]].

`docs/RTVM.md` §9.5's re-run trigger (RTVM-101/RTVM-106 end-to-end clauses on
the merge of the later of #8/#9) fires on #9's merge. Run early as advance
evidence and say plainly it is advance evidence, not a verdict — the trigger is
keyed to the merge, not the branch.
