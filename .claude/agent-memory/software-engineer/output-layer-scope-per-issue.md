---
name: output-layer-scope-per-issue
description: docs/SDD.md §3.3 draws a hard line between unit-tested TPs (write TEST_METHODs) and process-level TPs (implement only, Test Engineer runs it) — know which side a RTVM-4xx/0xx item falls on before reaching for a test file
metadata:
  type: project
---

Recorded 2026-08-14 on issue #11 (RTVM-201/RTVM-402).

`docs/SDD.md` §3.3 splits verification into two lanes:
- **Unit tests** (Software Engineer writes `TEST_METHOD`s, see
  [[unit-tests-are-the-software-engineers-to-write]]): TP-100…106,
  TP-200…204, TP-300…302, TP-400.
- **Process-level** (built to a `.exe`, driven by the Test Engineer's
  scripts against the real binary): TP-001…009, TP-401…406, TP-500…507.

TP-400 (grid format) is the one OUT item that's unit-testable, because
`formatGrid()` is a pure core function. TP-401 onward (non-unique note,
no-solution statement, invalid-input diagnostic, abort message, exit
codes, stdout-purity aggregate) all require the whole `main()` wiring —
stream assignment, exit code — so they're process-level even though the
string-producing function underneath (`Messages.cpp`) is trivially unit
material in principle.

**How to apply:** when a requirement's Design pointers cite `Reporter`/
`Messages`/exit codes, don't write a `TEST_METHOD` for it — implement the
wording/wiring, verify it locally with a throwaway driver (see the
`Reporter::report()` round-trip check in #11: construct a `SolveReport`,
run it through `Reporter`, assert the ostringstream contents and the
returned `ExitCode`), and say in the hand-off that TP-4xx itself is the
Test Engineer's to run against the Windows build. Don't add a
`ReporterTests.cpp`/`MessagesTests.cpp` to `SudokuSolver.Tests.vcxproj` for
these — they're deliberately out of the unit-test project's scope per
§3.3, and adding one would be scope the RTVM didn't ask for.

**`Messages.cpp` fills in one function at a time, across several issues.**
Its header comment carries a running `TODO(RTVM-...)` list; when an issue
lands one message, narrow the TODO list rather than removing the whole
scaffold note — the file stays honestly labeled as partially real for
whichever RTVM item is next (RTVM-400/401/403/404/004 still open as of
#11).

Related: [[unit-tests-are-the-software-engineers-to-write]],
[[solver-search-shape]]
