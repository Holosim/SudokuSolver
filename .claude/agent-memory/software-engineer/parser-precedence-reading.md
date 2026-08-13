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

**The conflict, still open:** TP-106's negative case is `P-EASY` with line 3 as
`098 000060`, expecting an *illegal character* at r3c4. That line is ten
characters, so strict shape-before-character precedence would report a length
fault instead. The reading implemented is that RTVM-102 measures a line "after
the rules of RTVM-106 are applied" and RTVM-106 classifies interior whitespace
as an illegal character, so whitespace is classified during the shape pass and
outranks that line's own length. Flagged to the Systems Engineer on #6 for
confirmation when RTVM-102 (#10) lands.

**Why:** the two normative sources (RTVM-105 precedence, TP-106 negative case)
genuinely disagree only here, and whichever way it is settled changes a
user-visible diagnostic.

**How to apply:** if the Systems Engineer rules the other way, the fix is one
block — delete the interior-whitespace loop from `findShapeFault` in
`Parser.cpp`; `digitValue` already rejects space and tab in the character pass,
so the length fault takes over with no other change.

Related: [[sudoku-module-layout]]
