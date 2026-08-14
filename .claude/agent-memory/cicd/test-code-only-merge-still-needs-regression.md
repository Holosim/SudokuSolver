---
name: test-code-only-merge-still-needs-regression
description: "#16 — a real branch whose only non-docs diff is new TEST_METHODs (no production src/ change) is NOT the docs-only carve-out; it's a code-bearing trunk merge and needs the normal regression-testing note"
metadata:
  type: project
---

On #16 (RTVM-203/RTVM-204, 2026-08-14), the Software Engineer's branch added
two new `TEST_METHOD`s to `tests/SudokuSolver.Tests/SolverTests.cpp` and
changed nothing under `src/`. My first instinct was to treat this like
[[docs-only-merge-no-build-check]]/[[rtvm-506-reverification-merge]] ("no
production code changed, nothing to regress") and wave off the regression
note in my hand-back comment — that was wrong, and I had to edit the comment
before handing off.

**The distinction that matters:** those two prior memories are about
branches whose diff is *only* `docs/RTVM.md` + agent memory — literally
nothing under `tests/` either. #16's diff genuinely touches
`tests/SudokuSolver.Tests/SolverTests.cpp` (151 lines of new test code) even
though `src/` is untouched. New test code landing on trunk is still new code
landing on trunk — it needs the g++ build+suite check pre-merge (which I did
run correctly: regex-driver discovered 65 methods, matching the Test
Engineer's count, 65/65 pass), and per [[branch-and-merge-conventions]]'s
base instruction the hand-back to Systems Engineer should say regression
testing **is** needed, not that it's waived — the `windows-verification`
workflow will have fired on the merge push and that's the Test Engineer's
pass to run, not something my local g++ result substitutes for.

**How to apply:** before writing "no regression needed" in a hand-back
comment, check the actual diff scope, not just "was `src/` touched?" — if
`tests/` changed at all (new methods, new fixtures, anything beyond doc
cross-references), treat it as a normal code merge for the regression-note
purpose, even when the underlying production behavior is unchanged. Only the
docs+memory-only shape gets the waiver.

**Why:** the whole point of routing every trunk merge back through Systems
Engineer with an accurate regression flag is so nothing skips a real
Windows/Test-Engineer pass on the assumption that "no prod code" is the same
test as "no code."
