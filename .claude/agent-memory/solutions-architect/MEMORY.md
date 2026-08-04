# Solutions Architect — memory

Durable knowledge only: product decisions, client and stakeholder
context, and questions that keep recurring. Task-by-task detail belongs
on the issue itself, not here. Curate this file as it grows — date each
entry, keep it terse, and fold near-duplicates together.

## Index

- [Sudoku Solver — product concept](project_sudoku_solver.md) — one-sentence brief, MVP shape, out-of-scope decisions, and why correctness beats speed here.
- [docs/ tree — what is real](reference_docs_tree.md) — the numbered folders are empty elevator-simulator templates; only `Workflow.txt` and the RTVM column shape carry over.
- [Deliverable requirements pattern](feedback_deliverable_requirements.md) — capture "a project I can open and extend" separately from features; the RTVM will never surface it.

## Product concepts

<!-- Vision and end-to-end user-flow decisions, organized per product
     line. Note anywhere two product lines share a UX pattern or
     interaction model worth reusing rather than re-deriving. -->

- **Sudoku Solver** — see [[project-sudoku-solver]]. Console app, launches
  straight into the core function (no menu); puzzle in via optional file-path
  argument else stdin; solved grid pretty-printed to stdout with distinct exit
  codes. Pattern worth reusing on any future console tool: *no menu for a
  single-action program, argument-or-stdin for input, exit codes always.*

## Client / stakeholder context

- 2026-08-04 — The client briefs in one sentence and expects the architect to
  interview for the rest. Their own `docs/Workflow.txt` §2 mandates "question
  all gaps, challenge all assumptions, 5 W's" — so a thorough kickoff
  interview is the expected behaviour, not overreach.
- 2026-08-04 — The client names their IDE in the brief. Treat named tooling as
  a deliverable requirement about the artifact, not an incidental build detail
  — see [[deliverable-requirements-pattern]].

## Open questions log

<!-- Ambiguities that have reached this role more than once. If the same
     kind of question keeps showing up, the concept doc for that product
     line probably needs to address it up front next time. -->

- **Recurring at kickoff, ask up front next time:** input method; grid/size
  limits; performance budget with a *number and a puzzle class*; multiple- vs
  no-solution handling; output format and exit codes; MVP tier boundary. These
  six were the bulk of the Systems Engineer's first RFI and none could be
  assumed. Fold them into the first client interview rather than discovering
  them via escalation.

## Decisions made

- 2026-08-04 — Answered a Systems Engineer RFI with a **draft** `docs/PROJECT_DEFINITION.md` marking every unconfirmed item `[PROPOSED]` rather than deciding on the client's behalf — proposals with recommended defaults let the client confirm in one reply without me inventing intent.
- 2026-08-04 — Recommended-default form for scope interviews: put every open decision to the client *with* a recommended answer, so silence-cost is low and a single "all defaults" reply unblocks the pipeline.
- 2026-08-04 — Algorithm choice and test-framework choice are explicitly **not** architect decisions on this project; redirected to the Systems Engineer as *how*, not *what*.
