---
name: rtvm-conventions
description: RTVM ID scheme, category tags/ID blocks, verification vocabulary and status vocabulary established for the SudokuSolver project
metadata:
  type: project
---

RTVM conventions established 2026-08-04 and recorded in full in `docs/RTVM.md`
(sections 1–4 — that file is authoritative, this is the pointer).

- Requirement IDs: `RTVM-nnn`, zero-padded, allocated in **category blocks** so
  the number alone identifies the functional area: `UI` 001–099, `DATA-IN`
  100–199, `CORE` 200–299, `DATA-OUT` 300–399, `OUT` 400–499, `NFR` 500–599,
  `DELIV` 900–999. IDs are never reused or renumbered; a dropped requirement
  stays in the table as `Withdrawn`.
- Stakeholder needs are `SN-<n>` and belong to the Solutions Architect in
  `docs/PROJECT_DEFINITION.md`. Test procedures are `TP-nnn[letter]`, numeric
  part matching the requirement they verify.
- Verification vocabulary: Test / Demonstration / Analysis / Inspection.
  `DELIV` items are Inspection and get specified in `docs/SDD.md` build
  conventions rather than a runtime test.
- Status vocabulary: Draft → Approved → In Implementation → In Test → Verified,
  plus Blocked / Withdrawn.

**Why:** The block-per-category scheme came from wanting an ID to be
self-describing in commit messages and issue titles (`[RTVM-014] ...`) without
a lookup. The `SN-#` / "Requirement Statement" / "SysML Tag" column shape
matches the client's own prior RTVM spreadsheet
(`docs/03_RTVM/RequirementsTraceabilityMatrix.xlsx`), so their engineers read
ours without retraining.

**How to apply:** Use these when adding any line item. Don't invent a parallel
scheme per functional area or per product line — extend the blocks instead.

See [[sudoku-solver-project-context]].
