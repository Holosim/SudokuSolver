---
name: no-msvc-in-agent-runner
description: Agent runs execute on Linux with g++ only — MSVC/msbuild builds cannot be verified here, so use g++ as a proxy and say so
metadata:
  type: project
---

Software Engineer runs for this repo execute on an **Ubuntu** runner. There is
no MSVC, no `msbuild`, no Visual Studio — but `g++` is present.

**Why:** this project's deliverable is a VS 2022 x64 solution (RTVM-900,
RTVM-906), so "it builds" can never be demonstrated in the run that writes the
code. That first happens on the Test Engineer's Windows build.

**How to apply:**
- Compile-check every source with
  `g++ -std=c++17 -Wall -Wextra -Isrc/SudokuCore -Isrc/SudokuSolver ...`
  before handing off. It catches the large majority of real errors.
- Keep Windows-only API calls out of headers and confined to a small number of
  `.cpp` files, so the rest stays g++-checkable (`StdinChannel` is the one
  place `<windows.h>` belongs).
- Syntax-check test sources against a throwaway `CppUnitTest.h` shim defining
  `TEST_CLASS` / `TEST_METHOD` / `Assert`.
- Validate every `.vcxproj` / `.sln` with an XML parser. Note `--` is illegal
  inside an XML comment — easy to write by accident in a prose comment.
- Always state on the issue that the MSVC build is unverified from this run.

Related: [[msvc-cppunittest-crt]]
