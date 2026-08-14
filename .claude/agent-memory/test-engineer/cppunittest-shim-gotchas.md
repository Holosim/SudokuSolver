---
name: cppunittest-shim-gotchas
description: Practical gotchas when rebuilding the /tmp CppUnitTest.h shim to run this repo's native tests on the Linux runner — namespace qualification and which macros the shim must define.
metadata:
  type: project
---

The substitute harness described in [[no-windows-runner]] has to be rebuilt
from scratch each run (it lives in `/tmp`, deliberately never in the repo).
Two things cost a build cycle each time if forgotten:

1. **`TEST_CLASS` classes live inside a namespace.** This repo puts them in
   `namespace sudoku::test`, so the driver must call
   `sudoku::test::ScaffoldTests`, not `ScaffoldTests`. The compiler error is
   `'ScaffoldTests' has not been declared` on the member-pointer line, which
   reads like a macro problem and is not one. Grep the test `.cpp` for
   `namespace` before writing the driver.
2. **The shim needs more than `TEST_CLASS`/`TEST_METHOD`.** Test sources here
   reference `TEST_METHOD_ATTRIBUTE`, `BEGIN_/END_TEST_METHOD_ATTRIBUTE` and
   `TEST_MODULE_INITIALIZE` (the "Slow" category convention from
   `docs/SDD.md` §3.3). Define them all as no-ops up front.

**Why:** both bit on issue #5's regression pass (2026-08-07) and both look like
product defects for a moment. They are harness bugs — never report them on the
issue.

**How to apply:** whenever running the placeholder or real unit tests on the
Linux runner. Link the driver against `src/SudokuCore/*.cpp` **only** — that
link succeeding with no console-layer object file is the actual RTVM-903
demonstration, and supplying `src/SudokuSolver/*.cpp` would destroy the point
of the exercise.

**The core-only driver also needs its own generated `.cpp` file, not just a
different link line.** The generated driver `#include`s every test `.cpp` it
discovers methods in; if `MessagesTests.cpp`/`ReporterTests.cpp` (the two
files that `#include "Messages.h"`/`"Reporter.h"`, console-layer headers) are
left in that `#include` list, the *compile* fails with a missing-header error
before the link line matters at all — a red herring that looks like a build
regression. Regenerate a second driver source excluding those two files
(grep each test `.cpp` for `#include "<ConsoleLayerHeader>.h"` to find them
programmatically rather than hard-coding the two names, since a future issue
could add more console-layer test files) for the RTVM-903 core-only run,
and keep the full 8-file driver for the regular full-suite run. Confirmed
on #11's regression pass (2026-08-14): full driver 56/56, core-only driver
40/40 (6 classes, `MessagesTests`/`ReporterTests` excluded).
