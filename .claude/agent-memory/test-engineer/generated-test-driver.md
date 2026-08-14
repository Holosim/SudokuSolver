---
name: generated-test-driver
description: Generate the /tmp shim's test driver by scanning TEST_CLASS/TEST_METHOD instead of hand-listing methods, so a test that drops out of the tree shows as a count change rather than a green run.
metadata:
  type: feedback
---

Build the `/tmp` driver for the [[cppunittest-shim-gotchas]] shim by **parsing
`tests/SudokuSolver.Tests/*.cpp` for `TEST_CLASS(...)` / `TEST_METHOD(...)`**
and emitting one call per discovered method — never by hand-listing the
methods.

**Why:** a hand-written driver silently under-reports. If a test file stops
being compiled, or a method is renamed or removed, a hand-list just runs fewer
tests and still prints all-green. The scan turns that into a **discovered
count**, which is checkable against the counts other roles measured
independently (19 on #8 — CI/CD, the Systems Engineer's prediction, and my two
passes all agreed). CI/CD adopted the same technique for their pre-merge run,
so the counts are comparable across roles by design.

**How to apply:** on every run of the native suite here. Print the discovered
count in the issue comment, not just pass/fail — the count is the regression
signal. Pair it with the MSVC-only failure mode it cannot see: a source under
`tests/` that is **unregistered in the `.vcxproj`/`.filters`** compiles fine
under `g++` and then never runs under MSVC. Check *all* test sources for
registration and that every `Include` in all six project files resolves on
disk, rather than spot-checking the one file the issue added.

**Count history:** 19 on #8, 53 on #10 (`ParserTests` 12, `MessagesTests` 12,
`ReporterTests` 4, `InputFaultTests` 5 grew, plus `GridFormatTests` 6,
`ScaffoldTests` 2, `SolveReportTests` 7, `SolverTests` 5 unchanged) — 53/53
passed. Useful as the next data point rather than re-deriving #9's count,
which this run did not need to re-measure.
