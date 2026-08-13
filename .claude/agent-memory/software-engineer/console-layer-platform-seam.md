---
name: console-layer-platform-seam
description: How the console layer stays runnable on the Linux agent while delivering Windows-only code — the three-function seam in StdinChannel.cpp
metadata:
  type: project
---

`src/SudokuSolver/StdinChannel.cpp` is the **only** file in the repository with
a platform `#if`. It holds three seam functions — `acquireStdinHandle`,
`classify`, `readSome` — and everything else in the console layer is portable
line handling on top of them. Added 2026-08-13 under issue #9 (RTVM-003).

**Why:** the deliverable is Windows-only (RTVM-906) but no Windows machine
exists anywhere in this project's loop — the pipeline has no Windows
environment (`docs/RTVM.md` §9.1) and the Test Engineer cannot write files. If
the stdin path were pure Win32, *nobody* could run the program end to end
before acceptance. With the seam, a plain `g++ src/SudokuCore/*.cpp
src/SudokuSolver/*.cpp` builds a working solver and TP-001/002/003/400 can be
executed for real on the agent.

**How to apply:**
- Keep new platform calls inside those three functions. If a fourth is needed
  (issue #17 will need the availability tests), add it as another seam
  function rather than an `#if` in the middle of logic.
- The POSIX branch ships nothing to the client — `SudokuSolver.vcxproj` only
  ever compiles the `_WIN32` side. Say so in the file header so an inspector
  doesn't read it as a cross-platform build (RTVM-906 forbids one).
- A descriptor is carried in the `void* m_handle` the SDD pins as opaque by
  storing `fd + 1`, so fd 0 stays distinguishable from "no handle".
- Files use `std::ifstream` in binary mode — portable, no seam needed. The one
  loose end is `InputFault::systemError`, documented as a `GetLastError` code
  but populated from `errno`; flagged to the Systems Engineer on issue #9.

Related: [[no-msvc-in-agent-runner]], [[sudoku-module-layout]],
[[blocking-is-allowed-before-the-solve]]
