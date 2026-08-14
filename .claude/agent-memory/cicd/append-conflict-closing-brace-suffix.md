---
name: append-conflict-closing-brace-suffix
description: When two branches each append TEST_METHODs to the same C++ test file, git factors the identical trailing closing braces out of the conflict — the losing side's last method silently needs a brace put back
metadata:
  type: project
---

Two branches each appending new `TEST_METHOD`s to the tail of the same
`TEST_CLASS` (e.g. `tests/SudokuSolver.Tests/SolverTests.cpp`) produce a real
`git merge` conflict, but the conflict markers can be misleading: the file's
trailing boilerplate — the last method's closing `}`, then `};` closing the
class, a blank line, `} // namespace ...` — is byte-identical on both sides
regardless of which method it closes. Git's diff factors that identical
*suffix* out of the conflict block entirely, showing it once, after the
`>>>>>>>` marker.

The trap: whichever side's hunk is shown *first* inside the markers (`HEAD`,
i.e. trunk here) has its **last method's closing brace missing** from what's
displayed — that brace was the shared suffix, consumed once. If you resolve
by simply concatenating both sides' method bodies in order, the result
compiles-looks-fine but is actually missing one `}` for the first side's
final method, with the second side's final method claiming the sole
remaining trailing brace.

**Fix:** after concatenating both sides' methods, put a manual `    }` after
the first side's last method (immediately before the second side's first
comment/`TEST_METHOD`), and let the file's existing trailing boilerplate
(from after the old `>>>>>>>` marker) close the second side's last method as
before. Sanity check afterwards with a brace-balance count
(`python3 -c "s=open(f).read(); print(s.count('{'), s.count('}'))"`) — it
should match, and it's a two-second check against a subtle, hard-to-spot
missing-brace bug that only a compiler would otherwise catch.

**Why:** hit on #13 (2026-08-14) merging `issue-13` (RTVM-507 tests) against
trunk's #12 (`rtvm202_*` tests) — both appended to
`tests/SudokuSolver.Tests/SolverTests.cpp`. The g++ pre-merge build check
(step 3 of [[pre-merge-check-sequence]]) is what would have caught a mistake
here had one been made; it's the reason that check exists.

**How to apply:** any merge conflict in a test file where two branches both
append `TEST_METHOD`s (or any C-family construct with closing-brace
boilerplate) to the same tail location. Related: [[doc-conflicts-on-merge]],
[[merge-conflicts-that-are-id-collisions]], [[pre-merge-check-sequence]].
