---
name: sudoku-solver-project-context
description: SudokuSolver project context — client ask, and the fact that docs/ ships prior-project (elevator sim) template shells that contain no real scope
metadata:
  type: project
---

Client ask (issue #1, 2026-08-04): a Sudoku solver for the **Windows console, in
C++, built with Visual Studio 2022 as the IDE**. That is the entire written
scope as of kickoff.

**The `docs/` tree at kickoff is a trap.** `00_Project_Definition/`,
`01_Business_Analysis/`, `02_Stakeholder_Need/`, `03_RTVM/`,
`04_SystemArchitecture/`, `05_Implementation Planning/` all look like completed
upstream artifacts but are **empty template shells carried over from a prior
elevator-simulator project**. The two Sudoku-named `.docx` files contain only
headings and literal placeholders ("etc.", "<Scenario Description>",
"This first phase."). The `.xlsx` files still contain elevator/building/occupant
content.

**Why:** I lost time on 2026-08-04 extracting text from every `.docx`/`.xlsx`
in `docs/` expecting to find scope, and found none. The only genuinely useful
carry-over is the *column shape* of the old RTVM spreadsheet (Req ID,
Requirement Statement, Stakeholder Need(s), SysML Tag, Notes) and
`docs/Workflow.txt`, which is a real and useful 10-step SE process checklist
(its step 2 "question all gaps, challenge all assumptions, 5 W's" is a good
template for writing an RFI).

**How to apply:** Treat `docs/PROJECT_DEFINITION.md` as the *only* source of
scope. If it doesn't exist, scope doesn't exist — don't mine the legacy
docx/xlsx tree for it, and don't let its apparent completeness suggest the
upstream steps are done.

See [[rtvm-conventions]], [[blocked-without-project-definition]].
