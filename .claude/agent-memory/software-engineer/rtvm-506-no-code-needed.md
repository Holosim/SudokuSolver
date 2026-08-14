---
name: rtvm-506-no-code-needed
description: Issue #14 (RTVM-506, static-CRT self-contained exe) required zero source changes — the static-CRT setup already landed at Generate Code Base and CI's dumpbin clause already runs clean
metadata:
  type: project
---

Recorded 2026-08-14 on issue #14 (RTVM-506, self-contained x64 exe / static
CRT). Same shape as [[rtvm-500-no-code-needed]]: "prove it, fix if it isn't
true" turned out to be pure verification.

**What was checked before concluding nothing needed to change:**
- `src/SudokuSolver/SudokuSolver.vcxproj` and `src/SudokuCore/SudokuCore.vcxproj`
  already have `RuntimeLibrary=MultiThreaded` (Release) /
  `MultiThreadedDebug` (Debug) — `/MT` / `/MTd`, exactly `docs/SDD.md` §3.2's
  row. This was set at Generate Code Base (#5, merged `85bab27`) and never
  touched since.
- `tests/SudokuSolver.Tests.vcxproj` stays `MultiThreadedDLL` /
  `MultiThreadedDebugDLL` (`/MD`/`/MDd`) per the §3.7 pre-authorised
  exception for `CppUnitTestFramework` — see [[msvc-cppunittest-crt]]. This
  doesn't touch the delivered exe's CRT, so it's irrelevant to RTVM-506
  itself; confirmed rather than assumed.
- No source file in `src/SudokuSolver/` includes anything beyond the C++
  standard library plus `<windows.h>` (confined to `StdinChannel.cpp`'s
  platform seam, see [[console-layer-platform-seam]]), and the only Win32
  calls made are `GetStdHandle`, `GetFileType`, `GetConsoleMode`, `ReadFile`
  — all `KERNEL32.dll`. Nothing pulls in an extra system DLL beyond the
  stock baseline.
- `docs/RTVM.md` §9.2/§9.4 already records that CI's Windows workflow
  (`windows-verification.yml`, built by issue #23) runs `dumpbin /dependents`
  on the delivered exe as one of its steps and that clause has **already
  executed clean** at SHA `4a849b7`: only `KERNEL32.dll` imported, no
  `MSVCP140.dll` / `VCRUNTIME140*.dll`. RTVM-506's matrix row was already
  "In Implementation" with Commit `85bab27` for exactly this reason — the
  source-level requirement was done, only the Test Engineer's formal
  ruling (issue #14 itself, per §9.2's explicit routing) was outstanding.
- §9.4 row A-1 already records the SA-level call that the literal
  "clean machine with no VC++ runtime ever installed" clause is
  unobservable on any rentable/hosted machine (they all ship the runtime)
  and that the `dumpbin` evidence is the substantive assertion — matching
  this issue's own body text pre-empting exactly that question.
- g++ compile-check (`-std=c++17 -O2 -DNDEBUG -Wall -Wextra`) of every
  `SudokuCore`/`SudokuSolver` source together, plus a live run of
  `samples/easy.txt`, both succeeded — nothing regressed since #5.

**How to apply:** when an RTVM item's Design pointers section reads like a
checklist against settings that already exist, check the settings directly
(don't trust "it should be done") before concluding there's no code to
write. If the RTVM matrix's own §9 already narrates that the source-level
work is done and only a Test Engineer verdict / clean-machine evidence is
outstanding, say that explicitly in the hand-off — cite the SHA the
evidence was taken at — rather than re-deriving it from scratch or
silently doing nothing.

Related: [[rtvm-500-no-code-needed]], [[msvc-cppunittest-crt]],
[[no-msvc-in-agent-runner]], [[console-layer-platform-seam]].
