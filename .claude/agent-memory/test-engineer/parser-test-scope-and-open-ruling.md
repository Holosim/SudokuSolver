---
name: parser-test-scope-and-open-ruling
description: What of TP-100/101/106 is actually runnable before the solver and reporter land, plus the unresolved RTVM-102 vs TP-106 precedence ruling that will decide a future test's expected result.
metadata:
  type: project
---

Two things about the DATA-IN procedures, established testing issue #6 on
2026-08-07 (`parseGrid`, RTVM-100/101/106).

**1. TP-101 and TP-106 are split procedures — only their unit half is
runnable until #8 (solver) and #9 (reporter/`formatGrid`) land.** Both are
worded end-to-end ("run to the `S-EASY` grid with exit `0`"), but
`Solver`, `Messages`, `Reporter`, `InputSource` and `SolveSession` are all
still scaffold stubs, so the built binary exits `1` with empty stdout *and
empty stderr* for a perfectly valid puzzle.

**Why:** that empty-stderr exit `1` looks exactly like a parser regression
and is not one — it is the console layer's stub state.

**How to apply:** verify the parse half against `SudokuCore` directly
(`parseGrid` + `toCompactString`), and say in the comment which half was
deferred rather than reporting the stub as a failure. Re-run the end-to-end
half when #9 closes. See [[no-windows-runner]] for why the MSVC half is
also deferred.

**2. There is an open Systems Engineer ruling on whether interior
whitespace outranks that line's own length check.** `P-EASY` line 3 as
`098 000060` is 10 characters: strict RTVM-105 precedence (shape →
character) makes it `LineTooLong` on line 3, but TP-106's negative case
asserts `IllegalCharacter` at `r3c4`. The implementation classifies
whitespace during the shape pass so TP-106 is satisfied, and that reading
was flagged to the Systems Engineer for confirmation, not settled.

**Why:** the two documents genuinely disagree; whichever way it is ruled,
one of TP-102 / TP-106 changes its expected result.

**How to apply:** when testing #10 (RTVM-102/104, fault reporting), check
the RTVM for a ruling *before* judging that case. If the ruling went the
other way and the code was not changed, that is a real failure; if no
ruling has been recorded, it is a Systems Engineer question and must be
escalated as such rather than handed back as a code defect. Note that
`P-MULTIFAULT` (8 lines) and `P-MULTIFAULT-9` behave per strict precedence
either way, so they do not distinguish the two readings.
