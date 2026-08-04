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
- The scope decisions I put to the client with recommended defaults are Q1–Q12
  in §4 of `docs/PROJECT_DEFINITION.md`; they consolidate the Systems
  Engineer's 18-question RFI in `docs/RTVM.md` §6. If scope is ever
  re-litigated, those two tables are the map between client-facing decisions
  and requirement line items.
- Out-of-scope list (generation, difficulty rating, hints, GUI, OCR,
  non-9×9, non-Windows) is deliberately recorded as a *decision*. If someone
  proposes one of these, it is a scope change requiring the client, not a
  gap to be filled in.
