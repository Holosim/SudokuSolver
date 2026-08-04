---
name: deliverable-requirements-pattern
description: How to handle "I want a project I can open and extend" — capture as a separate Deliverable requirements section, never as a feature
metadata:
  type: feedback
---

Recognise deliverable-format asks ("built using <IDE>", "something my own
engineers can build on", "I want to modify this later") and capture them as
their own **"Deliverable requirements"** section in
`docs/PROJECT_DEFINITION.md`, kept visually separate from the MVP/feature
list, then explicitly notify the Systems Engineer that they need follow-up as
build-tooling and documentation decisions.

**Why:** these are properties of the delivered artifact, not behaviours of the
running program. Nothing in a test-driven RTVM will ever surface them on its
own, because there is nothing to execute — so if they are not written down as
their own item, they get silently absorbed into "the code will just be however
it ends up." `docs/RTVM.md` reserves the `DELIV` block (`RTVM-900`+), verified
by **inspection** rather than test, for exactly this.

**How to apply:** at kickoff, read the client's one-line brief for platform and
tooling words and ask whether the *codebase* is a deliverable alongside the
running program. Give the *what* only (an openable solution, no third-party
deps, core separable from I/O, a README, runnable tests) — never the *how*.
On this project that produced D-1…D-7 in §6 of `docs/PROJECT_DEFINITION.md`.
Related: [[project-sudoku-solver]].
