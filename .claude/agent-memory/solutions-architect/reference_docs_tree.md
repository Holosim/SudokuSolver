---
name: reference-docs-tree
description: The docs/ tree is inherited empty template shells from a prior elevator-simulator project — do not mine it for Sudoku scope
metadata:
  type: reference
---

# `docs/` tree — what is real and what is not

Confirmed 2026-08-04 (Systems Engineer extracted every `.docx`/`.xlsx`):

- `docs/00_Project_Definition/`, `01_Business_Analysis/`, `02_Stakeholder_Need/`,
  `03_RTVM/`, `04_SystemArchitecture/`, `05_Implementation Planning…/` are
  **empty template shells carried over from a prior elevator-simulator
  project**. The two Sudoku-named `.docx` files contain only headings and
  literal placeholders; the spreadsheets still hold elevator/building/occupant
  content.
- The only genuinely useful carry-overs are the client's **RTVM column shape**
  (worth matching so their engineers can read ours) and **`docs/Workflow.txt`**
  — the client's own 7-stage systems-engineering process, from stakeholder
  needs through to code scaffolding. `Workflow.txt` §2 ("Question all gaps,
  challenge all assumptions, 5 W's") is effectively the client's stated
  expectation for how the Solutions Architect should run a kickoff interview.

**How to apply:** treat the live artifacts as `docs/PROJECT_DEFINITION.md`,
`docs/RTVM.md`, `docs/SDD.md`, `docs/IMPLEMENTATION_PLAN.md` at the `docs/`
root. Do not cite the numbered legacy folders as prior scope, and do not
re-derive their emptiness — it has been checked once. Related:
[[project-sudoku-solver]].
