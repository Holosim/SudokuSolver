---
name: rtvm-900-902-903-906-deliv-inspection-pass
description: 2026-08-14 issue #21 result — RTVM-903 promoted to Verified via real MSVC link evidence; RTVM-900's A-2 loader clause reconfirmed as a permanent unautomatable gap, not a fresh failure; RTVM-902/906 reconfirmed.
metadata:
  type: project
---

Issue #21 was a pure inspection pass over `DELIV` items RTVM-900/902/903/906
(no source change from the Software Engineer, correctly so — see
[[deliv-inspection-coverage]]). Result, 2026-08-14, branch `issue-21` @
`9d8663d`, Windows evidence run `31839960733` (in-flight for the exact SHA
under test when I picked it up — see [[windows-evidence-reading]]'s note on
that being fair game):

- **RTVM-902, RTVM-906 — reconfirmed Verified, no change.** Re-ran every
  TP-902/906 grep independently (not just re-read the SE's claim): no
  `packages.config`/`vcpkg.json`/`conanfile`/CMake/Makefile anywhere, every
  `Additional{Include,Library}Directories` resolves in-repo or to
  `$(VCInstallDir)Auxiliary\VS\UnitTest`, `stdcpp17` + `x64` only, across all
  three `.vcxproj`.
- **RTVM-903 — now promotable to Verified.** Its one outstanding clause per
  `docs/RTVM.md` was "re-confirm the link demonstration under MSVC rather than
  `g++`". This run's `build-debug.log` shows it directly: the `link.exe`
  invocation for `SudokuSolver.Tests.dll` pulls in only
  `Grid/GridFormat/Parser/SolveControl/SolveReport/Solver.obj` (core) plus
  `Messages.obj`/`Reporter.obj` (console-layer files that take `std::ostream&`
  by injection and contain zero `std::cin/cout/cerr` — confirmed by direct
  grep) — no `main.obj`, `CommandLine.obj`, `InputSource.obj`,
  `SolveSession.obj` or `StdinChannel.obj` anywhere in the link line. The
  `tests.trx` also carries `rtvm903_coreIsUsableWithoutTheConsoleLayer` and
  `rtvm905_testProjectRunsAndLinksTheCore` both `outcome="Passed"` at the
  per-method level (63/63 passed overall). `SudokuSolver.Tests.vcxproj`'s
  `ProjectReference` to `SudokuCore.vcxproj` sets
  `LinkLibraryDependencies=false`/`UseLibraryDependencyInputs=false` and
  instead source-compiles the core `.cpp` files directly into the test DLL —
  a deliberate, documented (`docs/SDD.md` §3.7) pattern, not a structural
  violation; don't flag it as one.
- **RTVM-900 — stays In Test, unchanged, and this is not a new failure.**
  Its outstanding clause (`§9.4 A-2`: the `.sln` opening in the actual VS 2022
  IDE with no migration prompt) is a **standing, already-documented,
  unautomatable gap on the `win25-vs2026` runner image** — `vswhere-instances.json`
  on this run shows only `Visual Studio Enterprise 2026` (`18.8.x`), no `17.x`
  instance, exactly as measured before on issue #23 (`docs/RTVM.md` §9.1.6,
  I-19). Don't re-report this as a fresh defect each time it comes up in an
  inspection issue — check `docs/RTVM.md`'s A-2 row and I-19 first.

Recommendation handed to the Systems Engineer: promote RTVM-903 to Verified
with this run's SHA as evidence; leave RTVM-900 at In Test citing A-2/I-19;
RTVM-902/906 need no table change.
