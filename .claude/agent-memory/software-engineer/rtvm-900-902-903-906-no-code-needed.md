---
name: rtvm-900-902-903-906-no-code-needed
description: Issue #21 (RTVM-900, 902, 903, 906 — the DELIV inspection quartet) required zero source changes; every clause TP-900/902/903/906 look for already held on trunk
metadata:
  type: project
---

Recorded 2026-08-14 on issue #21. Same shape as
[[rtvm-500-no-code-needed]] and [[rtvm-506-no-code-needed]]: "execute the
inspection, fix anything found" turned out to be pure verification —
nothing was wrong.

**What was actually checked (not assumed) before concluding that:**
- RTVM-900: `SudokuSolver.sln` + three `.vcxproj` tracked in git, VS2022
  format markers present (`Format Version 12.00`, `VisualStudioVersion =
  17.0.31903.59`); `.gitignore` excludes only `.vs/`/build-output/`.user`,
  never `*.sln`/`*.vcxproj`.
- RTVM-902: grepped for `packages.config`, `vcpkg.json`, `conanfile*`,
  `CMakeLists.txt`/`Makefile`/`meson.build`, NuGet `PackageReference` —
  none anywhere. `AdditionalIncludeDirectories`/`AdditionalLibraryDirectories`
  only ever point at `$(ProjectDir)..\SudokuCore` (in-repo) or
  `$(VCInstallDir)Auxiliary\VS\UnitTest\{include,lib}` (MSVC toolset itself,
  pre-authorised by SDD §3.3 for CppUnitTestFramework).
- RTVM-903: `grep`'d `src/SudokuCore/` for `std::cin`/`cout`/`cerr`/`printf`/
  `argv`/`<iostream>`/`<cstdio>` — zero hits. `SudokuCore.vcxproj` is
  `ConfigurationType=StaticLibrary`. Bare-literal-`9` sweep across
  `src/`+`tests/` (excluding `kBoxSize`/`kGridSize` themselves) turned up
  only puzzle-content digits, line numbers in comments/fixtures, and
  `'9' - '0'` char arithmetic in `GridFormat.cpp` — none of them a grid
  *dimension* literal. `kBoxSize = 3`, `kGridSize = kBoxSize * kBoxSize` is
  still the only place "9" is spelled as a dimension (`Grid.h`).
  `getenv("SUDOKU_DIAG_MIN_SOLVE_MS")` (the RTVM-507 hook, SDD §3.6) is
  still confined to `main.cpp` — `Solver.h`/`.cpp` only take
  `minSolveDuration` as a plain field, confirming SDD §3.6's claim held.
- RTVM-906: `stdcpp17` set in every config of all three `.vcxproj`; `x64`
  is the only `<Platform>` anywhere in the `.sln`/`.vcxproj` files; no
  cross-platform build file anywhere in the repo.
- g++ compile-checked all thirteen `.cpp` files individually (`-std=c++17
  -Wall -Wextra`), core sources compiled with **no console-layer object
  present**, demonstrating the RTVM-903 split the same way TP-903's Windows
  link clause does. Zero warnings.
- All six `.vcxproj`/`.filters` files parse as well-formed XML
  (`xml.dom.minidom`).

**Why no commit was needed beyond this memory update:** `docs/RTVM.md`
already carries `RTVM-902`/`RTVM-906` as `Verified` and `RTVM-900`/
`RTVM-903` as `In Test` with exactly one outstanding clause each (VS2022
IDE-open and MSVC-toolset core-only link — both require an actual MSVC
toolchain, unavailable on this Linux runner per
[[no-msvc-in-agent-runner]]). Nothing in this issue's Design pointers
named a setting that wasn't already correct on trunk.

**How to apply:** for a `DELIV`/Inspection-only issue, don't skip straight
to "nothing to do" — run every grep/check TP-9xx names explicitly and say
so in the hand-off, citing what was checked. Hand off to Test Engineer to
formally execute/rule on the four TPs (they may re-run the Windows
inspection or accept existing §9 evidence); RTVM.md promotion is Systems
Engineer's call after that, not Software Engineer's to pre-empt.

Related: [[rtvm-500-no-code-needed]], [[rtvm-506-no-code-needed]],
[[no-msvc-in-agent-runner]], [[msvc-cppunittest-crt]].
