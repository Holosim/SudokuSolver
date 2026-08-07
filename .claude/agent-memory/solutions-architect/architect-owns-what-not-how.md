---
name: architect-owns-what-not-how
description: On SudokuSolver the client sometimes asks the architect direct engineering questions (threading, algorithms) — record them as architecture-discovery items for the Systems Engineer rather than answering
metadata:
  type: feedback
---

When the client asks me a *how* question directly — 2026-08-07, issue #1:
"will the interrupt require multi-threading, or is there a simpler solution?" —
do not answer it. Record it in `docs/PROJECT_DEFINITION.md` as a named
architecture-discovery item, list the scope constraints any solution must
satisfy, and hand it to the Systems Engineer to answer in `docs/SDD.md`.

**Why:** my role owns *what*, not *how*; an architect-invented implementation
choice becomes an unexamined constraint downstream that engineering then treats
as mandated scope. The client's own workflow puts architecture in the Systems
Engineer's hands. Answering also removes the client's visible record of the
decision, since a comment reply is not a document.

**How to apply:** convert the question into (a) the numbered behavioural
constraints that bound the answer — for the abort prompt: solve continues while
prompting, default is continue, result reported immediately, unattended runs
never block, wall-clock timing — and (b) an explicit statement that the
mechanism is the Systems Engineer's call and scope expresses no preference.
Same treatment already applied to algorithm choice and test-framework choice.
See [[deliverable-requirements-pattern]].
