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
PROJECT_DEFINITION §7.1 (V-1…V-10), tracked on **#23**.

**Since 2026-08-13 this is only half true — a real MSVC run now exists.** Trunk
commit `fc23901` installed `.github/workflows/windows-verification.yml` (route
(b): a human copied it from `docs/ci/`, since agents still cannot push under
`.github/workflows/` — that limitation is permanent and is now V-10). It runs on
`windows-latest` on **every push to `main` and to `issue-*`**, so:

- A trunk merge now triggers a genuine `msbuild` Debug|x64 + Release|x64 build,
  `vstest.console.exe` discovery, `dumpbin /dependents`, and any
  `tests/windows/*.ps1` the Test Engineer has added. Evidence lands as the
  `windows-evidence-<sha>` artifact, 90-day retention, plus a per-TP table in
  the job summary.
- **It is evidence, not a verdict (W-2)** — it never labels, never pushes, never
  marks anything Verified. Most steps are `continue-on-error`, so a green run
  does not mean every clause passed; read the summary table, which says
  `executed` or `NOT-RUN` per TP.
- So CI/CD's honest post-merge line changed: instead of "MSVC unexecuted, owned
  on #23", point the Test Engineer at the workflow run and let them rule. The
  g++ pre-merge check below is still worth running — it fails in seconds rather
  than after a 45-minute Windows job.
- **Push the merge LAST.** The workflow sets `concurrency: windows-verification-
  ${{ github.ref }}` with `cancel-in-progress: true`, so every later push to
  `main` kills the run already going. On #9 the merge commit's own run was
  cancelled twice by CI/CD's two follow-up memory pushes, leaving the merge SHA
  with no evidence at all. Commit memory first and merge second, or — if that
  isn't possible — cite the *final* trunk SHA to the Test Engineer and state
  that its tree is identical to the merge commit's outside
  `.claude/agent-memory/` (`git diff --stat <merge> <tip>` proves it in one
  line). Never cite a SHA whose run was cancelled.

**Why:** the temptation is either to block merges on an MSVC build that can
never happen here, or to quietly call a `g++` build a pass. Both are wrong; the
project has a written policy instead.

**How to apply:** merge on the Test Engineer's PASS-with-a-stated-gap, and say
plainly in the commit message and issue comment which clauses were unexecuted —
now including "the Windows run for this SHA is the artifact to read, and it is
the Test Engineer's to interpret." Never mark anything Verified on
substitute-toolchain evidence, and never on a green Windows run either; that is
still a status the Systems Engineer writes.
Related: [[branch-and-merge-conventions]], [[lock-before-merging-docs]].
