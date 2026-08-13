---
name: parser-test-scope-and-open-ruling
description: What of TP-100/101/106 is actually runnable before the solver and reporter land, and the now-settled RTVM-102 vs TP-106 whitespace precedence ruling (§7 I-15).
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
deferred rather than reporting the stub as a failure. `docs/RTVM.md` §9.5
carries the re-run trigger: whoever closes the later of #8 and #9 should
expect RTVM-101 and RTVM-106 back. **Status 2026-08-13: #8 (solver) has
passed, #9 is still `status:on-hold`, so the trigger has NOT fired** — the
built console binary still exits `1` with empty stdout and stderr on
`P-EASY`. Re-check #9 before assuming the end-to-end clauses are runnable. Do **not** re-litigate these clauses on
a regression pass — they are recorded as outstanding, not as unknown. See
[[no-windows-runner]] for why the MSVC half is also deferred.

**2. The whitespace-precedence question is SETTLED — ruled 2026-08-13,
`docs/RTVM.md` §7 I-15.** `P-EASY` line 3 as `098 000060` is 10 characters,
and the ruling is that the **illegal character wins**: interior whitespace
is classified during the shape pass and outranks *that line's own* length
check. Expected at unit level: `!ok()`, `kind == IllegalCharacter`,
`character == ' '`, `first == {3,4}`, `line == 3` — never `LineTooLong`.
The exception is deliberately narrow: whitespace only, and only against the
same line's length. `P-LONGLINE` (11 chars, no whitespace) is still
`LineTooLong` on line 5, and `P-MULTIFAULT` (8 lines *and* an `X`) still
reports the missing line. Verified as-implemented on trunk `3bc1b22`.

**Why:** the two documents genuinely disagreed as written; the Systems
Engineer ratified the implemented reading rather than changing the code.

**How to apply:** when testing #10 (RTVM-102/104, fault reporting), the
expected result for that fixture is fixed — a `LineTooLong` there is now a
real failure, not an open question. `P-MULTIFAULT` / `P-MULTIFAULT-9`
behave identically under either reading, so they never settle it.
