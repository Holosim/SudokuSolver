---
name: msvc-cppunittest-crt
description: CppUnitTestFramework links the dynamic CRT, so a /MT delivered exe forces the test project to compile core sources itself
metadata:
  type: feedback
---

A VS native unit test project (`Microsoft::VisualStudio::CppUnitTestFramework`)
ships linked against the **dynamic** CRT. If the delivered exe must be `/MT`
(static CRT, no redistributable), the test DLL cannot both be `/MD` and link a
`/MT` static library — MSVC's `detect_mismatch` fails the link with LNK2038.

**Why:** SudokuSolver's RTVM-506 requires a self-contained exe, so `/MT` is not
negotiable for `SudokuSolver.exe`; `docs/SDD.md` §3.7 pre-authorised `/MD` for
the test project alone.

**How to apply:** keep the app and the static core at `/MT`, set the test
project to `/MD`/`/MDd`, and have the test project list the core's `.cpp`
files as its own `ClCompile` items rather than linking `SudokuCore.lib`.
Keep the `ProjectReference` with `LinkLibraryDependencies=false` so build
order and the dependency direction still hold. Adding extra solution
configurations instead does not work — one project builds one configuration
per solution configuration.

Unverified on a real VS 2022 install as of 2026-08-07 (agent runs are Linux;
no MSVC available). If a Windows build shows CppUnitTestFramework linking
happily against `/MT`, simplify back to a plain library link and update this.

Related: [[no-msvc-in-agent-runner]]
