---
name: project-sudoku-solver
description: Sudoku Solver product line — scope framing, MVP shape, and the deliverable requirement that the client gets an openable VS 2022 project
metadata:
  type: project
---

# Sudoku Solver (Holosim/SudokuSolver, kicked off issue #1, 2026-08-04)

The client's entire written brief was one sentence: a Sudoku solver for the
Windows console, in C++, built in Visual Studio 2022.

**Why:** this is a small, well-understood problem domain, so the risk is not
the algorithm — it is that scope silently defaults to whatever the code ends
up doing. The value the client is buying is a *correct* solver they *own*.

**How to apply:**
- Correctness beats speed wherever the two trade off. Say so when a scope
  question forces the choice.
- "Built using Visual Studio 2022 as an IDE" is a **deliverable requirement**,
  not a build detail — the client is asking for an openable, extensible
  project, not just an .exe. Captured under §6 of
  `docs/PROJECT_DEFINITION.md`. See [[deliverable-requirements-pattern]].
- **Scope was APPROVED 2026-08-04.** The client accepted every recommended
  default and answered the open toolchain question: **C++17, x64, VS solution
  only — no CMake**. §4 of `docs/PROJECT_DEFINITION.md` is now confirmed
  decisions, not questions; all 18 of the Systems Engineer's RFI questions in
  `docs/RTVM.md` §6 are answered there.
- **The one thing the client added themselves:** `SN-5` now requires a long
  solve to *prompt the user intermittently and let them stop it* — they care
  about never being stuck waiting on an apparently hung program. I set the
  concrete numbers (prompt after 5s, repeat every 5s, exit code `3` on abort,
  and must not hang a scripted caller); §4.4. Exit codes are therefore
  `0` solved / `1` invalid / `2` unsolvable / `3` aborted. If a future console
  tool has any operation that could run long, expect this client to want the
  same abortable-progress-prompt treatment.
- Out-of-scope list (generation, difficulty rating, hints, GUI, OCR,
  non-9×9, non-Windows) is deliberately recorded as a *decision*. If someone
  proposes one of these, it is a scope change requiring the client, not a
  gap to be filled in.
