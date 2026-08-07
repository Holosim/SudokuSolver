---
name: no-windows-build-verification
description: The deliverable is Windows/MSVC but every runner is Ubuntu — what "buildable" can and cannot mean before a merge, and where that gap is owned
metadata:
  type: project
---

The product is a VS 2022 / x64 / C++17 Windows console app, and every agent run
executes on Ubuntu with **no Visual Studio, no MSVC toolset, no `msbuild`**. So
"proven stable and buildable" before a trunk merge cannot mean an MSVC build.

What CI/CD can actually run as a pre-merge sanity check, and did on #5:

```
g++ -std=c++17 -Wall -Wextra -pedantic -Isrc/SudokuCore -Isrc/SudokuSolver \
    src/SudokuCore/*.cpp src/SudokuSolver/*.cpp -o /tmp/check
```

plus running the binary and checking the `samples/*.txt` byte counts. That is
**evidence, never a verdict** (`docs/PROJECT_DEFINITION.md` §7.1, V-1).

The gap is already owned and does **not** block merges: `docs/RTVM.md` §9 and
PROJECT_DEFINITION §7.1 (V-1…V-9), tracked on **#23**. Windows verification is
going onto a `windows-latest` runner; the complete workflow is written and
parked at `docs/ci/windows-verification.yml`, blocked on one repository-owner
action — either granting the relay App `Workflows: read & write` (then CI/CD
installs and maintains it) or a human copying that file into
`.github/workflows/`. Agents cannot push under `.github/workflows/` with the
current token, and `gh workflow run` returns 403.

**Why:** the temptation is either to block merges on an MSVC build that can
never happen here, or to quietly call a `g++` build a pass. Both are wrong; the
project has a written policy instead.

**How to apply:** merge on the Test Engineer's PASS-with-a-stated-gap, and say
plainly in the commit message and issue comment which clauses were unexecuted.
Never mark anything Verified on substitute-toolchain evidence. If option (a)
lands, installing that workflow becomes CI/CD's job.
Related: [[branch-and-merge-conventions]].
