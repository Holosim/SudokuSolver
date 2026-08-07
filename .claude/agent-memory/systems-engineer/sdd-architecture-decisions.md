---
name: sdd-architecture-decisions
description: SudokuSolver SDD decisions — single-threaded poll instead of a worker thread for the console interrupt, MRV solver, CppUnitTestFramework, env-var diagnostic hook, static CRT
metadata:
  type: project
---

Decisions taken on issue #3 (2026-08-07) and written into `docs/SDD.md`. That
file is authoritative; this is the pointer plus the reasoning most likely to be
questioned later.

## "Do we need multi-threading for a console interrupt?" — no, and the reason generalises

The client asked whether interrupting a long-running console solve requires
threads. It does not. **The apparent need for a thread comes entirely from
assuming that reading a reply means *waiting* for it.** Poll the reply instead
of awaiting it, from inside the long-running loop, and the concurrency
requirement evaporates — along with the atomics, the shutdown race, and the
thread blocked on a console read that cannot be cancelled at exit.

**Why:** this is worth remembering as a general move, not a Sudoku detail. Any
"do X while remaining responsive to Y" requirement on a single-process CLI has
this shape. The precondition is that the long-running work already has a
natural callback point — here it did, because interruptibility and a progress
counter were already separate requirements.

**How to apply:** before specifying a worker thread for responsiveness, check
whether the requirement actually says *wait*, or only says *respond*. If the
latter, cooperative polling is simpler, deterministic, and unit-testable
without a console. Then delete the SDD's Data Architecture section and say in
writing why it is absent, so the next reader knows it was decided.

## The genuinely hard part is non-blocking stdin on Windows, and it is per-handle-type

There is no single Win32 call that non-blockingly tests any standard-input
handle for data. `GetFileType(GetStdHandle(STD_INPUT_HANDLE))` must be
dispatched on: console → `GetNumberOfConsoleInputEvents` + `PeekConsoleInput`
for a pending `VK_RETURN`; pipe → `PeekNamedPipe`; disk file → `ReadFile`;
anything else (including `NUL:`, which is `FILE_TYPE_CHAR` but fails
`GetConsoleMode`) → a null channel that never reads. `std::getline(std::cin,…)`
blocks and must never appear in the solve path.

Also: **one owner of the stdin byte stream.** When the puzzle itself comes from
stdin, the puzzle reader and the control channel must share one buffer, or a
look-ahead in one silently eats bytes the other needed.

## Other choices, with the constraint that actually decided each

- **Solver:** bitmask propagation (naked + hidden singles) + MRV backtracking,
  candidates in ascending digit order (makes "first solution found"
  reproducible), stop at 2 solutions. Rejected dancing links — three orders of
  magnitude of unused headroom is not worth code the client cannot read.
- **Test framework:** `Microsoft::VisualStudio::CppUnitTestFramework`. Decided
  purely by "no third-party dependencies" — GoogleTest/Catch2/doctest all
  require vendoring, and the inspection procedure greps for a committed
  third-party source tree.
- **Static CRT (`/MT`).** Decided by "runs on a clean machine with no
  redistributable". `/MD` would have failed that inspection. Flagged the
  test-DLL linkage as the one place a fallback to `/MD` is acceptable.
- **`/W4` but deliberately not `/WX`.** Warnings-as-errors means a future MSVC
  that adds a warning breaks the *client's* build — against the "clone, open,
  build, no undocumented steps" requirement.
- **Windows SDK left as `10.0`** ("latest installed") rather than pinned to a
  build number, for the same clone-and-build reason.
- **Diagnostic hook is an environment variable, not a CLI switch** — the CLI
  contract already fixes the meaning of argv[1] and says to ignore the rest, so
  a hidden switch would collide with it. An env var sits outside the contract
  entirely.

See [[rtvm-conventions]], [[requirements-traps]],
[[sudoku-solver-project-context]].
