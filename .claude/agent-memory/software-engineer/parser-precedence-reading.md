---
name: parser-precedence-reading
description: How RTVM-105's fault precedence was implemented in parseGrid, and the one place the RTVM's own text conflicts with itself
metadata:
  type: project
---

Recorded 2026-08-07 on issue #6 (RTVM-100).

**RTVM-105's precedence is whole-input, not per-line.** `parseGrid` therefore
runs two passes over the nine logical lines — all shape checks first, then all
character checks. A single pass that finished each line before moving on would
report P-MULTIFAULT's `X` at r1c1 ahead of its missing line 9 and fail TP-105.

**The conflict, resolved 2026-08-13 as `docs/RTVM.md` §7 I-15 (ruled before
#10 started):** TP-106's negative case is `P-EASY` with line 3 as
`098 000060`, expecting an *illegal character* at r3c4. That line is ten
characters, so strict shape-before-character precedence would report a length
fault instead. Ruling: interior whitespace outranks the length fault of the
line it is on, and only that — the exception never crosses lines and never
applies to a non-whitespace character. This is exactly the reading #6 shipped
under, so no code changed; only the comments in `Parser.cpp` were reworded to
cite the ruling instead of flagging the question.

**Why:** the two normative sources (RTVM-105 precedence, TP-106 negative case)
genuinely disagreed only here, and whichever way it was settled would change a
user-visible diagnostic.

Related: [[sudoku-module-layout]], [[contradiction-pass-and-fault-wording]]
