---
name: no-windows-runner
description: Agent runs execute on Ubuntu with no MSVC/VS/msbuild, so Windows-dependent test procedures cannot be executed — only inspected. Includes the substitute harness that does work.
metadata:
  type: project
---

The agent runner for this repo is **Ubuntu with no MSVC, no `msbuild`, and no
Visual Studio**. SudokuSolver is a Windows-only VS 2022 x64 deliverable, so a
large share of `docs/RTVM.md` test procedures cannot be *executed* here — only
inspected.

**Why:** platform constraint of the CI environment, not a defect in any
deliverable. First hit on issue #5 (2026-08-07); the Software Engineer had
already declared the same limitation in their handoff, so it is a standing
condition of the project, not a one-off.

**How to apply:** before reporting a failure, check whether the procedure is
even executable here. Never report "unverifiable on this runner" as a *code*
failure handed back to the Software Engineer — they cannot fix it by
rebuilding, and it loops. State the gap explicitly in the test comment and let
the RTVM record it as partially verified.

Substitutes that do work on the Linux runner, and what each is worth:

- `g++ -std=c++17 -Wall -Wextra -pedantic` over `src/SudokuCore/*.cpp` and
  `src/SudokuSolver/*.cpp` compiles and links clean. Catches real C++ errors;
  proves nothing about MSVC conformance, `/permissive-`, or `/MT` linkage.
- A hand-written `CppUnitTest.h` shim in `/tmp` (`TEST_CLASS` → `class`,
  `TEST_METHOD` → `void f()`, `Assert::AreEqual/IsTrue/IsFalse` throwing) plus
  a driver that `#include`s the test `.cpp` and calls each method by name.
  Executes the assertions for real. Does **not** verify Test Explorer or
  `vstest.console.exe` discovery — that needs Windows.
- Linking that driver against `src/SudokuCore/*.cpp` **only** is a genuine
  demonstration of the RTVM-903 core/console split, not just a grep.

Pure-inspection procedures (TP-902, TP-903, TP-906, and the fixture half of
TP-907) are **fully** executable here — they are greps and byte diffs. See
[[deliv-inspection-coverage]].
