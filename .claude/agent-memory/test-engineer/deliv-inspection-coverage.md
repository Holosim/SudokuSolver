---
name: deliv-inspection-coverage
description: Which DELIV test procedures (TP-900..907) are fully executable on the Linux runner vs. which have a clause needing Windows, and the checks worth adding beyond the literal procedure text.
metadata:
  type: reference
---

Split of the `docs/RTVM.md` §"DELIV — inspection procedures" items by what can
actually be concluded on this runner. Established on issue #5 (2026-08-07).

**Fully executable (greps and byte diffs):**

- **TP-902** — no `packages.config` / `vcpkg.json` / `conanfile` / NuGet ref;
  every `AdditionalIncludeDirectories` / `AdditionalLibraryDirectories` inside
  the repo, the Windows SDK, or `$(VCInstallDir)`.
- **TP-903** — no `std::cin|cout|cerr|printf|argv|<iostream>|windows.h` under
  `src/SudokuCore/`; bare-`9` grep. Watch for matches that are only in
  *comments* — grep alone will flag those and they are not violations.
- **TP-906** — `<LanguageStandard>stdcpp17</LanguageStandard>` in every
  project, `x64` the only `<Platform>`, no `CMakeLists.txt`/`Makefile`/
  `meson.build`.
- **TP-907, fixture half** — diff `samples/*.txt` against the §6.1 fixtures.
  All five are exactly 90 bytes (9 lines x 9 chars + LF), LF endings, no
  trailing blank line. That byte count is a fast sanity check on its own.

**Has a clause that needs Windows:**

- **TP-900** — git-tracking of `.sln`/`.vcxproj` is checkable; "open in VS 2022
  with no migration prompt" is not.
- **TP-901, TP-905** — require an actual build / test run.
- **TP-904, TP-907 README half** — checkable, but the README is deliberately a
  stub until RTVM-904, so a fail there before that issue lands is expected, not
  a defect.

**Worth checking beyond the literal procedure text** — cheap, and each catches
a real "solution won't load / won't build" class of defect that inspection of
the listed items alone would miss:

- `.sln` project GUIDs match each `<ProjectGuid>`, and every
  `<ProjectReference><Project>` GUID resolves to a project in the solution.
- Every `<ClCompile>`/`<ClInclude>` Include path exists on disk, and no
  `src/`/`tests/` source is missing from all projects.
- Each `.vcxproj` and `.vcxproj.filters` parses as XML.
- `.gitignore` does not exclude the very files RTVM-900 requires be tracked
  (`*.sln`), and `.gitattributes` does not force CRLF onto `samples/*.txt`,
  which would break TP-907's byte diff on a Windows checkout.

See [[no-windows-runner]] for what to do about the unexecutable clauses.
