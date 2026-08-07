---
name: sudoku-module-layout
description: Where the SudokuSolver scaffold put things and which decisions are load-bearing rather than taste
metadata:
  type: project
---

The scaffold laid down on 2026-08-07 (issue #5) fixes a few things that later
issues must not quietly undo.

**Why:** several `DELIV` inspections (TP-900…907, TP-506) read the build
configuration rather than any runtime behaviour, so these are requirements
wearing the costume of project settings.

**How to apply — do not change without a requirement saying so:**
- `kGridSize` is derived from `kBoxSize` in `src/SudokuCore/Grid.h` and is the
  only place a grid dimension is spelled. TP-903 greps for a bare literal
  otherwise.
- `SudokuCore` may not name a stream, the command line, or a console API —
  *including in comments and in its `.vcxproj` comments*, since TP-903 is a
  grep-based inspection.
- Debug|x64 and Release|x64 are the only configurations. No Win32/x86, no
  `CMakeLists.txt`/`Makefile`/`meson.build` ever (client decision D-7).
- `samples/*.txt` are pinned to LF in `.gitattributes`; TP-907 diffs them
  byte for byte against `docs/RTVM.md` §6.1 and the repo default is
  `text=auto`.
- The README must never mention `SUDOKU_DIAG_MIN_SOLVE_MS` — TP-507 inspects
  for its absence there and its presence in `docs/SDD.md` §3.6.

Related: [[msvc-cppunittest-crt]], [[no-msvc-in-agent-runner]]
