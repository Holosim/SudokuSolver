---
name: test-dll-link-set-grows
description: Since #10, the native-suite pre-merge build must link Messages.cpp and Reporter.cpp alongside SudokuCore — not SudokuCore alone — because the test .vcxproj now compiles them into the test DLL too
metadata:
  type: project
---

[[pre-merge-check-sequence]]'s step 4 says "link against `src/SudokuCore/*.cpp`
**only**, with no console object file." That was correct through #9. As of #10
it needs one addition: `src/SudokuSolver/Messages.cpp` and
`src/SudokuSolver/Reporter.cpp` also link into the driver, because
`MessagesTests.cpp`/`ReporterTests.cpp` exercise them directly and the
Software Engineer registered both as `ClCompile` items in
`tests/SudokuSolver.Tests/SudokuSolver.Tests.vcxproj` (confirmed by grepping
that file — it's the source of truth for what to link, not a fixed rule).

Still excluded, and still the point of the exercise: `main.cpp`,
`CommandLine.cpp`, `InputSource.cpp`, `StdinChannel.cpp`, `SolveSession.cpp` —
anything that touches argv/console streams. Linking the driver clean without
those is still the live RTVM-903 layering demonstration; it's just that
`Messages`/`Reporter` turned out not to depend on them either, so the Software
Engineer moved them into the DLL-safe set.

**Why:** the driver failed to link on the first attempt this run (`undefined
reference` to `Reporter::Reporter`, `messages::inputFault`, `messages::cellName`)
before I re-read the test project's `ClCompile` list and added the two files.

**How to apply:** before assuming the link set, grep the test `.vcxproj` for
which `..\..\src\SudokuSolver\*.cpp` entries (if any) it registers, and match
the driver's link line to that — don't hardcode "core only" going forward.
Related: [[pre-merge-check-sequence]].
