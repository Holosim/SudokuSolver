---
name: contradiction-pass-and-fault-wording
description: How RTVM-104's contradiction pass is ordered deterministically, and where the RTVM-102..105/RTVM-009/RTVM-403 diagnostics are (and are not) pinned
metadata:
  type: project
---

Recorded 2026-08-13 on issue #10 (RTVM-102).

**The contradiction pass is one row-major scan with three lookup tables, not
three separate row/column/box passes.** `findContradictionFault` in
`Parser.cpp` visits cells in reading order; for each given it checks row,
then column, then box against every earlier given already recorded, and
records the cell into all three `Seen` tables before moving to the next.
RTVM-105 fixes shape → character → contradiction but says nothing about an
order *among* row/column/box, so row-then-column-then-box per cell was
chosen as the one deterministic reading that also happens to make
`P-CONTRA-ROW`/`-COL`/`-BOX` come out exactly as `docs/RTVM.md` §6.1's table
names them (each fixture is machine-verified to carry only one conflict
kind, so this only had to be *a* consistent order, not necessarily this
one — but this one needed no extra justification to pick).

**`InputFault::line` is populated for `RowDuplicate` (the shared row) and
left `0` for `ColumnDuplicate`/`BoxDuplicate`**, because a column or box
duplicate's two cells sit on different lines and nothing in RTVM-104 or
TP-104 asks for a line number there — location is carried entirely by
`first`/`second`. This matches the pre-existing `InputFaultTests.cpp`
expectation (`fault.line == 1` for the row case), which predates the
contradiction pass and was written against a hand-built fault.

**Box numbering in a message is display arithmetic, not a fault-detection
concern**, so it lives in `Messages.cpp` (`boxNumber()`), not in
`InputFault` or the parser: 1..kGridSize, row-major, computed from the
1-based `CellRef` already on the fault. No RTVM item names this scheme; it
was invented because RTVM-104 asks a diagnostic to name "the unit" and "box"
alone doesn't distinguish among nine.

**Only RTVM-401/402/404 and the progress prompt have RTVM-pinned wording**
(`docs/RTVM.md` §6.2's table). RTVM-102, RTVM-103, RTVM-104, RTVM-105,
RTVM-009 and RTVM-403 do not — their TPs assert the *elements* a message
must name (a line, a length, a character, a cell, a digit, a unit, a path),
confirmed explicitly by `docs/RTVM.md` §7 I-18 for RTVM-009's reason text.
`MessagesTests.cpp` therefore asserts substrings, not exact sentences, for
every `FaultKind` — matching that scope rather than over-specifying it.

**`SourceUnreadable`'s reason text goes through `std::strerror`, guarded
against `systemError == 0`** (never produced by `InputSource` today, but the
type doesn't forbid it) — `strerror(0)` is defined behaviour but not a
useful sentence, so `errnoReason()` special-cases it to "reason unknown"
rather than printing whatever the CRT does with `0`.

**How to apply:** if a future issue adds a fourth duplicate-adjacent fault
kind or renumbers boxes, `boxNumber()` and the `Seen`-table scan are the two
places to touch; the wording templates in `Messages.cpp` are one function
per `FaultKind`, so adding a kind is a compile error (exhaustive switch, no
default label) until a case is added — see
[[making-invariants-compile-time]].

Related: [[parser-precedence-reading]], [[making-invariants-compile-time]],
[[unit-tests-are-the-software-engineers-to-write]]
